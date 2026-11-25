import 'dart:convert';
import 'package:flutter/material.dart';
import 'carousel_template_theme.dart';

/// Represents a user-created, reusable layout configuration
/// storing element coordinates, offsets, visibility toggles, and card styling.
class CarouselCustomLayout {
  final String id;
  final String name;
  final DateTime createdAt;

  // Group offsets
  final double contentOffsetX;
  final double contentOffsetY;
  final double headerOffsetY;

  // Individual component coordinates (componentId -> Offset)
  final Map<String, Offset> componentOffsets;

  // Element visibility flags
  final bool showNumberBadge;
  final bool showAuthor;
  final bool showBodyText;
  final bool showTakeaway;
  final bool showWatermark;
  final bool showSlideCounter;
  final bool showHookTag;

  // Card & element styling
  final CardStyle cardStyle;
  final bool showCardBackdrop;
  final RankBadgeStyle rankBadgeStyle;
  final SynopsisCardStyle synopsisCardStyle;
  final TitleCardStyle titleCardStyle;

  // Element font & color overrides
  final Map<String, String> componentFonts;
  final Map<String, Color> componentColors;

  const CarouselCustomLayout({
    required this.id,
    required this.name,
    required this.createdAt,
    this.contentOffsetX = 0.0,
    this.contentOffsetY = 0.0,
    this.headerOffsetY = 0.0,
    this.componentOffsets = const {},
    this.showNumberBadge = false,
    this.showAuthor = false,
    this.showBodyText = true,
    this.showTakeaway = false,
    this.showWatermark = true,
    this.showSlideCounter = true,
    this.showHookTag = false,
    this.cardStyle = CardStyle.none,
    this.showCardBackdrop = false,
    this.rankBadgeStyle = RankBadgeStyle.modernGradient,
    this.synopsisCardStyle = SynopsisCardStyle.cleanMinimal,
    this.titleCardStyle = TitleCardStyle.standardText,
    this.componentFonts = const {},
    this.componentColors = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'contentOffsetX': contentOffsetX,
      'contentOffsetY': contentOffsetY,
      'headerOffsetY': headerOffsetY,
      'componentOffsets': componentOffsets.map(
        (key, offset) => MapEntry(key, {'dx': offset.dx, 'dy': offset.dy}),
      ),
      'showNumberBadge': showNumberBadge,
      'showAuthor': showAuthor,
      'showBodyText': showBodyText,
      'showTakeaway': showTakeaway,
      'showWatermark': showWatermark,
      'showSlideCounter': showSlideCounter,
      'showHookTag': showHookTag,
      'cardStyle': cardStyle.index,
      'showCardBackdrop': showCardBackdrop,
      'rankBadgeStyle': rankBadgeStyle.index,
      'synopsisCardStyle': synopsisCardStyle.index,
      'titleCardStyle': titleCardStyle.index,
      'componentFonts': componentFonts,
      'componentColors': componentColors.map((k, v) => MapEntry(k, v.value)),
    };
  }

  factory CarouselCustomLayout.fromMap(Map<String, dynamic> map) {
    Map<String, Offset> offsets = {};
    if (map['componentOffsets'] is Map) {
      (map['componentOffsets'] as Map).forEach((k, v) {
        if (k != null && v is Map) {
          final dx = (v['dx'] as num?)?.toDouble() ?? 0.0;
          final dy = (v['dy'] as num?)?.toDouble() ?? 0.0;
          offsets[k.toString()] = Offset(dx, dy);
        }
      });
    }

    Map<String, String> fonts = {};
    if (map['componentFonts'] is Map) {
      (map['componentFonts'] as Map).forEach((k, v) {
        if (k != null && v != null) fonts[k.toString()] = v.toString();
      });
    }

    Map<String, Color> colors = {};
    if (map['componentColors'] is Map) {
      (map['componentColors'] as Map).forEach((k, v) {
        if (k != null && v is int) colors[k.toString()] = Color(v);
      });
    }

    return CarouselCustomLayout(
      id: map['id'] as String? ?? 'layout_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Custom Layout',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      contentOffsetX: (map['contentOffsetX'] as num?)?.toDouble() ?? 0.0,
      contentOffsetY: (map['contentOffsetY'] as num?)?.toDouble() ?? 0.0,
      headerOffsetY: (map['headerOffsetY'] as num?)?.toDouble() ?? 0.0,
      componentOffsets: offsets,
      showNumberBadge: map['showNumberBadge'] as bool? ?? (map['showRankBadge'] as bool? ?? true),
      showAuthor: map['showAuthor'] as bool? ?? false,
      showBodyText: map['showBodyText'] as bool? ?? (map['showSynopsis'] as bool? ?? true),
      showTakeaway: map['showTakeaway'] as bool? ?? false,
      showWatermark: map['showWatermark'] as bool? ?? true,
      showSlideCounter: map['showSlideCounter'] as bool? ?? true,
      showHookTag: map['showHookTag'] as bool? ?? false,
      cardStyle: CardStyle.values[(map['cardStyle'] as int? ?? 0).clamp(0, CardStyle.values.length - 1)],
      showCardBackdrop: map['showCardBackdrop'] as bool? ?? false,
      rankBadgeStyle: RankBadgeStyle.values[
          (map['rankBadgeStyle'] as int? ?? 0).clamp(0, RankBadgeStyle.values.length - 1)],
      synopsisCardStyle: SynopsisCardStyle.values[
          (map['synopsisCardStyle'] as int? ?? 0).clamp(0, SynopsisCardStyle.values.length - 1)],
      titleCardStyle: TitleCardStyle.values[
          (map['titleCardStyle'] as int? ?? 0).clamp(0, TitleCardStyle.values.length - 1)],
      componentFonts: fonts,
      componentColors: colors,
    );
  }

  String toJson() => json.encode(toMap());
  factory CarouselCustomLayout.fromJson(String source) =>
      CarouselCustomLayout.fromMap(json.decode(source) as Map<String, dynamic>);
}
