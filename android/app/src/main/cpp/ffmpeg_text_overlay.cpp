#include "ffmpeg_text_overlay.h"
#include <cstring>
#include <cstdio>
#include <unistd.h>

static bool file_exists(const char* path) {
    return (path && path[0] != '\0' && access(path, F_OK) == 0);
}

#define BOX_HEIGHT 80
#define TEXT_PADDING_TOP 20

int text_overlay_init_context(TextOverlayContext* ctx) {
    if (!ctx) return -1;
    
    ffmpeg_init_context(&ctx->ffmpeg_ctx);
    ctx->filter_graph = nullptr;
    ctx->buffersrc_ctx = nullptr;
    ctx->buffersink_ctx = nullptr;
    ctx->pkt = nullptr;
    ctx->frame = nullptr;
    ctx->filt_frame = nullptr;
    ctx->enc_pkt = nullptr;
    ctx->frame_count = 0;
    
    return 0;
}

int text_overlay_setup_filter(TextOverlayContext* ctx,
                              const char* overlay_text,
                              const char* text_file_path,
                              const char* text_color,
                              const char* box_color,
                              float boxOpacity,
                              int boxHeight,
                              int horizontalPadding,
                              int verticalPadding,
                              const char* hAlign,
                              const char* vAlign,
                              float lineHeight,
                              const char* position,
                              const char* font,
                              int fontSize,
                              bool showShadow,
                              const char* shadowColor,
                              int shadowX,
                              int shadowY) {
    if (!ctx || !text_color || !box_color || !font) {
        LOGE("Invalid parameters for text overlay filter setup");
        return -1;
    }
    
    AVCodecContext* dec_ctx = ctx->ffmpeg_ctx.dec_ctx;
    if (!dec_ctx) {
        LOGE("Decoder context not initialized");
        return -1;
    }
    
    // Legacy support for Top/Bottom positions with boxes
    bool place_top = true;
    if (position && position[0] != '\0') {
        if (strcasecmp(position, "bottom") == 0) {
            place_top = false;
        }
    }
    
    char x_expr[128];
    snprintf(x_expr, sizeof(x_expr), "(w-tw)/2");

    char y_expr[128];
    if (place_top) {
        snprintf(y_expr, sizeof(y_expr), "(%d-th)/2", boxHeight);
    } else {
        snprintf(y_expr, sizeof(y_expr), "H-th-(%d-th)/2", boxHeight);
    }
    
    bool use_textfile = (text_file_path && text_file_path[0] != '\0');
    if (!use_textfile && (!overlay_text || overlay_text[0] == '\0')) {
        LOGE("No overlay_text or text_file_path provided");
        return -1;
    }

    char escaped_text[2048];
    if (!use_textfile) {
        int j = 0;
        for (int i = 0; overlay_text[i] != '\0' && j < 2040; i++) {
            const char c = overlay_text[i];
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

    char filter_str[4096];
    
    // Convert alignment to FFmpeg drawtext equivalent
    const char* text_align_val = "center";
    if (hAlign) {
        if (strcasecmp(hAlign, "left") == 0) text_align_val = "left";
        else if (strcasecmp(hAlign, "right") == 0) text_align_val = "right";
    }

    const bool have_fontfile = file_exists(font);
    if (!have_fontfile) {
        LOGE("Font file missing/unreadable, falling back to default: %s", (font ? font : "<null>"));
    }

    char effects_str[256] = {0};
    if (showShadow) {
        const char* sc = (shadowColor && shadowColor[0] != '\0') ? shadowColor : "0x000000";
        snprintf(effects_str, sizeof(effects_str), ":shadowcolor=%s:shadowx=%d:shadowy=%d", sc, shadowX, shadowY);
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

    if (place_top) {
        // Pad the frame to match encoder height (ih + boxHeight). Place original video below the top box.
        // This avoids uninitialized pixels (green belt) in the padded area.
        if (use_textfile) {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:%d:color=black,"
                    "drawbox=x=0:y=0:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=fontfile='%s':textfile='%s':reload=1:fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight, boxHeight,
                    boxHeight, box_color, boxOpacity,
                    font, escaped_textfile, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, text_align_val, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:%d:color=black,"
                    "drawbox=x=0:y=0:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=textfile='%s':reload=1:fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight, boxHeight,
                    boxHeight, box_color, boxOpacity,
                    escaped_textfile, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, text_align_val, effects_str);
            }
        } else {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:%d:color=black,"
                    "drawbox=x=0:y=0:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=fontfile='%s':text=\"%s\":fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight, boxHeight,
                    boxHeight, box_color, boxOpacity,
                    font, escaped_text, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, text_align_val, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:%d:color=black,"
                    "drawbox=x=0:y=0:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=text=\"%s\":fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight, boxHeight,
                    boxHeight, box_color, boxOpacity,
                    escaped_text, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, text_align_val, effects_str);
            }
        }
    } else {
        // Pad the frame to match encoder height (ih + boxHeight). Place original video at top, box at bottom.
        if (use_textfile) {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:0:color=black,"
                    "drawbox=x=0:y=H-%d:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=fontfile='%s':textfile='%s':reload=1:fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=H-%d+(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight,
                    boxHeight, boxHeight, box_color, boxOpacity,
                    font, escaped_textfile, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, boxHeight, text_align_val, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:0:color=black,"
                    "drawbox=x=0:y=H-%d:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=textfile='%s':reload=1:fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=H-%d+(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight,
                    boxHeight, boxHeight, box_color, boxOpacity,
                    escaped_textfile, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, boxHeight, text_align_val, effects_str);
            }
        } else {
            if (have_fontfile) {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:0:color=black,"
                    "drawbox=x=0:y=H-%d:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=fontfile='%s':text=\"%s\":fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=H-%d+(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight,
                    boxHeight, boxHeight, box_color, boxOpacity,
                    font, escaped_text, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, boxHeight, text_align_val, effects_str);
            } else {
                snprintf(filter_str, sizeof(filter_str),
                    "pad=iw:ih+%d:0:0:color=black,"
                    "drawbox=x=0:y=H-%d:w=iw:h=%d:color=%s@%.2f:t=fill,"
                    "drawtext=text=\"%s\":fontcolor=%s:fontsize=%d:line_spacing=%d:x=(w-tw)/2:y=H-%d+(%d-th)/2:text_align=%s%s,"
                    "format=pix_fmts=yuv420p",
                    boxHeight,
                    boxHeight, boxHeight, box_color, boxOpacity,
                    escaped_text, text_color, fontSize,
                    (int)((lineHeight - 1.0f) * fontSize), boxHeight, boxHeight, text_align_val, effects_str);
            }
        }
    }
    
    LOGI("Filter string: %s", filter_str);
    
    // Create filter graph
    ctx->filter_graph = avfilter_graph_alloc();
    if (!ctx->filter_graph) {
        LOGE("Cannot allocate filter graph");
        return -12;
    }
    
    // Get filter objects
    const AVFilter* buffersrc = avfilter_get_by_name("buffer");
    const AVFilter* buffersink = avfilter_get_by_name("buffersink");
    
    if (!buffersrc || !buffersink) {
        LOGE("Filter not found");
        return -13;
    }
    
    // Create buffer source
    AVRational tb = ctx->ffmpeg_ctx.video_time_base;
    AVRational sar = dec_ctx->sample_aspect_ratio;
    if (sar.num <= 0 || sar.den <= 0) {
        sar.num = 1;
        sar.den = 1;
    }
    
    char args[512];
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
             tb.num, tb.den,
             sar.num, sar.den);
    
    LOGI("Buffer source args: %s", args);
    
    int ret = avfilter_graph_create_filter(&ctx->buffersrc_ctx, buffersrc, "in", args, nullptr, ctx->filter_graph);
    if (ret < 0) {
        LOGE("Cannot create buffer source, ffmpeg error=%d", ret);
        return ret;
    }
    
    if (avfilter_graph_create_filter(&ctx->buffersink_ctx, buffersink, "out", nullptr, nullptr, ctx->filter_graph) < 0) {
        LOGE("Cannot create buffer sink");
        return -15;
    }
    
    // Parse and add filter
    AVFilterInOut* inputs = avfilter_inout_alloc();
    AVFilterInOut* outputs = avfilter_inout_alloc();
    
    outputs->name = av_strdup("in");
    outputs->filter_ctx = ctx->buffersrc_ctx;
    outputs->pad_idx = 0;
    outputs->next = nullptr;
    
    inputs->name = av_strdup("out");
    inputs->filter_ctx = ctx->buffersink_ctx;
    inputs->pad_idx = 0;
    inputs->next = nullptr;
    
    int parse_ret = avfilter_graph_parse_ptr(ctx->filter_graph, filter_str, &inputs, &outputs, nullptr);
    if (parse_ret < 0) {
        LOGE("Cannot parse filter graph, ffmpeg error=%d", parse_ret);
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return -16;
    }
    
    if (avfilter_graph_config(ctx->filter_graph, nullptr) < 0) {
        LOGE("Cannot configure filter graph");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return -17;
    }
    
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    
    return 0;
}

