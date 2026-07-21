package com.el7reef.app

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer

@UnstableApi
internal class PrideVideoExporter(
    private val context: Context,
) {
    interface Callback {
        fun onCompleted(file: File)

        fun onError(error: NativeExportException)
    }

    private var transformer: Transformer? = null
    private var finished = false

    fun export(
        request: NativePrideVideoExportRequest,
        outputFile: File,
        callback: Callback,
    ) {
        check(transformer == null) { "PrideVideoExporter instances are single-use" }

        val composition = buildComposition(request)
        val listener =
            object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    if (finished) return
                    finished = true
                    transformer = null
                    try {
                        validateOutput(outputFile, request)
                        callback.onCompleted(outputFile)
                    } catch (error: NativeExportException) {
                        callback.onError(error)
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    if (finished) return
                    finished = true
                    transformer = null
                    callback.onError(
                        NativeExportException(
                            code = "encoder_failed",
                            message = "Media3 could not encode the Pride video",
                            details =
                                mapOf(
                                    "media3ErrorCode" to exportException.errorCode,
                                    "media3ErrorName" to exportException.errorCodeName,
                                ),
                            cause = exportException,
                        ),
                    )
                }
            }

        val newTransformer =
            Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(listener)
                .build()
        transformer = newTransformer
        try {
            newTransformer.start(composition, outputFile.absolutePath)
        } catch (error: RuntimeException) {
            if (finished) return
            finished = true
            transformer = null
            callback.onError(
                NativeExportException(
                    code = "export_start_failed",
                    message = "Unable to start the Media3 Pride video export",
                    cause = error,
                ),
            )
        }
    }

    fun cancel() {
        if (finished) return
        finished = true
        try {
            transformer?.cancel()
        } finally {
            transformer = null
        }
    }

    private fun buildComposition(request: NativePrideVideoExportRequest): Composition {
        val imageMediaItem =
            MediaItem.Builder()
                .setUri(Uri.fromFile(request.sourceImage))
                .setImageDurationMs(request.durationMs)
                .build()
        val editedImage =
            EditedMediaItem.Builder(imageMediaItem)
                .setFrameRate(request.frameRate)
                .setEffects(PrideVideoEffects.create(context, request))
                .build()
        val sequences =
            mutableListOf(
                EditedMediaItemSequence.withVideoFrom(listOf(editedImage)),
            )

        request.audioFile?.let { audioFile ->
            val audioMediaItem =
                MediaItem.Builder()
                    .setUri(Uri.fromFile(audioFile))
                    .setClippingConfiguration(
                        MediaItem.ClippingConfiguration.Builder()
                            .setEndPositionMs(request.durationMs)
                            .build(),
                    )
                    .build()
            sequences +=
                EditedMediaItemSequence.withAudioFrom(
                    listOf(EditedMediaItem.Builder(audioMediaItem).build()),
                )
        }
        return Composition.Builder(sequences).build()
    }

    private fun validateOutput(outputFile: File, request: NativePrideVideoExportRequest) {
        if (!outputFile.isFile || !outputFile.canRead() || outputFile.length() == 0L) {
            throw invalidOutput("Media3 returned an empty Pride video")
        }

        val tracks = readTrackSummary(outputFile)
        if (tracks.videoMime != MimeTypes.VIDEO_H264) {
            throw invalidOutput(
                message = "Pride video output is not H.264",
                details = mapOf("videoMime" to tracks.videoMime),
            )
        }
        if (request.audioFile != null && tracks.audioMime != MimeTypes.AUDIO_AAC) {
            throw invalidOutput(
                message = "Pride video output is missing its AAC audio track",
                details = mapOf("audioMime" to tracks.audioMime),
            )
        }
        if (request.audioFile != null && tracks.audioSampleCount == 0) {
            throw invalidOutput(
                message = "Pride video output contains an empty audio track",
                details =
                    mapOf(
                        "audioMime" to tracks.audioMime,
                        "audioPayloadBytes" to tracks.audioPayloadBytes,
                    ),
            )
        }
        val audioSampleSpanUs = tracks.audioSampleSpanUs
        if (request.audioFile != null &&
            (audioSampleSpanUs == null ||
                audioSampleSpanUs < MIN_AUDIO_SAMPLE_SPAN_US)
        ) {
            throw invalidOutput(
                message = "Pride video output contains an incomplete audio sting",
                details =
                    mapOf(
                        "audioMime" to tracks.audioMime,
                        "audioSampleCount" to tracks.audioSampleCount,
                        "audioPayloadBytes" to tracks.audioPayloadBytes,
                        "audioFirstSampleTimeUs" to tracks.audioFirstSampleTimeUs,
                        "audioLastSampleTimeUs" to tracks.audioLastSampleTimeUs,
                        "audioSampleSpanUs" to audioSampleSpanUs,
                    ),
            )
        }
        if (tracks.frameRate != null && tracks.frameRate != request.frameRate) {
            throw invalidOutput(
                message = "Pride video output has an unexpected frame rate",
                details =
                    mapOf(
                        "expectedFrameRate" to request.frameRate,
                        "actualFrameRate" to tracks.frameRate,
                    ),
            )
        }

        val metadata = readVideoMetadata(outputFile)
        val dimensionsMatch = metadata.matches(request.width, request.height)
        if (!dimensionsMatch) {
            throw invalidOutput(
                message = "Pride video output has unexpected dimensions",
                details =
                    mapOf(
                        "expectedWidth" to request.width,
                        "expectedHeight" to request.height,
                        "actualWidth" to metadata.width,
                        "actualHeight" to metadata.height,
                        "rotation" to metadata.rotation,
                    ),
            )
        }
        if (metadata.durationMs == null ||
            kotlin.math.abs(metadata.durationMs - request.durationMs) > DURATION_TOLERANCE_MS
        ) {
            throw invalidOutput(
                message = "Pride video output has an unexpected duration",
                details =
                    mapOf(
                        "expectedDurationMs" to request.durationMs,
                        "actualDurationMs" to metadata.durationMs,
                    ),
            )
        }
    }

    private fun readTrackSummary(file: File): TrackSummary {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(file.absolutePath)
            var videoMime: String? = null
            var audioMime: String? = null
            var audioTrackIndex: Int? = null
            var frameRate: Int? = null
            repeat(extractor.trackCount) { index ->
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME)
                when {
                    mime?.startsWith("video/") == true -> {
                        videoMime = mime
                        if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                            frameRate = format.getInteger(MediaFormat.KEY_FRAME_RATE)
                        }
                    }
                    mime?.startsWith("audio/") == true -> {
                        audioMime = mime
                        audioTrackIndex = index
                    }
                }
            }
            val audioSamples = audioTrackIndex?.let {
                readAudioSampleSummary(extractor, it)
            } ?: AudioSampleSummary.empty
            TrackSummary(
                videoMime = videoMime,
                audioMime = audioMime,
                frameRate = frameRate,
                audioSampleCount = audioSamples.count,
                audioPayloadBytes = audioSamples.totalPayloadBytes,
                audioFirstSampleTimeUs = audioSamples.firstSampleTimeUs,
                audioLastSampleTimeUs = audioSamples.lastSampleTimeUs,
            )
        } catch (error: IOException) {
            throw invalidOutput("Unable to inspect the Pride video tracks", cause = error)
        } catch (error: RuntimeException) {
            throw invalidOutput("Unable to inspect the Pride video tracks", cause = error)
        } finally {
            extractor.release()
        }
    }

    private fun readAudioSampleSummary(
        extractor: MediaExtractor,
        trackIndex: Int,
    ): AudioSampleSummary {
        extractor.selectTrack(trackIndex)
        val sampleBuffer = ByteBuffer.allocate(MAX_AUDIO_SAMPLE_BYTES)
        var sampleCount = 0
        var totalPayloadBytes = 0L
        var firstSampleTimeUs: Long? = null
        var lastSampleTimeUs: Long? = null
        while (true) {
            sampleBuffer.clear()
            val sampleSize = extractor.readSampleData(sampleBuffer, 0)
            if (sampleSize < 0) break
            if (sampleSize > 0) {
                if (firstSampleTimeUs == null) {
                    firstSampleTimeUs = extractor.sampleTime
                }
                sampleCount += 1
                totalPayloadBytes += sampleSize
                lastSampleTimeUs = extractor.sampleTime
            }
            if (!extractor.advance()) break
        }
        return AudioSampleSummary(
            count = sampleCount,
            totalPayloadBytes = totalPayloadBytes,
            firstSampleTimeUs = firstSampleTimeUs,
            lastSampleTimeUs = lastSampleTimeUs,
        )
    }

    private fun readVideoMetadata(file: File): VideoMetadata {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            VideoMetadata(
                width = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                height = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                rotation = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION),
                durationMs = retriever.longMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION),
            )
        } catch (error: RuntimeException) {
            throw invalidOutput("Unable to inspect the Pride video metadata", cause = error)
        } finally {
            try {
                retriever.release()
            } catch (_: IOException) {
                // The export result has already been read; release failure is non-actionable.
            }
        }
    }

    private fun MediaMetadataRetriever.intMetadata(key: Int): Int? =
        extractMetadata(key)?.toIntOrNull()

    private fun MediaMetadataRetriever.longMetadata(key: Int): Long? =
        extractMetadata(key)?.toLongOrNull()

    private fun invalidOutput(
        message: String,
        details: Map<String, Any?>? = null,
        cause: Throwable? = null,
    ) =
        NativeExportException(
            code = "invalid_output",
            message = message,
            details = details,
            cause = cause,
        )

    private data class TrackSummary(
        val videoMime: String?,
        val audioMime: String?,
        val frameRate: Int?,
        val audioSampleCount: Int,
        val audioPayloadBytes: Long,
        val audioFirstSampleTimeUs: Long?,
        val audioLastSampleTimeUs: Long?,
    ) {
        val audioSampleSpanUs: Long?
            get() = audioFirstSampleTimeUs?.let { first ->
                audioLastSampleTimeUs?.minus(first)
            }
    }

    private data class AudioSampleSummary(
        val count: Int,
        val totalPayloadBytes: Long,
        val firstSampleTimeUs: Long?,
        val lastSampleTimeUs: Long?,
    ) {
        companion object {
            val empty =
                AudioSampleSummary(
                    count = 0,
                    totalPayloadBytes = 0,
                    firstSampleTimeUs = null,
                    lastSampleTimeUs = null,
                )
        }
    }

    private data class VideoMetadata(
        val width: Int?,
        val height: Int?,
        val rotation: Int?,
        val durationMs: Long?,
    ) {
        fun matches(expectedWidth: Int, expectedHeight: Int): Boolean {
            if (width == expectedWidth && height == expectedHeight) return true
            val isQuarterTurn = rotation == 90 || rotation == 270
            return isQuarterTurn && width == expectedHeight && height == expectedWidth
        }
    }

    private companion object {
        const val DURATION_TOLERANCE_MS = 50L
        const val MIN_AUDIO_SAMPLE_SPAN_US = 900_000L
        const val MAX_AUDIO_SAMPLE_BYTES = 64 * 1024
    }
}
