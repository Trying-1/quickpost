package com.quickpost.app

import android.content.Context
import android.util.Log

class FFmpegTextOverlay(private val context: Context) {

    private var isNativeLoaded: Boolean = false

    init {
        try {
            System.loadLibrary("myffmpeg")
            isNativeLoaded = true
            Log.i(TAG, "myffmpeg library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            isNativeLoaded = false
            Log.e(TAG, "Failed to load myffmpeg library", e)
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
    ): Int

    external fun nativeMergeAudioVideo(
        videoPath: String,
        audioPath: String,
        outputPath: String,
        duration: Int
    ): Int

    external fun nativeAddTextToImageVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
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
        duration: Double,
        transition: String,
    ): Int

    fun addTextToImageVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
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
        duration: Double,
        transition: String,
    ): Int {
        Log.i(TAG, "addTextToImageVideo called: input=$inputPath, duration=$duration, transition=$transition")
        if (!isNativeLoaded) return -999
        return nativeAddTextToImageVideo(
            inputPath, outputPath, text, fontSize, fontColor, boxColor, boxHeight,
            horizontalPadding, verticalPadding, hAlign, vAlign, lineHeight, position,
            fontPath, preset, crf, duration, transition
        )
    }

    fun addTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
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
    ): Int {
        Log.i(TAG, "addTextToVideo called: input=$inputPath, output=$outputPath")

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
    }

    companion object {
        private const val TAG = "FFmpegTextOverlay"
    }
}
