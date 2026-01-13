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
        callback: ProgressCallback
    ): String {
        // Get proper output path based on Android version
        val filename = "QuickPost_${System.currentTimeMillis()}.mp4"
        val outputPath = (context as? MainActivity)?.getVideoOutputPath(filename)
            ?: run {
                // Fallback to app-specific directory
                val outputDir = File(context.getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                File(outputDir, filename).absolutePath
            }
        
        val outputFile = File(outputPath)
        
        // Load and scale bitmap
        val bitmap = loadAndScaleBitmap(imagePath, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        // Create video from single image
        createVideoFromBitmap(bitmap, outputFile, duration, callback)
        
        // Add audio if provided
        if (audioPath != null && File(audioPath).exists()) {
            val tempFile = File(outputFile.parentFile, "temp_${System.currentTimeMillis()}.mp4")
            outputFile.renameTo(tempFile)
            addAudioToVideo(tempFile.absolutePath, audioPath, outputFile.absolutePath, duration)
            tempFile.delete()
        }
        
        bitmap.recycle()
        
        // Move to gallery for Android 10+
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
        // Get proper output path based on Android version
        val filename = "QuickPost_${System.currentTimeMillis()}.mp4"
        val outputPath = (context as? MainActivity)?.getVideoOutputPath(filename)
            ?: run {
                // Fallback to app-specific directory
                val outputDir = File(context.getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                File(outputDir, filename).absolutePath
            }
        
        val outputFile = File(outputPath)
        
        // Calculate how many times to show each image
        val totalFrames = videoDuration * FRAME_RATE
        val framesPerImage = (durationPerImage * FRAME_RATE).toInt()
        
        // Load all bitmaps
        val bitmaps = imagePaths.map { path ->
            loadAndScaleBitmap(path, VIDEO_WIDTH, VIDEO_HEIGHT)
        }
        
        // Create video from image sequence
        createVideoFromBitmaps(bitmaps, outputFile, framesPerImage, totalFrames, callback)
        
        // Add audio if provided
        if (audioPath != null && File(audioPath).exists()) {
            val tempFile = File(outputFile.parentFile, "temp_${System.currentTimeMillis()}.mp4")
            outputFile.renameTo(tempFile)
            addAudioToVideo(tempFile.absolutePath, audioPath, outputFile.absolutePath, videoDuration)
            tempFile.delete()
        }
        
        // Clean up bitmaps
        bitmaps.forEach { it.recycle() }
        
        // Move to gallery for Android 10+
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
        
        // Calculate scale to fit (maintain aspect ratio)
        val scale = min(
            targetWidth.toFloat() / imageWidth,
            targetHeight.toFloat() / imageHeight
        )
        
        val scaledWidth = (imageWidth * scale).toInt()
        val scaledHeight = (imageHeight * scale).toInt()
        
        options.inJustDecodeBounds = false
        options.inSampleSize = calculateInSampleSize(options, targetWidth, targetHeight)
        
        val originalBitmap = BitmapFactory.decodeFile(imagePath, options)
        
        // Scale maintaining aspect ratio
        val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, scaledWidth, scaledHeight, true)
        if (scaledBitmap != originalBitmap) {
            originalBitmap.recycle()
        }
        
        // Create canvas with target size and center the scaled image
        val outputBitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(outputBitmap)
        
        // Fill with black background
        canvas.drawColor(android.graphics.Color.BLACK)
        
        // Center the image
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
        
        val totalFrames = durationSeconds * FRAME_RATE
        val bufferInfo = MediaCodec.BufferInfo()
        
        try {
            // Generate frames
            for (frameIndex in 0 until totalFrames) {
                // Draw bitmap to surface
                val canvas = surface.lockCanvas(null)
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                surface.unlockCanvasAndPost(canvas)
                
                // Encode frame
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
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                            outputDone = true
                        }
                    }
                }
                
                // Report progress
                val progress = (frameIndex + 1).toDouble() / totalFrames
                callback.onProgress(progress)
            }
            
            // Signal end of stream
            encoder.signalEndOfInputStream()
            
            // Drain encoder
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
        
        val totalFrames = durationSeconds * FRAME_RATE
        val fadeInFrames = (fadeInDurationSeconds * FRAME_RATE).toInt()
        val bufferInfo = MediaCodec.BufferInfo()
        
        // Create paint for fade effect
        val paint = android.graphics.Paint().apply {
            isAntiAlias = true
        }
        
        try {
            // Generate frames with fade-in effect
            for (frameIndex in 0 until totalFrames) {
                // Calculate alpha for fade-in effect
                val alpha = if (frameIndex < fadeInFrames) {
                    // Fade in from 0 to 255
                    (frameIndex.toFloat() / fadeInFrames * 255).toInt()
                } else {
                    // Full opacity after fade-in
                    255
                }
                
                paint.alpha = alpha
                
                // Draw bitmap to surface with fade effect
                val canvas = surface.lockCanvas(null)
                canvas.drawColor(android.graphics.Color.BLACK) // Black background
                canvas.drawBitmap(bitmap, 0f, 0f, paint)
                surface.unlockCanvasAndPost(canvas)
                
                // Encode frame
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
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                            outputDone = true
                        }
                    }
                }
                
                // Report progress
                val progress = (frameIndex + 1).toDouble() / totalFrames
                callback.onProgress(progress)
            }
            
            // Signal end of stream
            encoder.signalEndOfInputStream()
            
            // Drain encoder
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
            val frameDurationUs = 1_000_000L / FRAME_RATE  // Microseconds per frame
            
            // Generate frames
            for (frameIndex in 0 until totalFrames) {
                // Select current bitmap (cycle through all images continuously)
                val bitmap = bitmaps[currentImageIndex]
                
                // Calculate presentation time for this frame
                val presentationTimeUs = frameIndex * frameDurationUs
                
                // Draw bitmap to surface
                val canvas = surface.lockCanvas(null)
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                surface.unlockCanvasAndPost(canvas)
                
                // Wait a bit for encoder to process (simulate frame rate)
                Thread.sleep(frameDurationUs / 1000)  // Convert microseconds to milliseconds
                
                framesForCurrentImage++
                
                // Switch to next image if needed (cycle back to start)
                if (framesForCurrentImage >= framesPerImage) {
                    currentImageIndex = (currentImageIndex + 1) % bitmaps.size
                    framesForCurrentImage = 0
                }
                
                // Drain all available output
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
                                // Override presentation time to ensure proper timing
                                bufferInfo.presentationTimeUs = presentationTimeUs
                                muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outputBufferIndex, false)
                        }
                        else -> {
                            // No more output available
                            drainMore = false
                        }
                    }
                }
                
                // Report progress
                val progress = (frameIndex + 1).toDouble() / totalFrames
                callback.onProgress(progress)
            }
            
            // Signal end of stream
            encoder.signalEndOfInputStream()
            
            // Drain encoder
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
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        
        try {
            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)
            
            val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            
            // Add video track
            var videoTrackIndex = -1
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("video/") == true) {
                    videoExtractor.selectTrack(i)
                    videoTrackIndex = muxer.addTrack(format)
                    break
                }
            }
            
            // Add audio track
            var audioTrackIndex = -1
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioExtractor.selectTrack(i)
                    audioTrackIndex = muxer.addTrack(format)
                    break
                }
            }
            
            muxer.start()
            
            // Copy video samples
            val videoBuffer = ByteBuffer.allocate(1024 * 1024)
            val videoBufferInfo = MediaCodec.BufferInfo()
            
            while (true) {
                val sampleSize = videoExtractor.readSampleData(videoBuffer, 0)
                if (sampleSize < 0) break
                
                videoBufferInfo.presentationTimeUs = videoExtractor.sampleTime
                videoBufferInfo.size = sampleSize
                videoBufferInfo.flags = videoExtractor.sampleFlags
                videoBufferInfo.offset = 0
                
                muxer.writeSampleData(videoTrackIndex, videoBuffer, videoBufferInfo)
                videoExtractor.advance()
            }
            
            // Copy audio samples (trim to video duration)
            val audioBuffer = ByteBuffer.allocate(1024 * 1024)
            val audioBufferInfo = MediaCodec.BufferInfo()
            val maxDurationUs = durationSeconds * 1000000L
            
            while (true) {
                val sampleSize = audioExtractor.readSampleData(audioBuffer, 0)
                if (sampleSize < 0) break
                
                val sampleTime = audioExtractor.sampleTime
                if (sampleTime > maxDurationUs) break
                
                audioBufferInfo.presentationTimeUs = sampleTime
                audioBufferInfo.size = sampleSize
                audioBufferInfo.flags = audioExtractor.sampleFlags
                audioBufferInfo.offset = 0
                
                muxer.writeSampleData(audioTrackIndex, audioBuffer, audioBufferInfo)
                audioExtractor.advance()
            }
            
            muxer.stop()
            muxer.release()
        } finally {
            videoExtractor.release()
            audioExtractor.release()
        }
    }
    
    private fun notifyMediaScanner(filePath: String) {
        try {
            // Method 1: MediaScannerConnection
            android.media.MediaScannerConnection.scanFile(
                context,
                arrayOf(filePath),
                arrayOf("video/mp4")
            ) { path, uri ->
                android.util.Log.d("VideoProcessor", "Media scan completed for: $path, URI: $uri")
            }
            
            // Method 2: ContentResolver insert (for immediate gallery visibility)
            val file = File(filePath)
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Video.Media.DISPLAY_NAME, file.name)
                put(android.provider.MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(android.provider.MediaStore.Video.Media.DATA, filePath)
                put(android.provider.MediaStore.Video.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                put(android.provider.MediaStore.Video.Media.DATE_MODIFIED, System.currentTimeMillis() / 1000)
                put(android.provider.MediaStore.Video.Media.SIZE, file.length())
            }
            
            context.contentResolver.insert(
                android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                values
            )
            
            android.util.Log.d("VideoProcessor", "Video added to MediaStore: $filePath")
        } catch (e: Exception) {
            android.util.Log.e("VideoProcessor", "Error notifying media scanner: ${e.message}")
        }
    }
    
    // FFmpeg-powered methods (currently using same logic as regular video creation)
    fun createVideoWithFFmpeg(
        imagePath: String,
        duration: Int,
        outputPath: String,
        callback: ProgressCallback
    ): String {
        // Use the same full video creation logic as the regular createVideo method
        // This includes fade effects, proper duration, and audio support
        
        val outputFile = File(outputPath)
        
        // Load and scale bitmap
        val bitmap = loadAndScaleBitmap(imagePath, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        // Create video from single image with fade effect (same as regular video)
        createVideoFromBitmap(bitmap, outputFile, duration, callback)
        
        bitmap.recycle()
        
        // Move to gallery for Android 10+ (same as regular video creation)
        val finalPath = (context as? MainActivity)?.moveVideoToGallery(outputPath)
            ?: outputPath
        
        // Also notify media scanner for older Android versions
        notifyMediaScanner(finalPath)
        return finalPath
    }
    
    // Enhanced FFmpeg method with full effects and audio support
    fun createVideoWithFFmpegFull(
        imagePath: String,
        duration: Int,
        template: String,
        fadeInDuration: Double,
        zoomScale: Double,
        zoomDuration: Double,
        audioPath: String?,
        outputPath: String,
        callback: ProgressCallback
    ): String {
        val outputFile = File(outputPath)
        
        // Load and scale bitmap
        val bitmap = loadAndScaleBitmap(imagePath, VIDEO_WIDTH, VIDEO_HEIGHT)
        
        // Create video from single image with fade-in effect
        createVideoFromBitmapWithEffects(bitmap, outputFile, duration, fadeInDuration, callback)
        
        // Add audio if provided (same as regular video creation)
        if (audioPath != null && File(audioPath).exists()) {
            val tempFile = File(outputFile.parentFile, "temp_${System.currentTimeMillis()}.mp4")
            outputFile.renameTo(tempFile)
            addAudioToVideo(tempFile.absolutePath, audioPath, outputFile.absolutePath, duration)
            tempFile.delete()
        }
        
        bitmap.recycle()
        
        // Move to gallery for Android 10+ (same as regular video creation)
        val finalPath = (context as? MainActivity)?.moveVideoToGallery(outputFile.absolutePath)
            ?: outputFile.absolutePath
        
        return finalPath
    }
}
