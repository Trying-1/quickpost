import 'package:flutter/material.dart';

/// Active interaction tool in the Shape Mask Studio.
enum ShapeMaskTool {
  maskToggle('Mask Tap', 'Tap any closed area to show or hide photo below', Icons.touch_app_rounded),
  rectangle('Box', 'Drag to draw a rectangle cutout box', Icons.crop_square_rounded),
  circle('Circle', 'Touch center & drag outward for a round circle', Icons.circle_outlined),
  arc('Arcs', 'Touch center & drag outward to draw segmented arcs', Icons.donut_large_rounded),
  lineCut('Line', 'Drag start to end to draw a line segment', Icons.horizontal_rule_rounded),
  polygon('Polygon', 'Tap points to craft a custom closed polygon', Icons.polyline_rounded),
  selectMove('Move', 'Tap to select; use Multi to group, merge, or style together', Icons.open_with_rounded),
  panPhoto('Pan Photo', 'Drag to reposition the underlying photo', Icons.pan_tool_rounded);

  final String label;
  final String hint;
  final IconData icon;

  const ShapeMaskTool(this.label, this.hint, this.icon);
}

/// Vector shape / line types supported on the mask canvas.
enum MaskElementType {
  rectangle,
  circle,
  arc,
  line,
  polygon,
}

/// Border stroke pattern options.
enum MaskStrokePattern {
  solid('Solid'),
  dashed('Dashed'),
  dotted('Dotted'),
  dashDot('Dash-Dot');

  final String label;
  const MaskStrokePattern(this.label);
}

/// Visual rendering style for areas where the underlying photo is masked OUT.
enum MaskBackdropStyle {
  dimmedDark('Focus Dim', 'Dims unmasked areas so cutouts spotlight clearly', Icons.brightness_4_rounded),
  bwColorPop('B&W Pop', 'Turns unmasked areas Noir B&W while cutouts stay vivid color', Icons.monochrome_photos_rounded),
  frostedBlur('Frosted Blur', 'Blurs unmasked areas while keeping cutouts razor sharp', Icons.blur_on_rounded),
  solidWhite('Clean White', 'Crisp studio white matte frame around cutouts', Icons.crop_portrait_rounded),
  solidBlack('Pitch Black', 'High-contrast obsidian matte overlay', Icons.dark_mode_rounded),
  gradientMatte('Teal Gradient', 'Rich aesthetic gradient matte backdrop', Icons.gradient_rounded),
  customColor('Custom Color', 'Pick any solid matte color around masked shapes', Icons.color_lens_rounded),
  transparentCutout('Transparent', 'Pure alpha-transparent PNG cutout for video overlays', Icons.grid_on_rounded);

  final String label;
  final String description;
  final IconData icon;

  const MaskBackdropStyle(this.label, this.description, this.icon);
}

/// Canvas aspect ratios.
enum ShapeMaskAspectRatio {
  original('Original', null),
  square1x1('1:1 Square', 1.0),
  portrait4x5('4:5 Portrait', 4.0 / 5.0),
  classic3x4('3:4 Classic', 3.0 / 4.0),
  story9x16('9:16 Story', 9.0 / 16.0);

  final String label;
  final double? ratio;

  const ShapeMaskAspectRatio(this.label, this.ratio);
}

/// 1-tap geometric shape presets insertable onto the canvas.
enum QuickStampShape {
  diamond('Diamond', Icons.diamond_outlined),
  triangle('Triangle', Icons.change_history_rounded),
  hexagon('Hexagon', Icons.hexagon_outlined),
  star('Star', Icons.star_outline_rounded),
  pill('Pill Card', Icons.rounded_corner_rounded);

  final String label;
  final IconData icon;

  const QuickStampShape(this.label, this.icon);
}

/// Immutable vector element drawn by the creator (in normalized 0.0..1.0 canvas coordinates).
class MaskElement {
  final String id;
  final String? groupId;
  final MaskElementType type;

  /// Normalized bounding rect (used for rectangle, circle, & arc rings)
  final Rect? rect;

  /// Normalized endpoints (used for line)
  final Offset? p1;
  final Offset? p2;

  /// Normalized vertices (primary closed contour for polygon / merged shape)
  final List<Offset> points;

  /// Optional extra contours produced by boolean merging disjoint shapes
  final List<List<Offset>> extraPolygons;

  final Color borderColor;
  final double borderWidth; // Logical px (0..20)
  final double cornerRadius; // Logical px (0..140, rectangle only)
  final double rotationDeg; // -180..180 degrees around normalizedCenter
  final MaskStrokePattern strokePattern;
  final double dashLength; // 3..36px
  final double dashGap; // 3..32px

