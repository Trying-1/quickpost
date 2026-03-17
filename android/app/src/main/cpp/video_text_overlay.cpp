#include <jni.h>
#include <cstring>
#include <cstdio>
#include <string>
#include <ctime>
#include <unistd.h>
#include "ffmpeg_common.h"

extern "C" {
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/pixdesc.h>
#include <libavutil/opt.h>
}

static bool file_exists(const char* path) {
    return (path && path[0] != '\0' && access(path, F_OK) == 0);
}

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

// Internal structure for Video Text Overlay
struct VideoOverlayContext {
    FFmpegContext ffmpeg_ctx;
    AVFilterGraph* filter_graph;
    AVFilterContext* buffersrc_ctx;
    AVFilterContext* buffersink_ctx;
    AVPacket* pkt;
    AVFrame* frame;
    AVFrame* filt_frame;
    AVPacket* enc_pkt;
    int frame_count;
};

// Initialize context
static void vo_init_context(VideoOverlayContext* ctx) {
    ffmpeg_init_context(&ctx->ffmpeg_ctx);
    ctx->filter_graph = nullptr;
    ctx->buffersrc_ctx = nullptr;
    ctx->buffersink_ctx = nullptr;
    ctx->pkt = nullptr;
    ctx->frame = nullptr;
    ctx->filt_frame = nullptr;
    ctx->enc_pkt = nullptr;
    ctx->frame_count = 0;
}

// Cleanup context
static void vo_cleanup(VideoOverlayContext* ctx) {
    if (!ctx) return;
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->filt_frame) av_frame_free(&ctx->filt_frame);
    if (ctx->enc_pkt) av_packet_free(&ctx->enc_pkt);
    if (ctx->filter_graph) avfilter_graph_free(&ctx->filter_graph);
    ffmpeg_cleanup(&ctx->ffmpeg_ctx);
}

