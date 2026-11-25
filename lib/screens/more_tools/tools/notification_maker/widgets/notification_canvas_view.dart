import 'dart:io';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';

/// Pixel-perfect Lock Screen Push Notification Canvas with zero-overflow proportional scaling.
/// Renders full lock screen (9:16, 4:5, 1:1) or standalone floating notification cards.
class NotificationCanvasView extends StatelessWidget {
  final NotificationPost post;
  final VoidCallback? onEditRequested;

  const NotificationCanvasView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStory = post.ratio == NotificationRatio.story9x16;
    final bool isSquare = post.ratio == NotificationRatio.square1x1;
    const double refWidth = 380.0;
    final double refHeight = isStory
        ? (380.0 * 16 / 9)
        : (isSquare ? 380.0 : (380.0 * 5 / 4));

    if (post.ratio == NotificationRatio.cardOnly) {
      return GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: refWidth,
              child: _buildNotificationStack(isStandalone: true),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: post.ratio.ratio,
      child: GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Wallpaper Backdrop
              _buildWallpaper(),

              // 2. Subtle Dark Vignette
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // 3. Proportional Foreground Lock Screen Elements (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 20 : (isSquare ? 12 : 16),
                    vertical: isStory ? 20 : (isSquare ? 8 : 12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      height: refHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDynamicIsland(),
                              const SizedBox(height: 10),
                              if (post.showLockHeader) _buildClockHeader(),
                            ],
                          ),
                          _buildNotificationStack(isStandalone: false),
                          if (isStory) ...[
                            _buildBottomShortcuts(),
                            const SizedBox(height: 6),
                            _buildHomeIndicator(),
                          ] else
                            const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Wallpaper Layer ───
  Widget _buildWallpaper() {
    if (post.customWallpaperPath != null && File(post.customWallpaperPath!).existsSync()) {
      return Image.file(
        File(post.customWallpaperPath!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: post.wallpaper.colors,
        ),
      ),
    );
  }

  // ─── Dynamic Island ───
  Widget _buildDynamicIsland() {
    return Center(
      child: Container(
        width: 86,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10, width: 0.8),
        ),
      ),
    );
  }

  // ─── Lock Screen Clock Header ───
  Widget _buildClockHeader() {
    final isCompact = post.ratio == NotificationRatio.square1x1;

    return Column(
      children: [
        const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
        const SizedBox(height: 2),
        Text(
          post.clockDate,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: isCompact ? 11 : 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          post.clockTime,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 38 : 54,
            fontWeight: FontWeight.bold,
            letterSpacing: -1.5,
            height: 1.05,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // ─── Floating Push Notifications Stack ───
  Widget _buildNotificationStack({required bool isStandalone}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: post.items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: post.isGlassmorphic
                ? const Color(0xCC1E293B) // Frosted dark glass
                : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
            boxShadow: isStandalone
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: App Icon, App Name & Time Header
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: item.appType.iconBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.appType.icon, size: 13, color: item.appType.iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.displayAppName,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  Text(
                    item.timeHeader,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Title
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),

              // Message Body
              Text(
                item.message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                  height: 1.35,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Bottom Flashlight & Camera Shortcuts ───
  Widget _buildBottomShortcuts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCircleShortcut(Icons.flashlight_on_rounded),
        _buildCircleShortcut(Icons.camera_alt_rounded),
      ],
    );
  }

  Widget _buildCircleShortcut(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  // ─── Home Bar Indicator ───
  Widget _buildHomeIndicator() {
    return Container(
      width: 120,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