  // Segmented arc properties (MaskElementType.arc)
  final int arcCount; // 1..12 arc segments
  final double arcSweepRatio; // 0.15..0.95 fill per arc slot
  final bool arcCloseMaskRegion; // Whether interior circular area participates in region mask

  const MaskElement({
    required this.id,
    this.groupId,
    required this.type,
    this.rect,
    this.p1,
    this.p2,
    this.points = const [],
    this.extraPolygons = const [],
    this.borderColor = Colors.white,
    this.borderWidth = 3.5,
    this.cornerRadius = 0.0,
    this.rotationDeg = 0.0,
    this.strokePattern = MaskStrokePattern.solid,
    this.dashLength = 10.0,
    this.dashGap = 6.0,
    this.arcCount = 3,
    this.arcSweepRatio = 0.68,
    this.arcCloseMaskRegion = true,
  });

  List<List<Offset>> get allPolygonLoops {
    if (points.isEmpty) return extraPolygons;
    return [points, ...extraPolygons];
  }

  Offset get normalizedCenter {
    if (rect != null) return rect!.center;
    if (p1 != null && p2 != null) return Offset((p1!.dx + p2!.dx) / 2, (p1!.dy + p2!.dy) / 2);
    if (points.isNotEmpty) {
      double sx = 0, sy = 0;
      for (final pt in points) {
        sx += pt.dx;
        sy += pt.dy;
      }
      return Offset(sx / points.length, sy / points.length);
    }
    return const Offset(0.5, 0.5);
  }

  MaskElement copyWith({
    String? groupId,
    bool clearGroupId = false,
    Rect? rect,
    Offset? p1,
    Offset? p2,
    List<Offset>? points,
    List<List<Offset>>? extraPolygons,
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
    double? rotationDeg,
    MaskStrokePattern? strokePattern,
    double? dashLength,
    double? dashGap,
    int? arcCount,
    double? arcSweepRatio,
    bool? arcCloseMaskRegion,
  }) {
    return MaskElement(
      id: id,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      type: type,
      rect: rect ?? this.rect,
      p1: p1 ?? this.p1,
      p2: p2 ?? this.p2,
      points: points ?? this.points,
      extraPolygons: extraPolygons ?? this.extraPolygons,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      strokePattern: strokePattern ?? this.strokePattern,
      dashLength: dashLength ?? this.dashLength,
      dashGap: dashGap ?? this.dashGap,
      arcCount: arcCount ?? this.arcCount,
      arcSweepRatio: arcSweepRatio ?? this.arcSweepRatio,
      arcCloseMaskRegion: arcCloseMaskRegion ?? this.arcCloseMaskRegion,
    );
  }

  MaskElement translated(Offset delta) {
    return copyWith(
      rect: rect?.shift(delta),
      p1: p1 != null ? p1! + delta : null,
      p2: p2 != null ? p2! + delta : null,
      points: points.map((p) => p + delta).toList(),
      extraPolygons: extraPolygons
          .map((loop) => loop.map((p) => p + delta).toList())
          .toList(),
    );
  }
}

/// Anchored toggle state for a closed area on the canvas.
class RegionToggleSeed {
  final Offset normPos;
  final bool showImage;
  final String? linkedElementId;

  const RegionToggleSeed({
    required this.normPos,
    required this.showImage,
    this.linkedElementId,
  });

  RegionToggleSeed copyWith({
    Offset? normPos,
    bool? showImage,
  }) {
    return RegionToggleSeed(
      normPos: normPos ?? this.normPos,
      showImage: showImage ?? this.showImage,
      linkedElementId: linkedElementId,
    );
  }
}

/// Complete immutable studio state for Undo/Redo and rendering.
class ShapeMaskConfig {
  final List<MaskElement> elements;
  final List<RegionToggleSeed> regionSeeds;
  final bool defaultRevealImage;
  final MaskBackdropStyle backdropStyle;
  final Color customBackdropColor;
  final double backdropIntensity;
  final ShapeMaskAspectRatio aspectRatio;

  // Global & Tool defaults
  final Color activeBorderColor;
  final double activeBorderWidth;
  final double activeCornerRadius;
  final MaskStrokePattern activeStrokePattern;
  final double activeDashLength;
  final double activeDashGap;
  final int activeArcCount;
  final double activeArcSweepRatio;
  final bool activeArcCloseMask;

  final bool extendLinesToEdge;
  final bool angleSnapLines;
  final bool lockPerfectCircle;
  final bool showAlignGuides;
  final bool enableWindowShadow;
  final double outerFrameWidth;
  final Color outerFrameColor;

  // Underlying photo pan/zoom inside mask windows
  final double imageScale;
  final Offset imageOffset;

