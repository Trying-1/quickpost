package com.quickpost.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.app.Activity
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.quickpost.app/processor"
    private val PICK_AUDIO_REQUEST = 1001
    private val PICK_VIDEO_REQUEST = 1002
    private val PICK_MULTIPLE_VIDEOS_REQUEST = 1003
    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var audioSource: String = "audio"
    private var mediaPlayer: android.media.MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "createVideo" -> {
                    val template = call.argument<String>("template") ?: "fade_in"
                    val duration = call.argument<Int>("duration") ?: 3
                    val fadeInDuration = call.argument<Double>("fadeInDuration") ?: 1.0
                    val zoomScale = call.argument<Double>("zoomScale") ?: 1.2
                    val zoomDuration = call.argument<Double>("zoomDuration") ?: 2.0
                    val audioPath = call.argument<String>("audioPath")
                    
                    // Handle both single image and image sequence
                    if (template == "image_sequence") {
                        val imagePaths = call.argument<List<String>>("imagePaths")
                        val durationPerImage = call.argument<Double>("durationPerImage") ?: 2.0
                        val sequenceMode = call.argument<String>("sequenceMode") ?: "sequential"
                        val allowRepeat = call.argument<Boolean>("allowRepeat") ?: true
                        val duration = call.argument<Int>("duration") ?: 3
                        
                        android.util.Log.d("MainActivity", "Received params: duration=$duration, durationPerImage=$durationPerImage, images=${imagePaths?.size}")
                        
                        if (imagePaths != null && imagePaths.isNotEmpty()) {
                            createVideoSequence(imagePaths, duration, durationPerImage, sequenceMode, allowRepeat, audioPath, result)
                        } else {
                            result.error("INVALID_ARGUMENT", "Image paths are required for image sequence", null)
                        }
                    } else {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath != null) {
                            createVideo(imagePath, duration, template, fadeInDuration, zoomScale, zoomDuration, audioPath, result)
                        } else {
                            result.error("INVALID_ARGUMENT", "Image path is required", null)
                        }
                    }
                }
                "pickAudioFile" -> {
                    pendingResult = result
                    audioSource = call.argument<String>("source") ?: "audio"
                    pickAudioFile()
                }
                "getAudioDuration" -> {
                    val audioPath = call.argument<String>("audioPath")
                    if (audioPath != null) {
                        val duration = getAudioDuration(audioPath)
                        result.success(duration)
                    } else {
                        result.error("INVALID_ARGUMENT", "Audio path is required", null)
                    }
                }
                "getVideoMetadata" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        val metadata = getVideoMetadata(videoPath)
                        result.success(metadata)
                    } else {
                        result.error("INVALID_ARGUMENT", "Video path is required", null)
                    }
                }
                "generateVideoThumbnail" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        val thumbnailPath = generateVideoThumbnail(videoPath)
                        result.success(thumbnailPath)
                    } else {
                        result.error("INVALID_ARGUMENT", "Video path is required", null)
                    }
                }
                "playAudio" -> {
                    val audioPath = call.argument<String>("audioPath")
                    if (audioPath != null) {
                        playAudio(audioPath)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Audio path is required", null)
                    }
                }
                "stopAudio" -> {
                    stopAudio()
                    result.success(null)
                }
                "pickMultipleVideos" -> {
                    pendingResult = result
                    pickMultipleVideos()
                }
                "extractAudioFromVideo" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        val audioPath = extractAudioFromVideoPath(videoPath)
                        result.success(audioPath)
                    } else {
                        result.error("INVALID_ARGUMENT", "Video path is required", null)
                    }
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "image/*"
                    if (filePath != null) {
                        scanMediaFile(filePath, mimeType)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "saveImageToGallery" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val filename = call.argument<String>("filename") ?: "QuickPost_${System.currentTimeMillis()}.png"
                    val folderName = call.argument<String>("folderName") ?: "Quick Post"
                    if (imageBytes != null) {
                        val savedPath = saveImageToGallery(imageBytes, filename, folderName)
                        result.success(savedPath)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image bytes are required", null)
                    }
                }
                "getVideoOutputPath" -> {
                    val filename = call.argument<String>("filename") ?: "QuickPost_${System.currentTimeMillis()}.mp4"
                    val outputPath = getVideoOutputPath(filename)
                    result.success(outputPath)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun pickAudioFile() {
        if (audioSource == "video") {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "video/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(Intent.createChooser(intent, "Select Video"), PICK_VIDEO_REQUEST)
        } else {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "audio/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(Intent.createChooser(intent, "Select Audio"), PICK_AUDIO_REQUEST)
        }
    }
    
    private fun pickMultipleVideos() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "video/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(Intent.createChooser(intent, "Select Videos"), PICK_MULTIPLE_VIDEOS_REQUEST)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            PICK_AUDIO_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null) {
                        val audioPath = getPathFromUri(uri)
                        pendingResult?.success(audioPath)
                    } else {
                        pendingResult?.success(null)
                    }
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
            PICK_VIDEO_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null) {
                        // Extract audio from video
                        extractAudioFromVideo(uri)
                    } else {
                        pendingResult?.success(null)
                        pendingResult = null
                    }
                } else {
                    pendingResult?.success(null)
                    pendingResult = null
                }
            }
            PICK_MULTIPLE_VIDEOS_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val videoPaths = mutableListOf<String>()
                    
                    // Handle multiple selection
                    if (data.clipData != null) {
                        val clipData = data.clipData!!
                        for (i in 0 until clipData.itemCount) {
                            val uri = clipData.getItemAt(i).uri
                            val path = getPathFromUri(uri)
                            if (path != null) {
                                videoPaths.add(path)
                            }
                        }
                    } else if (data.data != null) {
                        // Single selection
                        val uri = data.data!!
                        val path = getPathFromUri(uri)
                        if (path != null) {
                            videoPaths.add(path)
                        }
                    }
                    
                    pendingResult?.success(videoPaths)
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
        }
    }
    
    private fun extractAudioFromVideo(videoUri: Uri) {
        Thread {
            try {
                val videoPath = getPathFromUri(videoUri) ?: copyUriToCache(videoUri)
                
                // Save to app's audio directory with short name
                val audioDir = java.io.File(getExternalFilesDir(null), "ExtractedAudio")
                if (!audioDir.exists()) {
                    audioDir.mkdirs()
                }
                
                // Generate short sequential name
                val existingFiles = audioDir.listFiles()?.size ?: 0
                val outputFile = java.io.File(audioDir, "extAud_${existingFiles + 1}.m4a")
                
                val extractor = android.media.MediaExtractor()
                extractor.setDataSource(videoPath)
                
                // Find audio track
                var audioTrackIndex = -1
                var audioFormat: android.media.MediaFormat? = null
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(android.media.MediaFormat.KEY_MIME)
                    if (mime?.startsWith("audio/") == true) {
                        audioTrackIndex = i
                        audioFormat = format
                        break
                    }
                }
                
                if (audioTrackIndex == -1 || audioFormat == null) {
                    Handler(Looper.getMainLooper()).post {
                        pendingResult?.error("NO_AUDIO", "No audio track found in video", null)
                        pendingResult = null
                    }
                    return@Thread
                }
                
                extractor.selectTrack(audioTrackIndex)
                
                // Setup muxer
                val muxer = android.media.MediaMuxer(outputFile.absolutePath, android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val muxerTrackIndex = muxer.addTrack(audioFormat)
                muxer.start()
                
                // Copy audio data
                val buffer = java.nio.ByteBuffer.allocate(1024 * 1024)
                val bufferInfo = android.media.MediaCodec.BufferInfo()
                
                while (true) {
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break
                    
                    bufferInfo.presentationTimeUs = extractor.sampleTime
                    bufferInfo.size = sampleSize
                    bufferInfo.flags = extractor.sampleFlags
                    bufferInfo.offset = 0
                    
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                    extractor.advance()
                }
                
                extractor.release()
                muxer.stop()
                muxer.release()
                
                Handler(Looper.getMainLooper()).post {
                    pendingResult?.success(outputFile.absolutePath)
                    pendingResult = null
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    pendingResult?.error("EXTRACTION_ERROR", "Failed to extract audio: ${e.message}", null)
                    pendingResult = null
                }
            }
        }.start()
    }
    
    private fun extractAudioFromVideoPath(videoPath: String): String? {
        return try {
            // Save to app's audio directory with short name
            val audioDir = java.io.File(getExternalFilesDir(null), "ExtractedAudio")
            if (!audioDir.exists()) {
                audioDir.mkdirs()
            }
            
            // Generate short sequential name
            val existingFiles = audioDir.listFiles()?.size ?: 0
            val outputFile = java.io.File(audioDir, "extAud_${existingFiles + 1}.m4a")
            
            val extractor = android.media.MediaExtractor()
            extractor.setDataSource(videoPath)
            
            // Find audio track
            var audioTrackIndex = -1
            var audioFormat: android.media.MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }
            
            if (audioTrackIndex == -1 || audioFormat == null) {
                return null
            }
            
            extractor.selectTrack(audioTrackIndex)
            
            // Setup muxer
            val muxer = android.media.MediaMuxer(outputFile.absolutePath, android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerTrackIndex = muxer.addTrack(audioFormat)
            muxer.start()
            
            // Copy audio data
            val buffer = java.nio.ByteBuffer.allocate(1024 * 1024)
            val bufferInfo = android.media.MediaCodec.BufferInfo()
            
            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.size = sampleSize
                bufferInfo.flags = extractor.sampleFlags
                bufferInfo.offset = 0
                
                muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }
            
            extractor.release()
            muxer.stop()
            muxer.release()
            
            outputFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error extracting audio: ${e.message}")
            null
        }
    }
    
    private fun getAudioDuration(audioPath: String): String {
        return try {
            val extractor = android.media.MediaExtractor()
            extractor.setDataSource(audioPath)
            
            var durationUs = 0L
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    if (format.containsKey(android.media.MediaFormat.KEY_DURATION)) {
                        durationUs = format.getLong(android.media.MediaFormat.KEY_DURATION)
                    }
                    break
                }
            }
            extractor.release()
            
            val durationSeconds = durationUs / 1000000
            val minutes = durationSeconds / 60
            val seconds = durationSeconds % 60
            String.format("%d:%02d", minutes, seconds)
        } catch (e: Exception) {
            "Unknown"
        }
    }
    
    private fun playAudio(audioPath: String) {
        try {
            stopAudio() // Stop any existing playback
            
            mediaPlayer = android.media.MediaPlayer().apply {
                setDataSource(audioPath)
                prepare()
                start()
                
                setOnCompletionListener {
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("onAudioComplete", null)
                    }
                    release()
                    mediaPlayer = null
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun stopAudio() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.release()
            mediaPlayer = null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAudio()
    }
    
    private fun getPathFromUri(uri: Uri): String? {
        val cursor = contentResolver.query(uri, null, null, null, null)
        return cursor?.use {
            if (it.moveToFirst()) {
                val columnIndex = it.getColumnIndex(android.provider.MediaStore.Audio.Media.DATA)
                if (columnIndex >= 0) {
                    it.getString(columnIndex)
                } else {
                    // Fallback: copy to cache
                    copyUriToCache(uri)
                }
            } else null
        }
    }
    
    private fun copyUriToCache(uri: Uri): String {
        val inputStream = contentResolver.openInputStream(uri)
        val cacheFile = java.io.File(cacheDir, "temp_audio_${System.currentTimeMillis()}.mp3")
        inputStream?.use { input ->
            cacheFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return cacheFile.absolutePath
    }

    private fun createVideo(
        imagePath: String,
        duration: Int,
        template: String,
        fadeInDuration: Double,
        zoomScale: Double,
        zoomDuration: Double,
        audioPath: String?,
        result: MethodChannel.Result
    ) {
        // Start video processing in background thread
        Thread {
            try {
                val processor = VideoProcessor(this)
                val outputPath = processor.createVideo(
                    imagePath,
                    duration,
                    template,
                    fadeInDuration,
                    zoomScale,
                    zoomDuration,
                    audioPath,
                    object : VideoProcessor.ProgressCallback {
                        override fun onProgress(progress: Double) {
                            Handler(Looper.getMainLooper()).post {
                                methodChannel?.invokeMethod("onProgress", progress)
                            }
                        }
                    }
                )
                
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onComplete", outputPath)
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onError", e.message)
                    result.error("VIDEO_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun createVideoSequence(
        imagePaths: List<String>,
        videoDuration: Int,
        durationPerImage: Double,
        sequenceMode: String,
        allowRepeat: Boolean,
        audioPath: String?,
        result: MethodChannel.Result
    ) {
        android.util.Log.d("MainActivity", "createVideoSequence called with ${imagePaths.size} images, videoDuration=$videoDuration")
        // Start video processing in background thread
        Thread {
            try {
                android.util.Log.d("MainActivity", "Creating VideoProcessor")
                val processor = VideoProcessor(this)
                android.util.Log.d("MainActivity", "Calling processor.createVideoSequence")
                val outputPath = processor.createVideoSequence(
                    imagePaths,
                    videoDuration,
                    durationPerImage,
                    sequenceMode,
                    allowRepeat,
                    audioPath,
                    object : VideoProcessor.ProgressCallback {
                        override fun onProgress(progress: Double) {
                            Handler(Looper.getMainLooper()).post {
                                methodChannel?.invokeMethod("onProgress", progress)
                            }
                        }
                    }
                )
                
                android.util.Log.d("MainActivity", "Video created at: $outputPath")
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onComplete", outputPath)
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error creating video sequence", e)
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onError", e.message)
                    result.error("VIDEO_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun getVideoMetadata(videoPath: String): Map<String, Any> {
        val extractor = android.media.MediaExtractor()
        extractor.setDataSource(videoPath)
        
        val metadata = mutableMapOf<String, Any>()
        
        // Get duration
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            if (format.containsKey(android.media.MediaFormat.KEY_DURATION)) {
                val durationUs = format.getLong(android.media.MediaFormat.KEY_DURATION)
                metadata["durationMs"] = (durationUs / 1000).toInt()
                break
            }
        }
        
        // Get file size
        val file = java.io.File(videoPath)
        metadata["fileSizeBytes"] = file.length()
        
        // Get file name
        metadata["fileName"] = file.name
        
        extractor.release()
        return metadata
    }
    
    private fun generateVideoThumbnail(videoPath: String): String? {
        try {
            val retriever = android.media.MediaMetadataRetriever()
            retriever.setDataSource(videoPath)
            
            // Get frame at 1 second
            val bitmap = retriever.getFrameAtTime(1_000_000, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            retriever.release()
            
            if (bitmap != null) {
                // Save thumbnail
                val thumbDir = java.io.File(cacheDir, "video_thumbnails")
                if (!thumbDir.exists()) {
                    thumbDir.mkdirs()
                }
                
                val thumbFile = java.io.File(thumbDir, "thumb_${System.currentTimeMillis()}.jpg")
                val out = java.io.FileOutputStream(thumbFile)
                bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, out)
                out.flush()
                out.close()
                bitmap.recycle()
                
                return thumbFile.absolutePath
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error generating thumbnail", e)
        }
        return null
    }
    
    private fun scanMediaFile(filePath: String, mimeType: String) {
        android.media.MediaScannerConnection.scanFile(
            this,
            arrayOf(filePath),
            arrayOf(mimeType)
        ) { path, uri ->
            android.util.Log.d("MainActivity", "Media scan completed for: $path, URI: $uri")
        }
    }
    
    private fun saveImageToGallery(imageBytes: ByteArray, filename: String, folderName: String): String? {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                // Use MediaStore API for Android 10+
                val contentValues = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$folderName")
                    put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
                }
                
                val uri = contentResolver.insert(
                    android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    contentValues
                )
                
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(imageBytes)
                        outputStream.flush()
                    }
                    
                    // Mark as not pending anymore
                    contentValues.clear()
                    contentValues.put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)
                    
                    // Get the actual file path
                    val projection = arrayOf(android.provider.MediaStore.Images.Media.DATA)
                    contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val columnIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DATA)
                            return cursor.getString(columnIndex)
                        }
                    }
                    
                    // Return URI as string if path not available
                    return uri.toString()
                }
            } else {
                // Legacy method for Android 9 and below
                val picturesDir = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_PICTURES
                )
                val appDir = java.io.File(picturesDir, folderName)
                if (!appDir.exists()) {
                    appDir.mkdirs()
                }
                
                val imageFile = java.io.File(appDir, filename)
                java.io.FileOutputStream(imageFile).use { outputStream ->
                    outputStream.write(imageBytes)
                    outputStream.flush()
                }
                
                // Scan the file so it appears in gallery
                android.media.MediaScannerConnection.scanFile(
                    this,
                    arrayOf(imageFile.absolutePath),
                    arrayOf("image/png"),
                    null
                )
                
                return imageFile.absolutePath
            }
            
            null
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error saving image to gallery", e)
            null
        }
    }
    
    fun getVideoOutputPath(filename: String): String {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            // For Android 10+, use app-specific directory first, then move to MediaStore
            val outputDir = java.io.File(getExternalFilesDir(null), "Videos")
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }
            java.io.File(outputDir, filename).absolutePath
        } else {
            // For Android 9 and below, use DCIM directory
            try {
                val dcimDir = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_DCIM
                )
                val outputDir = java.io.File(dcimDir, "Quick Post")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                java.io.File(outputDir, filename).absolutePath
            } catch (e: Exception) {
                // Fallback to app-specific directory
                val outputDir = java.io.File(getExternalFilesDir(null), "Videos")
                if (!outputDir.exists()) {
                    outputDir.mkdirs()
                }
                java.io.File(outputDir, filename).absolutePath
            }
        }
    }
    
    fun moveVideoToGallery(videoPath: String): String? {
        return try {
            val videoFile = java.io.File(videoPath)
            if (!videoFile.exists()) {
                return null
            }
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                // Use MediaStore API for Android 10+
                val contentValues = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Video.Media.DISPLAY_NAME, videoFile.name)
                    put(android.provider.MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(android.provider.MediaStore.Video.Media.RELATIVE_PATH, "DCIM/Quick Post")
                    put(android.provider.MediaStore.Video.Media.IS_PENDING, 1)
                }
                
                val uri = contentResolver.insert(
                    android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    contentValues
                )
                
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        videoFile.inputStream().use { inputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    
                    // Mark as not pending
                    contentValues.clear()
                    contentValues.put(android.provider.MediaStore.Video.Media.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)
                    
                    // Delete temp file
                    videoFile.delete()
                    
                    // Get the actual file path
                    val projection = arrayOf(android.provider.MediaStore.Video.Media.DATA)
                    contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val columnIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Video.Media.DATA)
                            return cursor.getString(columnIndex)
                        }
                    }
                    
                    return uri.toString()
                }
            } else {
                // For Android 9 and below, file is already in DCIM
                // Just scan it
                android.media.MediaScannerConnection.scanFile(
                    this,
                    arrayOf(videoPath),
                    arrayOf("video/mp4"),
                    null
                )
                return videoPath
            }
            
            null
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error moving video to gallery", e)
            null
        }
    }
}
