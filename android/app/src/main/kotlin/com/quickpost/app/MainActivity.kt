package com.quickpost.app

import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.app.Activity
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import java.io.File
import androidx.documentfile.provider.DocumentFile
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.quickpost.app/processor"
    private val PICK_AUDIO_REQUEST = 1001
    private val PICK_VIDEO_REQUEST = 1002
    private val PICK_MULTIPLE_VIDEOS_REQUEST = 1003
    private val PICK_BACKUP_FOLDER_REQUEST = 1004
    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var audioSource: String = "audio"
    private var mediaPlayer: android.media.MediaPlayer? = null
    private var sharedImagePaths: MutableList<String> = mutableListOf()
    private var sharedImageUris: MutableList<Uri> = mutableListOf()
    private var sharedPurpose: String? = null
    private var shareIntentProcessed = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (!shareIntentProcessed) {
            handleShareIntent(intent)
            shareIntentProcessed = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        shareIntentProcessed = false
        handleShareIntent(intent)
        shareIntentProcessed = true
    }

    private fun handleShareIntent(intent: Intent) {
        android.util.Log.d("MainActivity", "handleShareIntent called with action: ${intent.action}")
        
        // Check for direct purpose from intent extras (for direct share targets)
        sharedPurpose = intent.getStringExtra("share_purpose")
        
        if (intent.action == Intent.ACTION_SEND) {
            val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (imageUri != null) {
                android.util.Log.d("MainActivity", "Processing single image share: $imageUri")
                sharedImageUris.clear()
                sharedImagePaths.clear()
                sharedImageUris.add(imageUri)
                val imagePath = getPathFromUri(imageUri)
                android.util.Log.d("MainActivity", "Converted URI to path: $imagePath")
                if (imagePath != null) {
                    sharedImagePaths.add(imagePath)
                    android.util.Log.d("MainActivity", "Added image path, total: ${sharedImagePaths.size}")
                }
                android.util.Log.d("MainActivity", "Received single image share: $imagePath, purpose: $sharedPurpose")
                notifyFlutterOfSharedImages()
            } else {
                android.util.Log.d("MainActivity", "No image URI found in SEND intent")
            }
        } else if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val imageUris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            android.util.Log.d("MainActivity", "Processing multiple images share: ${imageUris?.size} URIs")
            if (imageUris != null && imageUris.isNotEmpty()) {
                sharedImageUris.clear()
                sharedImagePaths.clear()
                for (uri in imageUris) {
                    sharedImageUris.add(uri)
                    val imagePath = getPathFromUri(uri)
                    android.util.Log.d("MainActivity", "Converted URI to path: $imagePath")
                    if (imagePath != null) {
                        sharedImagePaths.add(imagePath)
                    }
                }
                android.util.Log.d("MainActivity", "Received ${imageUris.size} images share, converted to ${sharedImagePaths.size} paths, purpose: $sharedPurpose")
                notifyFlutterOfSharedImages()
            } else {
                android.util.Log.d("MainActivity", "No image URIs found in SEND_MULTIPLE intent")
            }
        } else {
            android.util.Log.d("MainActivity", "Intent action not recognized: ${intent.action}")
        }
        
        // Clear the intent action to prevent re-processing
        intent.action = null
    }

    private fun notifyFlutterOfSharedImages() {
        if (sharedImagePaths.isNotEmpty()) {
            Handler(Looper.getMainLooper()).postDelayed({
                methodChannel?.invokeMethod("onImagesShared", mapOf(
                    "paths" to sharedImagePaths,
                    "count" to sharedImagePaths.size,
                    "purpose" to (sharedPurpose ?: "")
                ))
            }, 500) // Delay to ensure Flutter is ready
        }
    }

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
                    val automationSettings = call.argument<Map<String, Any>>("automationSettings")
                    val qualitySettings = call.argument<Map<String, Any>>("qualitySettings")
                    
                    if (automationSettings != null) {
                        // Use dedicated automation processor
                        createAutomationVideo(
                            call.argument<String>("imagePath") ?: "",
                            duration,
                            template,
                            fadeInDuration,
                            zoomScale,
                            zoomDuration,
                            audioPath,
                            automationSettings,
                            qualitySettings,
                            result
                        )
                    } else {
                        // Use standard processor
                        if (template == "image_sequence") {
                            val imagePaths = call.argument<List<String>>("imagePaths")
                            val durationPerImage = call.argument<Double>("durationPerImage") ?: 2.0
                            val sequenceMode = call.argument<String>("sequenceMode") ?: "sequential"
                            val allowRepeat = call.argument<Boolean>("allowRepeat") ?: true
                            createVideoSequence(imagePaths ?: listOf(), duration, durationPerImage, sequenceMode, allowRepeat, audioPath, result)
                        } else {
                            val imagePath = call.argument<String>("imagePath")
                            if (imagePath != null) {
                                createVideo(imagePath, duration, template, fadeInDuration, zoomScale, zoomDuration, audioPath, result)
                            } else {
                                result.error("INVALID_ARGUMENT", "Image path is required", null)
                            }
                        }
                    }
                }
                "pickAudioFile" -> {
                    pendingResult = result
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
                "pickBackupFolder" -> {
                    pendingResult = result
                    pickBackupFolder()
                }
                "importBackupFromSaf" -> {
                    val treeUri = call.argument<String>("treeUri")
                    val audioDestDir = call.argument<String>("audioDestDir")
                    val thumbDestDir = call.argument<String>("thumbDestDir")

                    if (treeUri == null || audioDestDir == null || thumbDestDir == null) {
                        result.error("INVALID_ARGUMENT", "treeUri, audioDestDir and thumbDestDir are required", null)
                    } else {
                        Thread {
                            try {
                                val importResult = importBackupFromSaf(treeUri, audioDestDir, thumbDestDir)
                                runOnUiThread {
                                    result.success(importResult)
                                }
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "SAF import failed", e)
                                runOnUiThread {
                                    result.error("IMPORT_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
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
                "createVideoWithFFmpeg" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val duration = call.argument<Int>("duration") ?: 3
                    val template = call.argument<String>("template") ?: "fade_in"
                    val fadeInDuration = call.argument<Double>("fadeInDuration") ?: 1.0
                    val zoomScale = call.argument<Double>("zoomScale") ?: 1.1
                    val zoomDuration = call.argument<Double>("zoomDuration") ?: duration.toDouble()
                    val audioPath = call.argument<String>("audioPath")
                    val automationSettings = call.argument<Map<String, Any>>("automationSettings")
                    
                    if (automationSettings != null) {
                        createAutomationVideo(imagePath ?: "", duration, template, fadeInDuration, zoomScale, zoomDuration, audioPath, automationSettings, null, result)
                    } else {
                        if (imagePath != null) {
                            try {
                                val videoProcessor = VideoProcessor(this)
                                val callback = object : VideoProcessor.ProgressCallback {
                                    override fun onProgress(progress: Double) {
                                        runOnUiThread {
                                            methodChannel?.invokeMethod("onProgress", progress)
                                        }
                                    }
                                }
                                
                                val filename = "QuickPost_${System.currentTimeMillis()}.mp4"
                                val outputPath = getVideoOutputPath(filename)
                                
                                Thread {
                                    try {
                                        val resultPath = videoProcessor.createVideo(
                                            imagePath, 
                                            duration, 
                                            template,
                                            fadeInDuration,
                                            zoomScale,
                                            zoomDuration,
                                            audioPath,
                                            1080, // Default width
                                            1920, // Default height
                                            callback
                                        )
                                        runOnUiThread {
                                            methodChannel?.invokeMethod("onComplete", resultPath)
                                            result.success(resultPath)
                                        }
                                    } catch (e: Exception) {
                                        runOnUiThread {
                                            methodChannel?.invokeMethod("onError", "FFmpeg video creation failed: ${e.message}")
                                            result.error("FFMPEG_ERROR", e.message, null)
                                        }
                                    }
                                }.start()
                            } catch (e: Exception) {
                                result.error("FFMPEG_ERROR", "Failed to start FFmpeg video creation: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "Image path is required", null)
                        }
                    }
                }
                "addTextToVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val text = call.argument<String>("text") ?: ""
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    val fontSize = call.argument<Int>("fontSize") ?: 40
                    val fontColor = call.argument<String>("fontColor") ?: "#000000"
                    val boxColor = call.argument<String>("boxColor") ?: "#FFFFFF"
                    val boxHeight = call.argument<Int>("boxHeight") ?: 80
                    val horizontalPadding = call.argument<Int>("horizontalPadding") ?: 12
                    val verticalPadding = call.argument<Int>("verticalPadding") ?: 8
                    val hAlign = call.argument<String>("hAlign") ?: "center"
                    val vAlign = call.argument<String>("vAlign") ?: "middle"
                    val lineHeight = call.argument<Double>("lineHeight")?.toFloat() ?: 1.2f
                    val position = call.argument<String>("position") ?: "top"
                    val fontPath = call.argument<String>("fontPath") ?: ""
                    val preset = call.argument<String>("preset") ?: "veryfast"
                    val crf = call.argument<Int>("crf") ?: 23
                    val audioPath = call.argument<String>("audioPath")

                    val showShadow = call.argument<Boolean>("showShadow") ?: false
                    val shadowColor = call.argument<String>("shadowColor") ?: "#000000"
                    val shadowX = call.argument<Int>("shadowX") ?: 2
                    val shadowY = call.argument<Int>("shadowY") ?: 2

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing input or output path", null)
                    } else {
                        Thread {
                            try {
                                val overlay = FFmpegTextOverlay(this)
                                val ret = overlay.addTextToVideo(
                                    inputPath,
                                    outputPath,
                                    text,
                                    x,
                                    y,
                                    fontSize,
                                    fontColor,
                                    boxColor,
                                    boxHeight,
                                    horizontalPadding,
                                    verticalPadding,
                                    hAlign,
                                    vAlign,
                                    lineHeight,
                                    position,
                                    fontPath,
                                    preset,
                                    crf,
                                    showShadow,
                                    shadowColor,
                                    shadowX,
                                    shadowY,
                                )

                                runOnUiThread {
                                    if (ret == 0) {
                                        scanMediaFile(outputPath)
                                        if (audioPath.isNullOrEmpty()) {
                                            result.success(outputPath)
                                        } else {
                                            try {
                                                val mergedPath = getVideoOutputPath("TextBox_Audio_${System.currentTimeMillis()}.mp4")
                                                val durationSec = ((getVideoMetadata(outputPath)["durationMs"] as? Int) ?: 0) / 1000
                                                val mergeRet = overlay.nativeMergeAudioVideo(outputPath, audioPath, mergedPath, durationSec)
                                                if (mergeRet == 0) {
                                                    scanMediaFile(mergedPath)
                                                    result.success(mergedPath)
                                                } else {
                                                    result.error("FFMPEG_ERROR", "Audio merge failed: $mergeRet", null)
                                                }
                                            } catch (e: Exception) {
                                                result.error("PROCESSING_FAILED", e.message, null)
                                            }
                                        }
                                    } else {
                                        result.error("FFMPEG_ERROR", "FFmpeg returned error code: $ret", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("PROCESSING_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "addTextToImageVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val text = call.argument<String>("text") ?: ""
                    val fontSize = call.argument<Int>("fontSize") ?: 40
                    val fontColor = call.argument<String>("fontColor") ?: "#000000"
                    val boxColor = call.argument<String>("boxColor") ?: "#FFFFFF"
                    val boxHeight = call.argument<Int>("boxHeight") ?: 80
                    val horizontalPadding = call.argument<Int>("horizontalPadding") ?: 12
                    val verticalPadding = call.argument<Int>("verticalPadding") ?: 8
                    val hAlign = call.argument<String>("hAlign") ?: "center"
                    val vAlign = call.argument<String>("vAlign") ?: "middle"
                    val lineHeight = call.argument<Double>("lineHeight")?.toFloat() ?: 1.2f
                    val position = call.argument<String>("position") ?: "top"
                    val fontPath = call.argument<String>("fontPath") ?: ""
                    val preset = call.argument<String>("preset") ?: "veryfast"
                    val crf = call.argument<Int>("crf") ?: 23
                    val duration = call.argument<Double>("duration") ?: 5.0
                    val fadeInDuration = call.argument<Double>("fadeInDuration") ?: 1.0
                    val transition = call.argument<String>("transition") ?: "none"
                    val audioPath = call.argument<String>("audioPath")

                    val showShadow = call.argument<Boolean>("showShadow") ?: false
                    val shadowColor = call.argument<String>("shadowColor") ?: "#000000"
                    val shadowX = call.argument<Int>("shadowX") ?: 2
                    val shadowY = call.argument<Int>("shadowY") ?: 2

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing input or output path", null)
                    } else {
                        Thread {
                            try {
                // Two-step pipeline to avoid treating an image as a video stream in native FFmpeg:
                                // 1) Create a temporary MP4 from the still image.
                                // 2) Apply the existing addTextToVideo overlay (stable video pipeline).
                                val videoProcessor = VideoProcessor(this)
                                
                                // Calculate dimensions to match the image aspect ratio, similar to video processing
                                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                BitmapFactory.decodeFile(inputPath, options)
                                var targetWidth = options.outWidth
                                var targetHeight = options.outHeight
                                
                                // Ensure even dimensions for FFmpeg
                                if (targetWidth % 2 != 0) targetWidth--
                                if (targetHeight % 2 != 0) targetHeight--

                                val template = if (transition.equals("fade", ignoreCase = true)) "fade_in" else "plain"

                                val createdVideoPath = videoProcessor.createVideo(
                                    inputPath,
                                    duration.toInt().coerceAtLeast(1),
                                    template,
                                    fadeInDuration,
                                    1.0,
                                    duration,
                                    null,
                                    targetWidth,
                                    targetHeight,
                                    object : VideoProcessor.ProgressCallback {
                                        override fun onProgress(progress: Double) {
                                            // no-op
                                        }
                                    }
                                )

                                // Overlay text onto the created video, writing to the requested outputPath
                                val overlay = FFmpegTextOverlay(this)
                                val ret = overlay.addTextToVideo(
                                    createdVideoPath,
                                    outputPath,
                                    text,
                                    0,
                                    0,
                                    fontSize,
                                    fontColor,
                                    boxColor,
                                    boxHeight,
                                    horizontalPadding,
                                    verticalPadding,
                                    hAlign,
                                    vAlign,
                                    lineHeight,
                                    position,
                                    fontPath,
                                    preset,
                                    crf,
                                    showShadow,
                                    shadowColor,
                                    shadowX,
                                    shadowY,
                                )

                                runOnUiThread {
                                    if (ret == 0) {
                                        scanMediaFile(outputPath)
                                        if (audioPath.isNullOrEmpty()) {
                                            result.success(outputPath)
                                        } else {
                                            try {
                                                val mergedPath = getVideoOutputPath("TextBox_Audio_${System.currentTimeMillis()}.mp4")
                                                val durationSec = duration.toInt().coerceAtLeast(1)
                                                val mergeRet = overlay.nativeMergeAudioVideo(outputPath, audioPath, mergedPath, durationSec)
                                                if (mergeRet == 0) {
                                                    scanMediaFile(mergedPath)
                                                    result.success(mergedPath)
                                                } else {
                                                    result.error("FFMPEG_ERROR", "Audio merge failed: $mergeRet", null)
                                                }
                                            } catch (e: Exception) {
                                                result.error("PROCESSING_FAILED", e.message, null)
                                            }
                                        }
                                    } else {
                                        result.error("FFMPEG_ERROR", "FFmpeg returned error code: $ret", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("PROCESSING_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "cropVideosBatch" -> {
                    val items = call.argument<List<Map<String, Any>>>("items")
                    val preset = call.argument<String>("preset") ?: "veryfast"
                    val crf = call.argument<Int>("crf") ?: 23

                    if (items == null || items.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "Items list is required", null)
                    } else {
                        Thread {
                            try {
                                val cropper = FFmpegVideoCropper(this)
                                val results = cropper.cropVideosBatch(items, preset, crf)
                                
                                // Move all successful results to gallery
                                val finalResults = results.map { path ->
                                    moveVideoToGallery(path) ?: path
                                }
                                
                                runOnUiThread {
                                    result.success(finalResults)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("FFMPEG_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "addTextToVideoNew" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val text = call.argument<String>("text") ?: ""
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    val fontSize = call.argument<Int>("fontSize") ?: 40
                    val fontColor = call.argument<String>("fontColor") ?: "#000000"
                    val boxColor = call.argument<String>("boxColor") ?: "#FFFFFF"
                    val boxOpacity = when (val arg = call.argument<Any>("boxOpacity")) {
                        is Double -> arg.toFloat()
                        is Int -> arg.toFloat()
                        else -> 0.0f
                    }
                    val boxHeight = call.argument<Int>("boxHeight") ?: 80
                    val horizontalPadding = call.argument<Int>("horizontalPadding") ?: 12
                    val verticalPadding = call.argument<Int>("verticalPadding") ?: 8
                    val hAlign = call.argument<String>("hAlign") ?: "center"
                    val vAlign = call.argument<String>("vAlign") ?: "middle"
                    val lineHeight = call.argument<Double>("lineHeight")?.toFloat() ?: 1.2f
                    val position = call.argument<String>("position") ?: "top"
                    val fontPath = call.argument<String>("fontPath") ?: ""
                    val preset = call.argument<String>("preset") ?: "veryfast"
                    val crf = call.argument<Int>("crf") ?: 23
                    val audioPath = call.argument<String>("audioPath")
                    
                    val showShadow = call.argument<Boolean>("showShadow") ?: true
                    val shadowColor = call.argument<String>("shadowColor") ?: "#000000"
                    val shadowX = call.argument<Int>("shadowX") ?: 2
                    val shadowY = call.argument<Int>("shadowY") ?: 2
                    val textOpacity = when (val arg = call.argument<Any>("textOpacity")) {
                        is Double -> arg.toFloat()
                        is Int -> arg.toFloat()
                        else -> 1.0f
                    }

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing input or output path", null)
                    } else {
                        Thread {
                            try {
                                val overlay = FFmpegVideoOverlay(this)
                                val ret = overlay.addTextToVideo(
                                    inputPath,
                                    outputPath,
                                    text,
                                    x,
                                    y,
                                    fontSize,
                                    fontColor,
                                    boxColor,
                                    boxOpacity,
                                    boxHeight,
                                    horizontalPadding,
                                    verticalPadding,
                                    hAlign,
                                    vAlign,
                                    lineHeight,
                                    position,
                                    fontPath,
                                    preset,
                                    crf,
                                    showShadow,
                                    shadowColor,
                                    shadowX,
                                    shadowY,
                                    textOpacity,
                                )

                                runOnUiThread {
                                    if (ret == 0) {
                                        if (audioPath.isNullOrEmpty()) {
                                            val finalPath = moveVideoToGallery(outputPath) ?: outputPath
                                            result.success(finalPath)
                                        } else {
                                            try {
                                                val mergedPath = getVideoOutputPath("VideoOverlay_Audio_${System.currentTimeMillis()}.mp4")
                                                val durationSec = ((getVideoMetadata(outputPath)["durationMs"] as? Int) ?: 0) / 1000
                                                // Using the merge from existing FFmpegTextOverlay for consistency
                                                val merger = FFmpegTextOverlay(this)
                                                val mergeRet = merger.nativeMergeAudioVideo(outputPath, audioPath, mergedPath, durationSec)
                                                if (mergeRet == 0) {
                                                    val finalPath = moveVideoToGallery(mergedPath) ?: mergedPath
                                                    result.success(finalPath)
                                                } else {
                                                    result.error("FFMPEG_ERROR", "Audio merge failed: $mergeRet", null)
                                                }
                                            } catch (e: Exception) {
                                                result.error("PROCESSING_FAILED", e.message, null)
                                            }
                                        }
                                    } else {
                                        result.error("FFMPEG_ERROR", "FFmpeg returned error code: $ret", null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("PROCESSING_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "getSharedVideos" -> {
                    val results = mapOf(
                        "paths" to sharedImagePaths.filter { it.endsWith(".mp4", true) || it.endsWith(".mov", true) || it.endsWith(".mkv", true) },
                        "count" to sharedImagePaths.size
                    )
                    // Clear after retrieval to match getSharedImages behavior
                    sharedImagePaths.clear()
                    sharedImageUris.clear()
                    sharedPurpose = null
                    result.success(results)
                }
                "saveProcessedImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val automationSettings = call.argument<Map<String, Any>>("automationSettings")
                    
                    if (imagePath != null && automationSettings != null) {
                        Thread {
                            try {
                                val processor = AriseAutomationProcessor(this)
                                processor.setAutomationSettings(automationSettings)
                                val savedPath = processor.saveProcessedImage(imagePath)
                                runOnUiThread {
                                    result.success(savedPath)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("SAVE_IMAGE_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENT", "imagePath and automationSettings are required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun pickAudioFile() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "audio/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        startActivityForResult(Intent.createChooser(intent, "Select Audio"), PICK_AUDIO_REQUEST)
    }
    
    private fun pickMultipleVideos() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "video/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(Intent.createChooser(intent, "Select Videos"), PICK_MULTIPLE_VIDEOS_REQUEST)
    }

    private fun pickBackupFolder() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            android.util.Log.d("MainActivity", "Launching folder picker for backup")
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                )
            }
            startActivityForResult(intent, PICK_BACKUP_FOLDER_REQUEST)
        } else {
            android.util.Log.e("MainActivity", "pickBackupFolder not supported on this Android version")
            pendingResult?.error("UNSUPPORTED", "Folder picker requires Android 5.0 or higher", null)
            pendingResult = null
        }
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
            PICK_BACKUP_FOLDER_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null) {
                        android.util.Log.d("MainActivity", "Folder picker returned URI: $uri")
                        pendingResult?.success(uri.toString())
                    } else {
                        pendingResult?.success(null)
                    }
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
        }
    }

    private fun importBackupFromSaf(treeUriStr: String, audioDestDir: String, thumbDestDir: String): Map<String, Any?> {
        val uri = Uri.parse(treeUriStr)
        val treeDoc = DocumentFile.fromTreeUri(this, uri)
            ?: throw IllegalStateException("Invalid backup folder URI")

        fun findManifest(doc: DocumentFile): DocumentFile? {
            doc.listFiles().forEach { child ->
                if (child.isFile && child.name == "manifest.json") {
                    return child
                }
            }
            // As a fallback, search one level deeper
            doc.listFiles().forEach { child ->
                if (child.isDirectory) {
                    val found = findManifest(child)
                    if (found != null) return found
                }
            }
            return null
        }

        val manifestDoc = findManifest(treeDoc)
            ?: throw IllegalStateException("manifest.json not found in selected folder")

        val manifestJson = contentResolver.openInputStream(manifestDoc.uri)?.use { input ->
            input.bufferedReader().use { it.readText() }
        } ?: throw IllegalStateException("Unable to read manifest.json")

        val manifest = JSONObject(manifestJson)
        android.util.Log.d("MainActivity", "Manifest read successfully")

        val backupRoot = manifestDoc.parentFile ?: treeDoc
        android.util.Log.d("MainActivity", "Backup root: ${backupRoot.name}")
        android.util.Log.d("MainActivity", "Backup root contents: ${backupRoot.listFiles().joinToString { "${it.name} (${if (it.isDirectory) "dir" else "file"})" }}")
        
        val audioDirDoc = backupRoot.listFiles().firstOrNull { it.isDirectory && it.name == "audio" }
        val thumbDirDoc = backupRoot.listFiles().firstOrNull { it.isDirectory && it.name == "thumbnails" }
        
        android.util.Log.d("MainActivity", "Audio dir found: ${audioDirDoc != null}, Thumb dir found: ${thumbDirDoc != null}")
        if (audioDirDoc != null) {
            val audioFiles = audioDirDoc.listFiles()
            android.util.Log.d("MainActivity", "Audio directory has ${audioFiles.size} files")
            audioFiles.forEach { file ->
                android.util.Log.d("MainActivity", "  - ${file.name} (${file.length()} bytes)")
            }
        }

        val foldersArray = manifest.optJSONArray("folders") ?: JSONArray()
        val audioArray = manifest.optJSONArray("audio") ?: JSONArray()
        android.util.Log.d("MainActivity", "Manifest contains ${audioArray.length()} audio entries and ${foldersArray.length()} folders")

        val foldersResult = mutableListOf<Map<String, Any?>>()
        val audioResult = mutableListOf<Map<String, Any?>>()

        for (i in 0 until foldersArray.length()) {
            val folderObj = foldersArray.getJSONObject(i)
            val folderMap = mutableMapOf<String, Any?>(
                "id" to folderObj.getString("id"),
                "name" to folderObj.getString("name"),
                "description" to if (folderObj.has("description") && !folderObj.isNull("description")) folderObj.getString("description") else null,
                "iconName" to if (folderObj.has("iconName") && !folderObj.isNull("iconName")) folderObj.getString("iconName") else null,
                "colorValue" to folderObj.optInt("colorValue", 0xFF9C27B0.toInt()),
            )
            foldersResult.add(folderMap)
        }

        fun copyDocumentFileTo(destinationDir: String, doc: DocumentFile, fileName: String): String {
            val destDir = java.io.File(destinationDir)
            if (!destDir.exists()) {
                destDir.mkdirs()
            }
            val destFile = java.io.File(destDir, fileName)
            android.util.Log.d("MainActivity", "Copying ${doc.name} to ${destFile.absolutePath}")
            contentResolver.openInputStream(doc.uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Unable to open input stream for ${doc.uri}")
            android.util.Log.d("MainActivity", "File copied successfully. Size: ${destFile.length()} bytes")
            return destFile.absolutePath
        }

        var importedCount = 0
        var skippedCount = 0

        for (i in 0 until audioArray.length()) {
            val audioObj = audioArray.getJSONObject(i)
            try {
                val audioFileName = audioObj.getString("audioFileName")
                android.util.Log.d("MainActivity", "Processing audio entry $i: $audioFileName")
                
                if (audioDirDoc == null) {
                    android.util.Log.w("MainActivity", "Audio directory not found in backup")
                    skippedCount++
                    continue
                }

                val audioDoc = audioDirDoc.listFiles().firstOrNull { it.isFile && it.name == audioFileName }
                if (audioDoc == null) {
                    android.util.Log.w("MainActivity", "Audio file not found: $audioFileName in ${audioDirDoc.name}")
                    skippedCount++
                    continue
                }

                val audioDestName = "audio_${System.currentTimeMillis()}_${i}.m4a"
                android.util.Log.d("MainActivity", "Copying audio file: $audioFileName -> $audioDestName")
                val audioPath = copyDocumentFileTo(audioDestDir, audioDoc, audioDestName)

                var thumbnailPath: String? = null
                val thumbnailFileName = if (audioObj.has("thumbnailFileName") && !audioObj.isNull("thumbnailFileName")) {
                    audioObj.getString("thumbnailFileName")
                } else null

                if (thumbnailFileName != null && thumbDirDoc != null) {
                    val thumbDoc = thumbDirDoc.listFiles().firstOrNull { it.isFile && it.name == thumbnailFileName }
                    if (thumbDoc != null) {
                        val thumbDestName = "thumb_${System.currentTimeMillis()}_${i}.jpg"
                        thumbnailPath = copyDocumentFileTo(thumbDestDir, thumbDoc, thumbDestName)
                    }
                }

                val audioMap = mutableMapOf<String, Any?>(
                    "name" to audioObj.getString("name"),
                    "durationMs" to audioObj.getInt("durationMs"),
                    "folderId" to audioObj.optString("folderId", "default"),
                    "originalVideoPath" to if (audioObj.has("originalVideoPath") && !audioObj.isNull("originalVideoPath")) audioObj.getString("originalVideoPath") else null,
                    "audioPath" to audioPath,
                    "thumbnailPath" to thumbnailPath,
                )

                audioResult.add(audioMap)
                importedCount++
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error importing audio entry", e)
                skippedCount++
            }
        }

        android.util.Log.d("MainActivity", "SAF import complete: imported=$importedCount, skipped=$skippedCount, folders=${foldersResult.size}")
        
        return mapOf(
            "folders" to foldersResult,
            "audio" to audioResult,
            "importedCount" to importedCount,
            "skippedCount" to skippedCount,
            "folderCount" to foldersResult.size,
        )
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
        return when (uri.scheme) {
            "content" -> {
                // Try to get path from MediaStore
                val projection = arrayOf(android.provider.MediaStore.MediaColumns.DATA)
                val cursor = contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val columnIndex = it.getColumnIndex(android.provider.MediaStore.MediaColumns.DATA)
                        if (columnIndex >= 0) {
                            val path = it.getString(columnIndex)
                            if (path != null && java.io.File(path).exists()) {
                                return@use path
                            }
                        }
                    }
                    null
                } ?: run {
                    // Fallback: copy to cache
                    copyUriToCache(uri)
                }
            }
            "file" -> uri.path
            else -> {
                // Fallback: copy to cache
                copyUriToCache(uri)
            }
        }
    }
    
    private fun copyUriToCache(uri: Uri): String {
        val inputStream = contentResolver.openInputStream(uri)
        val fileName = uri.lastPathSegment ?: "temp_image_${System.currentTimeMillis()}.jpg"
        val cacheFile = java.io.File(cacheDir, fileName)
        inputStream?.use { input ->
            cacheFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        android.util.Log.d("MainActivity", "Copied URI to cache: ${cacheFile.absolutePath}")
        return cacheFile.absolutePath
    }

    private fun createAutomationVideo(
        imagePath: String,
        duration: Int,
        template: String,
        fadeInDuration: Double,
        zoomScale: Double,
        zoomDuration: Double,
        audioPath: String?,
        automationSettings: Map<String, Any>,
        qualitySettings: Map<String, Any>?,
        result: MethodChannel.Result
    ) {
        val uiHandler = Handler(Looper.getMainLooper())
        
        Thread {
            try {
                android.util.Log.d("MainActivity", "Starting Automation Video Thread")
                val processor = AriseAutomationProcessor(this)
                processor.setAutomationSettings(automationSettings)
                
                val outputPath = processor.createVideo(
                    imagePath,
                    duration,
                    template,
                    fadeInDuration,
                    zoomScale,
                    zoomDuration,
                    audioPath,
                    qualitySettings,
                    object : AriseAutomationProcessor.ProgressCallback {
                        override fun onProgress(progress: Double) {
                            uiHandler.post {
                                android.util.Log.d("MainActivity", "Sending progress to Flutter: $progress")
                                methodChannel?.invokeMethod("onProgress", progress)
                            }
                        }
                    }
                )
                
                uiHandler.post {
                    android.util.Log.i("MainActivity", "Automation Video Complete: $outputPath")
                    methodChannel?.invokeMethod("onProgress", 1.0)
                    methodChannel?.invokeMethod("onComplete", outputPath)
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Automation Video Thread Error", e)
                uiHandler.post {
                    methodChannel?.invokeMethod("onError", "Automation video failed: ${e.message}")
                    result.error("AUTOMATION_ERROR", e.message, null)
                }
            }
        }.start()
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
                    1080, // Default width
                    1920, // Default height
                    object : VideoProcessor.ProgressCallback {
                        override fun onProgress(progress: Double) {
                            runOnUiThread {
                                methodChannel?.invokeMethod("onProgress", progress)
                            }
                        }
                    }
                )
                runOnUiThread {
                    methodChannel?.invokeMethod("onComplete", outputPath)
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    methodChannel?.invokeMethod("onError", "Video creation failed: ${e.message}")
                    result.error("PROCESSING_ERROR", e.message, null)
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
        val retriever = android.media.MediaMetadataRetriever()
        retriever.setDataSource(videoPath)
        
        val metadata = mutableMapOf<String, Any>()
        
        // Get duration
        val durationStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
        if (durationStr != null) {
            metadata["durationMs"] = durationStr.toInt()
        }
        
        // Get width and height
        val widthStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        val heightStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        if (widthStr != null && heightStr != null) {
            metadata["width"] = widthStr.toInt()
            metadata["height"] = heightStr.toInt()
        }

        // Get file size
        val file = java.io.File(videoPath)
        metadata["fileSizeBytes"] = file.length()
        
        // Get file name
        metadata["fileName"] = file.name
        
        retriever.release()
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
    
    private fun scanMediaFile(filePath: String, mimeType: String = "video/mp4") {
        android.media.MediaScannerConnection.scanFile(
            this,
            arrayOf(filePath),
            arrayOf(mimeType)
        ) { path, uri ->
            android.util.Log.d("MainActivity", "Media scan completed for: $path, URI: $uri")
        }
    }
    
    fun moveImageToGallery(filePath: String): String? {
        return try {
            val file = java.io.File(filePath)
            val imageBytes = file.readBytes()
            val filename = file.name
            saveImageToGallery(imageBytes, filename, "Quick Post")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error moving image to gallery", e)
            filePath
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
        val dcimDir = android.os.Environment.getExternalStoragePublicDirectory(
            android.os.Environment.DIRECTORY_DCIM
        )
        val outputDir = java.io.File(dcimDir, "Quick Post")
        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }
        return java.io.File(outputDir, filename).absolutePath
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
