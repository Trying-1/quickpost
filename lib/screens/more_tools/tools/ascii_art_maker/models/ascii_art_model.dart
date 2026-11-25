import 'package:flutter/material.dart';

/// Typographic character ramps ordered from darkest density to brightest (or empty space).
enum AsciiCharset {
  standard('Classic 10', '@%#*+=-:. ', 'Clean classic 10-step typographic ramp'),
  detailed70('Ultra 70', r'''$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:,"^`'. ''', 'Photorealistic 70-character ASCII density shading'),
  ansiBlocks('ANSI Blocks', '█▓▒░ ', 'Bold terminal Unicode shade blocks'),
  matrixBinary('Binary 01', '10 ', 'Hacker Matrix digital binary code stream'),
  cyberSymbols('Code & Mesh', '#X/\\|:-. ', 'Crisp wireframe slash & symbol texture'),
  typewriter('Typewriter', 'MNHQ\$OC?7>!:-;. ', 'Vintage mechanical typewriter ink characters'),
  custom('Custom Text', 'ASCII*:. ', 'Use your own custom letters or symbols');

  final String label;
  final String ramp;
  final String description;

  const AsciiCharset(this.label, this.ramp, this.description);
}

/// Color rendering themes for the ASCII characters and terminal canvas.
enum AsciiColorMode {
  matrixGreen(
    label: 'Matrix Green',
    bgColor: Color(0xFF040C06),
    fgColor: Color(0xFF00FF41),
    secondaryColor: Color(0xFF008F11),
    usesPhotoColors: false,
  ),
  trueColor(
    label: 'True Color',
    bgColor: Color(0xFF090B10),
    fgColor: Colors.white,
    secondaryColor: Color(0xFF38BDF8),
    usesPhotoColors: true,
  ),
  cyberAmber(
    label: 'Amber CRT',
    bgColor: Color(0xFF120800),
    fgColor: Color(0xFFFFB000),
    secondaryColor: Color(0xFFCC6A00),
    usesPhotoColors: false,
  ),
  synthNeon(
    label: 'Synth Neon',
    bgColor: Color(0xFF0B0719),
    fgColor: Color(0xFF00F5D4),
    secondaryColor: Color(0xFFFF2A85),
    usesPhotoColors: false,
  ),
  terminalChalk(
    label: 'Chalk Dark',
    bgColor: Color(0xFF0B0F17),
    fgColor: Color(0xFFF1F5F9),
    secondaryColor: Color(0xFF94A3B8),
    usesPhotoColors: false,
  ),
  newsprintInk(
    label: 'Zine Paper',
    bgColor: Color(0xFFFAF6EE),
    fgColor: Color(0xFF1E293B),
    secondaryColor: Color(0xFF64748B),
    usesPhotoColors: false,
  ),
  gameBoyLcd(
    label: 'DMG Olive',
    bgColor: Color(0xFF0F380F),
    fgColor: Color(0xFF9BBC0F),
    secondaryColor: Color(0xFF8BAC0F),
    usesPhotoColors: false,
  );

  final String label;
  final Color bgColor;
  final Color fgColor;
  final Color secondaryColor;
  final bool usesPhotoColors;

  const AsciiColorMode({
    required this.label,
    required this.bgColor,
    required this.fgColor,
    required this.secondaryColor,
    required this.usesPhotoColors,
  });
}

/// Optional framing styles around the ASCII viewport.
enum AsciiFrameStyle {
  frameless('Full Canvas', Icons.fullscreen_rounded),
  macTerminal('macOS Shell', Icons.terminal_rounded),
  crtMonitor('Retro Terminal', Icons.computer_rounded),
  zinePoster('Zine Poster', Icons.article_outlined);

  final String label;
  final IconData icon;

  const AsciiFrameStyle(this.label, this.icon);
}

/// Output canvas aspect ratios.
enum AsciiAspectRatio {
  original('Original', null),
  square1x1('1:1 Square', 1.0),
  portrait4x5('4:5 Portrait', 4.0 / 5.0),
  story9x16('9:16 Story', 9.0 / 16.0),
  landscape16x9('16:9 Wide', 16.0 / 9.0);

  final String label;
  final double? ratio;

  const AsciiAspectRatio(this.label, this.ratio);
}

/// Immutable configuration state for the ASCII Art Studio.
class AsciiArtConfig {
  final int columns; // 28 to 140 characters wide
  final AsciiCharset charset;
  final String customRampText;
  final AsciiColorMode colorMode;
  final bool invertLuminance;
  final double contrast; // 0.6 to 2.2
  final double brightness; // -0.35 to 0.35
  final bool enableGlow;
  final bool crtScanlines;
  final double scanlineOpacity; // 0.05 to 0.45
  final double photoBgOpacity; // 0.0 to 0.40 double-exposure bleed
  final AsciiFrameStyle frameStyle;
  final String headerTitle;
  final AsciiAspectRatio aspectRatio;

