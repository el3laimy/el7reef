package com.el7reef.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import androidx.media3.common.Effect
import androidx.media3.common.OverlaySettings
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Effects
import java.util.Random
import kotlin.math.PI
import kotlin.math.sin

@UnstableApi
internal object PrideVideoEffects {
    fun create(
        context: Context,
        request: NativePrideVideoExportRequest,
    ): Effects {
        val overlays =
            mutableListOf<TextureOverlay>(
                revealOverlay(request),
                shineOverlay(request),
                brandStampOverlay(context, request),
            )
        if (request.cardType == CHAMPION_CARD_TYPE) {
            overlays += championConfettiOverlay(request)
        }

        val videoEffects =
            listOf<Effect>(
                Presentation.createForWidthAndHeight(
                    request.width,
                    request.height,
                    Presentation.LAYOUT_SCALE_TO_FIT,
                ),
                OverlayEffect(overlays),
            )
        return Effects(emptyList(), videoEffects)
    }

    private fun revealOverlay(request: NativePrideVideoExportRequest): BitmapOverlay {
        val bitmap =
            Bitmap.createBitmap(request.width, request.height, Bitmap.Config.ARGB_8888).apply {
                eraseColor(Color.rgb(16, 20, 15))
            }
        return AnimatedBitmapOverlay(bitmap) { presentationTimeUs ->
            val progress = normalizedProgress(presentationTimeUs, 0L, REVEAL_DURATION_US)
            val alpha = MAX_REVEAL_ALPHA * (1f - smoothStep(progress))
            StaticOverlaySettings.Builder()
                .setAlphaScale(alpha)
                .build()
        }
    }

