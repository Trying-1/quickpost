import 'dart:io';
import 'package:flutter/material.dart';
import '../models/habit_tracker_model.dart';

/// Canvas renderer for the GitHub commit-style habit tracking post.
/// Renders directly onto the full canvas with custom dot shapes (Square, Squircle, Circle, 8-Bit),
/// milestone badges, top month headers, dot glow effects, and adaptive layout.
class HabitCanvasView extends StatelessWidget {
  final HabitGridPost post;
  final ValueChanged<int>? onTileTapped;

  const HabitCanvasView({
    super.key,
    required this.post,
    this.onTileTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isVerticalStory = post.ratio == HabitRatio.vertical9x16;
    final bool isSquare = post.ratio == HabitRatio.square1x1;
    const double refWidth = 380.0;
    final double refHeight = isVerticalStory
        ? (380.0 * 16 / 9)
        : (isSquare ? 380.0 : (380.0 * 5 / 4));

    if (post.ratio == HabitRatio.cardOnly) {
      return Container(
        decoration: BoxDecoration(
          color: post.transparentBg ? Colors.transparent : post.theme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: post.transparentBg ? null : Border.all(color: post.theme.cardBorder, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: refWidth,
            child: _buildCardContent(context, isVerticalStory: false),
          ),
        ),
      );
    }

    final backdrop = HabitBackdropPreset.presets[post.backdropIndex % HabitBackdropPreset.presets.length];

    final BoxDecoration canvasDecoration = BoxDecoration(
      color: post.transparentBg ? Colors.transparent : post.theme.cardBg,
      borderRadius: BorderRadius.circular(16),
      gradient: !post.transparentBg && post.customWallpaperPath == null && post.backdropIndex > 0
          ? LinearGradient(
              colors: backdrop.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      image: !post.transparentBg && post.customWallpaperPath != null
          ? DecorationImage(
              image: FileImage(File(post.customWallpaperPath!)),
              fit: BoxFit.cover,
            )
          : null,
      border: post.transparentBg ? null : Border.all(color: post.theme.cardBorder, width: 1.2),
      boxShadow: post.transparentBg
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
    );

    return AspectRatio(
      aspectRatio: post.ratio.aspectRatio,
      child: Container(
        decoration: canvasDecoration,
        padding: EdgeInsets.symmetric(
          horizontal: isVerticalStory ? 20 : (isSquare ? 14 : 16),
          vertical: isVerticalStory ? 24 : (isSquare ? 12 : 16),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: refWidth,
            height: refHeight,
            child: _buildCardContent(context, isVerticalStory: isVerticalStory),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, {required bool isVerticalStory}) {
    return Column(
      mainAxisAlignment: isVerticalStory ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: Year badge, Milestone, and Author info ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.theme.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: post.theme.accentColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    post.yearLabel.toUpperCase(),
                    style: TextStyle(
                      color: post.theme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (post.milestone != HabitMilestoneBadge.none) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      post.milestone.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (post.showAuthorBadge)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.authorAvatarPath != null) ...[
                    CircleAvatar(
                      radius: 11,
                      backgroundImage: FileImage(File(post.authorAvatarPath!)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    post.authorHandle,
                    style: TextStyle(
                      color: post.theme.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
          ],
        ),

        if (!isVerticalStory) const SizedBox(height: 12),

        // ─── Habit Title & Subtitle ───
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.habitTitle,
              style: TextStyle(
                color: post.theme.primaryText,
                fontSize: isVerticalStory ? 22 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                height: 1.25,
              ),
            ),
            if (post.habitSubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                post.habitSubtitle,
                style: TextStyle(
                  color: post.theme.secondaryText,
                  fontSize: isVerticalStory ? 13 : 11.5,
                  fontFamily: 'Poppins',
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),

        // ─── In 9:16 Vertical Story: Hero Streak Banner ───
        if (isVerticalStory) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: post.theme.levels[0].withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: post.theme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${post.displayStreak} DAYS STREAK',
                        style: TextStyle(
                          color: post.theme.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Consistency transforms effort into excellence',
                        style: TextStyle(
                          color: post.theme.secondaryText,
                          fontSize: 10.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        if (!isVerticalStory) const SizedBox(height: 12),

        // ─── Statistics Badges Row ───
        if (post.showStatsRow) ...[
          Row(
            children: [
              _buildStatBadge(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Streak',
                value: '${post.displayStreak} Days',
              ),
              const SizedBox(width: 8),
              _buildStatBadge(
                icon: Icons.check_circle_rounded,
                iconColor: post.theme.accentColor,
                title: 'Logged',
                value: '${post.completedDays} / ${post.timeSpan.totalDays}',
              ),
              const SizedBox(width: 8),
              _buildStatBadge(
                icon: Icons.insights_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: 'Rate',
                value: '${post.completionPercentage.toStringAsFixed(0)}%',
              ),
            ],
          ),
          if (!isVerticalStory) const SizedBox(height: 12),
        ],

        // ─── GitHub Commit-Style Heatmap Grid ───
        _buildContributionHeatmap(context, isVerticalStory: isVerticalStory),

        if (!isVerticalStory) const SizedBox(height: 12),

        // ─── Bottom Legend & Completion Count ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${post.completedDays} contributions logged',
              style: TextStyle(
                color: post.theme.secondaryText,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Less',
                  style: TextStyle(
                    color: post.theme.secondaryText,
                    fontSize: 9.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 5),
                ...List.generate(5, (index) {
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: post.theme.colorForLevel(index),
                      borderRadius: BorderRadius.circular(post.dotShape == HabitDotShape.circle ? 5.0 : 2.0),
                      border: Border.all(
                        color: index == 0 ? post.theme.cardBorder : Colors.transparent,
                        width: 0.5,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 2),
                Text(
                  'More',
                  style: TextStyle(
                    color: post.theme.secondaryText,
                    fontSize: 9.5,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: post.theme.levels[0],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: post.theme.cardBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: post.theme.secondaryText,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: post.theme.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionHeatmap(BuildContext context, {required bool isVerticalStory}) {
    final weeks = post.timeSpan.weeks;
    const daysPerWeek = 7;
    final dayLabels = ['M', '', 'W', '', 'F', '', 'S'];

    // Proportional tile sizing based on duration
    double tileSize;
    if (weeks <= 13) {
      tileSize = isVerticalStory ? 18.0 : 16.0;
    } else if (weeks <= 16) {
      tileSize = isVerticalStory ? 16.0 : 14.0;
    } else if (weeks <= 26) {
      tileSize = isVerticalStory ? 12.0 : 10.5;
    } else {
      tileSize = isVerticalStory ? 7.5 : 6.5;
    }
    final tileSpacing = post.dotSpacing;

    // Month headers
    final List<String> monthLabels = _computeMonthLabels(weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Month Headers (Jan, Feb, Mar...)
        if (post.showMonthLabels) ...[
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: List.generate(weeks, (colIndex) {
                  final label = colIndex < monthLabels.length ? monthLabels[colIndex] : '';
                  return Container(
                    width: tileSize + tileSpacing,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: post.theme.secondaryText,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Day Labels (M, W, F, S)
            if (post.showDayLabels) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(daysPerWeek, (dayIndex) {
                  return Container(
                    height: tileSize,
                    margin: EdgeInsets.only(bottom: tileSpacing),
                    alignment: Alignment.center,
                    child: Text(
                      dayLabels[dayIndex],
                      style: TextStyle(
                        color: post.theme.secondaryText,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 6),
            ],

            // The Heatmap Matrix (Columns = Weeks, Rows = Days 0..6)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: List.generate(weeks, (colIndex) {
                    return Padding(
                      padding: EdgeInsets.only(right: tileSpacing),
                      child: Column(
                        children: List.generate(daysPerWeek, (rowIndex) {
                          final tileIndex = (colIndex * daysPerWeek) + rowIndex;
                          final level = tileIndex < post.tileIntensities.length
                              ? post.tileIntensities[tileIndex]
                              : 0;

                          final isMaxGlow = post.enableDotGlow && level == 4;

                          return GestureDetector(
                            onTap: () => onTileTapped?.call(tileIndex),
                            child: Container(
                              width: tileSize,
                              height: tileSize,
                              margin: EdgeInsets.only(bottom: tileSpacing),
                              decoration: BoxDecoration(
                                color: post.theme.colorForLevel(level),
                                borderRadius: BorderRadius.circular(
                                  post.dotShape == HabitDotShape.circle
                                      ? tileSize / 2
                                      : (post.dotShape == HabitDotShape.pixelSharp
                                          ? 0.0
                                          : (post.dotShape == HabitDotShape.squircle ? tileSize * 0.45 : post.dotShape.radius)),
                                ),
                                border: Border.all(
                                  color: level == 0
                                      ? post.theme.cardBorder.withValues(alpha: 0.8)
                                      : Colors.transparent,
                                  width: 0.6,
                                ),
                                boxShadow: isMaxGlow
                                    ? [
                                        BoxShadow(
                                          color: post.theme.accentColor.withValues(alpha: 0.6),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _computeMonthLabels(int weeks) {
    final list = List<String>.filled(weeks, '');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    // Place a month label roughly every 4.3 weeks
    int monthIdx = 0;
    for (int w = 0; w < weeks; w += 4) {
      if (w < weeks && monthIdx < months.length) {
        list[w] = months[monthIdx % 12];
        monthIdx++;
      }
    }
    return list;
  }
}