  const AsciiArtConfig({
    this.columns = 54,
    this.charset = AsciiCharset.standard,
    this.customRampText = 'QUICKPOST*:. ',
    this.colorMode = AsciiColorMode.matrixGreen,
    this.invertLuminance = false,
    this.contrast = 1.25,
    this.brightness = 0.0,
    this.enableGlow = false,
    this.crtScanlines = true,
    this.scanlineOpacity = 0.18,
    this.photoBgOpacity = 0.0,
    this.frameStyle = AsciiFrameStyle.macTerminal,
    this.headerTitle = 'ascii_render.sh — 54x40',
    this.aspectRatio = AsciiAspectRatio.portrait4x5,
  });

  static const AsciiArtConfig initialDefault = AsciiArtConfig();

  AsciiArtConfig copyWith({
    int? columns,
    AsciiCharset? charset,
    String? customRampText,
    AsciiColorMode? colorMode,
    bool? invertLuminance,
    double? contrast,
    double? brightness,
    bool? enableGlow,
    bool? crtScanlines,
    double? scanlineOpacity,
    double? photoBgOpacity,
    AsciiFrameStyle? frameStyle,
    String? headerTitle,
    AsciiAspectRatio? aspectRatio,
  }) {
    return AsciiArtConfig(
      columns: columns ?? this.columns,
      charset: charset ?? this.charset,
      customRampText: customRampText ?? this.customRampText,
      colorMode: colorMode ?? this.colorMode,
      invertLuminance: invertLuminance ?? this.invertLuminance,
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      enableGlow: enableGlow ?? this.enableGlow,
      crtScanlines: crtScanlines ?? this.crtScanlines,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
      photoBgOpacity: photoBgOpacity ?? this.photoBgOpacity,
      frameStyle: frameStyle ?? this.frameStyle,
      headerTitle: headerTitle ?? this.headerTitle,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  /// Curated 1-tap aesthetic ASCII presets.
  static const List<({String name, String subtitle, AsciiArtConfig config})> studioPresets = [
    (
      name: 'Matrix Terminal',
      subtitle: 'Phosphor green Binary & Classic symbols in macOS terminal',
      config: AsciiArtConfig(
        columns: 58,
        charset: AsciiCharset.matrixBinary,
        colorMode: AsciiColorMode.matrixGreen,
        enableGlow: true,
        crtScanlines: true,
        contrast: 1.35,
        frameStyle: AsciiFrameStyle.macTerminal,
        headerTitle: 'neo@zion: ~/matrix_stream.sh',
      ),
    ),
    (
      name: 'True-Color Ultra',
      subtitle: 'Detailed 70-character ramp using vivid original photo colors',
      config: AsciiArtConfig(
        columns: 72,
        charset: AsciiCharset.detailed70,
        colorMode: AsciiColorMode.trueColor,
        enableGlow: false,
        crtScanlines: false,
        contrast: 1.2,
        photoBgOpacity: 0.14,
        frameStyle: AsciiFrameStyle.frameless,
      ),
    ),
    (
      name: 'ANSI Block Art',
      subtitle: 'Bold Unicode shaded blocks with Synth Neon contrast',
      config: AsciiArtConfig(
        columns: 48,
        charset: AsciiCharset.ansiBlocks,
        colorMode: AsciiColorMode.synthNeon,
        enableGlow: true,
        crtScanlines: true,
        contrast: 1.3,
        frameStyle: AsciiFrameStyle.crtMonitor,
        headerTitle: 'SYNTH_ANSI_V2.BIN',
      ),
    ),
    (
      name: 'Editorial Zine Ink',
      subtitle: 'Charcoal typewriter ink on warm cream gallery stock',
      config: AsciiArtConfig(
        columns: 64,
        charset: AsciiCharset.detailed70,
        colorMode: AsciiColorMode.newsprintInk,
        invertLuminance: false,
        enableGlow: false,
        crtScanlines: false,
        contrast: 1.3,
        frameStyle: AsciiFrameStyle.zinePoster,
        headerTitle: 'FIG 01. TYPOGRAPHIC STUDY',
      ),
    ),
    (
      name: '1982 Amber Monitor',
      subtitle: 'Monochrome warm amber terminal CRT with high-contrast shading',
      config: AsciiArtConfig(
        columns: 54,
        charset: AsciiCharset.standard,
        colorMode: AsciiColorMode.cyberAmber,
        enableGlow: true,
        crtScanlines: true,
        scanlineOpacity: 0.25,
        contrast: 1.4,
        frameStyle: AsciiFrameStyle.crtMonitor,
        headerTitle: 'VT-100 TERMINAL // OK',
      ),
    ),
  ];
}
