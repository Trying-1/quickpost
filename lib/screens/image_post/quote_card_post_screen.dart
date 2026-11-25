import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/instagram_quote_template.dart';
import '../../services/analytics_service.dart';
import '../../utils/font_selector.dart';
import 'quote_card/models/quote_card_config.dart';
import 'quote_card/services/quote_card_bulk_service.dart';
import 'quote_card/services/quote_card_export_service.dart';
import 'quote_card/services/quote_card_template_dialog_service.dart';
import 'quote_card/widgets/quote_card_preview_canvas.dart';
import 'quote_card/widgets/quote_card_shared_controls.dart';
import 'quote_card/widgets/tabs/quote_card_content_tabs.dart';
import 'quote_card/widgets/tabs/quote_card_style_tabs.dart';

/// Unified editor screen for Quote Card posts (full profile card or `@handle` only).
class QuoteCardPostScreen extends StatefulWidget {
  final bool handleOnly;

  const QuoteCardPostScreen({
    super.key,
    this.handleOnly = false,
  });

  @override
  State<QuoteCardPostScreen> createState() => _QuoteCardPostScreenState();
}

class _QuoteCardPostScreenState extends State<QuoteCardPostScreen> {
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final GlobalKey _previewKey = GlobalKey();

  FontInfo? _quoteFont;
  FontInfo? _authorFont;
  FontInfo? _displayNameFont;
  FontInfo? _handleFont;
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;
  Color _authorColor = Colors.black87;
  Color _displayNameColor = Colors.black87;
  Color _usernameColor = Colors.black54;

  bool _enableQuoteShadow = true;
  bool _enableAuthorShadow = false;
  bool _enableQuoteGlow = false;
  bool _enableAuthorGlow = false;
  Color _quoteShadowColor = Colors.black87;
  Color _authorShadowColor = Colors.black54;
  Color _quoteGlowColor = Colors.white70;
  Color _authorGlowColor = Colors.white70;
  double _quoteGlowRadius = 12.0;
  double _authorGlowRadius = 10.0;
  double _quoteShadowOffsetX = 1.0;
  double _quoteShadowOffsetY = 1.0;
  double _quoteShadowBlur = 3.0;
  double _authorShadowOffsetX = 1.0;
  double _authorShadowOffsetY = 1.0;
  double _authorShadowBlur = 3.0;
  double _letterSpacing = 0.0;
  double _fontSize = 0.5;
  double _lineHeight = 1.3;

  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = false;
  late bool _handleOnly;
  bool _isBulkMode = false;
  List<Map<String, String>> _bulkQuotes = [];
  int _currentBulkIndex = 0;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = const Alignment(0.0, 0.2);
  Alignment _identityPosition = const Alignment(0.0, -0.4);

  File? _profileImage;
  File? _backgroundImage;
  BoxFit _backgroundFit = BoxFit.cover;
  Offset _backgroundOffset = Offset.zero;
  double _backgroundScale = 1.0;
  double _backgroundBlur = 0.0;
  double _backgroundBrightness = 1.0;
  double _backgroundSaturation = 1.0;

  // 0: 4:5, 1: 1:1, 2: 9:16, 3: 16:9
  int _selectedAspectIndex = 1;

  static const _tabs = <Map<String, Object>>[
    {'icon': Icons.format_quote, 'label': 'Text', 'color': Colors.teal},
    {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.green},
    {
      'icon': Icons.format_color_text,
      'label': 'Colors',
      'color': Colors.deepOrange,
    },
    {'icon': Icons.auto_awesome, 'label': 'Effects', 'color': Colors.purple},
    {'icon': Icons.format_size, 'label': 'Spacing', 'color': Colors.indigo},
    {
      'icon': Icons.format_align_center,
      'label': 'Align',
      'color': Colors.blueGrey,
    },
    {'icon': Icons.open_with, 'label': 'Quote Pos', 'color': Colors.brown},
    {
      'icon': Icons.account_circle,
      'label': 'Identity Pos',
      'color': Colors.pink,
    },
    {'icon': Icons.wallpaper, 'label': 'BG Options', 'color': Colors.blue},
  ];

  double get _currentAspectRatio =>
      quoteCardAspectForIndex(_selectedAspectIndex).aspectRatio;

