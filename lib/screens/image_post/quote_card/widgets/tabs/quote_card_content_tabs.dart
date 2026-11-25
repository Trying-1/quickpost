import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../utils/font_selector.dart';
import '../quote_card_shared_controls.dart';

/// Text input, bulk mode import, and identity editor tab.
class QuoteCardTextTab extends StatelessWidget {
  final bool handleOnly;
  final ValueChanged<bool> onHandleOnlyChanged;
  final bool isBulkMode;
  final ValueChanged<bool> onBulkModeChanged;
  final TextEditingController quoteController;
  final TextEditingController authorController;
  final TextEditingController displayNameController;
  final TextEditingController usernameController;
  final VoidCallback onTextChanged;
  final VoidCallback onImportSingleQuote;
  final VoidCallback onImportBulkQuotes;
  final VoidCallback onImportCsv;
  final VoidCallback onPasteBulkText;
  final VoidCallback onClearBulkQuotes;
  final List<Map<String, String>> bulkQuotes;
  final File? profileImage;
  final VoidCallback onPickProfileImage;

  const QuoteCardTextTab({
    super.key,
    required this.handleOnly,
    required this.onHandleOnlyChanged,
    required this.isBulkMode,
    required this.onBulkModeChanged,
    required this.quoteController,
    required this.authorController,
    required this.displayNameController,
    required this.usernameController,
    required this.onTextChanged,
    required this.onImportSingleQuote,
    required this.onImportBulkQuotes,
    required this.onImportCsv,
    required this.onPasteBulkText,
    required this.onClearBulkQuotes,
    required this.bulkQuotes,
    required this.profileImage,
    required this.onPickProfileImage,
  });

