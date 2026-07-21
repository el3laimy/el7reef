package com.el7reef.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.platform.app.InstrumentationRegistry
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@LargeTest
@UnstableApi
@RunWith(Parameterized::class)
class PrideVideoMutedFormatInstrumentedTest(
    private val formatName: String,
    private val expectedWidth: Int,
    private val expectedHeight: Int,
) {
    @Test
    fun mutedExportPreservesRequestedMediaContract() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        PrideVideoExportFixture(context).use { fixture ->
            val output =
                fixture.export(
                    width = expectedWidth,
                    height = expectedHeight,
                    audioFile = null,
                )
            val media = inspectVideo(output)

            assertEquals("$formatName video codec", MimeTypes.VIDEO_H264, media.videoMime)
            assertNull("$formatName must stay muted", media.audioMime)
            assertRequestedDisplaySize(media, expectedWidth, expectedHeight, formatName)
            assertSixSecondThirtyFpsVideo(media, formatName)
        }
    }

    companion object {
        @JvmStatic
        @Parameterized.Parameters(name = "{0}")
        fun supportedFormats(): List<Array<Any>> =
            listOf(
                arrayOf("square1x1", 1080, 1080),
                arrayOf("feed4x5", 1080, 1350),
                arrayOf("story9x16", 1080, 1920),
                arrayOf("landscape16x9", 1920, 1080),
            )
    }
}

@LargeTest
@UnstableApi
@RunWith(AndroidJUnit4::class)
class PrideVideoAudioInstrumentedTest {
    @Test
    fun unmutedExportContainsCompleteAacSting() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        PrideVideoExportFixture(context).use { fixture ->
            val output =
                fixture.export(
                    width = 1080,
                    height = 1080,
                    audioFile = fixture.copySonicSting(),
                )
            val media = inspectVideo(output)

            assertEquals(MimeTypes.VIDEO_H264, media.videoMime)
            assertEquals(MimeTypes.AUDIO_AAC, media.audioMime)
            assertTrue(
                "sonic sting sample span is too short: count=${media.audioSampleCount}, " +
                    "payloadBytes=${media.audioPayloadBytes}, " +
                    "firstSampleTimeUs=${media.audioFirstSampleTimeUs}, " +
                    "lastSampleTimeUs=${media.audioLastSampleTimeUs}, " +
                    "spanUs=${media.audioSampleSpanUs}",
                requireNotNull(media.audioSampleSpanUs) >= MIN_STING_SAMPLE_SPAN_US,
            )
            assertRequestedDisplaySize(media, 1080, 1080, "unmuted square1x1")
            assertSixSecondThirtyFpsVideo(media, "unmuted square1x1")
        }
    }
}

@LargeTest
@UnstableApi
@RunWith(AndroidJUnit4::class)
class PrideVideoCancellationInstrumentedTest {
    @Test
    fun cancelledExportStopsCallbacksAndAllowsTheNextExport() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        PrideVideoExportFixture(context).use { fixture ->
            val cancelled = fixture.startAndCancel(width = 1080, height = 1080)

            assertFalse(
                "cancelled Media3 export must not complete a stale callback",
                cancelled.completion.await(CANCEL_CALLBACK_GRACE_SECONDS, TimeUnit.SECONDS),
            )
            assertEquals("cancelled export callback count", 0, cancelled.callbackCount.get())
            assertTrue(
                "cancelled partial output must be deletable",
                !cancelled.output.exists() || cancelled.output.delete(),
            )

            val followUp = fixture.export(width = 1080, height = 1080, audioFile = null)
            assertEquals(MimeTypes.VIDEO_H264, inspectVideo(followUp).videoMime)
        }
    }
}

