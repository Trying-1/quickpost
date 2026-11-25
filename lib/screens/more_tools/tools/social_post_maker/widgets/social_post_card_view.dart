import 'dart:io';
import 'package:flutter/material.dart';
import '../models/social_post_model.dart';

/// Pixel-perfect social post / tweet card renderer with zero-overflow proportional containment.
/// Renders as a full canvas (4:5, 1:1, 9:16) or standalone card for video overlays.
class SocialPostCardView extends StatelessWidget {
  final SocialPost post;
  final VoidCallback? onEditRequested;

  const SocialPostCardView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isVerticalStory = post.ratio == SocialPostRatio.story9x16;
    final bool isSquare = post.ratio == SocialPostRatio.square1x1;
    const double refWidth = 380.0;

    if (post.ratio == SocialPostRatio.cardOnly) {
      return GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: refWidth,
              child: _buildCardContainer(isStandalone: true),
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
            borderRadius: BorderRadius.circular(16),
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
              // 1. Backdrop (Custom Wallpaper or Gradient Preset)
              _buildBackdrop(),

              // 2. Subtle Dark Vignette
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),

              // 3. Proportional Centered Floating Social Card (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerticalStory ? 20 : (isSquare ? 16 : 18),
                    vertical: isVerticalStory ? 24 : 12,
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      child: _buildCardContainer(isStandalone: false),
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

  // ─── Backdrop Layer ───
  Widget _buildBackdrop() {
    if (post.customWallpaperPath != null && File(post.customWallpaperPath!).existsSync()) {
      return Image.file(
        File(post.customWallpaperPath!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: post.backdrop.colors,
        ),
      ),
    );
  }

  // ─── The Main Social Post Card ───
  Widget _buildCardContainer({required bool isStandalone}) {
    final theme = post.cardTheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder, width: 1.0),
        boxShadow: isStandalone
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header
          _buildAuthorHeader(),

          const SizedBox(height: 12),

          // 2. Main Post Content
          _buildPostContent(),

          // 3. Optional Attached Photo
          if (post.attachedImagePath != null && File(post.attachedImagePath!).existsSync()) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(post.attachedImagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 190,
              ),
            ),
          ],

          // 4. Timestamp & Views Row
          if (post.showTimestamp) ...[
            const SizedBox(height: 12),
            _buildTimestampRow(),
          ],

          // 5. Metrics Section
          if (post.showMetrics) ...[
            const SizedBox(height: 10),
            Divider(color: theme.cardBorder, height: 1),
            const SizedBox(height: 10),
            _buildMetricsRow(),
          ],

          // 6. Action Icons Row (Reply, Repost, Like, Bookmark, Share)
          const SizedBox(height: 10),
          Divider(color: theme.cardBorder, height: 1),
          const SizedBox(height: 10),
          _buildActionIconsRow(),
        ],
      ),
    );
  }

  // ─── Author Header ───
  Widget _buildAuthorHeader() {
    final theme = post.cardTheme;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF1E293B),
          backgroundImage: post.avatarPath != null && File(post.avatarPath!).existsSync()
              ? FileImage(File(post.avatarPath!))
              : null,
          child: post.avatarPath == null
              ? Text(
                  post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                )
              : null,
        ),
        const SizedBox(width: 10),

        // Name & Username
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primaryText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  if (post.verifiedBadge != VerifiedBadgeType.none) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: post.verifiedBadge.color,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '@${post.username}',
                style: TextStyle(
                  color: theme.secondaryText,
                  fontSize: 12.5,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),

        // More Icon (···)
        Icon(Icons.more_horiz_rounded, color: theme.secondaryText, size: 20),
      ],
    );
  }

  // ─── Post Text with Auto-Highlighted Tags ───
  Widget _buildPostContent() {
    final theme = post.cardTheme;
    final words = post.content.split(RegExp(r'(\s+)'));

    return RichText(
      text: TextSpan(
        children: words.map((word) {
          final isTag = word.startsWith('#') || word.startsWith('@') || word.startsWith('http');
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              color: isTag ? theme.accentColor : theme.primaryText,
              fontSize: 14,
              height: 1.4,
              fontWeight: isTag ? FontWeight.w600 : FontWeight.w400,
              fontFamily: 'Poppins',
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Timestamp & Views ───
  Widget _buildTimestampRow() {
    final theme = post.cardTheme;

    return Row(
      children: [
        Text(
          post.timestamp,
          style: TextStyle(color: theme.secondaryText, fontSize: 11.5, fontFamily: 'Poppins'),
        ),
        if (post.viewsCount.isNotEmpty) ...[
          Text(' · ', style: TextStyle(color: theme.secondaryText, fontSize: 11.5)),
          Text(
            '${post.viewsCount} Views',
            style: TextStyle(color: theme.secondaryText, fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
        ],
      ],
    );
  }

  // ─── Metrics Section (Reposts, Quotes, Likes, Bookmarks) ───
  Widget _buildMetricsRow() {
    final theme = post.cardTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricItem(post.repostsCount, 'Reposts', theme),
          const SizedBox(width: 14),
          _buildMetricItem(post.quotesCount, 'Quotes', theme),
          const SizedBox(width: 14),
          _buildMetricItem(post.likesCount, 'Likes', theme),
          const SizedBox(width: 14),
          _buildMetricItem(post.bookmarksCount, 'Bookmarks', theme),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String count, String label, SocialCardTheme theme) {
    return Row(
      children: [
        Text(
          count,
          style: TextStyle(
            color: theme.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.secondaryText,
            fontSize: 11.5,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // ─── Bottom Actions Bar ───
  Widget _buildActionIconsRow() {
    final theme = post.cardTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 17, color: theme.secondaryText),
        Icon(Icons.repeat_rounded, size: 18, color: theme.secondaryText),
        Icon(Icons.favorite_border_rounded, size: 18, color: theme.secondaryText),
        Icon(Icons.bookmark_border_rounded, size: 18, color: theme.secondaryText),
        Icon(Icons.share_outlined, size: 18, color: theme.secondaryText),
      ],
    );
  }
}