// Setup filter for pure text overlay at (x, y) with effects
static int vo_setup_filter(VideoOverlayContext* ctx, const char* text, const char* text_file_path, const char* color, 
                          const char* font, int fontSize, float lineHeight, int x, int y,
                          bool showShadow, const char* shadowColor,
                          int shadowX, int shadowY,
                          const char* boxColor, float boxOpacity, float textOpacity) {
    AVCodecContext* dec_ctx = ctx->ffmpeg_ctx.dec_ctx;

    const bool use_textfile = (text_file_path && text_file_path[0] != '\0');

    // Escape text
    char escaped_text[2048];
    if (!use_textfile) {
        int j = 0;
        for (int i = 0; text[i] != '\0' && j < 2040; i++) {
            const char c = text[i];
            // drawtext uses ':' as option separator and supports %{} expansions.
            // We pass text inside double quotes (text="..."), so we must escape
            // special characters to prevent filter parsing / unexpected expansions.
            if (c == '\\') {
                // Escape backslash itself.
                escaped_text[j++] = '\\';
                escaped_text[j++] = '\\';
            } else if (c == '\'') {
                // Escape apostrophe as FFmpeg filter parser may treat it as a quoting character.
                escaped_text[j++] = '\\';
                escaped_text[j++] = '\'';
            } else if (c == '"') {
                escaped_text[j++] = '\\';
                escaped_text[j++] = '"';
            } else if (c == ':') {
                // Escape ':' so it doesn't terminate the drawtext option.
                escaped_text[j++] = '\\';
                escaped_text[j++] = ':';
            } else if (c == '%') {
                // Escape '%' to avoid %{...} expansions.
                escaped_text[j++] = '\\';
                escaped_text[j++] = '%';
            } else {
                escaped_text[j++] = c;
            }
        }
        escaped_text[j] = '\0';
    }

    char escaped_textfile[2048];
    if (use_textfile) {
        int k = 0;
        for (int i = 0; text_file_path[i] != '\0' && k < 2040; i++) {
            const char c = text_file_path[i];
            if (c == '\\') {
                escaped_textfile[k++] = '\\';
                escaped_textfile[k++] = '\\';
            } else if (c == '\'') {
                escaped_textfile[k++] = '\\';
                escaped_textfile[k++] = '\'';
            } else {
                escaped_textfile[k++] = c;
            }
        }
        escaped_textfile[k] = '\0';
    }

    char filter_str[4096];
    char effects_str[1024] = {0};
    
    if (showShadow) {
        // FFmpeg standard 'drawtext' DOES NOT support 'shadowblur' as a direct option.
        // It only supports 'shadowcolor', 'shadowx', and 'shadowy'.
        snprintf(effects_str, sizeof(effects_str), ":shadowcolor=%s:shadowx=%d:shadowy=%d", 
                 shadowColor, shadowX, shadowY);
    }

    // Ensure numeric values are safe
    int safe_fontSize = (fontSize > 0) ? fontSize : 40;
    int safe_x = x;
    int safe_y = y;

    const bool have_fontfile = file_exists(font);
    if (!have_fontfile) {
        LOGE("Font file missing/unreadable, falling back to default: %s", (font ? font : "<null>"));
    }

    if (boxOpacity > 0.01f) {
        char box_filter[1024];
        // Using 'tw' and 'th' in drawbox is only valid if we use the same variables.
        // However, drawbox doesn't always have 'tw'/'th' available (those are drawtext specific).
        // Let's use a more compatible approach: 
        // We'll overlay the box with fixed dimensions or relative to the text if possible.
        // Actually, in FFmpeg, we can use 'text_w' and 'text_h' in some contexts, but not always.
        // The safest way is to use the drawtext 'box' parameter instead of a separate drawbox filter.
        
        if (use_textfile) {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=fontfile='%s':textfile='%s':reload=1:fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2:box=1:boxcolor=%s@%.2f:boxborderw=10%s",
                         font, escaped_textfile, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, boxColor, boxOpacity, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=textfile='%s':reload=1:fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2:box=1:boxcolor=%s@%.2f:boxborderw=10%s",
                         escaped_textfile, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, boxColor, boxOpacity, effects_str);
            }
        } else {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=fontfile='%s':text=\"%s\":fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2:box=1:boxcolor=%s@%.2f:boxborderw=10%s",
                         font, escaped_text, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, boxColor, boxOpacity, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=text=\"%s\":fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2:box=1:boxcolor=%s@%.2f:boxborderw=10%s",
                         escaped_text, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, boxColor, boxOpacity, effects_str);
            }
        }
    } else {
        if (use_textfile) {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=fontfile='%s':textfile='%s':reload=1:fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2%s",
                         font, escaped_textfile, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=textfile='%s':reload=1:fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2%s",
                         escaped_textfile, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, effects_str);
            }
        } else {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=fontfile='%s':text=\"%s\":fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2%s",
                         font, escaped_text, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                         "drawtext=text=\"%s\":fontcolor=%s@%.2f:fontsize=%d:line_spacing=%d:x=%d-tw/2:y=%d-th/2%s",
                         escaped_text, color, textOpacity, safe_fontSize, (int)((lineHeight - 1.0f) * safe_fontSize), safe_x, safe_y, effects_str);
            }
        }
    }

    LOGI("Video Text Overlay Filter: %s", filter_str);

    ctx->filter_graph = avfilter_graph_alloc();
    const AVFilter* buffersrc = avfilter_get_by_name("buffer");
    const AVFilter* buffersink = avfilter_get_by_name("buffersink");

    AVRational tb = ctx->ffmpeg_ctx.video_time_base;
    AVRational sar = dec_ctx->sample_aspect_ratio;
    if (sar.num <= 0 || sar.den <= 0) { sar.num = 1; sar.den = 1; }

    char args[512];
    snprintf(args, sizeof(args), "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt, tb.num, tb.den, sar.num, sar.den);

    int ret = avfilter_graph_create_filter(&ctx->buffersrc_ctx, buffersrc, "in", args, nullptr, ctx->filter_graph);
    if (ret < 0) return ret;

    ret = avfilter_graph_create_filter(&ctx->buffersink_ctx, buffersink, "out", nullptr, nullptr, ctx->filter_graph);
    if (ret < 0) return ret;

    AVFilterInOut* inputs = avfilter_inout_alloc();
    AVFilterInOut* outputs = avfilter_inout_alloc();
    outputs->name = av_strdup("in"); outputs->filter_ctx = ctx->buffersrc_ctx; outputs->pad_idx = 0; outputs->next = nullptr;
    inputs->name = av_strdup("out"); inputs->filter_ctx = ctx->buffersink_ctx; inputs->pad_idx = 0; inputs->next = nullptr;

    ret = avfilter_graph_parse_ptr(ctx->filter_graph, filter_str, &inputs, &outputs, nullptr);
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    if (ret < 0) {
        LOGE("Cannot parse filter graph, ffmpeg error=%d", ret);
        return ret;
    }

    return avfilter_graph_config(ctx->filter_graph, nullptr);
}