  @override
  void initState() {
    super.initState();
    _handleOnly = widget.handleOnly;
    final defaultFont = defaultQuoteCardFont();
    _quoteFont = defaultFont;
    _authorFont = defaultFont;
    _displayNameFont = defaultFont;
    _handleFont = defaultFont;

    _quoteController.text =
        'Its not about if I can, I am doing thing because I wanted to';
    _authorController.text = 'Monkey D. Luffy';
    AnalyticsService().setCurrentScreen(
      screenName: _handleOnly
          ? 'Quote Card Handle Post'
          : 'Quote Card Post',
    );
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _authorController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard current design?'),
            content: const Text(
              'If you go back now, your current quote card design will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() {
        _backgroundImage = File(picked.path);
      });
      AnalyticsService().logEvent(name: 'background_image_picked');
    } catch (_) {}
  }

  void _removeBackgroundImage() {
    setState(() {
      _backgroundImage = null;
      _backgroundOffset = Offset.zero;
      _backgroundScale = 1.0;
      _backgroundBlur = 0.0;
      _backgroundBrightness = 1.0;
      _backgroundSaturation = 1.0;
    });
  }

  Future<void> _pickProfileImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      setState(() => _profileImage = File(file.path));
    }
  }

  Future<void> _importFromMyQuotes() async {
    final selected = await QuoteCardBulkService.importFromMyQuotes(context);
    if (selected != null && mounted) {
      setState(() {
        _quoteController.text = selected.text;
        _authorController.text = selected.author;
      });
    }
  }

  Future<void> _importBulkFromMyQuotes() async {
    final loaded = await QuoteCardBulkService.importBulkFromMyQuotes(context);
    if (loaded.isNotEmpty && mounted) {
      setState(() {
        _bulkQuotes.addAll(loaded);
        _currentBulkIndex = 0;
      });
    }
  }

  Future<void> _importCsv() async {
    final loaded = await QuoteCardBulkService.importCsv(context);
    if (loaded.isNotEmpty && mounted) {
      setState(() {
        _bulkQuotes = loaded;
        _currentBulkIndex = 0;
      });
    }
  }

  Future<void> _pasteBulkText() async {
    final loaded = await QuoteCardBulkService.showPasteBulkDialog(context);
    if (loaded.isNotEmpty && mounted) {
      setState(() {
        _bulkQuotes = loaded;
        _currentBulkIndex = 0;
      });
    }
  }

  Future<void> _saveCurrentAsTemplate() {
    return QuoteCardTemplateDialogService.saveCurrentAsTemplate(
      context: context,
      handleOnly: _handleOnly,
      draft: QuoteCardTemplateDraft(
        displayName: _displayNameController.text,
        username: _usernameController.text,
        quoteFont: _quoteFont,
        authorFont: _authorFont,
        displayNameFont: _displayNameFont,
        handleFont: _handleFont,
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        authorColor: _authorColor,
        displayNameColor: _displayNameColor,
        usernameColor: _usernameColor,
        enableQuoteShadow: _enableQuoteShadow,
        enableAuthorShadow: _enableAuthorShadow,
        enableQuoteGlow: _enableQuoteGlow,
        enableAuthorGlow: _enableAuthorGlow,
        quoteShadowColor: _quoteShadowColor,
        authorShadowColor: _authorShadowColor,
        quoteGlowColor: _quoteGlowColor,
        authorGlowColor: _authorGlowColor,
        quoteGlowRadius: _quoteGlowRadius,
        authorGlowRadius: _authorGlowRadius,
        textAlign: _textAlign,
        textPosition: _textPosition,
        identityPosition: _identityPosition,
        letterSpacing: _letterSpacing,
        fontSize: _fontSize,
        aspectIndex: _selectedAspectIndex,
      ),
    );
  }

  Future<void> _showTemplatePicker() async {
    final selected = await QuoteCardTemplateDialogService.showTemplatePicker(
      context: context,
      handleOnly: _handleOnly,
    );
    if (selected == null || !mounted) return;
    _applyTemplate(selected);
  }

  void _applyTemplate(InstagramQuoteTemplate selected) {
    setState(() {
      _displayNameController.text = selected.displayName;
      _usernameController.text = selected.username;

      _quoteFont = fontInfoFromFamily(selected.quoteFontFamily);
      _authorFont = fontInfoFromFamily(selected.authorFontFamily);
      _displayNameFont = fontInfoFromFamily(selected.displayNameFontFamily);
      _handleFont = fontInfoFromFamily(selected.handleFontFamily);

      _backgroundColor = Color(selected.backgroundColorValue);
      _textColor = Color(selected.quoteColorValue);
      _authorColor = Color(selected.authorColorValue);
      _displayNameColor = Color(selected.displayNameColorValue);
      _usernameColor = Color(selected.usernameColorValue);

      _enableQuoteShadow = selected.enableQuoteShadow;
      _enableAuthorShadow = selected.enableAuthorShadow;
      _enableQuoteGlow = selected.enableQuoteGlow;
      _enableAuthorGlow = selected.enableAuthorGlow;

      _quoteShadowColor = Color(selected.quoteShadowColorValue);
      _authorShadowColor = Color(selected.authorShadowColorValue);
      _quoteGlowColor = Color(selected.quoteGlowColorValue);
      _authorGlowColor = Color(selected.authorGlowColorValue);

      _quoteGlowRadius = selected.quoteGlowRadius;
      _authorGlowRadius = selected.authorGlowRadius;

      _textAlign = indexToTextAlign(selected.textAlignIndex);
      _textPosition = Alignment(selected.textPosX, selected.textPosY);
      _identityPosition = Alignment(
        selected.identityPosX,
        selected.identityPosY,
      );

      _letterSpacing = selected.letterSpacing;
      _fontSize = selected.fontSizeMultiplier;
      _selectedAspectIndex = selected.aspectIndex;
    });
  }

  Future<void> _saveAsImage() {
    return QuoteCardExportService.saveAsImage(
      context: context,
      previewKey: _previewKey,
      selectedAspectIndex: _selectedAspectIndex,
      isBulkMode: _isBulkMode,
      bulkQuotes: _bulkQuotes,
      onSelectBulkIndex: (i) {
        if (mounted) setState(() => _currentBulkIndex = i);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscard();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: const Text(
            'Quote Card',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              tooltip: 'Load template',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: _showTemplatePicker,
            ),
            IconButton(
              tooltip: 'Save as template',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _saveCurrentAsTemplate,
            ),
          ],
        ),
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildPreviewArea()),
              _buildControlsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildAspectRatioSelector(),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: QuoteCardPreviewCanvas(
                  previewKey: _previewKey,
                  aspectRatio: _currentAspectRatio,
                  handleOnly: _handleOnly,
                  isBulkMode: _isBulkMode,
                  bulkQuotes: _bulkQuotes,
                  currentBulkIndex: _currentBulkIndex,
                  onBulkIndexChanged: (idx) =>
                      setState(() => _currentBulkIndex = idx),
                  quoteText: _quoteController.text,
                  authorText: _authorController.text,
                  displayNameText: _displayNameController.text,
                  usernameText: _usernameController.text,
                  quoteFont: _quoteFont,
                  authorFont: _authorFont,
                  displayNameFont: _displayNameFont,
                  handleFont: _handleFont,
                  backgroundColor: _backgroundColor,
                  textColor: _textColor,
                  authorColor: _authorColor,
                  displayNameColor: _displayNameColor,
                  usernameColor: _usernameColor,
                  enableQuoteShadow: _enableQuoteShadow,
                  quoteShadowColor: _quoteShadowColor,
                  quoteShadowOffsetX: _quoteShadowOffsetX,
                  quoteShadowOffsetY: _quoteShadowOffsetY,
                  quoteShadowBlur: _quoteShadowBlur,
                  enableQuoteGlow: _enableQuoteGlow,
                  quoteGlowColor: _quoteGlowColor,
                  quoteGlowRadius: _quoteGlowRadius,
                  enableAuthorShadow: _enableAuthorShadow,
                  authorShadowColor: _authorShadowColor,
                  authorShadowOffsetX: _authorShadowOffsetX,
                  authorShadowOffsetY: _authorShadowOffsetY,
                  authorShadowBlur: _authorShadowBlur,
                  enableAuthorGlow: _enableAuthorGlow,
                  authorGlowColor: _authorGlowColor,
                  authorGlowRadius: _authorGlowRadius,
                  textAlign: _textAlign,
                  fontSizeMultiplier: _fontSize,
                  lineHeight: _lineHeight,
                  letterSpacing: _letterSpacing,
                  textPosition: _textPosition,
                  identityPosition: _identityPosition,
                  onTextPositionChanged: (pos) =>
                      setState(() => _textPosition = pos),
                  onIdentityPositionChanged: (pos) =>
                      setState(() => _identityPosition = pos),
                  profileImage: _profileImage,
                  backgroundImage: _backgroundImage,
                  backgroundFit: _backgroundFit,
                  backgroundOffset: _backgroundOffset,
                  backgroundScale: _backgroundScale,
                  backgroundBlur: _backgroundBlur,
                  backgroundBrightness: _backgroundBrightness,
                  backgroundSaturation: _backgroundSaturation,
                  onBackgroundOffsetChanged: (offset) =>
                      setState(() => _backgroundOffset = offset),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRatioSelector() {
    return Row(
      children: [
        const Text(
          'Size',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quoteCardAspectOptions.map((opt) {
                final isSelected = _selectedAspectIndex == opt.index;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAspectIndex = opt.index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? Colors.black87
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isTabContentExpanded)
            Container(
              height: 240,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(child: _buildActiveTabContent()),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: ElevatedButton(
              onPressed: _saveAsImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Icon(Icons.download, size: 20),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (_, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = _tabs[index];
                final baseColor = tab['color']! as Color;
                final highlighted = isSelected && _isTabContentExpanded;
                return GestureDetector(
                  onTap: () {
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
                    width: 70,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? baseColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon']! as IconData,
                          size: 22,
                          color: highlighted ? baseColor : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label']! as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: highlighted
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: highlighted ? baseColor : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return QuoteCardTextTab(
          handleOnly: _handleOnly,
          onHandleOnlyChanged: (val) => setState(() => _handleOnly = val),
          isBulkMode: _isBulkMode,
          onBulkModeChanged: (val) {
            setState(() {
              _isBulkMode = val;
              if (!val) {
                _bulkQuotes.clear();
                _currentBulkIndex = 0;
              }
            });
          },
          quoteController: _quoteController,
          authorController: _authorController,
          displayNameController: _displayNameController,
          usernameController: _usernameController,
          onTextChanged: () => setState(() {}),
          onImportSingleQuote: _importFromMyQuotes,
          onImportBulkQuotes: _importBulkFromMyQuotes,
          onImportCsv: _importCsv,
          onPasteBulkText: _pasteBulkText,
          onClearBulkQuotes: () => setState(() {
            _bulkQuotes.clear();
            _currentBulkIndex = 0;
          }),
          bulkQuotes: _bulkQuotes,
          profileImage: _profileImage,
          onPickProfileImage: _pickProfileImage,
        );
      case 1:
        return QuoteCardFontTab(
          handleOnly: _handleOnly,
          quoteFont: _quoteFont,
          authorFont: _authorFont,
          displayNameFont: _displayNameFont,
          handleFont: _handleFont,
          onQuoteFontChanged: (f) => setState(() => _quoteFont = f),
          onAuthorFontChanged: (f) => setState(() => _authorFont = f),
          onDisplayNameFontChanged: (f) => setState(() => _displayNameFont = f),
          onHandleFontChanged: (f) => setState(() => _handleFont = f),
        );
      case 2:
        return QuoteCardColorsTab(
          handleOnly: _handleOnly,
          textColor: _textColor,
          backgroundColor: _backgroundColor,
          authorColor: _authorColor,
          displayNameColor: _displayNameColor,
          usernameColor: _usernameColor,
          backgroundImage: _backgroundImage,
          onTextColorChanged: (c) => setState(() => _textColor = c),
          onBackgroundColorChanged: (c) =>
              setState(() => _backgroundColor = c),
          onAuthorColorChanged: (c) => setState(() => _authorColor = c),
          onDisplayNameColorChanged: (c) =>
              setState(() => _displayNameColor = c),
          onUsernameColorChanged: (c) => setState(() => _usernameColor = c),
          onPickBackgroundImage: _pickBackgroundImage,
          onRemoveBackgroundImage: _removeBackgroundImage,
        );
      case 3:
        return QuoteCardEffectsTab(
          enableQuoteShadow: _enableQuoteShadow,
          quoteShadowColor: _quoteShadowColor,
          quoteShadowOffsetX: _quoteShadowOffsetX,
          quoteShadowOffsetY: _quoteShadowOffsetY,
          quoteShadowBlur: _quoteShadowBlur,
          onEnableQuoteShadowChanged: (v) =>
              setState(() => _enableQuoteShadow = v),
          onQuoteShadowColorChanged: (c) =>
              setState(() => _quoteShadowColor = c),
          onQuoteShadowOffsetXChanged: (v) =>
              setState(() => _quoteShadowOffsetX = v),
          onQuoteShadowOffsetYChanged: (v) =>
              setState(() => _quoteShadowOffsetY = v),
          onQuoteShadowBlurChanged: (v) =>
              setState(() => _quoteShadowBlur = v),
          enableAuthorShadow: _enableAuthorShadow,
          authorShadowColor: _authorShadowColor,
          authorShadowOffsetX: _authorShadowOffsetX,
          authorShadowOffsetY: _authorShadowOffsetY,
          authorShadowBlur: _authorShadowBlur,
          onEnableAuthorShadowChanged: (v) =>
              setState(() => _enableAuthorShadow = v),
          onAuthorShadowColorChanged: (c) =>
              setState(() => _authorShadowColor = c),
          onAuthorShadowOffsetXChanged: (v) =>
              setState(() => _authorShadowOffsetX = v),
          onAuthorShadowOffsetYChanged: (v) =>
              setState(() => _authorShadowOffsetY = v),
          onAuthorShadowBlurChanged: (v) =>
              setState(() => _authorShadowBlur = v),
          enableQuoteGlow: _enableQuoteGlow,
          quoteGlowColor: _quoteGlowColor,
          quoteGlowRadius: _quoteGlowRadius,
          onEnableQuoteGlowChanged: (v) =>
              setState(() => _enableQuoteGlow = v),
          onQuoteGlowColorChanged: (c) => setState(() => _quoteGlowColor = c),
          onQuoteGlowRadiusChanged: (v) =>
              setState(() => _quoteGlowRadius = v),
          enableAuthorGlow: _enableAuthorGlow,
          authorGlowColor: _authorGlowColor,
          authorGlowRadius: _authorGlowRadius,
          onEnableAuthorGlowChanged: (v) =>
              setState(() => _enableAuthorGlow = v),
          onAuthorGlowColorChanged: (c) =>
              setState(() => _authorGlowColor = c),
          onAuthorGlowRadiusChanged: (v) =>
              setState(() => _authorGlowRadius = v),
        );
      case 4:
        return QuoteCardSpacingTab(
          letterSpacing: _letterSpacing,
          lineHeight: _lineHeight,
          fontSize: _fontSize,
          onLetterSpacingChanged: (v) => setState(() => _letterSpacing = v),
          onLineHeightChanged: (v) => setState(() => _lineHeight = v),
          onFontSizeChanged: (v) => setState(() => _fontSize = v),
        );
      case 5:
        return QuoteCardAlignmentTab(
          textAlign: _textAlign,
          onChanged: (align) => setState(() => _textAlign = align),
        );
      case 6:
        return QuoteCardPositionSection(
          title: 'Quote Position',
          icon: Icons.open_with,
          accentColor: Colors.brown.shade600,
          position: _textPosition,
          resetAlignment: Alignment.center,
          onPositionChanged: (pos) => setState(() => _textPosition = pos),
        );
      case 7:
        return QuoteCardPositionSection(
          title: 'Identity Bar Position',
          icon: Icons.account_circle,
          accentColor: Colors.pink.shade600,
          position: _identityPosition,
          resetAlignment: Alignment.bottomCenter,
          onPositionChanged: (pos) =>
              setState(() => _identityPosition = pos),
        );
      default:
        return QuoteCardBackgroundTab(
          backgroundImage: _backgroundImage,
          backgroundFit: _backgroundFit,
          backgroundScale: _backgroundScale,
          backgroundBlur: _backgroundBlur,
          backgroundBrightness: _backgroundBrightness,
          backgroundSaturation: _backgroundSaturation,
          onFitChanged: (fit) => setState(() => _backgroundFit = fit),
          onScaleChanged: (v) => setState(() => _backgroundScale = v),
          onBlurChanged: (v) => setState(() => _backgroundBlur = v),
          onBrightnessChanged: (v) =>
              setState(() => _backgroundBrightness = v),
          onSaturationChanged: (v) =>
              setState(() => _backgroundSaturation = v),
          onResetAll: () => setState(() {
            _backgroundOffset = Offset.zero;
            _backgroundScale = 1.0;
            _backgroundBlur = 0.0;
            _backgroundBrightness = 1.0;
            _backgroundSaturation = 1.0;
          }),
        );
    }
  }
}

