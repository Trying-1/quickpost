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
import com.quickpost.app.CollageRenderingBridge

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.quickpost.app/processor"
    private val PICK_AUDIO_REQUEST = 1001
    private val PICK_VIDEO_REQUEST = 1002
    private val PICK_MULTIPLE_VIDEOS_REQUEST = 1003
    private val PICK_BACKUP_FOLDER_REQUEST = 1004
    private val PICK_SAVE_PRESETS_REQUEST = 1005
    private val PICK_LOAD_PRESETS_REQUEST = 1006
    private val PICK_LOAD_FILE_REQUEST = 1007
    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPresetsJson: String? = null
    private var pendingPresetsBytes: ByteArray? = null
    private var audioSource: String = "audio"
    private var mediaPlayer: android.media.MediaPlayer? = null
    private var sharedImagePaths: MutableList<String> = mutableListOf()
    private var sharedImageUris: MutableList<Uri> = mutableListOf()
    private var sharedPurpose: String? = null
    private var shareIntentProcessed = false
    private var currentWatermarkProcessor: OpenGLWatermarkProcessor? = null
    private var currentVideoCropper: OpenGLVideoCropper? = null
    
    private var previewMethodChannel: MethodChannel? = null

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

        CollageRenderingBridge.register(flutterEngine.dartExecutor.binaryMessenger, this)
        
        previewMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.quickpost.app/preview")

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
                            call.argument<Boolean>("isVideo") ?: false,
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
                    
                    if (treeUri == null || audioDestDir == null) {
                        result.error("INVALID_ARGUMENT", "treeUri and audioDestDir are required", null)
                    } else {
                        Thread {
                            try {
                                val importResult = importBackupFromSaf(treeUri, audioDestDir)
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
                    val isTemporary = call.argument<Boolean>("isTemporary") ?: false
                    val outputPath = getVideoOutputPath(filename, isTemporary)
                    result.success(outputPath)
                }
                "createCarouselVideo" -> {
                    val slides = call.argument<List<Map<String, Any?>>>("slides")
                    val width = call.argument<Int>("width") ?: 1080
                    val height = call.argument<Int>("height") ?: 1350
                    val durationPerSlide = call.argument<Double>("durationPerSlide") ?: 3.0
                    val audioPath = call.argument<String>("audioPath")
                    
                    if (slides != null) {
                        createCarouselVideo(slides, width, height, durationPerSlide, audioPath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Slides are required", null)
                    }
                }
                "createCarouselImages" -> {
                    val slides = call.argument<List<Map<String, Any?>>>("slides")
                    val width = call.argument<Int>("width") ?: 1080
                    val height = call.argument<Int>("height") ?: 1350
                    
                    if (slides != null) {
                        createCarouselImages(slides, width, height, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Slides are required", null)
                    }
                }
                "createVideoFromImages" -> {
                    val imagePaths = call.argument<List<String>>("imagePaths")
                    val durationPerSlide = call.argument<Double>("durationPerSlide") ?: 3.0
                    
                    if (imagePaths != null && imagePaths.isNotEmpty()) {
                        createVideoFromImages(imagePaths, durationPerSlide, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image paths are required", null)
                    }
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
                        createAutomationVideo(imagePath ?: "", duration, template, fadeInDuration, zoomScale, zoomDuration, audioPath, automationSettings, null, false, result)
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
                                    override fun onStep(step: String) {
                                        runOnUiThread {
                                            methodChannel?.invokeMethod("onStep", step)
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
                                        override fun onStep(step: String) {
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
                    if (items == null || items.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "Items list is required", null)
                    } else {
                        Thread {
                            try {
                                val cropper = OpenGLVideoCropper(this)
                                currentVideoCropper = cropper
                                val outputPaths = mutableListOf<String>()
                                
                                for ((index, item) in items.withIndex()) {
                                    val inputPath = item["inputPath"] as String
                                    val cropX = (item["x"] as? Number)?.toInt() ?: 0
                                    val cropY = (item["y"] as? Number)?.toInt() ?: 0
                                    val cropW = (item["width"] as? Number)?.toInt() ?: 100
                                    val cropH = (item["height"] as? Number)?.toInt() ?: 100
                                    val rotation = (item["rotation"] as? Number)?.toInt() ?: 0
                                    val isFlipped = item["isFlipped"] as? Boolean ?: false
                                    val fillEnabled = item["fillEnabled"] as? Boolean ?: false
                                    val bgColor = item["bgColor"] as? String ?: "#000000"
                                    val bgImagePath = item["bgImagePath"] as? String
                                    val bgBlur = (item["bgBlur"] as? Number)?.toFloat() ?: 10.0f
                                    val bgImageBlur = (item["bgImageBlur"] as? Number)?.toFloat() ?: 0.0f
                                    val bgBrightness = (item["bgBrightness"] as? Number)?.toFloat() ?: 1.0f
                                    val bgSaturation = (item["bgSaturation"] as? Number)?.toFloat() ?: 1.0f
                                    val bgOpacity = (item["bgOpacity"] as? Number)?.toFloat() ?: 0.0f
                                    
                                    val outFileName = "Crop_${System.currentTimeMillis()}_$index.mp4"
                                    val outputPath = (item["outputPath"] as? String) ?: getVideoOutputPath(outFileName)
                                    
                                    val success = cropper.processVideo(
                                        inputPath, outputPath, 
                                        cropX, cropY, cropW, cropH, 
                                        rotation, isFlipped, fillEnabled, bgColor, bgImagePath, 
                                        bgBlur, bgImageBlur, bgBrightness, bgSaturation, bgOpacity,
                                        object : OpenGLVideoCropper.ProgressCallback {
                                            override fun onProgress(progress: Double) {
                                                val totalProgress = (index + progress) / items.size
                                                runOnUiThread { methodChannel?.invokeMethod("onProgress", totalProgress) }
                                            }
                                        }
                                    )
                                    
                                    if (success) {
                                        outputPaths.add(outputPath)
                                    }
                                }
                                
                                runOnUiThread {
                                    currentVideoCropper = null
                                    result.success(outputPaths)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    currentVideoCropper = null
                                    result.error("OPENGL_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                }
                "cropImagesBatch" -> {
                    val items = call.argument<List<Map<String, Any>>>("items")
                    if (items == null || items.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "Items list is required", null)
                    } else {
                        Thread {
                            try {
                                val cropper = OpenGLImageCropper(this)
                                val outputPaths = mutableListOf<String>()
                                
                                for ((index, item) in items.withIndex()) {
                                    val inputPath = item["inputPath"] as String
                                    val cropX = (item["x"] as? Number)?.toInt() ?: 0
                                    val cropY = (item["y"] as? Number)?.toInt() ?: 0
                                    val cropW = (item["width"] as? Number)?.toInt() ?: 100
                                    val cropH = (item["height"] as? Number)?.toInt() ?: 100
                                    val rotation = (item["rotation"] as? Number)?.toInt() ?: 0
                                    val isFlipped = item["isFlipped"] as? Boolean ?: false
                                    
                                    val pDir = java.io.File(getExternalFilesDir(null), "exports")
                                    if (!pDir.exists()) pDir.mkdirs()
                                    val outFileName = "ImageCrop_${System.currentTimeMillis()}_$index.jpg"
                                    val outPath = java.io.File(pDir, outFileName).absolutePath
                                    
                                    val success = cropper.processImage(inputPath, outPath, cropX, cropY, cropW, cropH, rotation, isFlipped)
                                    if (success) {
                                        outputPaths.add(outPath)
                                    }
                                    
                                    runOnUiThread {
                                        val progress = (index + 1.0) / items.size
                                        methodChannel?.invokeMethod("onProgress", progress)
                                    }
                                }
                                
                                runOnUiThread {
                                    result.success(outputPaths)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("OPENGL_ERROR", e.message, null)
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
                                val processor = OpenGLTextOverlayProcessor(this)
                                val textParams = mapOf<String, Any?>(
                                    "text" to text,
                                    "x" to x,
                                    "y" to y,
                                    "fontSize" to fontSize,
                                    "fontColor" to fontColor,
                                    "boxColor" to boxColor,
                                    "boxOpacity" to boxOpacity,
                                    "boxHeight" to boxHeight,
                                    "hAlign" to hAlign,
                                    "vAlign" to vAlign,
                                    "lineHeight" to lineHeight,
                                    "fontPath" to fontPath,
                                    "preset" to preset,
                                    "crf" to crf,
                                    "showShadow" to showShadow,
                                    "shadowColor" to shadowColor,
                                    "shadowX" to shadowX,
                                    "shadowY" to shadowY,
                                    "textOpacity" to textOpacity,
                                    "horizontalPadding" to horizontalPadding,
                                    "verticalPadding" to verticalPadding,
                                )

                                val outputFile = java.io.File(outputPath)
                                val glCallback = object : OpenGLTextOverlayProcessor.ProgressCallback {
                                    override fun onProgress(progress: Double) {
                                        runOnUiThread {
                                            methodChannel?.invokeMethod("onProgress", progress)
                                        }
                                    }
                                    override fun onStep(step: String) {
                                        Log.d("VideoTextOverlay", "Step: $step")
                                    }
                                }
                                processor.processVideoWithText(inputPath, outputFile, textParams, glCallback)

                                runOnUiThread {
                                    if (outputFile.exists() && outputFile.length() > 0) {
                                        if (!audioPath.isNullOrEmpty()) {
                                            // Merge external audio
                                            try {
                                                val mergedPath = getVideoOutputPath("VideoOverlay_Audio_${System.currentTimeMillis()}.mp4")
                                                val durationSec = ((getVideoMetadata(outputPath)["durationMs"] as? Int) ?: 0) / 1000
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
                                        } else {
                                            val finalPath = moveVideoToGallery(outputPath) ?: outputPath
                                            result.success(finalPath)
                                        }
                                    } else {
                                        result.error("PROCESSING_FAILED", "Output file is empty or missing", null)
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

                "addWatermarkToVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val type = call.argument<String>("type") ?: "profile"
                    val fullScreen = call.argument<Boolean>("fullScreen") ?: false
                    val bgColor = call.argument<String>("bgColor") ?: "#000000"
                    val showBox = call.argument<Boolean>("showBox") ?: true
                    val boxColor = call.argument<String>("boxColor") ?: "#000000"
                    val boxOpacity = (call.argument<Number>("boxOpacity"))?.toFloat() ?: 0.3f
                    val boxRadius = (call.argument<Number>("boxRadius"))?.toFloat() ?: 12f
                    val username = call.argument<String>("username") ?: ""
                    val handle = call.argument<String>("handle") ?: ""
                    val x = call.argument<Number>("x")?.toInt() ?: 100
                    val y = call.argument<Number>("y")?.toInt() ?: 100
                    val profileImagePath = call.argument<String>("profileImagePath") ?: ""
                    val fontSize = call.argument<Number>("fontSize")?.toFloat() ?: 40f
                    val iconSize = call.argument<Number>("iconSize")?.toFloat() ?: 100f
                    val textColor = call.argument<String>("textColor") ?: "#FFFFFF"
                    val accentColor = call.argument<String>("accentColor") ?: "#AAAAAA"
                    val fontPath = call.argument<String>("fontPath") ?: ""
                    val bgImagePath = call.argument<String>("bgImagePath") ?: ""
                    val bgBrightness = (call.argument<Number>("bgBrightness"))?.toFloat() ?: 1.0f
                    val bgSaturation = (call.argument<Number>("bgSaturation"))?.toFloat() ?: 1.0f
                    val bgBlur = (call.argument<Number>("bgBlur"))?.toFloat() ?: 0f
                    val videoY = (call.argument<Number>("videoY"))?.toFloat() ?: 0.5f
                    val audioPath = call.argument<String>("audioPath")
                    val patches = call.argument<List<Map<String, Any?>>>("patches") ?: emptyList()

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing input or output path", null)
                    } else {
                        Thread {
                            try {
                                 val processor = OpenGLWatermarkProcessor(this)
                                currentWatermarkProcessor = processor
                                val params = mapOf<String, Any?>(
                                    "type" to type,
                                    "fullScreen" to fullScreen,
                                    "bgColor" to bgColor,
                                    "showBox" to showBox,
                                    "boxColor" to boxColor,
                                    "boxOpacity" to boxOpacity,
                                    "boxRadius" to boxRadius,
                                    "username" to username,
                                    "handle" to handle,
                                    "x" to x,
                                    "y" to y,
                                    "profileImagePath" to profileImagePath,
                                    "iconSize" to iconSize,
                                    "usernameSize" to ((call.argument<Number>("usernameSize"))?.toFloat() ?: 36f),
                                    "handleSize" to ((call.argument<Number>("handleSize"))?.toFloat() ?: 30f),
                                    "textColor" to textColor,
                                    "accentColor" to accentColor,
                                    "fontPath" to fontPath,
                                    "handleFontPath" to (call.argument<String>("handleFontPath") ?: fontPath),
                                    "bgImagePath" to bgImagePath,
                                    "bgBrightness" to bgBrightness,
                                    "bgSaturation" to bgSaturation,
                                    "bgBlur" to bgBlur,
                                    "showStoryRing" to (call.argument<Boolean>("showStoryRing") ?: false),
                                    "storyRingColor" to (call.argument<String>("storyRingColor") ?: "gradient"),
                                    "storyRingWidth" to ((call.argument<Number>("storyRingWidth"))?.toFloat() ?: 5f),
                                    "isVerified" to (call.argument<Boolean>("isVerified") ?: false),
                                    "verifiedBadgeColor" to (call.argument<String>("verifiedBadgeColor") ?: "#1DA1F2"),
                                    "verifiedBadgeAttachTo" to (call.argument<String>("verifiedBadgeAttachTo") ?: "handle"),
                                    "patches" to patches,
                                    "showUsernameShadow" to (call.argument<Boolean>("showUsernameShadow") ?: false),
                                    "usernameShadowColor" to (call.argument<String>("usernameShadowColor") ?: "#000000"),
                                    "usernameShadowBlur" to ((call.argument<Number>("usernameShadowBlur"))?.toFloat() ?: 4f),
                                    "showHandleShadow" to (call.argument<Boolean>("showHandleShadow") ?: false),
                                    "handleShadowColor" to (call.argument<String>("handleShadowColor") ?: "#000000"),
                                    "handleShadowBlur" to ((call.argument<Number>("handleShadowBlur"))?.toFloat() ?: 4f),
                                    "showIconShadow" to (call.argument<Boolean>("showIconShadow") ?: false),
                                    "iconShadowColor" to (call.argument<String>("iconShadowColor") ?: "#000000"),
                                    "iconShadowBlur" to ((call.argument<Number>("iconShadowBlur"))?.toFloat() ?: 4f),
                                    "usernameShadowOffsetX" to ((call.argument<Number>("usernameShadowOffsetX"))?.toFloat() ?: 1f),
                                    "usernameShadowOffsetY" to ((call.argument<Number>("usernameShadowOffsetY"))?.toFloat() ?: 1f),
                                    "handleShadowOffsetX" to ((call.argument<Number>("handleShadowOffsetX"))?.toFloat() ?: 1f),
                                    "handleShadowOffsetY" to ((call.argument<Number>("handleShadowOffsetY"))?.toFloat() ?: 1f),
                                    "iconShadowOffsetX" to ((call.argument<Number>("iconShadowOffsetX"))?.toFloat() ?: 1.5f),
                                    "iconShadowOffsetY" to ((call.argument<Number>("iconShadowOffsetY"))?.toFloat() ?: 1.5f),
                                    "videoY" to videoY,
                                    "watermarkScale" to ((call.argument<Number>("watermarkScale"))?.toFloat() ?: 1.0f),
                                    "textOverlays" to (call.argument<List<Map<String, Any?>>>("textOverlays") ?: emptyList()),
                                    "imageOverlays" to (call.argument<List<Map<String, Any?>>>("imageOverlays") ?: emptyList()),
                                    "showVideoShadow" to (call.argument<Boolean>("showVideoShadow") ?: false),
                                    "videoShadowColor" to (call.argument<String>("videoShadowColor") ?: "#000000"),
                                    "videoShadowBlur" to ((call.argument<Number>("videoShadowBlur"))?.toFloat() ?: 10f),
                                    "videoShadowSpread" to ((call.argument<Number>("videoShadowSpread"))?.toFloat() ?: 0f),
                                    "videoShadowOffsetX" to ((call.argument<Number>("videoShadowOffsetX"))?.toFloat() ?: 0f),
                                    "videoShadowOffsetY" to ((call.argument<Number>("videoShadowOffsetY"))?.toFloat() ?: 0f),
                                    "videoRadius" to ((call.argument<Number>("videoRadius"))?.toFloat() ?: 0f),
                                    "videoBorderWidth" to ((call.argument<Number>("videoBorderWidth"))?.toFloat() ?: 0f),
                                    "videoBorderColor" to (call.argument<String>("videoBorderColor") ?: "#000000"),
                                    "videoScale" to ((call.argument<Number>("videoScale"))?.toFloat() ?: 1.0f),
                                    "wireRadius" to ((call.argument<Number>("wireRadius"))?.toFloat() ?: 12f),
                                    "wireWidth" to ((call.argument<Number>("wireWidth"))?.toFloat() ?: 1.5f),
                                    "wireColor" to (call.argument<String>("wireColor") ?: "#FFFFFF"),
                                    "wireCutout" to (call.argument<Boolean>("wireCutout") ?: true),
                                    "wireCutoutDots" to (call.argument<Boolean>("wireCutoutDots") ?: true),
                                    "previewScale" to ((call.argument<Number>("previewScale"))?.toFloat() ?: 0.33f),
                                    "wireInset" to ((call.argument<Number>("wireInset"))?.toFloat() ?: 40f),
                                    "wireTextPosition" to (call.argument<String>("wireTextPosition") ?: "bottom"),
                                    "wireGap" to ((call.argument<Number>("wireGap"))?.toFloat() ?: 16f)
                                )
                                val outputFile = java.io.File(outputPath)
                                val callback = object : OpenGLWatermarkProcessor.ProgressCallback {
                                    override fun onProgress(p: Double) {
                                        runOnUiThread { methodChannel?.invokeMethod("onProgress", p) }
                                    }
                                    override fun onStep(s: String) {
                                        runOnUiThread { methodChannel?.invokeMethod("onStep", s) }
                                    }
                                }
                                try {
                                    processor.processVideoWithWatermark(inputPath, outputFile, params, callback)
                                    runOnUiThread {
                                        if (outputFile.exists() && outputFile.length() > 0) {
                                            scanMediaFile(outputFile.absolutePath)
                                            result.success(outputFile.absolutePath)
                                        } else {
                                            result.error("PROCESSING_FAILED", "Output file is empty or missing.", null)
                                        }
                                    }
                                } finally {
                                    currentWatermarkProcessor = null
                                }
                            } catch (e: Exception) {
                                currentWatermarkProcessor = null
                                runOnUiThread { result.error("PROCESSING_FAILED", e.message, null) }
                            }
                        }.start()
                    }
                }


                "cancelWatermarkToVideo" -> {
                    currentWatermarkProcessor?.cancel()
                    result.success(true)
                }
                "getSharedImages" -> {
                    val results = mapOf(
                        "paths" to sharedImagePaths.toList(),
                        "count" to sharedImagePaths.size,
                        "purpose" to (sharedPurpose ?: "")
                    )
                    // Clear after retrieval
                    sharedImagePaths.clear()
                    sharedImageUris.clear()
                    sharedPurpose = null
                    result.success(results)
                }
                "exportPresets" -> {
                    val json = call.argument<String>("json")
                    pendingResult = result
                    exportPresets(json)
                }
                "importPresets" -> {
                    pendingResult = result
                    importPresets()
                }
                "exportFile" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "QuickPost_Project.zip"
                    val mimeType = call.argument<String>("mimeType") ?: "application/zip"
                    pendingResult = result
                    exportFile(bytes, filename, mimeType)
                }
                "importFile" -> {
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    pendingResult = result
                    importFile(mimeType)
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
                "saveVideoToGallery" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        val galleryPath = moveVideoToGallery(videoPath)
                        result.success(galleryPath)
                    } else {
                        result.error("INVALID_ARGUMENT", "videoPath is required", null)
                    }
                }
                "saveImageToGallery" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath != null) {
                        val galleryPath = moveImageToGallery(imagePath)
                        result.success(galleryPath)
                    } else {
                        result.error("INVALID_ARGUMENT", "imagePath is required", null)
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

    private fun exportPresets(json: String?) {
        if (json == null) {
            pendingResult?.error("INVALID_ARGUMENT", "JSON is null", null)
            pendingResult = null
            return
        }
        pendingPresetsJson = json
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "QuickPost_Watermark_Presets.json")
        }
        startActivityForResult(intent, PICK_SAVE_PRESETS_REQUEST)
    }

    private fun importPresets() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
        }
        startActivityForResult(intent, PICK_LOAD_PRESETS_REQUEST)
    }

    private fun exportFile(bytes: ByteArray?, filename: String, mimeType: String) {
        if (bytes == null) {
            pendingResult?.error("INVALID_ARGUMENT", "Bytes are null", null)
            pendingResult = null
            return
        }
        pendingPresetsBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, filename)
        }
        startActivityForResult(intent, PICK_SAVE_PRESETS_REQUEST)
    }

    private fun importFile(mimeType: String) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            if (mimeType == "*/*") {
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "application/zip", "application/x-zip-compressed"))
            }
        }
        startActivityForResult(intent, PICK_LOAD_FILE_REQUEST)
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
            PICK_SAVE_PRESETS_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null && (pendingPresetsJson != null || pendingPresetsBytes != null)) {
                        try {
                            contentResolver.openOutputStream(uri)?.use { out ->
                                if (pendingPresetsBytes != null) {
                                    out.write(pendingPresetsBytes)
                                } else {
                                    out.write(pendingPresetsJson!!.toByteArray(Charsets.UTF_8))
                                }
                            }
                            pendingResult?.success(true)
                        } catch (e: Exception) {
                            pendingResult?.error("WRITE_ERROR", e.message, null)
                        }
                    } else {
                        pendingResult?.success(false)
                    }
                } else {
                    pendingResult?.success(false)
                }
                pendingPresetsJson = null
                pendingPresetsBytes = null
                pendingResult = null
            }
            PICK_LOAD_PRESETS_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null) {
                        try {
                            val json = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                            pendingResult?.success(json)
                        } catch (e: Exception) {
                            pendingResult?.error("READ_ERROR", e.message, null)
                        }
                    } else {
                        pendingResult?.success(null)
                    }
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
            1007 -> { // PICK_LOAD_FILE_REQUEST
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val uri = data.data
                    if (uri != null) {
                        try {
                            val cachedPath = copyUriToCache(uri)
                            pendingResult?.success(cachedPath)
                        } catch (e: Exception) {
                            pendingResult?.error("READ_ERROR", e.message, null)
                        }
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

    private fun importBackupFromSaf(treeUriStr: String, audioDestDir: String): Map<String, Any?> {
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
        
        android.util.Log.d("MainActivity", "Audio dir found: ${audioDirDoc != null}")
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

        val totalAudio = audioArray.length()
        runOnUiThread {
            methodChannel?.invokeMethod(
                "onSafImportProgress",
                mapOf(
                    "current" to 0,
                    "total" to totalAudio,
                    "status" to "Preparing import..."
                )
            )
        }

        for (i in 0 until audioArray.length()) {
            val audioObj = audioArray.getJSONObject(i)
            try {
                val audioFileName = audioObj.getString("audioFileName")
                android.util.Log.d("MainActivity", "Processing audio entry $i: $audioFileName")

                runOnUiThread {
                    methodChannel?.invokeMethod(
                        "onSafImportProgress",
                        mapOf(
                            "current" to (i + 1),
                            "total" to totalAudio,
                            "status" to "Importing: ${audioObj.optString("name", audioFileName)}"
                        )
                    )
                }
                
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

                val audioMap = mutableMapOf<String, Any?>(
                    "name" to audioObj.getString("name"),
                    "durationMs" to audioObj.getInt("durationMs"),
                    "folderId" to audioObj.optString("folderId", "default"),
                    "originalVideoPath" to if (audioObj.has("originalVideoPath") && !audioObj.isNull("originalVideoPath")) audioObj.getString("originalVideoPath") else null,
                    "audioPath" to audioPath,
                    "thumbnailPath" to null,
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
        isVideo: Boolean,
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
                        override fun onStep(step: String) {
                            uiHandler.post {
                                methodChannel?.invokeMethod("onStep", step)
                            }
                        }
                    },
                    isVideo
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
                    targetWidth = 1080,
                    targetHeight = 1920,
                    callback = object : VideoProcessor.ProgressCallback {
                        override fun onProgress(progress: Double) {
                            runOnUiThread { methodChannel?.invokeMethod("onProgress", progress) }
                        }
                        override fun onStep(step: String) {
                            runOnUiThread { methodChannel?.invokeMethod("onStep", step) }
                        }
                    }
                )
                runOnUiThread { result.success(outputPath) }
            } catch (e: Exception) {
                runOnUiThread { result.error("VIDEO_ERROR", e.message, null) }
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
                        override fun onStep(step: String) {
                            Handler(Looper.getMainLooper()).post {
                                methodChannel?.invokeMethod("onStep", step)
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
    
    fun getVideoOutputPath(filename: String, isTemporary: Boolean = false): String {
        val outputDir = if (isTemporary) {
            val tempDir = java.io.File(getExternalFilesDir(null), "temp_outputs")
            if (!tempDir.exists()) {
                tempDir.mkdirs()
            }
            tempDir
        } else {
            val dcimDir = android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DCIM
            )
            val dir = java.io.File(dcimDir, "Quick Post")
            if (!dir.exists()) {
                dir.mkdirs()
            }
            dir
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

    private fun createCarouselVideo(
        slides: List<Map<String, Any?>>,
        width: Int,
        height: Int,
        durationPerSlide: Double,
        audioPath: String?,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val processor = OpenGLCarouselProcessor(this)
                val filename = "Carousel_${System.currentTimeMillis()}.mp4"
                val outFile = File(getExternalFilesDir(null), filename)

                val callback = object : OpenGLCarouselProcessor.ProgressCallback {
                    override fun onProgress(progress: Double) {
                        runOnUiThread { methodChannel?.invokeMethod("onProgress", progress) }
                    }
                    override fun onStep(step: String) {
                        runOnUiThread { methodChannel?.invokeMethod("onStep", step) }
                    }
                }

                val success = processor.processCarousel(slides, width, height, durationPerSlide, outFile, callback)

                if (success) {
                    val finalPath = outFile.absolutePath
                    val galleryPath = moveVideoToGallery(finalPath) ?: finalPath
                    runOnUiThread {
                        methodChannel?.invokeMethod("onComplete", galleryPath)
                        result.success(galleryPath)
                    }
                } else {
                    runOnUiThread {
                        result.error("PROCESS_FAILED", "OpenGL Carousel processing failed", null)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun createCarouselImages(
        slides: List<Map<String, Any?>>,
        width: Int,
        height: Int,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val processor = OpenGLCarouselProcessor(this)
                val callback = object : OpenGLCarouselProcessor.ProgressCallback {
                    override fun onProgress(progress: Double) {
                        runOnUiThread { methodChannel?.invokeMethod("onProgress", progress) }
                    }
                    override fun onStep(step: String) {
                        runOnUiThread { methodChannel?.invokeMethod("onStep", step) }
                    }
                }

                val savedPaths = processor.processCarouselImages(slides, width, height, callback)
                
                // Move images to public gallery
                val galleryPaths = savedPaths.map { path ->
                    // For images, we can use saveImageToGallery or move to DCIM
                    // Since OpenGLCarouselProcessor saves them to internal exports, we should move them
                    val file = File(path)
                    val outFileName = "Carousel_${System.currentTimeMillis()}_${file.name}"
                    saveImageToGallery(file.readBytes(), outFileName, "Quick Post") ?: path
                }

                runOnUiThread {
                    methodChannel?.invokeMethod("onComplete", galleryPaths)
                    result.success(galleryPaths)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun createVideoFromImages(
        imagePaths: List<String>,
        durationPerSlide: Double,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val processor = OpenGLCarouselProcessor(this)
                val filename = "Carousel_${System.currentTimeMillis()}.mp4"
                val outFile = File(getExternalFilesDir(null), filename)

                val callback = object : OpenGLCarouselProcessor.ProgressCallback {
                    override fun onProgress(progress: Double) {
                        runOnUiThread { methodChannel?.invokeMethod("onProgress", progress) }
                    }
                    override fun onStep(step: String) {
                        runOnUiThread { methodChannel?.invokeMethod("onStep", step) }
                    }
                }

                val success = processor.processVideoFromImages(imagePaths, durationPerSlide, outFile, callback)

                if (success) {
                    val finalPath = outFile.absolutePath
                    val galleryPath = moveVideoToGallery(finalPath) ?: finalPath
                    runOnUiThread {
                        methodChannel?.invokeMethod("onComplete", galleryPath)
                        result.success(galleryPath)
                    }
                } else {
                    runOnUiThread {
                        result.error("PROCESS_FAILED", "Video encoding failed", null)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("ERROR", e.message, null)
                }
            }
        }.start()
    }
}

