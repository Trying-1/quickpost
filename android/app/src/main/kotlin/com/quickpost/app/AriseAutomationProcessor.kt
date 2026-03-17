package com.quickpost.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.min

class AriseAutomationProcessor(private val context: Context) {
    
    private var automationSettings: Map<String, Any>? = null
    private var trackStarted = false

    fun setAutomationSettings(settings: Map<String, Any>?) {
        this.automationSettings = settings
    }
    
    interface ProgressCallback {
        fun onProgress(progress: Double)
    }
    
    companion object {
        private const val VIDEO_WIDTH = 1080
        private const val VIDEO_HEIGHT = 1920
        private const val VIDEO_BIT_RATE = 6000000
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
    }
    
    fun createVideo(
        imagePath: String,
        duration: Int,
        template: String,
        fadeInDuration: Double,
        zoomScale: Double,
        zoomDuration: Double,
        audioPath: String?,
        qualitySettings: Map<String, Any>?,
        callback: ProgressCallback
    ): String {
        android.util.Log.d("AriseAutomation", "createVideo started: duration=$duration, template=$template, quality=$qualitySettings")
        val filename = "Arise_${System.currentTimeMillis()}.mp4"
        val outputPath = (context as? MainActivity)?.getVideoOutputPath(filename)
            ?: run {
                val outputDir = File(context.getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) outputDir.mkdirs()
                File(outputDir, filename).absolutePath
            }
        
        val outputFile = File(outputPath)
        val bitmap = loadAndScaleBitmap(imagePath, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        if (template == "fade_in") {
            createVideoFromBitmapWithEffects(bitmap, outputFile, duration, fadeInDuration, qualitySettings, callback)
        } else {
            createVideoFromBitmap(bitmap, outputFile, duration, qualitySettings, callback)
        }
        
        if (audioPath != null && File(audioPath).exists()) {
            android.util.Log.d("AriseAutomation", "Adding audio to video: $audioPath")
            val tempFile = File(outputFile.parentFile, "temp_${System.currentTimeMillis()}.mp4")
            outputFile.renameTo(tempFile)
            addAudioToVideo(tempFile.absolutePath, audioPath, outputFile.absolutePath, duration)
            tempFile.delete()
        }
        
        android.util.Log.d("AriseAutomation", "createVideo completed: ${outputFile.absolutePath}")
        bitmap.recycle()
        return (context as? MainActivity)?.moveVideoToGallery(outputFile.absolutePath) ?: outputFile.absolutePath
    }

    fun saveProcessedImage(imagePath: String): String {
        val bitmap = loadAndScaleBitmap(imagePath, VIDEO_WIDTH, VIDEO_HEIGHT)
        val outputBitmap = Bitmap.createBitmap(VIDEO_WIDTH, VIDEO_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(outputBitmap)
        
        applyBackground(canvas, bitmap)
        drawProcessedBitmap(canvas, bitmap, automationSettings)
        
        val filename = "Arise_${System.currentTimeMillis()}.png"
        val outputDir = File(context.getExternalFilesDir(null), "Pictures")
        if (!outputDir.exists()) outputDir.mkdirs()
        val outputFile = File(outputDir, filename)
        
        outputFile.outputStream().use { 
            outputBitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        
        bitmap.recycle()
        outputBitmap.recycle()
        
        return (context as? MainActivity)?.moveImageToGallery(outputFile.absolutePath) ?: outputFile.absolutePath
    }

    private fun loadAndScaleBitmap(imagePath: String, targetWidth: Int, targetHeight: Int): Bitmap {
        val options = BitmapFactory.Options()
        options.inJustDecodeBounds = true
        BitmapFactory.decodeFile(imagePath, options)
        
        val imageWidth = options.outWidth
        val imageHeight = options.outHeight

        options.inJustDecodeBounds = false
        options.inSampleSize = calculateInSampleSize(options, targetWidth, targetHeight)

        // IMPORTANT: return the decoded image bitmap (not a pre-padded canvas).
        // Padding/background are rendered per-frame in applyBackground(), and drawProcessedBitmap()
        // handles scaling/centering + rounded corners + stroke around the image only.
        return BitmapFactory.decodeFile(imagePath, options)
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun drawProcessedBitmap(canvas: android.graphics.Canvas, bitmap: Bitmap, settings: Map<String, Any>?, paint: android.graphics.Paint? = null) {
        val roundedCorners = settings?.get("roundedCorners") as? Boolean ?: false
        val cornerRadius = (settings?.get("cornerRadius") as? Double ?: 0.0).toFloat()
        val strokeEnabled = settings?.get("strokeEnabled") as? Boolean ?: false
        val strokeWidth = (settings?.get("strokeWidth") as? Double ?: 0.0).toFloat()
        val strokeColorStr = settings?.get("strokeColor") as? String ?: "#FFFFFF"

        val targetWidth = VIDEO_WIDTH.toFloat()
        val targetHeight = VIDEO_HEIGHT.toFloat()

        val insetW = if (strokeEnabled && strokeWidth > 0f) (targetWidth - strokeWidth * 2f).coerceAtLeast(1f) else targetWidth
        val insetH = if (strokeEnabled && strokeWidth > 0f) (targetHeight - strokeWidth * 2f).coerceAtLeast(1f) else targetHeight

        val scale = min(insetW / bitmap.width, insetH / bitmap.height)
        val drawW = bitmap.width * scale
        val drawH = bitmap.height * scale
        val left = (targetWidth - drawW) / 2f
        val top = (targetHeight - drawH) / 2f
        val imageRect = android.graphics.RectF(left, top, left + drawW, top + drawH)

        if (roundedCorners && cornerRadius > 0) {
            val path = android.graphics.Path()
            path.addRoundRect(imageRect, cornerRadius, cornerRadius, android.graphics.Path.Direction.CW)
            canvas.save()
            canvas.clipPath(path)
            canvas.drawBitmap(bitmap, null, imageRect, paint)
            canvas.restore()
        } else {
            canvas.drawBitmap(bitmap, null, imageRect, paint)
        }

        if (strokeEnabled && strokeWidth > 0) {
            val strokePaint = android.graphics.Paint().apply {
                style = android.graphics.Paint.Style.STROKE
                this.strokeWidth = strokeWidth
                color = try { android.graphics.Color.parseColor(strokeColorStr) } catch(e: Exception) { android.graphics.Color.WHITE }
                isAntiAlias = true
            }
            if (paint != null) strokePaint.alpha = paint.alpha

            val strokeOuterRect = android.graphics.RectF(
                imageRect.left - strokeWidth,
                imageRect.top - strokeWidth,
                imageRect.right + strokeWidth,
                imageRect.bottom + strokeWidth,
            )

            val half = strokeWidth / 2f
            val strokeRect = android.graphics.RectF(strokeOuterRect).apply { inset(half, half) }
            val strokeRadius = (cornerRadius + strokeWidth).coerceAtLeast(0f)

            if (roundedCorners && cornerRadius > 0) {
                canvas.drawRoundRect(strokeRect, strokeRadius, strokeRadius, strokePaint)
            } else {
                canvas.drawRect(strokeRect, strokePaint)
            }
        }
    }

    private fun blurBitmap(bitmap: Bitmap, radius: Float): Bitmap? {
        if (radius <= 0) {
            val config = bitmap.config ?: Bitmap.Config.ARGB_8888
            return bitmap.copy(config, true)
        }
        try {
            val rs = android.renderscript.RenderScript.create(context)
            val input = android.renderscript.Allocation.createFromBitmap(rs, bitmap)
            val output = android.renderscript.Allocation.createTyped(rs, input.type)
            val script = android.renderscript.ScriptIntrinsicBlur.create(rs, android.renderscript.Element.U8_4(rs))
            script.setRadius(radius.coerceIn(0f, 25f))
            script.setInput(input)
            script.forEach(output)
            val blurred = Bitmap.createBitmap(bitmap.width, bitmap.height, bitmap.config ?: Bitmap.Config.ARGB_8888)
            output.copyTo(blurred)
            rs.destroy()
            return blurred
        } catch (e: Exception) {
            val config = bitmap.config ?: Bitmap.Config.ARGB_8888
            return bitmap.copy(config, true)
        }
    }

    private fun getBitrateFromQuality(qualitySettings: Map<String, Any>?): Int {
        val preset = qualitySettings?.get("preset") as? String ?: "fast"
        val crf = (qualitySettings?.get("crf") as? Number)?.toInt() ?: 23
        
        val factor = Math.pow(2.0, (23.0 - crf) / 6.0)
        var bitrate = (VIDEO_BIT_RATE * factor).toInt()
        
        bitrate = when (preset) {
            "ultrafast" -> (bitrate * 0.8).toInt()
            "fast" -> bitrate
            "medium" -> (bitrate * 1.2).toInt()
            "slow" -> (bitrate * 1.5).toInt()
            else -> bitrate
        }
        
        return bitrate.coerceIn(1_000_000, 20_000_000)
    }

    private fun createVideoFromBitmap(bitmap: Bitmap, outputFile: File, durationSeconds: Int, qualitySettings: Map<String, Any>?, callback: ProgressCallback) {
        val bitrate = getBitrateFromQuality(qualitySettings)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, VIDEO_WIDTH, VIDEO_HEIGHT)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = encoder.createInputSurface()
        encoder.start()
        
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        trackStarted = false
        val totalFrames = durationSeconds * FRAME_RATE
        val bufferInfo = MediaCodec.BufferInfo()
        
        try {
            for (frameIndex in 0 until totalFrames) {
                val canvas = surface.lockCanvas(null)
                applyBackground(canvas, bitmap)
                drawProcessedBitmap(canvas, bitmap, automationSettings)
                surface.unlockCanvasAndPost(canvas)

                var outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 2500)
                while (outputBufferIndex >= 0) {
                    if (trackIndex == -1) {
                        trackIndex = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        trackStarted = true
                    }
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                } 
                
                if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    if (trackIndex >= 0 && !trackStarted) {
                        muxer.start()
                        trackStarted = true
                    }
                }

                if (frameIndex % 2 == 0 || frameIndex == totalFrames - 1) {
                    val progress = (frameIndex + 1).toDouble() / totalFrames
                    android.util.Log.i("AriseAutomation", "Reporting Progress: $progress (frame $frameIndex/$totalFrames)")
                    callback.onProgress(progress)
                }
                Thread.sleep(5)
            }
            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, trackIndex, bufferInfo)
        } finally {
            surface.release(); try { encoder.stop() } catch(e: Exception) {}; encoder.release(); try { muxer.stop() } catch(e: Exception) {}; muxer.release()
        }
    }

