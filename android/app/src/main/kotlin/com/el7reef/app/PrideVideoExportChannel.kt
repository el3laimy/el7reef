package com.el7reef.app

import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.DataInputStream
import java.io.EOFException
import java.io.FileInputStream
import java.io.IOException

internal class PrideVideoExportChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var activeExport: ActiveExport? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_EXPORT -> startExport(call, result)
            METHOD_CANCEL -> cancelExport(result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        finishCancelled("engine_detached", "Flutter engine detached during video export")
    }

    private fun startExport(call: MethodCall, result: MethodChannel.Result) {
        if (activeExport != null) {
            result.error(
                "export_in_progress",
                "A Pride video export is already running",
                null,
            )
            return
        }

        val request =
            try {
                parseRequest(call)
            } catch (error: NativeExportException) {
                result.error(error.code, error.message, error.details)
                return
            }

        val outputFile =
            try {
                createOutputFile(request.outputFileName)
            } catch (error: NativeExportException) {
                result.error(error.code, error.message, error.details)
                return
            }

        val exporter = PrideVideoExporter(context)
        val export = ActiveExport(exporter, outputFile, result)
        activeExport = export

        try {
            exporter.export(
                request = request,
                outputFile = outputFile,
                callback = exportCallback(export),
            )
        } catch (error: RuntimeException) {
            finishFailedExport(
                export,
                NativeExportException(
                    code = "export_start_failed",
                    message = "Unable to prepare the Media3 Pride video export",
                    cause = error,
                ),
            )
        }
    }

    private fun exportCallback(export: ActiveExport) =
        object : PrideVideoExporter.Callback {
            override fun onCompleted(file: File) {
                if (activeExport !== export) return
                activeExport = null
                export.result.success(file.absolutePath)
            }

            override fun onError(error: NativeExportException) {
                finishFailedExport(export, error)
            }
        }

    private fun finishFailedExport(export: ActiveExport, error: NativeExportException) {
        if (activeExport !== export) return
        activeExport = null
        export.outputFile.delete()
        Log.e(TAG, "Pride video export failed: ${error.code}", error)
        export.result.error(error.code, error.message, error.details)
    }

    private fun cancelExport(result: MethodChannel.Result) {
        finishCancelled("export_cancelled", "Pride video export was cancelled")
        result.success(null)
    }

    private fun finishCancelled(code: String, message: String) {
        val export = activeExport ?: return
        activeExport = null
        try {
            export.exporter.cancel()
        } catch (error: RuntimeException) {
            Log.e(TAG, "Media3 failed while cancelling a Pride video export", error)
        } finally {
            deleteOrLog(export.outputFile)
            export.result.error(code, message, null)
        }
    }

    private fun parseRequest(call: MethodCall): NativePrideVideoExportRequest {
        val sourceImagePath = call.argument<String>("sourceImagePath")?.trim().orEmpty()
        val outputFileName = call.argument<String>("outputFileName")?.trim().orEmpty()
        val width = call.numberArgument("width")?.toInt()
        val height = call.numberArgument("height")?.toInt()
        val durationMs = call.numberArgument("durationMs")?.toLong()
        val frameRate = call.numberArgument("frameRate")?.toInt()
        val includeAudio = call.argument<Boolean>("includeAudio") ?: false
        val cardType = call.argument<String>("cardType")?.trim()?.takeIf(String::isNotEmpty)

        if (
            sourceImagePath.isEmpty() ||
            outputFileName.isEmpty() ||
            width == null ||
            height == null ||
            durationMs == null ||
            frameRate == null ||
            cardType == null
        ) {
            throw NativeExportException(
                code = "invalid_arguments",
                message = "Missing required Pride video export arguments",
            )
        }
        if ((width to height) !in SUPPORTED_DIMENSIONS) {
            throw NativeExportException(
                code = "invalid_arguments",
                message = "Unsupported Pride video dimensions: ${width}x$height",
                details = mapOf("width" to width, "height" to height),
            )
        }
        if (durationMs != EXPORT_DURATION_MS || frameRate != EXPORT_FRAME_RATE) {
            throw NativeExportException(
                code = "invalid_arguments",
                message = "Pride videos must be 6000ms at 30fps",
                details = mapOf("durationMs" to durationMs, "frameRate" to frameRate),
            )
        }
        if (cardType !in SUPPORTED_CARD_TYPES) {
            throw NativeExportException(
                code = "invalid_arguments",
                message = "Unsupported Pride video card type: $cardType",
                details = mapOf("cardType" to cardType),
            )
        }

        val sourceImage = File(sourceImagePath)
        validateSourceImage(sourceImage, width, height)
        val resolvedAudio =
            if (includeAudio) {
                resolveAudioFile()
            } else {
                null
            }

        return NativePrideVideoExportRequest(
            sourceImage = sourceImage,
            outputFileName = outputFileName,
            width = width,
            height = height,
            durationMs = durationMs,
            frameRate = frameRate,
            audioFile = resolvedAudio,
            cardType = cardType,
        )
    }

    private fun validateSourceImage(sourceImage: File, expectedWidth: Int, expectedHeight: Int) {
        if (!sourceImage.isFile || !sourceImage.canRead() || sourceImage.length() == 0L) {
            throw NativeExportException(
                code = "source_image_missing",
                message = "Pride source image does not exist or cannot be read",
            )
        }

        val isPng =
            try {
                DataInputStream(FileInputStream(sourceImage)).use { stream ->
                    val header = ByteArray(PNG_SIGNATURE.size)
                    stream.readFully(header)
                    header.contentEquals(PNG_SIGNATURE)
                }
            } catch (error: EOFException) {
                false
            } catch (error: IOException) {
                false
            }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(sourceImage.absolutePath, bounds)
        if (
            !isPng ||
            bounds.outWidth != expectedWidth ||
            bounds.outHeight != expectedHeight
        ) {
            throw NativeExportException(
                code = "source_image_invalid",
                message = "Pride source must be a PNG matching the requested dimensions",
                details =
                    mapOf(
                        "expectedWidth" to expectedWidth,
                        "expectedHeight" to expectedHeight,
                        "actualWidth" to bounds.outWidth,
                        "actualHeight" to bounds.outHeight,
                    ),
            )
        }
    }

    private fun resolveAudioFile(): File {
        val rawResourceId =
            context.resources.getIdentifier(PRIDE_STING_RESOURCE, "raw", context.packageName)
        if (rawResourceId == 0) {
            throw NativeExportException(
                code = "audio_unavailable",
                message = "The Pride sonic sting resource is unavailable",
            )
        }

        val audioDirectory = File(context.cacheDir, AUDIO_CACHE_DIRECTORY)
        if (!audioDirectory.exists() && !audioDirectory.mkdirs()) {
            throw NativeExportException(
                code = "audio_unavailable",
                message = "Unable to prepare the Pride audio cache",
            )
        }
        val cachedAudio = File(audioDirectory, "$PRIDE_STING_RESOURCE.wav")
        try {
            context.resources.openRawResource(rawResourceId).use { input ->
                cachedAudio.outputStream().use(input::copyTo)
            }
        } catch (error: IOException) {
            cachedAudio.delete()
            throw NativeExportException(
                code = "audio_unavailable",
                message = "Unable to copy the Pride sonic sting",
                cause = error,
            )
        }
        if (!cachedAudio.hasReadableAudioTrack()) {
            cachedAudio.delete()
            throw NativeExportException(
                code = "audio_unavailable",
                message = "The Pride sonic sting is not a readable audio file",
            )
        }
        return cachedAudio
    }

    private fun File.hasReadableAudioTrack(): Boolean {
        if (!isFile || !canRead() || length() == 0L) return false
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(absolutePath)
            (0 until extractor.trackCount).any { index ->
                extractor.getTrackFormat(index)
                    .getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            }
        } catch (error: IOException) {
            false
        } catch (error: RuntimeException) {
            false
        } finally {
            extractor.release()
        }
    }

    private fun createOutputFile(requestedName: String): File {
        val outputDirectory = File(context.cacheDir, OUTPUT_CACHE_DIRECTORY)
        if (!outputDirectory.exists() && !outputDirectory.mkdirs()) {
            throw NativeExportException(
                code = "output_unavailable",
                message = "Unable to prepare the Pride video cache",
            )
        }
        pruneExpiredFiles(outputDirectory)
        val safeName =
            requestedName
                .substringBeforeLast('.', requestedName)
                .replace(UNSAFE_FILE_NAME, "_")
                .trim('_')
                .take(MAX_FILE_NAME_LENGTH)
                .ifEmpty { "el7reef_pride" }
        return File(
            outputDirectory,
            "${safeName}_${System.currentTimeMillis()}_${System.nanoTime()}.mp4",
        )
    }

    private fun pruneExpiredFiles(directory: File) {
        val cutoff = System.currentTimeMillis() - CACHE_MAX_AGE_MS
        try {
            directory.listFiles()?.forEach { file ->
                if (file.isFile && file.lastModified() in 1 until cutoff) {
                    deleteOrLog(file)
                }
            }
        } catch (error: SecurityException) {
            Log.w(TAG, "Unable to prune the Pride video cache", error)
        }
    }

    private fun deleteOrLog(file: File) {
        if (file.exists() && !file.delete()) {
            Log.w(TAG, "Unable to delete cached Pride media: ${file.name}")
        }
    }

    private fun MethodCall.numberArgument(name: String): Number? = argument<Number>(name)

    private data class ActiveExport(
        val exporter: PrideVideoExporter,
        val outputFile: File,
        val result: MethodChannel.Result,
    )

    private companion object {
        const val CHANNEL_NAME = "com.el7reef.app/pride_video_export"
        const val METHOD_EXPORT = "export"
        const val METHOD_CANCEL = "cancel"
        const val EXPORT_DURATION_MS = 6_000L
        const val EXPORT_FRAME_RATE = 30
        const val OUTPUT_CACHE_DIRECTORY = "pride_video_exports"
        const val AUDIO_CACHE_DIRECTORY = "pride_audio"
        const val PRIDE_STING_RESOURCE = "pride_sting"
        const val MAX_FILE_NAME_LENGTH = 80
        const val CACHE_MAX_AGE_MS = 24L * 60L * 60L * 1_000L
        const val TAG = "PrideVideoExport"

        val SUPPORTED_DIMENSIONS =
            setOf(
                1080 to 1080,
                1080 to 1350,
                1080 to 1920,
                1920 to 1080,
            )
        val SUPPORTED_CARD_TYPES =
            setOf(
                "matchResult",
                "mvp",
                "goalScorer",
                "qualification",
                "champion",
                "playerMilestone",
            )
        val PNG_SIGNATURE =
            byteArrayOf(
                0x89.toByte(),
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A,
            )
        val UNSAFE_FILE_NAME = Regex("[^A-Za-z0-9_-]")
    }
}

internal data class NativePrideVideoExportRequest(
    val sourceImage: File,
    val outputFileName: String,
    val width: Int,
    val height: Int,
    val durationMs: Long,
    val frameRate: Int,
    val audioFile: File?,
    val cardType: String,
)

internal class NativeExportException(
    val code: String,
    override val message: String,
    val details: Map<String, Any?>? = null,
    cause: Throwable? = null,
) : Exception(message, cause)
