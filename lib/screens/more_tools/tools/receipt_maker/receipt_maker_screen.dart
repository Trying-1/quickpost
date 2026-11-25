import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/receipt_model.dart';
import 'services/receipt_service.dart';
import 'widgets/receipt_canvas_view.dart';

/// Aesthetic Thermal Receipt Studio ("Receiptify" Style):
/// - Generates viral cash register receipts for music playlists, daily habits, coffee runs, and year goals
/// - Watermark-screen-style integrated control tabs (Store, Items, Totals, Footer, Style, Format, Backdrop)
/// - Multiple aspect ratios: 4:5 Feed Portrait, 1:1 Square, 9:16 Story/Reels, or Receipt Only for video overlays
/// - Realistic thermal paper textures (Vintage Cream, Crisp White, Dark Thermal, Sakura Pink, Cyber Green)
/// - Authentic zigzag serrated or scalloped tear paper edges, realistic barcode, and monospace typography
/// - Uncompressed 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Receipts
class ReceiptMakerScreen extends StatefulWidget {
  const ReceiptMakerScreen({super.key});

  @override
  State<ReceiptMakerScreen> createState() => _ReceiptMakerScreenState();
}

class _ReceiptMakerScreenState extends State<ReceiptMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  ReceiptPost _post = ReceiptPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _storeNameController;
  late TextEditingController _storeSubtitleController;
  late TextEditingController _orderNumberController;
  late TextEditingController _cashierController;
  late TextEditingController _dateTimeController;
  late TextEditingController _itemCountLabelController;
  late TextEditingController _itemCountValController;
  late TextEditingController _totalLabelController;
  late TextEditingController _totalValController;
  late TextEditingController _cardInfoController;
  late TextEditingController _authCodeController;
  late TextEditingController _footerQuoteController;
  late TextEditingController _footerSubController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Receiptify Studio');
    _storeNameController = TextEditingController(text: _post.storeName);
    _storeSubtitleController = TextEditingController(text: _post.storeSubtitle);
    _orderNumberController = TextEditingController(text: _post.orderNumber);
    _cashierController = TextEditingController(text: _post.cashierName);
    _dateTimeController = TextEditingController(text: _post.dateTimeStr);
    _itemCountLabelController = TextEditingController(text: _post.itemCountLabel);
    _itemCountValController = TextEditingController(text: _post.itemCountValue);
    _totalLabelController = TextEditingController(text: _post.totalLabel);
    _totalValController = TextEditingController(text: _post.totalValue);
    _cardInfoController = TextEditingController(text: _post.cardInfo);
    _authCodeController = TextEditingController(text: _post.authCode);
    _footerQuoteController = TextEditingController(text: _post.footerQuote);
    _footerSubController = TextEditingController(text: _post.footerSub);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeSubtitleController.dispose();
    _orderNumberController.dispose();
    _cashierController.dispose();
    _dateTimeController.dispose();
    _itemCountLabelController.dispose();
    _itemCountValController.dispose();
    _totalLabelController.dispose();
    _totalValController.dispose();
    _cardInfoController.dispose();
    _authCodeController.dispose();
    _footerQuoteController.dispose();
    _footerSubController.dispose();
    super.dispose();
  }

  void _syncControllersFromPost(ReceiptPost post) {
    _storeNameController.text = post.storeName;
    _storeSubtitleController.text = post.storeSubtitle;
    _orderNumberController.text = post.orderNumber;
    _cashierController.text = post.cashierName;
    _dateTimeController.text = post.dateTimeStr;
    _itemCountLabelController.text = post.itemCountLabel;
    _itemCountValController.text = post.itemCountValue;
    _totalLabelController.text = post.totalLabel;
    _totalValController.text = post.totalValue;
    _cardInfoController.text = post.cardInfo;
    _authCodeController.text = post.authCode;
    _footerQuoteController.text = post.footerQuote;
    _footerSubController.text = post.footerSub;
  }

  void _addItem() {
    if (_post.items.length >= 10) return;
    HapticFeedback.selectionClick();
    final count = _post.items.length + 1;
    final newItem = ReceiptItem(
      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
      qty: count < 10 ? '0$count' : '$count',
      title: 'NEW TRACK / HABIT #$count',
      amount: '03:30',
    );
    setState(() {
      final updated = [..._post.items, newItem];
      _post = _post.copyWith(
        items: updated,
        itemCountValue: updated.length < 10 ? '0${updated.length}' : '${updated.length}',
      );
      _itemCountValController.text = _post.itemCountValue;
    });
  }

  void _removeItem(int index) {
    if (_post.items.length <= 1) return;
    HapticFeedback.selectionClick();
    final updated = List<ReceiptItem>.from(_post.items);
    updated.removeAt(index);
    setState(() {
      _post = _post.copyWith(
        items: updated,
        itemCountValue: updated.length < 10 ? '0${updated.length}' : '${updated.length}',
      );
      _itemCountValController.text = _post.itemCountValue;
    });
  }

  void _updateItem(int index, {String? qty, String? title, String? amount}) {
    if (index >= _post.items.length) return;
    final updated = List<ReceiptItem>.from(_post.items);
    updated[index] = updated[index].copyWith(qty: qty, title: title, amount: amount);
    setState(() => _post = _post.copyWith(items: updated));
  }

  Future<void> _pickWallpaper() async {
    final file = await ReceiptService().pickImage();
    if (file != null && mounted) {
      setState(() => _post = _post.copyWith(customWallpaperPath: file.path));
    }
  }

  Future<void> _exportReceipt() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await ReceiptService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await ReceiptService().saveReceiptToGallery(
        pngBytes,
        _post.storeName.isNotEmpty ? _post.storeName : 'Receiptify',
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _lastSavedPath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primarySurface, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thermal receipt saved to Gallery! (Pictures/Quick Post Receipts)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting receipt: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await ReceiptService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await ReceiptService().saveReceiptToGallery(
          pngBytes,
          _post.storeName.isNotEmpty ? _post.storeName : 'Receiptify',
        );
      }
    }

    if (_lastSavedPath != null) {
      await ReceiptService().shareReceipt(_lastSavedPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thermal Receipt Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<ReceiptPost>(
            tooltip: 'Load Viral Receipt Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _post = template;
                _syncControllersFromPost(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL RECEIPT PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...ReceiptPost.viralPresets.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: preset.paperTheme.paperBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preset.storeName,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Center Interactive Canvas ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: ReceiptCanvasView(
                      post: _post,
                      onEditRequested: () {
                        setState(() {
                          _selectedTabIndex = 1;
                          _isTabContentExpanded = true;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Watermark-style Active Tab Content Panel ───
          if (_isTabContentExpanded) _buildActiveTabContent(),

          // ─── Watermark-style Horizontal Control Tabs Bar ───
          _buildControlTabsBar(),

          // ─── Bottom Sticky Action Dock (Reset, Share, Export) ───
          _buildBottomActionDock(),
        ],
      ),
    );
  }

  // ─── Horizontal Control Tabs Bar ───
  Widget _buildControlTabsBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _buildTabItem(0, Icons.storefront_rounded, 'Store', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.format_list_numbered_rounded, 'Items', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.calculate_rounded, 'Totals', const Color(0xFFF59E0B)),
          _buildTabItem(3, Icons.qr_code_scanner_rounded, 'Footer', const Color(0xFF8B5CF6)),
          _buildTabItem(4, Icons.palette_rounded, 'Style', const Color(0xFFF97316)),
          _buildTabItem(5, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(6, Icons.wallpaper_rounded, 'Backdrop', const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_selectedTabIndex == index) {
            _isTabContentExpanded = !_isTabContentExpanded;
          } else {
            _selectedTabIndex = index;
            _isTabContentExpanded = true;
          }
        });
      },
      child: Container(
        width: 74,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Tab Content Container ───
  Widget _buildActiveTabContent() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildStoreTab();
      case 1:
        return _buildItemsTab();
      case 2:
        return _buildTotalsTab();
      case 3:
        return _buildFooterTab();
      case 4:
        return _buildStyleTab();
      case 5:
        return _buildFormatTab();
      case 6:
        return _buildBackdropTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Store Header ───
  Widget _buildStoreTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'Store / Brand Title',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(storeName: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _orderNumberController,
                decoration: InputDecoration(
                  labelText: 'Order # Label',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(orderNumber: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _storeSubtitleController,
          decoration: InputDecoration(
            labelText: 'Subtitle / Rotation Info',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(storeSubtitle: val)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cashierController,
                decoration: InputDecoration(
                  labelText: 'Cashier / Server Name',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(cashierName: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _dateTimeController,
                decoration: InputDecoration(
                  labelText: 'Date & Time String',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(dateTimeStr: val)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 1: Itemized Lines ───
  Widget _buildItemsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Receipt Items (${_post.items.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            if (_post.items.length < 10)
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Line', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: _addItem,
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(_post.items.length, (i) {
          final item = _post.items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: TextFormField(
                    initialValue: item.qty,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      labelStyle: const TextStyle(fontSize: 9),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    onChanged: (val) => _updateItem(i, qty: val),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    initialValue: item.title,
                    decoration: InputDecoration(
                      labelText: 'Item / Track Title',
                      labelStyle: const TextStyle(fontSize: 9),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                    onChanged: (val) => _updateItem(i, title: val),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 62,
                  child: TextFormField(
                    initialValue: item.amount,
                    decoration: InputDecoration(
                      labelText: 'Amt / Time',
                      labelStyle: const TextStyle(fontSize: 9),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    onChanged: (val) => _updateItem(i, amount: val),
                  ),
                ),
                if (_post.items.length > 1) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    onPressed: () => _removeItem(i),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── Tab 2: Totals & Payments ───
  Widget _buildTotalsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _itemCountLabelController,
                decoration: InputDecoration(
                  labelText: 'Item Count Label',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(itemCountLabel: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _itemCountValController,
                decoration: InputDecoration(
                  labelText: 'Count Value',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(itemCountValue: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _totalLabelController,
                decoration: InputDecoration(
                  labelText: 'Total Label (e.g. TOTAL:)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(totalLabel: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _totalValController,
                decoration: InputDecoration(
                  labelText: 'Total Value (e.g. 18:42, \$15.25)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(totalValue: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardInfoController,
                decoration: InputDecoration(
                  labelText: 'Card / Payment Info',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                onChanged: (val) => setState(() => _post = _post.copyWith(cardInfo: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _authCodeController,
                decoration: InputDecoration(
                  labelText: 'Auth Code / Status',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
                onChanged: (val) => setState(() => _post = _post.copyWith(authCode: val)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 3: Footer & Barcode ───
  Widget _buildFooterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Thermal Barcode', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.showBarcode,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showBarcode: val)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _footerQuoteController,
          decoration: InputDecoration(
            labelText: 'Footer Quote / Note',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(footerQuote: val)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _footerSubController,
          decoration: InputDecoration(
            labelText: 'Brand / Social Subtext',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(footerSub: val)),
        ),
      ],
    );
  }

  // ─── Tab 4: Paper Theme & Edge Style ───
  Widget _buildStyleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THERMAL PAPER THEME',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: ReceiptPaperTheme.values.map((theme) {
            final isSelected = _post.paperTheme == theme;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(paperTheme: theme));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.paperBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : theme.accentBorder,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: theme.inkPrimary, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.inkPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'PAPER EDGE TEAR STYLE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Row(
          children: ReceiptEdgeStyle.values.map((edge) {
            final isSelected = _post.edgeStyle == edge;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  avatar: Icon(edge.icon, size: 14, color: isSelected ? AppColors.primary : Colors.grey.shade700),
                  label: Text(edge.label, style: const TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
                  selected: isSelected,
                  selectedColor: AppColors.primarySurface,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _post = _post.copyWith(edgeStyle: edge));
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 5: Canvas Aspect Ratio ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANVAS ASPECT RATIO',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ReceiptRatio.values.map((ratio) {
            final isSelected = _post.ratio == ratio;
            return ChoiceChip(
              avatar: Icon(ratio.icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey.shade700),
              label: Text(ratio.label, style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _post = _post.copyWith(ratio: ratio));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Transparent PNG (Video Overlay)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.transparentBg,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(transparentBg: val)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 6: Backdrop & Wallpaper ───
  Widget _buildBackdropTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GRADIENT BACKDROP PRESETS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ReceiptBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = ReceiptBackdropPreset.presets[index];
              final isSelected = _post.backdropIndex == index && _post.customWallpaperPath == null;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _post = _post.copyWith(backdropIndex: index, clearWallpaper: true);
                  });
                },
                child: Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: preset.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wallpaper_rounded, size: 18),
                label: Text(
                  _post.customWallpaperPath != null ? 'Change Custom Wallpaper' : 'Custom Photo Backdrop',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickWallpaper,
              ),
            ),
            if (_post.customWallpaperPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.red),
                tooltip: 'Clear wallpaper',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(clearWallpaper: true));
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Bottom Sticky Action Dock ───
  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Reset Button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: 'Reset to default',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _post = ReceiptPost.initialDefault;
                  _syncControllersFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share receipt',
              onPressed: _isSaving ? null : _shareReceipt,
            ),

            const SizedBox(width: 8),

            // Export to Gallery Button
            Expanded(
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Exporting...' : 'Save to Gallery',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _exportReceipt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
