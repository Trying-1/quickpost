package com.quickpost.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

object BackgroundRemover {
    private const val TAG = "BackgroundRemover"

    suspend fun removeBackground(
        context: Context, 
        inputPath: String, 
        outputPath: String,
        smoothing: Float = 0f,
        strokeWidth: Float = 0f,
        strokeColor: Int = Color.TRANSPARENT,
        bgColor: Int = Color.TRANSPARENT,
        edgePadding: Int = 0,
        scale: Float = 1.0f,
        offsetX: Float = 0f,
        offsetY: Float = 0f,
        outputWidth: Int = 0,
        outputHeight: Int = 0,
        shadowRadius: Float = 0f,
        shadowColor: Int = Color.TRANSPARENT,
        shadowDx: Float = 0f,
        shadowDy: Float = 0f,
        bgImagePath: String? = null,
        brightness: Float = 0f,
        contrast: Float = 1.0f,
        saturation: Float = 1.0f,
        autoTrim: Boolean = false
    ): String = withContext(Dispatchers.IO) {
        val originalBitmap = BitmapFactory.decodeFile(inputPath)
            ?: throw Exception("Failed to decode image from $inputPath")

        // Preprocessing: Add padding to allow stroke expansion without clipping
        val bitmap = if (edgePadding > 0) {
            val padded = Bitmap.createBitmap(
                originalBitmap.width + 2 * edgePadding, 
                originalBitmap.height + 2 * edgePadding, 
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(padded)
            canvas.drawBitmap(originalBitmap, edgePadding.toFloat(), edgePadding.toFloat(), null)
            padded
        } else {
            originalBitmap
        }

        val inputImage = InputImage.fromBitmap(bitmap, 0)
        
        // Configure options to get foreground bitmap
        val options = SubjectSegmenterOptions.Builder()
            .enableForegroundBitmap()
            .build()

        val segmenter = SubjectSegmentation.getClient(options)

        val resultMask = suspendCoroutine<com.google.mlkit.vision.segmentation.subject.SubjectSegmentationResult> { continuation ->
            segmenter.process(inputImage)
                .addOnSuccessListener { result ->
                    continuation.resume(result)
                }
                .addOnFailureListener { e ->
                    Log.e("BackgroundRemover", "Subject segmentation failed", e)
                    continuation.resumeWithException(e)
                }
        }

        val fgBitmap = resultMask.foregroundBitmap
        if (fgBitmap == null) {
            segmenter.close()
            throw Exception("Segmentation failed to return a foreground bitmap")
        }

        val finalW = if (outputWidth > 0) outputWidth else bitmap.width
        val finalH = if (outputHeight > 0) outputHeight else bitmap.height
        
        val outBitmap = Bitmap.createBitmap(finalW, finalH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(outBitmap)
        
        // 1. Draw Background
        if (bgColor != Color.TRANSPARENT) {
            canvas.drawColor(bgColor)
        }
        if (bgImagePath != null && bgImagePath.isNotEmpty()) {
            val bgBitmap = BitmapFactory.decodeFile(bgImagePath)
            if (bgBitmap != null) {
                val bgScale = Math.max(finalW.toFloat() / bgBitmap.width, finalH.toFloat() / bgBitmap.height)
                val scaledW = bgBitmap.width * bgScale
                val scaledH = bgBitmap.height * bgScale
                val bgDx = (finalW - scaledW) / 2f
                val bgDy = (finalH - scaledH) / 2f
                val bgRect = android.graphics.RectF(bgDx, bgDy, bgDx + scaledW, bgDy + scaledH)
                canvas.drawBitmap(bgBitmap, null, bgRect, null)
                bgBitmap.recycle()
            }
        }

        // Apply Transform (Scale and Offset)
        canvas.save()
        val defaultDx = (finalW - bitmap.width) / 2f
        val defaultDy = (finalH - bitmap.height) / 2f
        canvas.translate(defaultDx + offsetX, defaultDy + offsetY)
        canvas.scale(scale, scale, bitmap.width / 2f, bitmap.height / 2f)

        // Prepare foreground (apply smoothing if needed)
        var finalFg = fgBitmap
        if (smoothing > 0f) {
            val alpha = fgBitmap.extractAlpha()
            val smoothFg = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
            val smoothCanvas = Canvas(smoothFg)
            
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.maskFilter = android.graphics.BlurMaskFilter(smoothing, android.graphics.BlurMaskFilter.Blur.NORMAL)
            smoothCanvas.drawBitmap(alpha, 0f, 0f, paint)
            
            paint.maskFilter = null
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            smoothCanvas.drawBitmap(bitmap, 0f, 0f, paint)
            
            alpha.recycle()
            finalFg = smoothFg
        }

        // 1.5 Draw Shadow
        if (shadowRadius > 0f && shadowColor != Color.TRANSPARENT) {
            val alpha = finalFg.extractAlpha()
            val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            shadowPaint.color = shadowColor
            shadowPaint.maskFilter = android.graphics.BlurMaskFilter(shadowRadius, android.graphics.BlurMaskFilter.Blur.NORMAL)
            canvas.drawBitmap(alpha, shadowDx, shadowDy, shadowPaint)
            alpha.recycle()
        }

        // 2. Draw Stroke
        if (strokeWidth > 0f && strokeColor != Color.TRANSPARENT) {
            val alpha = finalFg.extractAlpha()
            val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG)
            strokePaint.color = strokeColor
            strokePaint.maskFilter = android.graphics.BlurMaskFilter(strokeWidth, android.graphics.BlurMaskFilter.Blur.SOLID)
            
            canvas.drawBitmap(alpha, 0f, 0f, strokePaint)
            canvas.drawBitmap(alpha, 0f, 0f, strokePaint)
            
            alpha.recycle()
        }

        // 3. Draw Foreground with Filters
        val fgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        if (brightness != 0f || contrast != 1.0f || saturation != 1.0f) {
            val cm = android.graphics.ColorMatrix()
            if (saturation != 1.0f) {
                cm.setSaturation(saturation)
            }
            if (brightness != 0f || contrast != 1.0f) {
                val scaleFactor = contrast
                val translate = brightness * 255f
                val bcMatrix = android.graphics.ColorMatrix(floatArrayOf(
                    scaleFactor, 0f, 0f, 0f, translate,
                    0f, scaleFactor, 0f, 0f, translate,
                    0f, 0f, scaleFactor, 0f, translate,
                    0f, 0f, 0f, 1f, 0f
                ))
                cm.postConcat(bcMatrix)
            }
            fgPaint.colorFilter = android.graphics.ColorMatrixColorFilter(cm)
        }
        canvas.drawBitmap(finalFg, 0f, 0f, fgPaint)
        
        canvas.restore() // Restore transform

        // 4. Auto-Trim
        var finalOutBitmap = outBitmap
        if (autoTrim) {
            var minX = finalOutBitmap.width
            var minY = finalOutBitmap.height
            var maxX = -1
            var maxY = -1

            val pixels = IntArray(finalOutBitmap.width * finalOutBitmap.height)
            finalOutBitmap.getPixels(pixels, 0, finalOutBitmap.width, 0, 0, finalOutBitmap.width, finalOutBitmap.height)
            
            for (y in 0 until finalOutBitmap.height) {
                for (x in 0 until finalOutBitmap.width) {
                    val alpha = (pixels[y * finalOutBitmap.width + x] ushr 24) and 0xff
                    if (alpha > 0) {
                        if (x < minX) minX = x
                        if (x > maxX) maxX = x
                        if (y < minY) minY = y
                        if (y > maxY) maxY = y
                    }
                }
            }

            if (maxX >= minX && maxY >= minY) {
                val trimW = maxX - minX + 1
                val trimH = maxY - minY + 1
                finalOutBitmap = Bitmap.createBitmap(finalOutBitmap, minX, minY, trimW, trimH)
            }
        }

        // Save output to file
        val outFile = File(outputPath)
        FileOutputStream(outFile).use { out ->
            finalOutBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }

        if (finalFg != fgBitmap) {
            finalFg.recycle()
        }
        fgBitmap.recycle()
        if (bitmap != originalBitmap) {
            bitmap.recycle()
        }
        originalBitmap.recycle()
        segmenter.close()

        outFile.absolutePath
    }
}