    private fun createVideoFromBitmapWithEffects(bitmap: Bitmap, outputFile: File, durationSeconds: Int, fadeInDurationSeconds: Double, qualitySettings: Map<String, Any>?, callback: ProgressCallback) {
        val bitrate = getBitrateFromQuality(qualitySettings)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, VIDEO_WIDTH, VIDEO_HEIGHT)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = encoder.createInputSurface()
        encoder.start()
        
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        trackStarted = false
        val totalFrames = durationSeconds * FRAME_RATE
        val fadeInFrames = (fadeInDurationSeconds * FRAME_RATE).toInt()
        val bufferInfo = MediaCodec.BufferInfo()
        val paint = android.graphics.Paint().apply { isAntiAlias = true }
        
        try {
            for (frameIndex in 0 until totalFrames) {
                val alpha = if (frameIndex < fadeInFrames) (frameIndex.toFloat() / (if (fadeInFrames > 0) fadeInFrames else 1) * 255).toInt() else 255
                paint.alpha = alpha
                
                val canvas = surface.lockCanvas(null)
                applyBackground(canvas, bitmap, alpha)
                drawProcessedBitmap(canvas, bitmap, automationSettings, paint)
                surface.unlockCanvasAndPost(canvas)

                var outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 2500)
                while (outputBufferIndex >= 0) {
                    if (trackIndex == -1) {
                        trackIndex = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        trackStarted = true
                    }
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                } 
                
                if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    if (trackIndex >= 0 && !trackStarted) {
                        muxer.start()
                        trackStarted = true
                    }
                }