@UnstableApi
private class PrideVideoExportFixture(
    private val context: Context,
) : Closeable {
    private val createdFiles = mutableListOf<File>()

    fun export(width: Int, height: Int, audioFile: File?): File {
        val sourceImage = createSourceImage(width, height)
        val outputFile = trackedFile("pride_test_${width}x$height.mp4")
        val completion = CountDownLatch(1)
        var completedFile: File? = null
        var exportError: NativeExportException? = null
        val exporter = PrideVideoExporter(context)
        val request =
            NativePrideVideoExportRequest(
                sourceImage = sourceImage,
                outputFileName = outputFile.name,
                width = width,
                height = height,
                durationMs = VIDEO_DURATION_MS,
                frameRate = VIDEO_FRAME_RATE,
                audioFile = audioFile,
                cardType = "matchResult",
            )

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            exporter.export(
                request = request,
                outputFile = outputFile,
                callback =
                    object : PrideVideoExporter.Callback {
                        override fun onCompleted(file: File) {
                            completedFile = file
                            completion.countDown()
                        }

                        override fun onError(error: NativeExportException) {
                            exportError = error
                            completion.countDown()
                        }
                    },
            )
        }

        assertTrue(
            "Media3 export timed out for ${width}x$height",
            completion.await(EXPORT_TIMEOUT_SECONDS, TimeUnit.SECONDS),
        )
        exportError?.let { error ->
            throw AssertionError(
                "Media3 export failed: ${error.code} ${error.message}; " +
                    "details=${error.details}",
                error,
            )
        }
        return requireNotNull(completedFile) { "Media3 completed without an output file" }
    }

    fun copySonicSting(): File {
        val output = trackedFile("pride_sting.wav")
        context.resources.openRawResource(R.raw.pride_sting).use { input ->
            output.outputStream().use(input::copyTo)
        }
        return output
    }

    fun startAndCancel(width: Int, height: Int): CancelledExport {
        val sourceImage = createSourceImage(width, height)
        val outputFile = trackedFile("pride_cancel_${width}x$height.mp4")
        val completion = CountDownLatch(1)
        val callbackCount = AtomicInteger()
        val exporter = PrideVideoExporter(context)
        val request =
            NativePrideVideoExportRequest(
                sourceImage = sourceImage,
                outputFileName = outputFile.name,
                width = width,
                height = height,
                durationMs = VIDEO_DURATION_MS,
                frameRate = VIDEO_FRAME_RATE,
                audioFile = null,
                cardType = "matchResult",
            )

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            exporter.export(
                request = request,
                outputFile = outputFile,
                callback =
                    object : PrideVideoExporter.Callback {
                        override fun onCompleted(file: File) {
                            callbackCount.incrementAndGet()
                            completion.countDown()
                        }

                        override fun onError(error: NativeExportException) {
                            callbackCount.incrementAndGet()
                            completion.countDown()
                        }
                    },
            )
            exporter.cancel()
        }
        return CancelledExport(outputFile, completion, callbackCount)
    }

    private fun createSourceImage(width: Int, height: Int): File {
        val output = trackedFile("pride_source_${width}x$height.png")
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.rgb(44, 132, 75))
            val paint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.rgb(244, 247, 238)
                    strokeWidth = (width / 40f).coerceAtLeast(8f)
                }
            canvas.drawLine(0f, 0f, width.toFloat(), height.toFloat(), paint)
            canvas.drawCircle(width * 0.5f, height * 0.5f, width * 0.12f, paint)
            FileOutputStream(output).use { stream ->
                check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                    "Unable to create the Pride PNG fixture"
                }
            }
        } finally {
            bitmap.recycle()
        }
        return output
    }

    private fun trackedFile(name: String): File {
        val file = File(context.cacheDir, "${System.nanoTime()}_$name")
        check(!file.exists() || file.delete()) { "Unable to reset ${file.name}" }
        createdFiles += file
        return file
    }

    override fun close() {
        createdFiles.forEach(File::delete)
    }
}

