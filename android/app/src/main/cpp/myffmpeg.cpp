#include <jni.h>
#include <cstring>
#include <cstdio>
#include <ctime>
#include <string>
#include <unistd.h>
#include "ffmpeg_text_overlay.h"

static std::string jstring_to_utf8(JNIEnv* env, jstring str) {
    if (str == nullptr) return std::string();

    const jchar* chars = env->GetStringChars(str, nullptr);
    if (chars == nullptr) return std::string();
    const jsize len = env->GetStringLength(str);

    std::string out;
    out.reserve(static_cast<size_t>(len) * 3);

    for (jsize i = 0; i < len; i++) {
        uint32_t codepoint = chars[i];
        if (codepoint >= 0xD800 && codepoint <= 0xDBFF && (i + 1) < len) {
            const uint32_t low = chars[i + 1];
            if (low >= 0xDC00 && low <= 0xDFFF) {
                codepoint = 0x10000 + (((codepoint - 0xD800) << 10) | (low - 0xDC00));
                i++;
            }
        }

        if (codepoint <= 0x7F) {
            out.push_back(static_cast<char>(codepoint));
        } else if (codepoint <= 0x7FF) {
            out.push_back(static_cast<char>(0xC0 | ((codepoint >> 6) & 0x1F)));
            out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        } else if (codepoint <= 0xFFFF) {
            out.push_back(static_cast<char>(0xE0 | ((codepoint >> 12) & 0x0F)));
            out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xF0 | ((codepoint >> 18) & 0x07)));
            out.push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
        }
    }

    env->ReleaseStringChars(str, chars);
    return out;
}

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
    jint boxHeight,
    jint horizontalPadding,
    jint verticalPadding,
    jstring hAlign,
    jstring vAlign,
    jfloat lineHeight,
    jstring position,
    jstring fontPath,
    jstring preset,
    jint crf,
    jboolean showShadow, jstring shadowColor, jint shadowX, jint shadowY,
    jstring audioPathStr, jfloat audioVolume, jboolean loopAudio,
    jstring boxImagePath, jint boxOverlap) {
    // Get JNI strings
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    const std::string overlay_text_utf8 = jstring_to_utf8(env, text);
    const char* overlay_text = overlay_text_utf8.c_str();
    const char* text_color_raw = env->GetStringUTFChars(fontColor, nullptr);
    const char* box_color_raw = env->GetStringUTFChars(boxColor, nullptr);
    const char* h_align_raw = env->GetStringUTFChars(hAlign, nullptr);
    const char* v_align_raw = env->GetStringUTFChars(vAlign, nullptr);
    const char* position_raw = env->GetStringUTFChars(position, nullptr);
    const char* font = env->GetStringUTFChars(fontPath, nullptr);
    const char* preset_str = env->GetStringUTFChars(preset, nullptr);
    const char* shadow_color_raw = shadowColor ? env->GetStringUTFChars(shadowColor, nullptr) : nullptr;
    const char* box_image_path = boxImagePath ? env->GetStringUTFChars(boxImagePath, nullptr) : nullptr;

    LOGI("Starting text overlay: input=%s, output=%s", input_file, output_file);
    LOGI("Text: %s, Position: (%d, %d), FontSize: %d, TextColor: %s, BoxColor: %s, BoxHeight: %d, HorizontalPadding: %d, VerticalPadding: %d, HAlign: %s, VAlign: %s, LineHeight: %.2f, BoxPos: %s, Font: %s, Preset: %s, CRF: %d, Shadow: %d, ShadowColor: %s, ShadowX: %d, ShadowY: %d, BoxImagePath: %s",
         overlay_text, x, y, fontSize, text_color_raw, box_color_raw, boxHeight, horizontalPadding, verticalPadding, h_align_raw, v_align_raw, lineHeight, position_raw, font, preset_str, crf,
         (int)showShadow, (shadow_color_raw ? shadow_color_raw : ""), (int)shadowX, (int)shadowY, (box_image_path ? box_image_path : ""));

    // Convert hex colors from #RRGGBB to 0xRRGGBB format
    char text_color_buf[16];
    char box_color_buf[16];
    char shadow_color_buf[16];
    const char* text_color = text_color_raw;
    const char* box_color = box_color_raw;
    const char* shadow_color = shadow_color_raw;

    if (text_color_raw && text_color_raw[0] == '#' && strlen(text_color_raw) == 7) {
        snprintf(text_color_buf, sizeof(text_color_buf), "0x%.6s", text_color_raw + 1);
        text_color = text_color_buf;
    }

    if (box_color_raw && box_color_raw[0] == '#' && strlen(box_color_raw) == 7) {
        snprintf(box_color_buf, sizeof(box_color_buf), "0x%.6s", box_color_raw + 1);
        box_color = box_color_buf;
    }

    if (shadow_color_raw && shadow_color_raw[0] == '#' && strlen(shadow_color_raw) == 7) {
        snprintf(shadow_color_buf, sizeof(shadow_color_buf), "0x%.6s", shadow_color_raw + 1);
        shadow_color = shadow_color_buf;
    }

    int ret = 0;
    const char* textfile_cstr = nullptr;

    std::string textfile_path;
    bool textfile_created = false;
    if (overlay_text && overlay_text[0] != '\0') {
        std::string input_path_str = (input_file ? std::string(input_file) : std::string());
        std::string dir = "/data/local/tmp";
        const size_t slash = input_path_str.find_last_of('/');
        if (slash != std::string::npos) {
            dir = input_path_str.substr(0, slash);
        }

        char name_buf[256];
        snprintf(name_buf, sizeof(name_buf), "qp_text_%d_%ld.txt", (int)getpid(), (long)time(nullptr));
        textfile_path = dir + "/" + name_buf;

        FILE* f = fopen(textfile_path.c_str(), "wb");
        if (f) {
            fwrite(overlay_text_utf8.data(), 1, overlay_text_utf8.size(), f);
            fclose(f);
            textfile_created = true;
        } else {
            LOGE("Failed to create textfile for drawtext: %s", textfile_path.c_str());
        }
    }

    if (textfile_created) {
        textfile_cstr = textfile_path.c_str();
    }

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
    int padHeight;
    padHeight = boxHeight - boxOverlap;
    if (padHeight < 0) padHeight = 0;
    if ((ret = ffmpeg_setup_encoder(&ctx.ffmpeg_ctx, output_file, preset_str, crf, padHeight)) < 0) {
        goto cleanup;
    }

    // Step 3: Setup audio passthrough
    if ((ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }

    // Step 4: Setup text overlay filter
    if ((ret = text_overlay_setup_filter(&ctx, overlay_text, textfile_cstr, text_color, box_color, 1.0f, boxHeight,
                                         horizontalPadding, verticalPadding, h_align_raw, v_align_raw, lineHeight, position_raw, font, fontSize,
                                         (bool)showShadow, shadow_color, shadowX, shadowY, box_image_path, boxOverlap)) < 0) {
        goto cleanup;
    }

    // Step 5: Process frames
    if ((ret = text_overlay_process_frames(&ctx, output_file)) < 0) {
        goto cleanup;
    }

    LOGI("Text overlay completed successfully");

cleanup:
    text_overlay_cleanup(&ctx);
    if (textfile_created) {
        remove(textfile_path.c_str());
    }
    if (input_file) env->ReleaseStringUTFChars(inputPath, input_file);
    if (output_file) env->ReleaseStringUTFChars(outputPath, output_file);
    if (text_color_raw) env->ReleaseStringUTFChars(fontColor, text_color_raw);
    if (box_color_raw) env->ReleaseStringUTFChars(boxColor, box_color_raw);
    if (h_align_raw) env->ReleaseStringUTFChars(hAlign, h_align_raw);
    if (v_align_raw) env->ReleaseStringUTFChars(vAlign, v_align_raw);
    if (position_raw) env->ReleaseStringUTFChars(position, position_raw);
    if (font) env->ReleaseStringUTFChars(fontPath, font);
    if (preset_str) env->ReleaseStringUTFChars(preset, preset_str);
    if (shadow_color_raw) env->ReleaseStringUTFChars(shadowColor, shadow_color_raw);
    if (box_image_path) env->ReleaseStringUTFChars(boxImagePath, box_image_path);

    return ret;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_FFmpegTextOverlay_nativeMergeAudioVideo(
    JNIEnv* env,
    jobject thiz,
    jstring videoPath,
    jstring audioPath,
    jstring outputPath,
    jint duration
) {
    const char* video_file = env->GetStringUTFChars(videoPath, nullptr);
    const char* audio_file = env->GetStringUTFChars(audioPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);

    LOGI("Starting native merge: video=%s, audio=%s, output=%s, duration=%d", video_file, audio_file, output_file, duration);

    AVFormatContext *ifmt_ctx_v = nullptr, *ifmt_ctx_a = nullptr, *ofmt_ctx = nullptr;
    int ret = 0;
    int video_stream_idx = -1, audio_stream_idx = -1;
    int out_video_stream_idx = -1, out_audio_stream_idx = -1;
    AVPacket pkt;
    int64_t max_ts = (int64_t)duration * AV_TIME_BASE;

    // Open video input
    if ((ret = avformat_open_input(&ifmt_ctx_v, video_file, nullptr, nullptr)) < 0) {
        LOGE("Could not open video input file");
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx_v, nullptr)) < 0) {
        LOGE("Failed to retrieve video stream information");
        goto end;
    }

    // Open audio input
    if ((ret = avformat_open_input(&ifmt_ctx_a, audio_file, nullptr, nullptr)) < 0) {
        LOGE("Could not open audio input file");
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx_a, nullptr)) < 0) {
        LOGE("Failed to retrieve audio stream information");
        goto end;
    }

    // Create output context
    avformat_alloc_output_context2(&ofmt_ctx, nullptr, nullptr, output_file);
    if (!ofmt_ctx) {
        LOGE("Could not create output context");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    // Find video stream in video input
    for (unsigned int i = 0; i < ifmt_ctx_v->nb_streams; i++) {
        if (ifmt_ctx_v->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_idx = i;
            AVStream *in_stream = ifmt_ctx_v->streams[i];
            AVStream *out_stream = avformat_new_stream(ofmt_ctx, nullptr);
            if (!out_stream) {
                LOGE("Failed allocating output video stream");
                ret = AVERROR_UNKNOWN;
                goto end;
            }
            avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
            out_stream->codecpar->codec_tag = 0;
            out_video_stream_idx = out_stream->index;
            break;
        }
    }

    // Find audio stream in audio input
    for (unsigned int i = 0; i < ifmt_ctx_a->nb_streams; i++) {
        if (ifmt_ctx_a->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audio_stream_idx = i;
            AVStream *in_stream = ifmt_ctx_a->streams[i];
            AVStream *out_stream = avformat_new_stream(ofmt_ctx, nullptr);
            if (!out_stream) {
                LOGE("Failed allocating output audio stream");
                ret = AVERROR_UNKNOWN;
                goto end;
            }
            avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
            out_stream->codecpar->codec_tag = 0;
            out_audio_stream_idx = out_stream->index;
            break;
        }
    }

    if (!(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if ((ret = avio_open(&ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE)) < 0) {
            LOGE("Could not open output file %s", output_file);
            goto end;
        }
    }

    if ((ret = avformat_write_header(ofmt_ctx, nullptr)) < 0) {
        LOGE("Error occurred when opening output file");
        goto end;
    }

    // Video packets from video input
    while (av_read_frame(ifmt_ctx_v, &pkt) >= 0) {
        if (pkt.stream_index == video_stream_idx) {
            AVStream *in_stream = ifmt_ctx_v->streams[video_stream_idx];
            AVStream *out_stream = ofmt_ctx->streams[out_video_stream_idx];
            
            if (av_compare_ts(pkt.pts, in_stream->time_base, max_ts, {1, AV_TIME_BASE}) > 0) {
                av_packet_unref(&pkt);
                break;
            }

            pkt.stream_index = out_video_stream_idx;
            av_packet_rescale_ts(&pkt, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;
            av_interleaved_write_frame(ofmt_ctx, &pkt);
        }
        av_packet_unref(&pkt);
    }

    // Audio packets from audio input
    while (av_read_frame(ifmt_ctx_a, &pkt) >= 0) {
        if (pkt.stream_index == audio_stream_idx) {
            AVStream *in_stream = ifmt_ctx_a->streams[audio_stream_idx];
            AVStream *out_stream = ofmt_ctx->streams[out_audio_stream_idx];

            if (av_compare_ts(pkt.pts, in_stream->time_base, max_ts, {1, AV_TIME_BASE}) > 0) {
                av_packet_unref(&pkt);
                break;
            }

            pkt.stream_index = out_audio_stream_idx;
            av_packet_rescale_ts(&pkt, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;
            av_interleaved_write_frame(ofmt_ctx, &pkt);
        }
        av_packet_unref(&pkt);
    }

    av_write_trailer(ofmt_ctx);
    LOGI("Native merge completed successfully");

end:
    if (ifmt_ctx_v) avformat_close_input(&ifmt_ctx_v);
    if (ifmt_ctx_a) avformat_close_input(&ifmt_ctx_a);
    if (ofmt_ctx && !(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) avio_closep(&ofmt_ctx->pb);
    if (ofmt_ctx) avformat_free_context(ofmt_ctx);

    if (video_file) env->ReleaseStringUTFChars(videoPath, video_file);
    if (audio_file) env->ReleaseStringUTFChars(audioPath, audio_file);
    if (output_file) env->ReleaseStringUTFChars(outputPath, output_file);

    return ret;
}
