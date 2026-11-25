import 'package:flutter/material.dart';

/// Authentic retro console and aesthetic color palettes.
enum PixelPaletteType {
  trueColor('True Color', 'Original photo colors quantized cleanly', [
    Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFFDD835),
  ]),
  gameBoyDmg('Game Boy DMG (1989)', '4-shade iconic olive green pea-soup LCD screen', [
    Color(0xFF0F380F), Color(0xFF306230), Color(0xFF8BAC0F), Color(0xFF9BBC0F),
  ]),
  gameBoyPocket('Game Boy Pocket (1996)', 'Crisp 4-level silver & charcoal monochrome display', [
    Color(0xFF181818), Color(0xFF545454), Color(0xFFA0A0A0), Color(0xFFF8F8F8),
  ]),
  oneBitNoir('1-Bit Noir (Pure B&W)', 'High-contrast Playdate & classic Mac 1-bit ink', [
    Color(0xFF0B0C10), Color(0xFFF7F7F2),
  ]),
  cyberAmber('Amber Phosphor CRT', 'Warm 1980s monochrome amber terminal monitor', [
    Color(0xFF1A0B00), Color(0xFF6B3200), Color(0xFFCC6B00), Color(0xFFFFB833),
  ]),
  ibmCga('IBM CGA (1981)', 'Iconic 4-color retro PC magenta, cyan & white', [
    Color(0xFF000000), Color(0xFF55FFFF), Color(0xFFFF55FF), Color(0xFFFFFFFF),
  ]),
  nesClassic('NES 8-Bit', 'Classic 1985 Nintendo Entertainment System palette', [
    Color(0xFF000000), Color(0xFFFCFCFC), Color(0xFFBCBCBC), Color(0xFF747474),
    Color(0xFF002494), Color(0xFF2038EC), Color(0xFF3CB4FA), Color(0xFF246014),
    Color(0xFF00A800), Color(0xFF58F858), Color(0xFF881400), Color(0xFFE40058),
    Color(0xFFF83800), Color(0xFFF87858), Color(0xFFE45C10), Color(0xFFFCE0A8),
  ]),
  snesPastel('SNES 16-Bit Pastel', 'Rich warm fantasy JRPG & 16-bit console palette', [
    Color(0xFF181425), Color(0xFF262B44), Color(0xFF3A4466), Color(0xFF5A6988),
    Color(0xFF8B9BB4), Color(0xFFC0CBDC), Color(0xFFFFFFFF), Color(0xFFE43B44),
    Color(0xFFF77622), Color(0xFFFEE761), Color(0xFF63C74D), Color(0xFF3E8948),
    Color(0xFF0095E9), Color(0xFF124E89), Color(0xFFB55088), Color(0xFFF6757A),
    Color(0xFFE8B796), Color(0xFFC28569), Color(0xFF733E39), Color(0xFF3E2731),
  ]),
  pico8('PICO-8 Fantasy', 'Beloved 16-color indie fantasy console palette', [
    Color(0xFF000000), Color(0xFF1D2B53), Color(0xFF7E2553), Color(0xFF008751),
    Color(0xFFAB5236), Color(0xFF5F574F), Color(0xFFC2C3C7), Color(0xFFFFF1E8),
    Color(0xFFFF004D), Color(0xFFFFA300), Color(0xFFFFEC27), Color(0xFF00E436),
    Color(0xFF29ADFF), Color(0xFF83769C), Color(0xFFFF77A8), Color(0xFFFFCCAA),
  ]),
  commodore64('Commodore 64', 'Iconic 1982 home computer warm phosphor colors', [
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF880000), Color(0xFFAAE4E4),
    Color(0xFF993399), Color(0xFF44AC55), Color(0xFF323CBE), Color(0xFFEEEE77),
    Color(0xFFD36F17), Color(0xFF8B5400), Color(0xFFBA6666), Color(0xFF444444),
    Color(0xFF777777), Color(0xFF99EE99), Color(0xFF7788EE), Color(0xFFBBBBBB),
  ]),
  cyberArcade('Cyber Arcade Neon', 'High-contrast synthwave neon cyan, magenta & violet', [
    Color(0xFF050510), Color(0xFF1A0B2E), Color(0xFF7B2CBF), Color(0xFFC77DFF),
    Color(0xFFFF007F), Color(0xFFFF5400), Color(0xFFFFBD00), Color(0xFF00F5D4),
    Color(0xFF00BBF9), Color(0xFFFFFFFF),
  ]),
  sepiaRetro('1984 Macintosh', 'Warm 2-bit vintage amber-sepia print aesthetic', [
    Color(0xFF2C1E14), Color(0xFF6B4C35), Color(0xFFB58E68), Color(0xFFF4ECD8),
  ]);

  final String label;
  final String description;
  final List<Color> swatchColors;

  const PixelPaletteType(this.label, this.description, this.swatchColors);
}

