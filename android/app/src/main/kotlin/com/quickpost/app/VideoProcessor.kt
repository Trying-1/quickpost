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

class VideoProcessor(private val context: Context) {
    
    interface ProgressCallback {
        fun onProgress(progress: Double)
        fun onStep(step: String)
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
        targetWidth: Int = VIDEO_WIDTH,
        targetHeight: Int = VIDEO_HEIGHT,
        callback: ProgressCallback
    ): String {
        val filename = "QuickPost_${System.currentTimeMillis()}.mp4"
        val outputPath = (context as? MainActivity)?.getVideoOutputPath(filename)
            ?: run {
                val outputDir = File(context.getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                File(outputDir, filename).absolutePath
            }
        
        val outputFile = File(outputPath)
        
        callback.onStep("Preparing image...")
        val startTime = System.currentTimeMillis()
        val bitmap = loadAndScaleBitmap(imagePath, targetWidth, targetHeight)
        val imagePrepTime = System.currentTimeMillis() - startTime
        android.util.Log.d("VideoProcessor", "Image preparation took ${imagePrepTime}ms")
        
        callback.onStep("Encoding video...")
        val encodeStart = System.currentTimeMillis()
        if (template == "fade_in") {
            createVideoFromBitmapWithEffects(bitmap, outputFile, duration, fadeInDuration, targetWidth, targetHeight, callback)
        } else {
            createVideoFromBitmap(bitmap, outputFile, duration, targetWidth, targetHeight, callback)
        }
        val encodeTime = System.currentTimeMillis() - encodeStart
        android.util.Log.d("VideoProcessor", "Video encoding took ${encodeTime}ms")
        
        if (audioPath != null && File(audioPath).exists()) {
            callback.onStep("Merging audio...")
            val mergeStart = System.currentTimeMillis()
            val audioMergeOutputPath = (context as? MainActivity)?.getVideoOutputPath("Merged_${System.currentTimeMillis()}.mp4")
                ?: File(outputFile.parentFile, "merged_${System.currentTimeMillis()}.mp4").absolutePath
            
            addAudioToVideo(outputFile.absolutePath, audioPath, audioMergeOutputPath, duration)
            
            val mergedFile = File(audioMergeOutputPath)
            if (mergedFile.exists() && mergedFile.length() > 0) {
                outputFile.delete()
                val mergeTime = System.currentTimeMillis() - mergeStart
                android.util.Log.d("VideoProcessor", "Audio merge took ${mergeTime}ms")
                return (context as? MainActivity)?.moveVideoToGallery(audioMergeOutputPath)
                    ?: audioMergeOutputPath
            }
        }
        
        bitmap.recycle()
        
        val finalPath = (context as? MainActivity)?.moveVideoToGallery(outputFile.absolutePath)
            ?: outputFile.absolutePath
        
        return finalPath
    }
    
    fun createVideoSequence(
        imagePaths: List<String>,
        videoDuration: Int,
        durationPerImage: Double,
        sequenceMode: String,
        allowRepeat: Boolean,
        audioPath: String?,
        callback: ProgressCallback
    ): String {
        val filename = "QuickPost_${System.currentTimeMillis()}.mp4"
        val outputPath = (context as? MainActivity)?.getVideoOutputPath(filename)
            ?: run {
                val outputDir = File(context.getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                File(outputDir, filename).absolutePath
            }
        
        val outputFile = File(outputPath)
        val totalFrames = videoDuration * FRAME_RATE
        val framesPerImage = (durationPerImage * FRAME_RATE).toInt()
        
        callback.onStep("Preparing images...")
        val bitmaps = imagePaths.map { path ->
            loadAndScaleBitmap(path, VIDEO_WIDTH, VIDEO_HEIGHT)
        }
        
        callback.onStep("Encoding video sequence...")
        createVideoFromBitmaps(bitmaps, outputFile, framesPerImage, totalFrames, callback)
        
        if (audioPath != null && File(audioPath).exists()) {
            callback.onStep("Merging audio...")
            val audioMergeOutputPath = (context as? MainActivity)?.getVideoOutputPath("Merged_${System.currentTimeMillis()}.mp4")
                ?: File(outputFile.parentFile, "merged_${System.currentTimeMillis()}.mp4").absolutePath
            
            addAudioToVideo(outputFile.absolutePath, audioPath, audioMergeOutputPath, videoDuration)
            
            val mergedFile = File(audioMergeOutputPath)
            if (mergedFile.exists() && mergedFile.length() > 0) {
                outputFile.delete()
                return (context as? MainActivity)?.moveVideoToGallery(audioMergeOutputPath)
                    ?: audioMergeOutputPath
            }
        }
        
        bitmaps.forEach { it.recycle() }
        
        val finalPath = (context as? MainActivity)?.moveVideoToGallery(outputFile.absolutePath)
            ?: outputFile.absolutePath
        
        return finalPath
    }
    
    private fun loadAndScaleBitmap(imagePath: String, targetWidth: Int, targetHeight: Int): Bitmap {
        val options = BitmapFactory.Options()
        options.inJustDecodeBounds = true
        BitmapFactory.decodeFile(imagePath, options)
        
        val imageWidth = options.outWidth
        val imageHeight = options.outHeight
        
        val scale = min(
            targetWidth.toFloat() / imageWidth,
            targetHeight.toFloat() / imageHeight
        )
        
        val scaledWidth = (imageWidth * scale).toInt()
        val scaledHeight = (imageHeight * scale).toInt()
        
        options.inJustDecodeBounds = false
        options.inSampleSize = calculateInSampleSize(options, targetWidth, targetHeight)
        
        val originalBitmap = BitmapFactory.decodeFile(imagePath, options)
        val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, scaledWidth, scaledHeight, true)
        if (scaledBitmap != originalBitmap) {
            originalBitmap.recycle()
        }
        
        val outputBitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(outputBitmap)
        canvas.drawColor(android.graphics.Color.BLACK)
        
        val left = (targetWidth - scaledWidth) / 2f
        val top = (targetHeight - scaledHeight) / 2f
        
        canvas.drawBitmap(scaledBitmap, left, top, null)
        scaledBitmap.recycle()
        
        return outputBitmap
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
    
    private fun createVideoFromBitmap(
        bitmap: Bitmap,
        outputFile: File,
        durationSeconds: Int,
        targetWidth: Int,
        targetHeight: Int,
        callback: ProgressCallback
    ) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, targetWidth, targetHeight)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = encoder.createInputSurface()
        encoder.start()
        
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        
        val totalFrames = durationSeconds * FRAME_RATE
        val frameDurationUs = 1_000_000L / FRAME_RATE
        val bufferInfo = MediaCodec.BufferInfo()
        
        try {
            for (frameIndex in 0 until totalFrames) {
                val presentationTimeUs = frameIndex * frameDurationUs
                val canvas = surface.lockCanvas(null)
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                surface.unlockCanvasAndPost(canvas)
                
                var outputDone = false
                while (!outputDone) {
                    val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                    
                    when {
                        outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            trackIndex = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                        }
                        outputBufferIndex >= 0 -> {
                            val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                bufferInfo.presentationTimeUs = presentationTimeUs
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                            outputDone = true
                        }
                        else -> {
                            outputDone = true
                        }
                    }
                }
                callback.onProgress((frameIndex + 1).toDouble() / totalFrames)
            }
            
            encoder.signalEndOfInputStream()
            
            var outputDone = false
            while (!outputDone) {
                val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        } finally {
            surface.release()
            encoder.stop()
            encoder.release()
            muxer.stop()
            muxer.release()
        }
    }
    
