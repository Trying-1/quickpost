import 'dart:io';
import 'package:flutter/material.dart';
import '../models/receipt_model.dart';

/// Pixel-perfect Thermal Paper Receipt Canvas with zero-overflow proportional containment.
/// Generates viral "Receiptify" style cash register receipts with authentic zigzag edges,
/// thermal typography, itemized tracks/habits, barcode, and high-contrast backdrops.
class ReceiptCanvasView extends StatelessWidget {
  final ReceiptPost post;
  final VoidCallback? onEditRequested;

  const ReceiptCanvasView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStory = post.ratio == ReceiptRatio.story9x16;
    final bool isSquare = post.ratio == ReceiptRatio.square1x1;
    const double refWidth = 380.0;

    if (post.ratio == ReceiptRatio.receiptOnly) {
      return GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(
            color: post.transparentBg ? Colors.transparent : post.paperTheme.paperBg,
            borderRadius: BorderRadius.circular(post.edgeStyle == ReceiptEdgeStyle.clean ? 16 : 0),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: refWidth,
              child: _buildClippedReceipt(isStandalone: true),
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
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Backdrop (Gradient or Custom Wallpaper)
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

              // 3. Proportional Centered Floating Thermal Receipt (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 28 : (isSquare ? 16 : 22),
                    vertical: isStory ? 28 : (isSquare ? 12 : 18),
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      child: _buildClippedReceipt(isStandalone: false),
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

  // ─── Clipped Receipt with Jagged / Perforated / Clean Edges ───
  Widget _buildClippedReceipt({required bool isStandalone}) {
    final theme = post.paperTheme;

    Widget receiptContent = Container(
      color: theme.paperBg,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Header Title
          Text(
            post.storeName.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.inkPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),

          // Subtitle / Rotation info
          if (post.storeSubtitle.isNotEmpty) ...[
            Text(
              post.storeSubtitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.inkSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Double Dashed Divider
          _buildDashedLine('=', theme.inkSecondary),
          const SizedBox(height: 4),

          // Order #, Cashier, Date Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                post.orderNumber.toUpperCase(),
                style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              Text(
                post.cashierName.toUpperCase(),
                style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            post.dateTimeStr.toUpperCase(),
            style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),

          // Divider
          _buildDashedLine('-', theme.inkSecondary),
          const SizedBox(height: 6),

          // Items Table Header
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('QTY', style: TextStyle(color: theme.inkPrimary, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ),
              Expanded(
                child: Text('DESCRIPTION', style: TextStyle(color: theme.inkPrimary, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ),
              Text('AMT', style: TextStyle(color: theme.inkPrimary, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          _buildDashedLine('-', theme.inkSecondary),
          const SizedBox(height: 6),

          // Itemized Lines
          ...post.items.map((item) => _buildItemRow(item, theme)),

          const SizedBox(height: 6),
          _buildDashedLine('-', theme.inkSecondary),
          const SizedBox(height: 6),

          // Item Count & Total Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(post.itemCountLabel, style: TextStyle(color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              Text(post.itemCountValue, style: TextStyle(color: theme.inkPrimary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                post.totalLabel,
                style: TextStyle(color: theme.inkPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontFamily: 'monospace'),
              ),
              Text(
                post.totalValue,
                style: TextStyle(color: theme.inkPrimary, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontFamily: 'monospace'),
              ),
            ],
          ),

          const SizedBox(height: 8),
          _buildDashedLine('=', theme.inkSecondary),
          const SizedBox(height: 6),

          // Card info & Auth
          Text(
            post.cardInfo.toUpperCase(),
            style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Text(
            post.authCode.toUpperCase(),
            style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, fontFamily: 'monospace'),
          ),

          const SizedBox(height: 12),

          // Barcode Section
          if (post.showBarcode) ...[
            _buildBarcode(theme),
            const SizedBox(height: 10),
          ],

          // Footer Quote & Brand Subtext
          if (post.footerQuote.isNotEmpty) ...[
            Text(
              post.footerQuote.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.inkPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (post.footerSub.isNotEmpty) ...[
            Text(
              post.footerSub.toLowerCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.inkSecondary,
                fontSize: 9.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );

    // Apply Edge Clipper
    CustomClipper<Path>? clipper;
    if (post.edgeStyle == ReceiptEdgeStyle.zigzag) {
      clipper = _ZigzagReceiptClipper();
    } else if (post.edgeStyle == ReceiptEdgeStyle.perforated) {
      clipper = _PerforatedReceiptClipper();
    }

    Widget styledPaper = clipper != null
        ? ClipPath(clipper: clipper, child: receiptContent)
        : ClipRRect(borderRadius: BorderRadius.circular(12), child: receiptContent);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isStandalone ? 0.25 : 0.45),
            blurRadius: isStandalone ? 16 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: styledPaper,
    );
  }

  // ─── Item Row ───
  Widget _buildItemRow(ReceiptItem item, ReceiptPaperTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              item.qty,
              style: TextStyle(color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
          Expanded(
            child: Text(
              item.title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.inkPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.amount,
            style: TextStyle(color: theme.inkPrimary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // ─── Dashed Line Generator ───
  Widget _buildDashedLine(String char, Color color) {
    return Text(
      char * 44,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11, letterSpacing: -0.5, fontFamily: 'monospace'),
    );
  }

  // ─── Realistic Thermal Barcode ───
  Widget _buildBarcode(ReceiptPaperTheme theme) {
    const barPattern = [
      3, 1, 2, 4, 1, 3, 2, 1, 2, 4, 1, 2, 3, 1, 4, 2, 1, 3, 1, 2, 4, 1, 3, 2,
      1, 4, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 4, 1, 3, 2, 1, 4, 2, 1, 3, 1, 2,
    ];

    return Column(
      children: [
        SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(barPattern.length, (i) {
              final isBar = i % 2 == 0;
              final width = barPattern[i].toDouble() * 1.35;
              return Container(
                width: width,
                color: isBar ? theme.inkPrimary : Colors.transparent,
              );
            }),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '9 780201 379624',
          style: TextStyle(color: theme.inkSecondary, fontSize: 9.5, letterSpacing: 3.0, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

/// Triangular zigzag serrated paper tear clipper for top and bottom receipt edges.
class _ZigzagReceiptClipper extends CustomClipper<Path> {
  final double toothWidth = 8.0;
  final double toothHeight = 5.0;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, toothHeight);

    // Top Zigzag
    double x = 0;
    while (x < size.width) {
      path.lineTo(x + toothWidth / 2, 0);
      path.lineTo(x + toothWidth, toothHeight);
      x += toothWidth;
    }

    // Right Edge
    path.lineTo(size.width, size.height - toothHeight);

    // Bottom Zigzag
    x = size.width;
    while (x > 0) {
      path.lineTo(x - toothWidth / 2, size.height);
      path.lineTo(x - toothWidth, size.height - toothHeight);
      x -= toothWidth;
    }

    // Left Edge
    path.lineTo(0, toothHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Scalloped perforated tear paper clipper.
class _PerforatedReceiptClipper extends CustomClipper<Path> {
  final double scallopWidth = 12.0;
  final double scallopHeight = 4.0;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, scallopHeight);

    // Top scalloped curve
    double x = 0;
    while (x < size.width) {
      path.quadraticBezierTo(x + scallopWidth / 2, 0, x + scallopWidth, scallopHeight);
      x += scallopWidth;
    }

    // Right Edge
    path.lineTo(size.width, size.height - scallopHeight);

    // Bottom scalloped curve
    x = size.width;
    while (x > 0) {
      path.quadraticBezierTo(x - scallopWidth / 2, size.height, x - scallopWidth, size.height - scallopHeight);
      x -= scallopWidth;
    }

    path.lineTo(0, scallopHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