/// Color quantization dithering algorithms.
enum DitherAlgorithm {
  none('Flat Clean', 'Crisp un-dithered flat pixel color blocks'),
  bayer4x4('Bayer 4x4', 'Classic 16-step ordered retro crosshatch'),
  bayer2x2('Bayer 2x2', 'Chunky 4-step vintage stipple checkerboard'),
  floydSteinberg('Floyd-Steinberg', 'Smooth error-diffusion for photographic detail');

  final String label;
  final String description;

  const DitherAlgorithm(this.label, this.description);
}

/// Visual rendering geometry of each individual pixel cell.
enum PixelBlockShape {
  square('Classic Pixels', 'Sharp edge-to-edge square pixel blocks', Icons.square_rounded),
  lcdMatrix('LCD Matrix', 'Backlit handheld LCD grid with dark pixel gaps', Icons.grid_on_rounded),
  ledBoard('LED Display', 'Rounded glowing pixel diodes on black matrix', Icons.light_mode_rounded),
  pegboard('Pegboard Dots', 'Circular Perler bead / Lite-Brite dot matrix', Icons.circle_outlined);

  final String label;
  final String description;
  final IconData icon;

  const PixelBlockShape(this.label, this.description, this.icon);
}

/// Optional retro corner HUD badges overlaid on the pixel artwork.
enum PixelHudBadge {
  none('None', ''),
  recLive('REC 8-BIT', '● REC  00:19:89'),
  hpHearts('HP Hearts', 'HP 100/100 ♥♥♥'),
  levelUp('LVL 99', '★ LEVEL 99 UNLOCKED'),
  saveSlot('SAVE 01', 'SAVE FILE [01] OK');

  final String label;
  final String badgeText;

  const PixelHudBadge(this.label, this.badgeText);
}

/// Retro framing overlays around the pixel canvas.
enum PixelFrameStyle {
  frameless('Frameless', 'Pure edge-to-edge raw pixel art', Icons.fullscreen_rounded),
  gameBoyShell('Handheld DMG', '1989 handheld shell with screen bezel & power LED', Icons.videogame_asset_rounded),
  arcadeCrt('Arcade CRT', 'Curved cathode ray monitor with scanlines & coin HUD', Icons.tv_rounded),
  retroWin95('Retro Win95', 'Classic 90s desktop window with title bar and buttons', Icons.web_asset_rounded),
  rpgDialogBox('8-Bit RPG', 'Vintage fantasy JRPG dialogue box with editable dialogue', Icons.subtitles_rounded),
  polaroid8Bit('8-Bit Instant', 'Nostalgic instant print frame with pixel caption', Icons.photo_camera_front_rounded),
  cartridgeCard('Game Stat Card', 'Retro game cartridge & character card frame', Icons.style_rounded);

  final String label;
  final String description;
  final IconData icon;

  const PixelFrameStyle(this.label, this.description, this.icon);
}

/// Canvas aspect ratio formats.
enum PixelAspectRatio {
  original('Original', 'Preserves photo original proportion', null),
  square1x1('1:1 Square', 'Social feed posts & retro avatars', 1.0),
  portrait4x5('4:5 Portrait', 'Social feed optimal ratio', 4.0 / 5.0),
  story9x16('9:16 Story', 'Reels, TikTok & Phone Wallpapers', 9.0 / 16.0);

  final String label;
  final String subtitle;
  final double? ratio;

  const PixelAspectRatio(this.label, this.subtitle, this.ratio);
}

/// Compare visualization modes.
enum CompareViewMode {
  off('Pixel Art', 'Show only the retro pixel art'),
  fullOriginal('Original', 'Show full original photo'),
  splitWipe('Split Wipe', 'Interactive split divider between Original & Pixel');

