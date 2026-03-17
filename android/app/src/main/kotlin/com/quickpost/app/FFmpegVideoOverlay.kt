package com.quickpost.app

import android.content.Context
import android.util.Log

class FFmpegVideoOverlay(private val context: Context) {

    private var isNativeLoaded: Boolean = false

    init {
        try {
            System.loadLibrary("myffmpeg")
            isNativeLoaded = true
            Log.i(TAG, "myffmpeg library loaded successfully for VideoOverlay")
        } catch (e: UnsatisfiedLinkError) {
            isNativeLoaded = false
            Log.e(TAG, "Failed to load myffmpeg library for VideoOverlay", e)
        }
    }

    external fun nativeAddTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
        boxOpacity: Float,
        boxHeight: Int,
        horizontalPadding: Int,
        verticalPadding: Int,
        hAlign: String,
        vAlign: String,
        lineHeight: Float,
        position: String,
        fontPath: String,
        preset: String,
        crf: Int,
        showShadow: Boolean,
        shadowColor: String,
        shadowX: Int,
        shadowY: Int,
        textOpacity: Float,
    ): Int

    fun addTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
        boxOpacity: Float,
        boxHeight: Int,
        horizontalPadding: Int,
        verticalPadding: Int,
        hAlign: String,
        vAlign: String,
        lineHeight: Float,
        position: String,
        fontPath: String,
        preset: String,
        crf: Int,
        showShadow: Boolean,
        shadowColor: String,
        shadowX: Int,
        shadowY: Int,
        textOpacity: Float,
    ): Int {
        Log.i(TAG, "addTextToVideo (New) called: input=$inputPath, output=$outputPath")

        if (!isNativeLoaded) {
            Log.e(TAG, "Native library not loaded, aborting addTextToVideo")
            return -999
        }

        return nativeAddTextToVideo(
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
    }

    companion object {
        private const val TAG = "FFmpegVideoOverlay"
    }
}