    private fun shineOverlay(request: NativePrideVideoExportRequest): BitmapOverlay {
        val shineWidth = (request.width / 4).coerceIn(MIN_SHINE_WIDTH, MAX_SHINE_WIDTH)
        val bitmap = Bitmap.createBitmap(shineWidth, request.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.shader =
            LinearGradient(
                0f,
                request.height.toFloat(),
                shineWidth.toFloat(),
                0f,
                intArrayOf(
                    Color.TRANSPARENT,
                    Color.argb(18, 244, 247, 238),
                    Color.argb(96, 244, 247, 238),
                    Color.argb(18, 126, 217, 87),
                    Color.TRANSPARENT,
                ),
                floatArrayOf(0f, 0.28f, 0.5f, 0.72f, 1f),
                Shader.TileMode.CLAMP,
            )
        canvas.drawRect(0f, 0f, shineWidth.toFloat(), request.height.toFloat(), paint)

        return AnimatedBitmapOverlay(bitmap) { presentationTimeUs ->
            val progress =
                normalizedProgress(
                    presentationTimeUs,
                    SHINE_START_US,
                    SHINE_END_US,
                )
            val alpha = (sin(PI * progress).toFloat() * MAX_SHINE_ALPHA).coerceAtLeast(0f)
            StaticOverlaySettings.Builder()
                .setAlphaScale(alpha)
                .setBackgroundFrameAnchor(-1f + (2f * progress), 0f)
                .build()
        }
    }

    private fun brandStampOverlay(
        context: Context,
        request: NativePrideVideoExportRequest,
    ): BitmapOverlay {
        val stampSize = (request.width / 5).coerceIn(MIN_STAMP_SIZE, MAX_STAMP_SIZE)
        val bitmap = renderBrandStamp(context, stampSize)
        return AnimatedBitmapOverlay(bitmap) { presentationTimeUs ->
            val revealProgress =
                smoothStep(
                    normalizedProgress(
                        presentationTimeUs,
                        STAMP_START_US,
                        STAMP_REVEAL_END_US,
                    ),
                )
            val fadeProgress =
                smoothStep(
                    normalizedProgress(
                        presentationTimeUs,
                        STAMP_FADE_START_US,
                        STAMP_END_US,
                    ),
                )
            val alpha = MAX_STAMP_ALPHA * revealProgress * (1f - fadeProgress)
            val scale = STAMP_START_SCALE + ((1f - STAMP_START_SCALE) * revealProgress)
            StaticOverlaySettings.Builder()
                .setAlphaScale(alpha)
                .setScale(scale, scale)
                .setBackgroundFrameAnchor(STAMP_ANCHOR_X, STAMP_ANCHOR_Y)
                .build()
        }
    }

    private fun championConfettiOverlay(
        request: NativePrideVideoExportRequest,
    ): BitmapOverlay {
        val bitmapHeight = (request.height * CONFETTI_HEIGHT_RATIO).toInt()
        val bitmap = Bitmap.createBitmap(request.width, bitmapHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val colors = intArrayOf(BRAND_PITCH, BRAND_CHALK, CHAMPION_GOLD)
        val random = Random(CONFETTI_SEED)
        repeat(CONFETTI_COUNT) { index ->
            paint.color = colors[index % colors.size]
            val x = random.nextFloat() * request.width
            val y = random.nextFloat() * bitmapHeight
            val width = CONFETTI_MIN_SIZE + (random.nextFloat() * CONFETTI_SIZE_RANGE)
            val height = width * (1.4f + random.nextFloat())
            canvas.save()
            canvas.rotate(random.nextFloat() * 90f, x, y)
            canvas.drawRoundRect(x, y, x + width, y + height, width / 3f, width / 3f, paint)
            canvas.restore()
        }

        return AnimatedBitmapOverlay(bitmap) { presentationTimeUs ->
            val progress =
                normalizedProgress(
                    presentationTimeUs,
                    CONFETTI_START_US,
                    CONFETTI_END_US,
                )
            val alpha = (sin(PI * progress).toFloat() * MAX_CONFETTI_ALPHA).coerceAtLeast(0f)
            StaticOverlaySettings.Builder()
                .setAlphaScale(alpha)
                .setOverlayFrameAnchor(0f, 1f)
                .setBackgroundFrameAnchor(0f, 1f - (CONFETTI_DROP_DISTANCE * progress))
                .setRotationDegrees(CONFETTI_ROTATION_DEGREES * progress)
                .build()
        }
    }

    private fun renderBrandStamp(context: Context, size: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val resourceId =
            context.resources.getIdentifier(BRAND_MARK_RESOURCE, "drawable", context.packageName)
        val drawable = resourceId.takeIf { it != 0 }?.let(context::getDrawable)
        if (drawable != null) {
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            return bitmap
        }

        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = BRAND_PITCH
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.SQUARE
                strokeJoin = Paint.Join.ROUND
                strokeWidth = size * 0.09f
            }
        val path =
            Path().apply {
                moveTo(size * 0.2f, size * 0.24f)
                lineTo(size * 0.8f, size * 0.24f)
                lineTo(size * 0.42f, size * 0.78f)
            }
        canvas.drawPath(path, paint)
        return bitmap
    }

    private fun normalizedProgress(
        presentationTimeUs: Long,
        startUs: Long,
        endUs: Long,
    ): Float {
        if (endUs <= startUs) return 1f
        return ((presentationTimeUs - startUs).toFloat() / (endUs - startUs))
            .coerceIn(0f, 1f)
    }

    private fun smoothStep(value: Float): Float = value * value * (3f - (2f * value))

    private class AnimatedBitmapOverlay(
        private val bitmap: Bitmap,
        private val settingsAt: (Long) -> OverlaySettings,
    ) : BitmapOverlay() {
        override fun getBitmap(presentationTimeUs: Long): Bitmap = bitmap

        override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings =
            settingsAt(presentationTimeUs)

        override fun release() {
            try {
                super.release()
            } finally {
                if (!bitmap.isRecycled) bitmap.recycle()
            }
        }
    }

    private const val CHAMPION_CARD_TYPE = "champion"
    private const val BRAND_MARK_RESOURCE = "splash_mark"
    private const val BRAND_PITCH = 0xFF7ED957.toInt()
    private const val BRAND_CHALK = 0xFFF4F7EE.toInt()
    private const val CHAMPION_GOLD = 0xFFD5AA46.toInt()

    private const val MAX_REVEAL_ALPHA = 0.58f
    private const val REVEAL_DURATION_US = 700_000L
    private const val SHINE_START_US = 650_000L
    private const val SHINE_END_US = 1_650_000L
    private const val MAX_SHINE_ALPHA = 0.42f
    private const val MIN_SHINE_WIDTH = 180
    private const val MAX_SHINE_WIDTH = 320

    private const val STAMP_START_US = 3_850_000L
    private const val STAMP_REVEAL_END_US = 4_300_000L
    private const val STAMP_FADE_START_US = 5_350_000L
    private const val STAMP_END_US = 5_850_000L
    private const val MAX_STAMP_ALPHA = 0.9f
    private const val STAMP_START_SCALE = 0.78f
    private const val STAMP_ANCHOR_X = -0.76f
    private const val STAMP_ANCHOR_Y = 0.76f
    private const val MIN_STAMP_SIZE = 160
    private const val MAX_STAMP_SIZE = 260

    private const val CONFETTI_START_US = 1_550_000L
    private const val CONFETTI_END_US = 3_050_000L
    private const val MAX_CONFETTI_ALPHA = 0.86f
    private const val CONFETTI_HEIGHT_RATIO = 0.52f
    private const val CONFETTI_DROP_DISTANCE = 0.62f
    private const val CONFETTI_ROTATION_DEGREES = 3f
    private const val CONFETTI_COUNT = 34
    private const val CONFETTI_MIN_SIZE = 9f
    private const val CONFETTI_SIZE_RANGE = 13f
    private const val CONFETTI_SEED = 7L
}