  @override
  Widget build(BuildContext context) {
    return QuoteCardSectionCard(
      icon: Icons.format_quote,
      iconColor: Colors.teal.shade600,
      title: 'Text Input',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: isBulkMode ? onImportBulkQuotes : onImportSingleQuote,
            icon: const Icon(Icons.bookmark, size: 16),
            label: const Text('My Quotes', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          const Text('Bulk', style: TextStyle(fontSize: 12)),
          Switch(value: isBulkMode, onChanged: onBulkModeChanged),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isBulkMode) ...[
            TextField(
              controller: quoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your quote...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
              onChanged: (_) => onTextChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                hintText: 'Author (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => onTextChanged(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Identity',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Handle Only', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: handleOnly,
                      onChanged: onHandleOnlyChanged,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!handleOnly) ...[
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(
                  hintText: 'Your theme page',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: (_) => onTextChanged(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                hintText: '@yourhandle',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (_) => onTextChanged(),
            ),
            if (!handleOnly) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: onPickProfileImage,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage:
                          profileImage != null ? FileImage(profileImage!) : null,
                      child: profileImage == null
                          ? const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tap to add/change profile picture',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Identity',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Handle Only', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: handleOnly,
                      onChanged: onHandleOnlyChanged,
                    ),
                  ],
                ),
              ],
            ),
            if (!handleOnly) ...[
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(
                  hintText: 'Your theme page',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: (_) => onTextChanged(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                hintText: '@yourhandle',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (_) => onTextChanged(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImportCsv,
                    icon: const Icon(Icons.file_present),
                    label: const Text('Import CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPasteBulkText,
                    icon: const Icon(Icons.paste),
                    label: const Text('Paste Text'),
                  ),
                ),
              ],
            ),
            if (bulkQuotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${bulkQuotes.length} quotes loaded',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'First 3 lines:',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              ...bulkQuotes.take(3).map(
                    (q) => Text(
                      '${q['quote']} - ${q['author']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              TextButton(
                onPressed: onClearBulkQuotes,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Font picker tab for quote, author, optional display name, and handle fonts.
class QuoteCardFontTab extends StatelessWidget {
  final bool handleOnly;
  final FontInfo? quoteFont;
  final FontInfo? authorFont;
  final FontInfo? displayNameFont;
  final FontInfo? handleFont;
  final ValueChanged<FontInfo> onQuoteFontChanged;
  final ValueChanged<FontInfo> onAuthorFontChanged;
  final ValueChanged<FontInfo> onDisplayNameFontChanged;
  final ValueChanged<FontInfo> onHandleFontChanged;

  const QuoteCardFontTab({
    super.key,
    required this.handleOnly,
    required this.quoteFont,
    required this.authorFont,
    required this.displayNameFont,
    required this.handleFont,
    required this.onQuoteFontChanged,
    required this.onAuthorFontChanged,
    required this.onDisplayNameFontChanged,
    required this.onHandleFontChanged,
  });

  Widget _buildFontRow({
    required String label,
    required List<FontInfo> fonts,
    required FontInfo? selectedFont,
    required ValueChanged<FontInfo> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length,
            itemBuilder: (_, index) {
              final font = fonts[index];
              final isSelected = selectedFont == font;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight ?? FontWeight.w400,
                      fontStyle: font.style ?? FontStyle.normal,
                      fontSize: 13,
                    ),
                  ),
                  selectedColor: Colors.green[100],
                  backgroundColor: Colors.grey[100],
                  onSelected: (_) => onSelected(font),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fonts = getAllFonts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFontRow(
          label: 'Quote font',
          fonts: fonts,
          selectedFont: quoteFont,
          onSelected: onQuoteFontChanged,
        ),
        const SizedBox(height: 12),
        _buildFontRow(
          label: 'Author font',
          fonts: fonts,
          selectedFont: authorFont,
          onSelected: onAuthorFontChanged,
        ),
        if (!handleOnly) ...[
          const SizedBox(height: 12),
          _buildFontRow(
            label: 'Username font',
            fonts: fonts,
            selectedFont: displayNameFont,
            onSelected: onDisplayNameFontChanged,
          ),
        ],
        const SizedBox(height: 12),
        _buildFontRow(
          label: 'Handle font',
          fonts: fonts,
          selectedFont: handleFont,
          onSelected: onHandleFontChanged,
        ),
      ],
    );
  }
}

/// Colors & background image selector tab.
class QuoteCardColorsTab extends StatelessWidget {
  final bool handleOnly;
  final Color textColor;
  final Color backgroundColor;
  final Color authorColor;
  final Color displayNameColor;
  final Color usernameColor;
  final File? backgroundImage;
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<Color> onAuthorColorChanged;
  final ValueChanged<Color> onDisplayNameColorChanged;
  final ValueChanged<Color> onUsernameColorChanged;
  final VoidCallback onPickBackgroundImage;
  final VoidCallback onRemoveBackgroundImage;

  const QuoteCardColorsTab({
    super.key,
    required this.handleOnly,
    required this.textColor,
    required this.backgroundColor,
    required this.authorColor,
    required this.displayNameColor,
    required this.usernameColor,
    required this.backgroundImage,
    required this.onTextColorChanged,
    required this.onBackgroundColorChanged,
    required this.onAuthorColorChanged,
    required this.onDisplayNameColorChanged,
    required this.onUsernameColorChanged,
    required this.onPickBackgroundImage,
    required this.onRemoveBackgroundImage,
  });

  Future<void> _pickColor(
    BuildContext context,
    String title,
    Color current,
    ValueChanged<Color> onChanged,
  ) async {
    final picked = await showQuoteCardColorPickerDialog(
      context: context,
      title: title,
      initialColor: current,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuoteCardColorSwatchRow(
          label: 'Text color',
          color: textColor,
          onTap: () =>
              _pickColor(context, 'Text Color', textColor, onTextColorChanged),
        ),
        const SizedBox(height: 8),
        QuoteCardColorSwatchRow(
          label: 'Background',
          color: backgroundColor,
          onTap: () => _pickColor(
            context,
            'Background Color',
            backgroundColor,
            onBackgroundColorChanged,
          ),
          trailing: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickBackgroundImage,
                  icon: const Icon(Icons.image, size: 18),
                  label: Text(
                    backgroundImage == null ? 'Add bg image' : 'Change bg',
                  ),
                ),
              ),
              if (backgroundImage != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove background image',
                  onPressed: onRemoveBackgroundImage,
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        QuoteCardColorSwatchRow(
          label: 'Author color',
          color: authorColor,
          onTap: () => _pickColor(
            context,
            'Author Color',
            authorColor,
            onAuthorColorChanged,
          ),
        ),
        if (!handleOnly) ...[
          const SizedBox(height: 8),
          QuoteCardColorSwatchRow(
            label: 'Username color',
            color: displayNameColor,
            onTap: () => _pickColor(
              context,
              'Username Color',
              displayNameColor,
              onDisplayNameColorChanged,
            ),
          ),
        ],
        const SizedBox(height: 8),
        QuoteCardColorSwatchRow(
          label: 'Handle color',
          color: usernameColor,
          onTap: () => _pickColor(
            context,
            'Handle Color',
            usernameColor,
            onUsernameColorChanged,
          ),
        ),
      ],
    );
  }
}