int text_overlay_process_frames(TextOverlayContext* ctx, const char* output_file) {
    if (!ctx || !output_file) return -1;
    
    FFmpegContext* ffmpeg_ctx = &ctx->ffmpeg_ctx;
    AVCodecContext* dec_ctx = ffmpeg_ctx->dec_ctx;
    AVCodecContext* enc_ctx = ffmpeg_ctx->enc_ctx;
    AVFormatContext* ifmt_ctx = ffmpeg_ctx->ifmt_ctx;
    AVFormatContext* ofmt_ctx = ffmpeg_ctx->ofmt_ctx;
    
    // Open output file
    if (!(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE) < 0) {
            LOGE("Cannot open output file");
            return -18;
        }
    }
    
    if (avformat_write_header(ofmt_ctx, nullptr) < 0) {
        LOGE("Cannot write header");
        return -19;
    }
    
    // Allocate frame/packet structures
    ctx->pkt = av_packet_alloc();
    ctx->frame = av_frame_alloc();
    ctx->filt_frame = av_frame_alloc();
    
    if (!ctx->pkt || !ctx->frame || !ctx->filt_frame) {
        LOGE("Cannot allocate frame/packet");
        return -20;
    }
    
    // Process frames
    while (av_read_frame(ifmt_ctx, ctx->pkt) >= 0) {
        // Handle audio stream - copy directly without re-encoding
        if (ffmpeg_ctx->audio_stream_idx >= 0 && ctx->pkt->stream_index == ffmpeg_ctx->audio_stream_idx) {
            if (ffmpeg_ctx->audio_out_stream) {
                av_packet_rescale_ts(ctx->pkt, ifmt_ctx->streams[ffmpeg_ctx->audio_stream_idx]->time_base, 
                                     ffmpeg_ctx->audio_out_stream->time_base);
                ctx->pkt->stream_index = ffmpeg_ctx->audio_out_stream->index;
                av_interleaved_write_frame(ofmt_ctx, ctx->pkt);
            }
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        // Handle video stream
        if (ctx->pkt->stream_index != ffmpeg_ctx->video_stream_idx) {
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        if (avcodec_send_packet(dec_ctx, ctx->pkt) < 0) {
            LOGE("Error sending packet to decoder");
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        while (avcodec_receive_frame(dec_ctx, ctx->frame) == 0) {
            // Push frame to filter
            if (av_buffersrc_add_frame_flags(ctx->buffersrc_ctx, ctx->frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
                LOGE("Error feeding frame to filter");
                break;
            }
            
            // Get filtered frames
            while (av_buffersink_get_frame(ctx->buffersink_ctx, ctx->filt_frame) >= 0) {
                ctx->filt_frame->pict_type = AV_PICTURE_TYPE_NONE;
                
                // Encode frame
                if (avcodec_send_frame(enc_ctx, ctx->filt_frame) < 0) {
                    LOGE("Error sending frame to encoder");
                    av_frame_unref(ctx->filt_frame);
                    break;
                }
                
                ctx->enc_pkt = av_packet_alloc();
                while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
                    ctx->enc_pkt->stream_index = ffmpeg_ctx->out_stream->index;
                    av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ffmpeg_ctx->out_stream->time_base);
                    av_interleaved_write_frame(ofmt_ctx, ctx->enc_pkt);
                    av_packet_unref(ctx->enc_pkt);
                }
                av_packet_free(&ctx->enc_pkt);
                
                av_frame_unref(ctx->filt_frame);
            }
        }
        
        av_packet_unref(ctx->pkt);
        ctx->frame_count++;
        if (ctx->frame_count % 30 == 0) {
            LOGI("Processed %d frames", ctx->frame_count);
        }
    }
    
    // Flush encoders
    avcodec_send_frame(enc_ctx, nullptr);
    ctx->enc_pkt = av_packet_alloc();
    while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
        ctx->enc_pkt->stream_index = 0;
        av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ffmpeg_ctx->out_stream->time_base);
        av_interleaved_write_frame(ofmt_ctx, ctx->enc_pkt);
        av_packet_unref(ctx->enc_pkt);
    }
    av_packet_free(&ctx->enc_pkt);
    
    av_write_trailer(ofmt_ctx);
    
    LOGI("Text overlay completed successfully. Total frames: %d", ctx->frame_count);
    
    return 0;
}

void text_overlay_cleanup(TextOverlayContext* ctx) {
    if (!ctx) return;
    
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->filt_frame) av_frame_free(&ctx->filt_frame);
    if (ctx->enc_pkt) av_packet_free(&ctx->enc_pkt);
    
    // Free the filter graph, which also frees all contained filter contexts
    if (ctx->filter_graph) {
        avfilter_graph_free(&ctx->filter_graph);
        ctx->buffersrc_ctx = nullptr;
        ctx->buffersink_ctx = nullptr;
    }
    
    ffmpeg_cleanup(&ctx->ffmpeg_ctx);
}