  final String label;
  final String description;

  const CompareViewMode(this.label, this.description);
}

/// Immutable configuration model for the Retro Pixel Art Studio.
class PixelArtConfig {
  final int pixelColumns;
  final PixelPaletteType palette;
  final DitherAlgorithm ditherAlgorithm;
  final double ditherStrength; // 0.0 to 1.0
  final PixelBlockShape blockShape;
  final bool showPixelGrid;
  final bool crtScanlines;
  final double scanlineOpacity; // 0.0 to 0.6
  final bool crtVignette;
  final int rgbSplitColumns; // 0 to 3 pixel column chromatic drift
  final bool edgeOutline; // Inked dark sprite contour lines
  final bool invertColors;
  final double brightness; // -0.4 to 0.4
  final double contrast; // 0.5 to 2.0
  final double saturation; // 0.0 to 2.0
  final PixelFrameStyle frameStyle;
  final PixelHudBadge hudBadge;
  final String customTitleText;
  final String rpgDialogueText;
  final String rpgSpeakerName;
  final PixelAspectRatio aspectRatio;
  final CompareViewMode compareMode;
  final double compareSplit; // 0.0 to 1.0

  const PixelArtConfig({
    this.pixelColumns = 56,
    this.palette = PixelPaletteType.gameBoyDmg,
    this.ditherAlgorithm = DitherAlgorithm.bayer4x4,
    this.ditherStrength = 0.65,
    this.blockShape = PixelBlockShape.square,
    this.showPixelGrid = false,
    this.crtScanlines = true,
    this.scanlineOpacity = 0.22,
    this.crtVignette = false,
    this.rgbSplitColumns = 0,
    this.edgeOutline = false,
    this.invertColors = false,
    this.brightness = 0.0,
    this.contrast = 1.15,
    this.saturation = 1.05,
    this.frameStyle = PixelFrameStyle.gameBoyShell,
    this.hudBadge = PixelHudBadge.none,
    this.customTitleText = 'NOSTALGIA_1989.BMP',
    this.rpgDialogueText = 'A wild memory appeared! Level 99 nostalgia.',
    this.rpgSpeakerName = 'HERO',
    this.aspectRatio = PixelAspectRatio.original,
    this.compareMode = CompareViewMode.off,
    this.compareSplit = 0.5,
  });

  static const PixelArtConfig initialDefault = PixelArtConfig();

  PixelArtConfig copyWith({
    int? pixelColumns,
    PixelPaletteType? palette,
    DitherAlgorithm? ditherAlgorithm,
    double? ditherStrength,
    PixelBlockShape? blockShape,
    bool? showPixelGrid,
    bool? crtScanlines,
    double? scanlineOpacity,
    bool? crtVignette,
    int? rgbSplitColumns,
    bool? edgeOutline,
    bool? invertColors,
    double? brightness,
    double? contrast,
    double? saturation,
    PixelFrameStyle? frameStyle,
    PixelHudBadge? hudBadge,
    String? customTitleText,
    String? rpgDialogueText,
    String? rpgSpeakerName,
    PixelAspectRatio? aspectRatio,
    CompareViewMode? compareMode,
    double? compareSplit,
  }) {
    return PixelArtConfig(
      pixelColumns: pixelColumns ?? this.pixelColumns,
      palette: palette ?? this.palette,
      ditherAlgorithm: ditherAlgorithm ?? this.ditherAlgorithm,
      ditherStrength: ditherStrength ?? this.ditherStrength,
      blockShape: blockShape ?? this.blockShape,
      showPixelGrid: showPixelGrid ?? this.showPixelGrid,
      crtScanlines: crtScanlines ?? this.crtScanlines,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
      crtVignette: crtVignette ?? this.crtVignette,
      rgbSplitColumns: rgbSplitColumns ?? this.rgbSplitColumns,
      edgeOutline: edgeOutline ?? this.edgeOutline,
      invertColors: invertColors ?? this.invertColors,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      frameStyle: frameStyle ?? this.frameStyle,
      hudBadge: hudBadge ?? this.hudBadge,
      customTitleText: customTitleText ?? this.customTitleText,
      rpgDialogueText: rpgDialogueText ?? this.rpgDialogueText,
      rpgSpeakerName: rpgSpeakerName ?? this.rpgSpeakerName,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      compareMode: compareMode ?? this.compareMode,
      compareSplit: compareSplit ?? this.compareSplit,
    );
  }

