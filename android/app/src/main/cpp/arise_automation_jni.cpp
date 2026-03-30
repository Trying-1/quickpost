#include <jni.h>
#include <android/bitmap.h>
#include <cstdint>

extern "C" JNIEXPORT void JNICALL
Java_com_quickpost_app_AriseAutomationProcessor_nativeEncodeBitmapToYuv420SemiPlanar(
    JNIEnv* env,
    jobject thiz,
    jobject bitmap,
    jobject buffer,
    jint width,
    jint height
) {
    AndroidBitmapInfo info;
    if (AndroidBitmap_getInfo(env, bitmap, &info) < 0) return;
    if (info.format != ANDROID_BITMAP_FORMAT_RGBA_8888) return;

    void* pixels;
    if (AndroidBitmap_lockPixels(env, bitmap, &pixels) < 0) return;

    uint8_t* out = (uint8_t*)env->GetDirectBufferAddress(buffer);
    if (!out) {
        AndroidBitmap_unlockPixels(env, bitmap);
        return;
    }

    uint8_t* y_plane = out;
    uint8_t* uv_plane = out + (width * height);

    uint32_t* src = (uint32_t*)pixels;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint32_t argb = src[y * width + x];
            // Format is RGBA_8888, so memory is [R, G, B, A]
            uint8_t r = (argb & 0x000000FF);
            uint8_t g = (argb & 0x0000FF00) >> 8;
            uint8_t b = (argb & 0x00FF0000) >> 16;

            int y_val = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
            y_plane[y * width + x] = (uint8_t)y_val;

            if (y % 2 == 0 && x % 2 == 0) {
                int u_val = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
                int v_val = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
                // NV12 (UVUV...)
                uv_plane[(y / 2) * width + x] = (uint8_t)v_val;
                uv_plane[(y / 2) * width + x + 1] = (uint8_t)u_val;
            }
        }
    }

    AndroidBitmap_unlockPixels(env, bitmap);
}