  const ShapeMaskConfig({
    this.elements = const [],
    this.regionSeeds = const [],
    this.defaultRevealImage = false,
    this.backdropStyle = MaskBackdropStyle.bwColorPop,
    this.customBackdropColor = const Color(0xFF00796B),
    this.backdropIntensity = 0.65,
    this.aspectRatio = ShapeMaskAspectRatio.portrait4x5,
    this.activeBorderColor = Colors.white,
    this.activeBorderWidth = 3.5,
    this.activeCornerRadius = 0.0,
    this.activeStrokePattern = MaskStrokePattern.solid,
    this.activeDashLength = 10.0,
    this.activeDashGap = 6.0,
    this.activeArcCount = 3,
    this.activeArcSweepRatio = 0.68,
    this.activeArcCloseMask = true,
    this.extendLinesToEdge = false,
    this.angleSnapLines = true,
    this.lockPerfectCircle = true,
    this.showAlignGuides = false,
    this.enableWindowShadow = true,
    this.outerFrameWidth = 0.0,
    this.outerFrameColor = Colors.white,
    this.imageScale = 1.0,
    this.imageOffset = Offset.zero,
  });

  static const ShapeMaskConfig initialDefault = ShapeMaskConfig();

  ShapeMaskConfig copyWith({
    List<MaskElement>? elements,
    List<RegionToggleSeed>? regionSeeds,
    bool? defaultRevealImage,
    MaskBackdropStyle? backdropStyle,
    Color? customBackdropColor,
    double? backdropIntensity,
    ShapeMaskAspectRatio? aspectRatio,
    Color? activeBorderColor,
    double? activeBorderWidth,
    double? activeCornerRadius,
    MaskStrokePattern? activeStrokePattern,
    double? activeDashLength,
    double? activeDashGap,
    int? activeArcCount,
    double? activeArcSweepRatio,
    bool? activeArcCloseMask,
    bool? extendLinesToEdge,
    bool? angleSnapLines,
    bool? lockPerfectCircle,
    bool? showAlignGuides,
    bool? enableWindowShadow,
    double? outerFrameWidth,
    Color? outerFrameColor,
    double? imageScale,
    Offset? imageOffset,
  }) {
    return ShapeMaskConfig(
      elements: elements ?? this.elements,
      regionSeeds: regionSeeds ?? this.regionSeeds,
      defaultRevealImage: defaultRevealImage ?? this.defaultRevealImage,
      backdropStyle: backdropStyle ?? this.backdropStyle,
      customBackdropColor: customBackdropColor ?? this.customBackdropColor,
      backdropIntensity: backdropIntensity ?? this.backdropIntensity,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      activeBorderColor: activeBorderColor ?? this.activeBorderColor,
      activeBorderWidth: activeBorderWidth ?? this.activeBorderWidth,
      activeCornerRadius: activeCornerRadius ?? this.activeCornerRadius,
      activeStrokePattern: activeStrokePattern ?? this.activeStrokePattern,
      activeDashLength: activeDashLength ?? this.activeDashLength,
      activeDashGap: activeDashGap ?? this.activeDashGap,
      activeArcCount: activeArcCount ?? this.activeArcCount,
      activeArcSweepRatio: activeArcSweepRatio ?? this.activeArcSweepRatio,
      activeArcCloseMask: activeArcCloseMask ?? this.activeArcCloseMask,
      extendLinesToEdge: extendLinesToEdge ?? this.extendLinesToEdge,
      angleSnapLines: angleSnapLines ?? this.angleSnapLines,
      lockPerfectCircle: lockPerfectCircle ?? this.lockPerfectCircle,
      showAlignGuides: showAlignGuides ?? this.showAlignGuides,
      enableWindowShadow: enableWindowShadow ?? this.enableWindowShadow,
      outerFrameWidth: outerFrameWidth ?? this.outerFrameWidth,
      outerFrameColor: outerFrameColor ?? this.outerFrameColor,
      imageScale: imageScale ?? this.imageScale,
      imageOffset: imageOffset ?? this.imageOffset,
    );
  }