  /// Curated 1-tap studio aesthetic presets.
  static final List<({String name, String subtitle, PixelArtConfig config})> studioPresets = [
    (
      name: '1989 Handheld DMG',
      subtitle: 'Olive LCD screen, Bayer 4x4 crosshatch & DMG shell',
      config: const PixelArtConfig(
        pixelColumns: 48,
        palette: PixelPaletteType.gameBoyDmg,
        ditherAlgorithm: DitherAlgorithm.bayer4x4,
        ditherStrength: 0.7,
        blockShape: PixelBlockShape.lcdMatrix,
        crtScanlines: false,
        contrast: 1.2,
        frameStyle: PixelFrameStyle.gameBoyShell,
      ),
    ),
    (
      name: 'Synthwave CRT Arcade',
      subtitle: 'Neon cyber colors, RGB split glitch & Arcade cabinet',
      config: const PixelArtConfig(
        pixelColumns: 64,
        palette: PixelPaletteType.cyberArcade,
        ditherAlgorithm: DitherAlgorithm.bayer4x4,
        ditherStrength: 0.6,
        blockShape: PixelBlockShape.ledBoard,
        crtScanlines: true,
        scanlineOpacity: 0.28,
        crtVignette: true,
        rgbSplitColumns: 1,
        saturation: 1.35,
        contrast: 1.25,
        frameStyle: PixelFrameStyle.arcadeCrt,
        hudBadge: PixelHudBadge.recLive,
      ),
    ),
    (
      name: '1-Bit Playdate Noir',
      subtitle: 'High-contrast pure Black & White Floyd-Steinberg ink',
      config: const PixelArtConfig(
        pixelColumns: 64,
        palette: PixelPaletteType.oneBitNoir,
        ditherAlgorithm: DitherAlgorithm.floydSteinberg,
        ditherStrength: 0.85,
        blockShape: PixelBlockShape.square,
        crtScanlines: false,
        contrast: 1.3,
        frameStyle: PixelFrameStyle.polaroid8Bit,
        customTitleText: 'INK & PIXEL • VOL. 1',
      ),
    ),
    (
      name: 'Paint 95 Nostalgia',
      subtitle: 'Classic PC 16-color VGA with Win95 desktop window',
      config: const PixelArtConfig(
        pixelColumns: 72,
        palette: PixelPaletteType.nesClassic,
        ditherAlgorithm: DitherAlgorithm.bayer2x2,
        ditherStrength: 0.65,
        blockShape: PixelBlockShape.square,
        crtScanlines: false,
        contrast: 1.15,
        frameStyle: PixelFrameStyle.retroWin95,
        customTitleText: 'summer_2001.bmp - Paint95',
      ),
    ),
    (
      name: '16-Bit JRPG Cutscene',
      subtitle: 'SNES pastel palette with sprite ink edges & RPG dialogue',
      config: const PixelArtConfig(
        pixelColumns: 80,
        palette: PixelPaletteType.snesPastel,
        ditherAlgorithm: DitherAlgorithm.floydSteinberg,
        ditherStrength: 0.55,
        blockShape: PixelBlockShape.square,
        crtScanlines: true,
        scanlineOpacity: 0.14,
        edgeOutline: true,
        saturation: 1.2,
        frameStyle: PixelFrameStyle.rpgDialogBox,
        hudBadge: PixelHudBadge.hpHearts,
        rpgSpeakerName: 'MEMORIES',
        rpgDialogueText: 'You found an old photograph! +50 Nostalgia.',
      ),
    ),
    (
      name: 'Pegboard Bead Art',
      subtitle: 'Chunky 36px circular dots with vibrant PICO-8 palette',
      config: const PixelArtConfig(
        pixelColumns: 36,
        palette: PixelPaletteType.pico8,
        ditherAlgorithm: DitherAlgorithm.none,
        blockShape: PixelBlockShape.pegboard,
        crtScanlines: false,
        saturation: 1.3,
        contrast: 1.15,
        frameStyle: PixelFrameStyle.cartridgeCard,
        customTitleText: 'PICO PEGBOARD EDITION',
      ),
    ),
  ];
}
