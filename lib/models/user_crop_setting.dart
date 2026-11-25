import 'dart:convert';

/// Represents a normalized crop rectangle where all coordinates are in the 0.0 - 1.0 range
/// relative to the media display area.
class NormalizedCropRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const NormalizedCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get aspectRatio => height > 0 ? width / height : 1.0;

  NormalizedCropRect clamp() {
    final clampedW = width.clamp(0.05, 1.0);
    final clampedH = height.clamp(0.05, 1.0);
    final clampedX = x.clamp(0.0, 1.0 - clampedW);
    final clampedY = y.clamp(0.0, 1.0 - clampedH);
    return NormalizedCropRect(
      x: clampedX,
      y: clampedY,
      width: clampedW,
      height: clampedH,
    );
  }

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory NormalizedCropRect.fromMap(Map<String, dynamic> map) {
    return NormalizedCropRect(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 1.0,
      height: (map['height'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// A user-defined or built-in crop setting preset.
///
/// Can either enforce an exact framing (exact normalized position & size)
/// or an aspect ratio centered on the media.
class UserCropSetting {
  final String id;
  final String name;
  final double aspectRatio;
  final String ratioLabel;
  final bool isExactFraming;
  final double normalizedX;
  final double normalizedY;
  final double normalizedWidth;
  final double normalizedHeight;
  final bool isBuiltIn;
  final DateTime createdAt;

  const UserCropSetting({
    required this.id,
    required this.name,
    required this.aspectRatio,
    required this.ratioLabel,
    this.isExactFraming = false,
    this.normalizedX = 0.0,
    this.normalizedY = 0.0,
    this.normalizedWidth = 1.0,
    this.normalizedHeight = 1.0,
    this.isBuiltIn = false,
    required this.createdAt,
  });

  NormalizedCropRect get normalizedRect => NormalizedCropRect(
    x: normalizedX,
    y: normalizedY,
    width: normalizedWidth,
    height: normalizedHeight,
  );

  UserCropSetting copyWith({
    String? id,
    String? name,
    double? aspectRatio,
    String? ratioLabel,
    bool? isExactFraming,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return UserCropSetting(
      id: id ?? this.id,
      name: name ?? this.name,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      ratioLabel: ratioLabel ?? this.ratioLabel,
      isExactFraming: isExactFraming ?? this.isExactFraming,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'aspectRatio': aspectRatio,
      'ratioLabel': ratioLabel,
      'isExactFraming': isExactFraming,
      'normalizedX': normalizedX,
      'normalizedY': normalizedY,
      'normalizedWidth': normalizedWidth,
      'normalizedHeight': normalizedHeight,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory UserCropSetting.fromMap(Map<String, dynamic> map) {
    return UserCropSetting(
      id: map['id'] as String? ?? 'preset_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Crop Preset',
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      ratioLabel: map['ratioLabel'] as String? ?? '1:1',
      isExactFraming: map['isExactFraming'] as bool? ?? false,
      normalizedX: (map['normalizedX'] as num?)?.toDouble() ?? 0.0,
      normalizedY: (map['normalizedY'] as num?)?.toDouble() ?? 0.0,
      normalizedWidth: (map['normalizedWidth'] as num?)?.toDouble() ?? 1.0,
      normalizedHeight: (map['normalizedHeight'] as num?)?.toDouble() ?? 1.0,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserCropSetting.fromJson(String source) =>
      UserCropSetting.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