  /// Curated 1-tap starter templates for Bento Collages, Color Pop, & HUD Arcs.
  static List<({String name, String subtitle, ShapeMaskConfig config})> starterPresets = [
    (
      name: 'B&W Color Pop Triptych',
      subtitle: 'Noir B&W backdrop with vivid full-color Bento cutout windows',
      config: const ShapeMaskConfig(
        backdropStyle: MaskBackdropStyle.bwColorPop,
        backdropIntensity: 0.65,
        activeBorderColor: Colors.white,
        activeBorderWidth: 3.5,
        activeCornerRadius: 12.0,
        enableWindowShadow: true,
        elements: [
          MaskElement(
            id: 'preset_r1',
            type: MaskElementType.rectangle,
            rect: Rect.fromLTWH(0.08, 0.08, 0.40, 0.84),
            borderColor: Colors.white,
            borderWidth: 3.5,
            cornerRadius: 12.0,
          ),
          MaskElement(
            id: 'preset_r2',
            type: MaskElementType.rectangle,
            rect: Rect.fromLTWH(0.52, 0.08, 0.40, 0.40),
            borderColor: Colors.white,
            borderWidth: 3.5,
            cornerRadius: 12.0,
          ),
          MaskElement(
            id: 'preset_r3',
            type: MaskElementType.rectangle,
            rect: Rect.fromLTWH(0.52, 0.52, 0.40, 0.40),
            borderColor: Colors.white,
            borderWidth: 3.5,
            cornerRadius: 12.0,
          ),
        ],
        regionSeeds: [
          RegionToggleSeed(normPos: Offset(0.28, 0.50), showImage: true, linkedElementId: 'preset_r1'),
          RegionToggleSeed(normPos: Offset(0.72, 0.28), showImage: true, linkedElementId: 'preset_r2'),
          RegionToggleSeed(normPos: Offset(0.72, 0.72), showImage: true, linkedElementId: 'preset_r3'),
        ],
      ),
    ),
    (
      name: 'HUD Segmented Arcs',
      subtitle: 'Dual-ring rotated cyber arcs with dotted & solid accents',
      config: const ShapeMaskConfig(
        backdropStyle: MaskBackdropStyle.bwColorPop,
        backdropIntensity: 0.70,
        elements: [
          MaskElement(
            id: 'preset_a1',
            type: MaskElementType.arc,
            rect: Rect.fromLTWH(0.20, 0.16, 0.60, 0.48),
            borderColor: Color(0xFF00E5FF),
            borderWidth: 4.5,
            arcCount: 4,
            arcSweepRatio: 0.65,
            rotationDeg: 22.0,
            arcCloseMaskRegion: true,
          ),
          MaskElement(
            id: 'preset_a2',
            type: MaskElementType.arc,
            rect: Rect.fromLTWH(0.14, 0.112, 0.72, 0.576),
            borderColor: Colors.white,
            borderWidth: 2.5,
            strokePattern: MaskStrokePattern.dotted,
            dashGap: 8.0,
            arcCount: 2,
            arcSweepRatio: 0.75,
            rotationDeg: -15.0,
            arcCloseMaskRegion: false,
          ),
        ],
        regionSeeds: [
          RegionToggleSeed(normPos: Offset(0.50, 0.40), showImage: true, linkedElementId: 'preset_a1'),
        ],
      ),
    ),
    (
      name: 'Mondrian Gold Split',
      subtitle: 'Intersecting divider lines with alternating visible regions',
      config: const ShapeMaskConfig(
        backdropStyle: MaskBackdropStyle.solidBlack,
        activeBorderColor: Color(0xFFFACC15),
        activeBorderWidth: 5.0,
        elements: [
          MaskElement(
            id: 'preset_l1',
            type: MaskElementType.line,
            p1: Offset(0.0, 0.36),
            p2: Offset(1.0, 0.36),
            borderColor: Color(0xFFFACC15),
            borderWidth: 5.0,
          ),
          MaskElement(
            id: 'preset_l2',
            type: MaskElementType.line,
            p1: Offset(0.45, 0.0),
            p2: Offset(0.45, 1.0),
            borderColor: Color(0xFFFACC15),
            borderWidth: 5.0,
          ),
          MaskElement(
            id: 'preset_l3',
            type: MaskElementType.line,
            p1: Offset(0.45, 0.36),
            p2: Offset(1.0, 1.0),
            borderColor: Color(0xFFFACC15),
            borderWidth: 5.0,
          ),
        ],
        regionSeeds: [
          RegionToggleSeed(normPos: Offset(0.20, 0.18), showImage: true),
          RegionToggleSeed(normPos: Offset(0.75, 0.50), showImage: true),
          RegionToggleSeed(normPos: Offset(0.22, 0.70), showImage: true),
        ],
      ),
    ),
    (
      name: 'Diamond Spotlight',
      subtitle: 'Rotated diamond window over frosted blurred glass backdrop',
      config: const ShapeMaskConfig(
        backdropStyle: MaskBackdropStyle.frostedBlur,
        backdropIntensity: 0.78,
        activeBorderColor: Color(0xFF00E5FF),
        activeBorderWidth: 4.0,
        enableWindowShadow: true,
        elements: [
          MaskElement(
            id: 'preset_d1',
            type: MaskElementType.rectangle,
            rect: Rect.fromLTWH(0.22, 0.22, 0.56, 0.45),
            borderColor: Color(0xFF00E5FF),
            borderWidth: 4.0,
            cornerRadius: 18.0,
            rotationDeg: 45.0,
          ),
        ],
        regionSeeds: [
          RegionToggleSeed(normPos: Offset(0.50, 0.445), showImage: true, linkedElementId: 'preset_d1'),
        ],
      ),
    ),
  ];
}