    private fun createVideoFromBitmapWithEffects(
        bitmap: Bitmap,
        outputFile: File,
        durationSeconds: Int,
        fadeInDurationSeconds: Double,
        targetWidth: Int,
        targetHeight: Int,
        callback: ProgressCallback
    ) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, targetWidth, targetHeight)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = encoder.createInputSurface()
        encoder.start()
        
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        
        val totalFrames = durationSeconds * FRAME_RATE
        val frameDurationUs = 1_000_000L / FRAME_RATE
        val fadeInFrames = (fadeInDurationSeconds * FRAME_RATE).toInt()
        val bufferInfo = MediaCodec.BufferInfo()
        
        val paint = android.graphics.Paint().apply {
            isAntiAlias = true
        }
        
        try {
            for (frameIndex in 0 until totalFrames) {
                val presentationTimeUs = frameIndex * frameDurationUs
                val alpha = if (frameIndex < fadeInFrames) {
                    (frameIndex.toFloat() / fadeInFrames * 255).toInt()
                } else {
                    255
                }
                
                paint.alpha = alpha
                val canvas = surface.lockCanvas(null)
                canvas.drawColor(android.graphics.Color.BLACK)
                canvas.drawBitmap(bitmap, 0f, 0f, paint)
                surface.unlockCanvasAndPost(canvas)
                
                var outputDone = false
                while (!outputDone) {
                    val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                    
                    when {
                        outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            trackIndex = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                        }
                        outputBufferIndex >= 0 -> {
                            val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                bufferInfo.presentationTimeUs = presentationTimeUs
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                            outputDone = true
                        }
                        else -> {
                            outputDone = true
                        }
                    }
                }
                callback.onProgress((frameIndex + 1).toDouble() / totalFrames)
            }
            
            encoder.signalEndOfInputStream()
            
            var outputDone = false
            while (!outputDone) {
                val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        } finally {
            surface.release()
            encoder.stop()
            encoder.release()
            muxer.stop()
            muxer.release()
        }
    }
    
    private fun createVideoFromBitmaps(
        bitmaps: List<Bitmap>,
        outputFile: File,
        framesPerImage: Int,
        totalFrames: Int,
        callback: ProgressCallback
    ) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, VIDEO_WIDTH, VIDEO_HEIGHT)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = encoder.createInputSurface()
        encoder.start()
        
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        
        val bufferInfo = MediaCodec.BufferInfo()
        
        try {
            var currentImageIndex = 0
            var framesForCurrentImage = 0
            val frameDurationUs = 1_000_000L / FRAME_RATE
            
            for (frameIndex in 0 until totalFrames) {
                val bitmap = bitmaps[currentImageIndex]
                val presentationTimeUs = frameIndex * frameDurationUs
                
                val canvas = surface.lockCanvas(null)
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                surface.unlockCanvasAndPost(canvas)
                
                framesForCurrentImage++
                if (framesForCurrentImage >= framesPerImage) {
                    currentImageIndex = (currentImageIndex + 1) % bitmaps.size
                    framesForCurrentImage = 0
                }
                
                var drainMore = true
                while (drainMore) {
                    val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 100)
                    when {
                        outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            trackIndex = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                        }
                        outputBufferIndex >= 0 -> {
                            val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                bufferInfo.presentationTimeUs = presentationTimeUs
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                        }
                        else -> {
                            drainMore = false
                        }
                    }
                }
                callback.onProgress((frameIndex + 1).toDouble() / totalFrames)
            }
            
            encoder.signalEndOfInputStream()
            
            var outputDone = false
            while (!outputDone) {
                val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        } finally {
            surface.release()
            encoder.stop()
            encoder.release()
            muxer.stop()
            muxer.release()
        }
    }
    
    private fun addAudioToVideo(videoPath: String, audioPath: String, outputPath: String, durationSeconds: Int) {
        val overlay = FFmpegTextOverlay(context)
        overlay.nativeMergeAudioVideo(videoPath, audioPath, outputPath, durationSeconds)
    }
}