// Main processing loop
static int vo_process(VideoOverlayContext* ctx, const char* output_file) {
    FFmpegContext* fctx = &ctx->ffmpeg_ctx;
    if (!(fctx->ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&fctx->ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE) < 0) return -1;
    }
    if (avformat_write_header(fctx->ofmt_ctx, nullptr) < 0) return -1;

    ctx->pkt = av_packet_alloc();
    ctx->frame = av_frame_alloc();
    ctx->filt_frame = av_frame_alloc();

    while (av_read_frame(fctx->ifmt_ctx, ctx->pkt) >= 0) {
        if (fctx->audio_stream_idx >= 0 && ctx->pkt->stream_index == fctx->audio_stream_idx) {
            if (fctx->audio_out_stream) {
                av_packet_rescale_ts(ctx->pkt, fctx->ifmt_ctx->streams[fctx->audio_stream_idx]->time_base, fctx->audio_out_stream->time_base);
                ctx->pkt->stream_index = fctx->audio_out_stream->index;
                av_interleaved_write_frame(fctx->ofmt_ctx, ctx->pkt);
            }
            av_packet_unref(ctx->pkt);
            continue;
        }

        if (ctx->pkt->stream_index != fctx->video_stream_idx) {
            av_packet_unref(ctx->pkt);
            continue;
        }

        if (avcodec_send_packet(fctx->dec_ctx, ctx->pkt) >= 0) {
            while (avcodec_receive_frame(fctx->dec_ctx, ctx->frame) == 0) {
                if (av_buffersrc_add_frame_flags(ctx->buffersrc_ctx, ctx->frame, AV_BUFFERSRC_FLAG_KEEP_REF) >= 0) {
                    while (av_buffersink_get_frame(ctx->buffersink_ctx, ctx->filt_frame) >= 0) {
                        ctx->filt_frame->pict_type = AV_PICTURE_TYPE_NONE;
                        if (avcodec_send_frame(fctx->enc_ctx, ctx->filt_frame) >= 0) {
                            ctx->enc_pkt = av_packet_alloc();
                            while (avcodec_receive_packet(fctx->enc_ctx, ctx->enc_pkt) == 0) {
                                ctx->enc_pkt->stream_index = fctx->out_stream->index;
                                av_packet_rescale_ts(ctx->enc_pkt, fctx->enc_ctx->time_base, fctx->out_stream->time_base);
                                av_interleaved_write_frame(fctx->ofmt_ctx, ctx->enc_pkt);
                                av_packet_unref(ctx->enc_pkt);
                            }
                            av_packet_free(&ctx->enc_pkt);
                        }
                        av_frame_unref(ctx->filt_frame);
                    }
                }
                av_frame_unref(ctx->frame);
            }
        }
        av_packet_unref(ctx->pkt);
    }

    avcodec_send_frame(fctx->enc_ctx, nullptr);
    ctx->enc_pkt = av_packet_alloc();
    while (avcodec_receive_packet(fctx->enc_ctx, ctx->enc_pkt) == 0) {
        ctx->enc_pkt->stream_index = fctx->out_stream->index;
        av_packet_rescale_ts(ctx->enc_pkt, fctx->enc_ctx->time_base, fctx->out_stream->time_base);
        av_interleaved_write_frame(fctx->ofmt_ctx, ctx->enc_pkt);
        av_packet_unref(ctx->enc_pkt);
    }
    av_packet_free(&ctx->enc_pkt);
    av_write_trailer(fctx->ofmt_ctx);
    return 0;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_FFmpegVideoOverlay_nativeAddTextToVideo(
    JNIEnv* env, jobject thiz, jstring inputPath, jstring outputPath, jstring text,
    jint x, jint y, jint fontSize, jstring fontColor, jstring boxColor, jfloat boxOpacity,
    jint boxHeight, jint horizontalPadding, jint verticalPadding, jstring hAlign, jstring vAlign,
    jfloat lineHeight, jstring position, jstring fontPath, jstring preset, jint crf,
    jboolean showShadow, jstring shadowColor, jint shadowX, jint shadowY, jfloat textOpacity
) {
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    const std::string overlay_text_utf8 = jstring_to_utf8(env, text);
    const char* overlay_text = overlay_text_utf8.c_str();
    const char* text_color_raw = env->GetStringUTFChars(fontColor, nullptr);
    const char* box_color_raw = env->GetStringUTFChars(boxColor, nullptr);
    const char* shadow_color_raw = env->GetStringUTFChars(shadowColor, nullptr);
    const char* font = env->GetStringUTFChars(fontPath, nullptr);
    const char* preset_str = env->GetStringUTFChars(preset, nullptr);

    char text_color_buf[16] = {0};
    const char* text_color = text_color_raw;
    if (text_color_raw && text_color_raw[0] == '#' && strlen(text_color_raw) == 7) {
        snprintf(text_color_buf, sizeof(text_color_buf), "0x%.6s", text_color_raw + 1);
        text_color = text_color_buf;
    }

    char box_color_buf[16] = {0};
    const char* box_color = box_color_raw;
    if (box_color_raw && box_color_raw[0] == '#' && strlen(box_color_raw) == 7) {
        snprintf(box_color_buf, sizeof(box_color_buf), "0x%.6s", box_color_raw + 1);
        box_color = box_color_buf;
    }

    char shadow_color_buf[16] = {0};
    const char* shadow_color = shadow_color_raw;
    if (shadow_color_raw && shadow_color_raw[0] == '#' && strlen(shadow_color_raw) == 7) {
        snprintf(shadow_color_buf, sizeof(shadow_color_buf), "0x%.6s", shadow_color_raw + 1);
        shadow_color = shadow_color_buf;
    }

    // FFmpeg's drawtext x/y expressions don't like 'tw' and 'th' inside 'drawbox' 
    // if those variables aren't defined for the drawbox filter.
    // Instead of x=x-tw/2, we calculate the absolute center or use safe expressions.

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
        snprintf(name_buf, sizeof(name_buf), "qp_vtext_%d_%ld.txt", (int)getpid(), (long)time(nullptr));
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

    VideoOverlayContext ctx;
    vo_init_context(&ctx);

    int ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file);
    if (ret >= 0) ret = ffmpeg_setup_decoder(&ctx.ffmpeg_ctx);
    if (ret >= 0) ret = ffmpeg_setup_encoder(&ctx.ffmpeg_ctx, output_file, preset_str, crf, 0);
    if (ret >= 0) ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx);
    const char* textfile_cstr = (textfile_created ? textfile_path.c_str() : nullptr);
    if (ret >= 0) ret = vo_setup_filter(&ctx, overlay_text, textfile_cstr, text_color, font, fontSize, lineHeight, x, y, 
                                       showShadow, shadow_color, shadowX, shadowY, box_color, boxOpacity, textOpacity);
    if (ret >= 0) ret = vo_process(&ctx, output_file);

    vo_cleanup(&ctx);
    if (textfile_created) {
        remove(textfile_path.c_str());
    }
    env->ReleaseStringUTFChars(inputPath, input_file);
    env->ReleaseStringUTFChars(outputPath, output_file);
    env->ReleaseStringUTFChars(fontColor, text_color_raw);
    env->ReleaseStringUTFChars(boxColor, box_color_raw);
    env->ReleaseStringUTFChars(shadowColor, shadow_color_raw);
    env->ReleaseStringUTFChars(fontPath, font);
    env->ReleaseStringUTFChars(preset, preset_str);
    return ret;
}