private fun inspectVideo(file: File): InspectedVideo {
    val extractor = MediaExtractor()
    var videoMime: String? = null
    var audioMime: String? = null
    var frameRate: Int? = null
    var audioTrackIndex: Int? = null
    var audioSampleCount = 0
    var audioPayloadBytes = 0L
    var audioFirstSampleTimeUs: Long? = null
    var audioLastSampleTimeUs: Long? = null
    try {
        extractor.setDataSource(file.absolutePath)
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
        audioTrackIndex?.let { index ->
            extractor.selectTrack(index)
            val sampleBuffer = ByteBuffer.allocate(MAX_AUDIO_SAMPLE_BYTES)
            while (true) {
                sampleBuffer.clear()
                val sampleSize = extractor.readSampleData(sampleBuffer, 0)
                if (sampleSize < 0) break
                if (sampleSize > 0) {
                    if (audioFirstSampleTimeUs == null) {
                        audioFirstSampleTimeUs = extractor.sampleTime
                    }
                    audioSampleCount += 1
                    audioPayloadBytes += sampleSize
                    audioLastSampleTimeUs = extractor.sampleTime
                }
                if (!extractor.advance()) break
            }
        }
    } finally {
        extractor.release()
    }

    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(file.absolutePath)
        InspectedVideo(
            videoMime = videoMime,
            audioMime = audioMime,
            encodedWidth = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
            encodedHeight = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
            rotation = retriever.intMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: 0,
            durationMs = retriever.longMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION),
            frameRate = frameRate,
            audioSampleCount = audioSampleCount,
            audioPayloadBytes = audioPayloadBytes,
            audioFirstSampleTimeUs = audioFirstSampleTimeUs,
            audioLastSampleTimeUs = audioLastSampleTimeUs,
        )
    } finally {
        releaseRetriever(retriever)
    }
}

private fun assertRequestedDisplaySize(
    media: InspectedVideo,
    expectedWidth: Int,
    expectedHeight: Int,
    label: String,
) {
    assertTrue("$label rotation is invalid: ${media.rotation}", media.rotation in VALID_ROTATIONS)
    val quarterTurn = media.rotation == 90 || media.rotation == 270
    val displayWidth = if (quarterTurn) media.encodedHeight else media.encodedWidth
    val displayHeight = if (quarterTurn) media.encodedWidth else media.encodedHeight
    assertEquals("$label display width", expectedWidth, displayWidth)
    assertEquals("$label display height", expectedHeight, displayHeight)
}

private fun assertSixSecondThirtyFpsVideo(media: InspectedVideo, label: String) {
    val durationMs = media.durationMs
    assertNotNull("$label duration is missing", durationMs)
    assertTrue(
        "$label duration is ${durationMs}ms",
        abs(requireNotNull(durationMs) - VIDEO_DURATION_MS) <= DURATION_TOLERANCE_MS,
    )
    assertEquals("$label frame rate", VIDEO_FRAME_RATE, media.frameRate)
}

private fun MediaMetadataRetriever.intMetadata(key: Int): Int? =
    extractMetadata(key)?.toIntOrNull()

private fun MediaMetadataRetriever.longMetadata(key: Int): Long? =
    extractMetadata(key)?.toLongOrNull()

private fun releaseRetriever(retriever: MediaMetadataRetriever) {
    try {
        retriever.release()
    } catch (_: IOException) {
        // Metadata has already been read; release failure cannot change the assertion result.
    }
}

private data class InspectedVideo(
    val videoMime: String?,
    val audioMime: String?,
    val encodedWidth: Int?,
    val encodedHeight: Int?,
    val rotation: Int,
    val durationMs: Long?,
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

private data class CancelledExport(
    val output: File,
    val completion: CountDownLatch,
    val callbackCount: AtomicInteger,
)

private const val VIDEO_DURATION_MS = 6_000L
private const val VIDEO_FRAME_RATE = 30
private const val EXPORT_TIMEOUT_SECONDS = 120L
private const val CANCEL_CALLBACK_GRACE_SECONDS = 2L
private const val DURATION_TOLERANCE_MS = 100L
private const val MIN_STING_SAMPLE_SPAN_US = 900_000L
private const val MAX_AUDIO_SAMPLE_BYTES = 64 * 1024
private val VALID_ROTATIONS = setOf(0, 90, 180, 270)
