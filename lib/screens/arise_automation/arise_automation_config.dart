import 'package:flutter/material.dart';

class AriseAutomationConfig {
  // Constants matching resize_for_social.py
  static const double targetWidth = 1080;
  static const double targetHeight = 1920;

  // Configuration variables
  Color paddingColor;
  bool useBackgroundImage;
  double backgroundBlurRadius;
  bool roundedCorners;
  double cornerRadius;
  bool strokeEnabled;
  double strokeWidth;
  Color strokeColor;
  int videoDuration; // In seconds
  int fps;
  bool fadeWholeVideo;
  double imageScale;
  double backgroundBrightness;
  double backgroundSaturation;

  AriseAutomationConfig({
    this.paddingColor = Colors.black,
    this.useBackgroundImage = true,
    this.backgroundBlurRadius = 20.0,
    this.roundedCorners = true,
    this.cornerRadius = 40.0,
    this.strokeEnabled = true,
    this.strokeWidth = 4.0,
    this.strokeColor = Colors.white,
    this.videoDuration = 8,
    this.fps = 30,
    this.fadeWholeVideo = true,
    this.imageScale = 0.9,
    this.backgroundBrightness = 1.0,
    this.backgroundSaturation = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'paddingColor': '#${paddingColor.value.toRadixString(16).padLeft(8, '0')}',
      'useBackgroundImage': useBackgroundImage,
      'backgroundBlurRadius': backgroundBlurRadius,
      'roundedCorners': roundedCorners,
      'cornerRadius': cornerRadius,
      'strokeEnabled': strokeEnabled,
      'strokeWidth': strokeWidth,
      'strokeColor': '#${strokeColor.value.toRadixString(16).padLeft(8, '0')}',
      'videoDuration': videoDuration,
      'fps': fps,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'fadeWholeVideo': fadeWholeVideo,
      'imageScale': imageScale,
      'backgroundBrightness': backgroundBrightness,
      'backgroundSaturation': backgroundSaturation,
    };
  }

  factory AriseAutomationConfig.defaultConfig() => AriseAutomationConfig();
}
