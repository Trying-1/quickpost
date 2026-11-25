import 'package:flutter/material.dart';

/// Canvas aspect ratio choices for the Thermal Receipt graphic.
enum ReceiptRatio {
  portrait4x5(
    id: '4:5',
    label: '4:5 Feed Portrait',
    ratio: 4 / 5,
    icon: Icons.portrait_rounded,
  ),
  square1x1(
    id: '1:1',
    label: '1:1 Square Feed',
    ratio: 1.0,
    icon: Icons.crop_square_rounded,
  ),
  story9x16(
    id: '9:16',
    label: '9:16 Story / Reels',
    ratio: 9 / 16,
    icon: Icons.stay_current_portrait_rounded,
  ),
  receiptOnly(
    id: 'Receipt',
    label: 'Receipt Only (Overlay)',
    ratio: 0.0,
    icon: Icons.receipt_long_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const ReceiptRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Paper color and thermal ink themes.
enum ReceiptPaperTheme {
  classicCream(
    name: 'Vintage Cream',
    paperBg: Color(0xFFFDFBF5),
    inkPrimary: Color(0xFF1E1E1E),
    inkSecondary: Color(0xFF57534E),
    accentBorder: Color(0xFFE7E5E4),
  ),
  crispWhite(
    name: 'Crisp White',
    paperBg: Color(0xFFFFFFFF),
    inkPrimary: Color(0xFF0F172A),
    inkSecondary: Color(0xFF475569),
    accentBorder: Color(0xFFE2E8F0),
  ),
  moodyDark(
    name: 'Dark Thermal',
    paperBg: Color(0xFF18181B),
    inkPrimary: Color(0xFFF4F4F5),
    inkSecondary: Color(0xFFA1A1AA),
    accentBorder: Color(0xFF27272A),
  ),
  sakuraPink(
    name: 'Sakura Pink',
    paperBg: Color(0xFFFFF0F5),
    inkPrimary: Color(0xFF4A044E),
    inkSecondary: Color(0xFF86198F),
    accentBorder: Color(0xFFFBCFE8),
  ),
  cyberTerminal(
    name: 'Cyber Green',
    paperBg: Color(0xFF090D16),
    inkPrimary: Color(0xFF4ADE80),
    inkSecondary: Color(0xFF22C55E),
    accentBorder: Color(0xFF14532D),
  );

  final String name;
  final Color paperBg;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color accentBorder;

  const ReceiptPaperTheme({
    required this.name,
    required this.paperBg,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.accentBorder,
  });
}

/// Top & bottom cut paper edge styles.
enum ReceiptEdgeStyle {
  zigzag(label: 'Zigzag Tear', icon: Icons.cut_rounded),
  perforated(label: 'Scallop Edge', icon: Icons.waves_rounded),
  clean(label: 'Clean Cut', icon: Icons.crop_7_5_rounded);

  final String label;
  final IconData icon;

  const ReceiptEdgeStyle({required this.label, required this.icon});
}

/// Curated background backdrop presets behind the thermal paper.
class ReceiptBackdropPreset {
  final String name;
  final List<Color> colors;

  const ReceiptBackdropPreset({required this.name, required this.colors});

  static const List<ReceiptBackdropPreset> presets = [
    ReceiptBackdropPreset(
      name: 'Moody Slate',
      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    ),
    ReceiptBackdropPreset(
      name: 'Warm Espresso',
      colors: [Color(0xFF271B15), Color(0xFF432F25)],
    ),
    ReceiptBackdropPreset(
      name: 'Midnight Violet',
      colors: [Color(0xFF1A0B2E), Color(0xFF3B136B)],
    ),
    ReceiptBackdropPreset(
      name: 'Forest Moss',
      colors: [Color(0xFF062019), Color(0xFF0D4033)],
    ),
    ReceiptBackdropPreset(
      name: 'Soft Stone',
      colors: [Color(0xFFD6D3D1), Color(0xFFE7E5E4)],
    ),
    ReceiptBackdropPreset(
      name: 'Charcoal',
      colors: [Color(0xFF111111), Color(0xFF1C1C1C)],
    ),
  ];
}

/// A single itemized line row on the thermal receipt.
class ReceiptItem {
  final String id;
  final String qty;
  final String title;
  final String amount;

  const ReceiptItem({
    required this.id,
    required this.qty,
    required this.title,
    required this.amount,
  });

  ReceiptItem copyWith({
    String? id,
    String? qty,
    String? title,
    String? amount,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      qty: qty ?? this.qty,
      title: title ?? this.title,
      amount: amount ?? this.amount,
    );
  }
}

/// Core configuration model for the Thermal Receipt Studio.
class ReceiptPost {
  final String storeName;
  final String storeSubtitle;
  final String orderNumber;
  final String cashierName;
  final String dateTimeStr;
  final List<ReceiptItem> items;
  final String itemCountLabel;
  final String itemCountValue;
  final String totalLabel;
  final String totalValue;
  final String cardInfo;
  final String authCode;
  final String footerQuote;
  final String footerSub;
  final bool showBarcode;
  final ReceiptPaperTheme paperTheme;
  final ReceiptEdgeStyle edgeStyle;
  final ReceiptRatio ratio;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool transparentBg;

  const ReceiptPost({
    this.storeName = 'RECEIPTIFY',
    this.storeSubtitle = 'LAST MONTH • TOP TRACKS',
    this.orderNumber = 'ORDER #0042 FOR QUICKPOST',
    this.cashierName = 'SERVER: STUDIO AI',
    this.dateTimeStr = 'TUE NOV 10, 2026  11:15 AM',
    required this.items,
    this.itemCountLabel = 'ITEM COUNT:',
    this.itemCountValue = '05',
    this.totalLabel = 'TOTAL:',
    this.totalValue = '18:42',
    this.cardInfo = 'CARD #: **** **** **** 2026',
    this.authCode = 'AUTH CODE: 849201',
    this.footerQuote = 'THANK YOU FOR VISITING!',
    this.footerSub = '@quickpost.studio',
    this.showBarcode = true,
    this.paperTheme = ReceiptPaperTheme.classicCream,
    this.edgeStyle = ReceiptEdgeStyle.zigzag,
    this.ratio = ReceiptRatio.portrait4x5,
    this.backdropIndex = 0,
    this.customWallpaperPath,
    this.transparentBg = false,
  });

  ReceiptBackdropPreset get backdrop =>
      ReceiptBackdropPreset.presets[backdropIndex.clamp(0, ReceiptBackdropPreset.presets.length - 1)];

  ReceiptPost copyWith({
    String? storeName,
    String? storeSubtitle,
    String? orderNumber,
    String? cashierName,
    String? dateTimeStr,
    List<ReceiptItem>? items,
    String? itemCountLabel,
    String? itemCountValue,
    String? totalLabel,
    String? totalValue,
    String? cardInfo,
    String? authCode,
    String? footerQuote,
    String? footerSub,
    bool? showBarcode,
    ReceiptPaperTheme? paperTheme,
    ReceiptEdgeStyle? edgeStyle,
    ReceiptRatio? ratio,
    int? backdropIndex,
    String? customWallpaperPath,
    bool? transparentBg,
    bool clearWallpaper = false,
  }) {
    return ReceiptPost(
      storeName: storeName ?? this.storeName,
      storeSubtitle: storeSubtitle ?? this.storeSubtitle,
      orderNumber: orderNumber ?? this.orderNumber,
      cashierName: cashierName ?? this.cashierName,
      dateTimeStr: dateTimeStr ?? this.dateTimeStr,
      items: items ?? List.from(this.items),
      itemCountLabel: itemCountLabel ?? this.itemCountLabel,
      itemCountValue: itemCountValue ?? this.itemCountValue,
      totalLabel: totalLabel ?? this.totalLabel,
      totalValue: totalValue ?? this.totalValue,
      cardInfo: cardInfo ?? this.cardInfo,
      authCode: authCode ?? this.authCode,
      footerQuote: footerQuote ?? this.footerQuote,
      footerSub: footerSub ?? this.footerSub,
      showBarcode: showBarcode ?? this.showBarcode,
      paperTheme: paperTheme ?? this.paperTheme,
      edgeStyle: edgeStyle ?? this.edgeStyle,
      ratio: ratio ?? this.ratio,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      transparentBg: transparentBg ?? this.transparentBg,
    );
  }

  static ReceiptPost get initialDefault => const ReceiptPost(
        items: [
          ReceiptItem(id: 'r1', qty: '01', title: 'MIDNIGHT CITY - M83', amount: '04:03'),
          ReceiptItem(id: 'r2', qty: '02', title: 'STARBOY - THE WEEKND', amount: '03:50'),
          ReceiptItem(id: 'r3', qty: '03', title: 'GOLDEN HOUR - JVKE', amount: '03:29'),
          ReceiptItem(id: 'r4', qty: '04', title: 'SWEATER WEATHER - NBHD', amount: '04:00'),
          ReceiptItem(id: 'r5', qty: '05', title: 'NIGHT CHANGES - 1D', amount: '03:46'),
        ],
      );

  static List<ReceiptPost> get viralPresets => [
        // 1. Receiptify Heavy Rotation
        initialDefault,

        // 2. Daily Habits Audit
        const ReceiptPost(
          storeName: 'HABIT RECEIPT',
          storeSubtitle: 'MORNING ROUTINE AUDIT',
          orderNumber: 'STREAK #45 • DISCIPLINE LAB',
          cashierName: 'MINDSET: UNSTOPPABLE',
          dateTimeStr: 'NOV 10, 2026  06:30 AM',
          items: [
            ReceiptItem(id: 'h1', qty: '1x', title: '05:30 AM WAKE UP', amount: 'DONE'),
            ReceiptItem(id: 'h2', qty: '1x', title: 'COLD SHOWER & HYDRATE', amount: 'DONE'),
            ReceiptItem(id: 'h3', qty: '45m', title: 'HEAVY GYM WORKOUT', amount: '100%'),
            ReceiptItem(id: 'h4', qty: '2h', title: 'DEEP UNBROKEN FOCUS', amount: '100%'),
            ReceiptItem(id: 'h5', qty: '20p', title: 'NON-FICTION READING', amount: 'DONE'),
          ],
          itemCountLabel: 'HABITS COMPLETED:',
          itemCountValue: '05/05',
          totalLabel: 'DAILY SCORE:',
          totalValue: '100%',
          cardInfo: 'PAID WITH: PURE DISCIPLINE',
          authCode: 'STREAK VERIFIED ✓',
          footerQuote: 'CONSISTENCY COMPOUNDS DAILY.',
          footerSub: '@daily.discipline',
          paperTheme: ReceiptPaperTheme.crispWhite,
          backdropIndex: 3,
        ),

        // 3. Aesthetic Coffee Run
        const ReceiptPost(
          storeName: 'CAFÉ LUNA',
          storeSubtitle: 'SUNDAY MORNING RITUAL',
          orderNumber: 'TABLE #07 • BARISTA: MAYA',
          cashierName: 'ROAST: SINGLE ORIGIN',
          dateTimeStr: 'SUN NOV 08, 2026  09:15 AM',
          items: [
            ReceiptItem(id: 'c1', qty: '1x', title: 'ICED OAT MATCHA LATTE', amount: '\$6.50'),
            ReceiptItem(id: 'c2', qty: '1x', title: 'ALMOND BUTTER CROISSANT', amount: '\$5.25'),
            ReceiptItem(id: 'c3', qty: '1x', title: 'ESPRESSO SHOT (DOUBLE)', amount: '\$3.50'),
            ReceiptItem(id: 'c4', qty: '2h', title: 'SUNLIT WINDOW READING', amount: 'FREE'),
          ],
          itemCountLabel: 'ITEMS:',
          itemCountValue: '04',
          totalLabel: 'TOTAL:',
          totalValue: '\$15.25',
          cardInfo: 'APPLE PAY •••• 9182',
          authCode: 'THANK YOU FOR BEING KIND',
          footerQuote: 'GOOD VIBES & WARM PASTRIES',
          footerSub: '@cafeluna.aesthetic',
          paperTheme: ReceiptPaperTheme.sakuraPink,
          backdropIndex: 1,
        ),

        // 4. 2026 Bucket List / Year Goals
        const ReceiptPost(
          storeName: '2026 CHECKOUT',
          storeSubtitle: 'YEAR IN REVIEW • CHAPTER 11',
          orderNumber: 'RECEIPT #2026-Q4',
          cashierName: 'CHAPTER: GROWTH',
          dateTimeStr: 'NOV 10, 2026  11:59 PM',
          items: [
            ReceiptItem(id: 'y1', qty: '✓', title: 'BUILT MY PASSION PROJECT', amount: 'PRICELESS'),
            ReceiptItem(id: 'y2', qty: '✓', title: 'PRIORITIZED MENTAL HEALTH', amount: '100%'),
            ReceiptItem(id: 'y3', qty: '✓', title: 'SOLO TRIP TO NEW CITY', amount: 'UNLOCKED'),
            ReceiptItem(id: 'y4', qty: '✓', title: 'CUT TOXIC HABITS OUT', amount: '-\$0.00'),
          ],
          itemCountLabel: 'MILESTONES:',
          itemCountValue: '04',
          totalLabel: 'NET GAIN:',
          totalValue: 'PEACE',
          cardInfo: 'PAYMENT: HARD WORK & PATIENCE',
          authCode: 'NO REFUNDS • KEEP GOING',
          footerQuote: 'BEST YEAR YET.',
          footerSub: '@year2026.journal',
          paperTheme: ReceiptPaperTheme.moodyDark,
          backdropIndex: 2,
        ),
      ];
}
