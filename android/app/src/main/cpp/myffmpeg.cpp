#include <jni.h>
#include <cstring>
#include "ffmpeg_text_overlay.h"

extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_FFmpegTextOverlay_nativeAddTextToVideo(
    JNIEnv* env,
    jobject thiz,
    jstring inputPath,
    jstring outputPath,
    jstring text,
    jint x,
    jint y,
    jint fontSize,
    jstring fontColor,
    jstring boxColor,
    jstring position,
    jstring fontPath,
    jstring preset,
    jint crf
) {
    // Get JNI strings
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    const char* overlay_text = env->GetStringUTFChars(text, nullptr);
    const char* text_color_raw = env->GetStringUTFChars(fontColor, nullptr);
    const char* box_color_raw = env->GetStringUTFChars(boxColor, nullptr);
    const char* position_raw = env->GetStringUTFChars(position, nullptr);
    const char* font = env->GetStringUTFChars(fontPath, nullptr);
    const char* preset_str = env->GetStringUTFChars(preset, nullptr);

    LOGI("Starting text overlay: input=%s, output=%s", input_file, output_file);
    LOGI("Text: %s, Position: (%d, %d), FontSize: %d, TextColor: %s, BoxColor: %s, BoxPos: %s, Font: %s, Preset: %s, CRF: %d",
         overlay_text, x, y, fontSize, text_color_raw, box_color_raw, position_raw, font, preset_str, crf);

    // Convert hex colors from #RRGGBB to 0xRRGGBB format
    char text_color_buf[16];
    char box_color_buf[16];
    const char* text_color = text_color_raw;
    const char* box_color = box_color_raw;

    if (text_color_raw && text_color_raw[0] == '#' && strlen(text_color_raw) == 7) {
        snprintf(text_color_buf, sizeof(text_color_buf), "0x%.6s", text_color_raw + 1);
        text_color = text_color_buf;
    }

    if (box_color_raw && box_color_raw[0] == '#' && strlen(box_color_raw) == 7) {
        snprintf(box_color_buf, sizeof(box_color_buf), "0x%.6s", box_color_raw + 1);
        box_color = box_color_buf;
    }

    int ret = 0;

    // Initialize text overlay context
    TextOverlayContext ctx;
    text_overlay_init_context(&ctx);

    // Step 1: Open input and setup decoder
    if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) {
        goto cleanup;
    }

    if ((ret = ffmpeg_setup_decoder(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }

    // Step 2: Setup encoder and output
    if ((ret = ffmpeg_setup_encoder(&ctx.ffmpeg_ctx, output_file, preset_str, crf)) < 0) {
        goto cleanup;
    }

    // Step 3: Setup audio passthrough
    if ((ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }

    // Step 4: Setup text overlay filter
    if ((ret = text_overlay_setup_filter(&ctx, overlay_text, text_color, box_color,
                                         position_raw, font, fontSize)) < 0) {
        goto cleanup;
    }

    // Step 5: Process frames
    if ((ret = text_overlay_process_frames(&ctx, output_file)) < 0) {
        goto cleanup;
    }

    LOGI("Text overlay completed successfully");

cleanup:
    text_overlay_cleanup(&ctx);
    ffmpeg_release_jni_strings(env, inputPath, input_file, outputPath, output_file,
                               text, overlay_text, fontColor, text_color_raw,
                               boxColor, box_color_raw, position, position_raw,
                               fontPath, font, preset, preset_str);

    return ret;
}