                if (frameIndex % 2 == 0 || frameIndex == totalFrames - 1) {
                    val progress = (frameIndex + 1).toDouble() / totalFrames
                    android.util.Log.i("AriseAutomation", "Reporting Progress: $progress (frame $frameIndex/$totalFrames)")
                    callback.onProgress(progress)
                }
                Thread.sleep(5)
            }
            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, trackIndex, bufferInfo)
        } finally {
            surface.release(); try { encoder.stop() } catch(e: Exception) {}; encoder.release(); try { muxer.stop() } catch(e: Exception) {}; muxer.release()
        }
    }

    private fun applyBackground(canvas: android.graphics.Canvas, bitmap: Bitmap, alpha: Int = 255) {
        val paddingColorStr = automationSettings?.get("paddingColor") as? String
        try {
            canvas.drawColor(if (paddingColorStr != null) android.graphics.Color.parseColor(paddingColorStr) else android.graphics.Color.BLACK)
        } catch (e: Exception) {
            canvas.drawColor(android.graphics.Color.BLACK)
        }

        val useBgBlur = automationSettings?.get("useBackgroundImage") as? Boolean ?: false
        if (useBgBlur) {
            val blurRadius = (automationSettings?.get("backgroundBlurRadius") as? Double ?: 20.0).toFloat()
            val blurredBitmap = blurBitmap(bitmap, blurRadius)
            if (blurredBitmap != null) {
                val dst = android.graphics.Rect(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT)
                val blurPaint = android.graphics.Paint().apply { this.alpha = alpha }
                canvas.drawBitmap(blurredBitmap, null, dst, blurPaint)
                blurredBitmap.recycle()
            }
        }
    }

    private fun drainEncoder(encoder: MediaCodec, muxer: MediaMuxer, trackIndex: Int, bufferInfo: MediaCodec.BufferInfo) {
        var outputDone = false
        while (!outputDone) {
            val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
            if (outputBufferIndex >= 0) {
                val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                if (outputBuffer != null && bufferInfo.size > 0) {
                    muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                }
                encoder.releaseOutputBuffer(outputBufferIndex, false)
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outputDone = true
            } else if (outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                // Should not happen with EOS signaled, but safety first
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outputDone = true
            }
        }
    }

    private fun addAudioToVideo(videoPath: String, audioPath: String, outputPath: String, durationSeconds: Int) {
        try {
            val overlay = FFmpegTextOverlay(context)
            val ret = overlay.nativeMergeAudioVideo(
                videoPath,
                audioPath,
                outputPath,
                durationSeconds
            )
            
            if (ret == 0) {
                android.util.Log.d("AriseAutomation", "Native audio merge successful")
            } else {
                android.util.Log.e("AriseAutomation", "Native audio merge failed: code $ret")
                File(videoPath).copyTo(File(outputPath), overwrite = true)
            }
        } catch (e: Exception) {
            android.util.Log.e("AriseAutomation", "Error in addAudioToVideo: ${e.message}")
            e.printStackTrace()
            File(videoPath).copyTo(File(outputPath), overwrite = true)
        }
    }
}
