import 'package:flutter/material.dart';

import '../../../../models/instagram_quote_template.dart';
import '../../../../services/instagram_quote_template_service.dart';
import '../../../../utils/font_selector.dart';
import '../models/quote_card_config.dart';

/// Snapshot of style values passed when saving a Quote Card template.
class QuoteCardTemplateDraft {
  final String displayName;
  final String username;
  final FontInfo? quoteFont;
  final FontInfo? authorFont;
  final FontInfo? displayNameFont;
  final FontInfo? handleFont;
  final Color backgroundColor;
  final Color textColor;
  final Color authorColor;
  final Color displayNameColor;
  final Color usernameColor;
  final bool enableQuoteShadow;
  final bool enableAuthorShadow;
  final bool enableQuoteGlow;
  final bool enableAuthorGlow;
  final Color quoteShadowColor;
  final Color authorShadowColor;
  final Color quoteGlowColor;
  final Color authorGlowColor;
  final double quoteGlowRadius;
  final double authorGlowRadius;
  final TextAlign textAlign;
  final Alignment textPosition;
  final Alignment identityPosition;
  final double letterSpacing;
  final double fontSize;
  final int aspectIndex;

  const QuoteCardTemplateDraft({
    required this.displayName,
    required this.username,
    required this.quoteFont,
    required this.authorFont,
    required this.displayNameFont,
    required this.handleFont,
    required this.backgroundColor,
    required this.textColor,
    required this.authorColor,
    required this.displayNameColor,
    required this.usernameColor,
    required this.enableQuoteShadow,
    required this.enableAuthorShadow,
    required this.enableQuoteGlow,
    required this.enableAuthorGlow,
    required this.quoteShadowColor,
    required this.authorShadowColor,
    required this.quoteGlowColor,
    required this.authorGlowColor,
    required this.quoteGlowRadius,
    required this.authorGlowRadius,
    required this.textAlign,
    required this.textPosition,
    required this.identityPosition,
    required this.letterSpacing,
    required this.fontSize,
    required this.aspectIndex,
  });
}

/// Dialogs and persistence helpers for saving, picking, renaming, and deleting templates.
class QuoteCardTemplateDialogService {
  const QuoteCardTemplateDialogService._();

  /// Prompts for a template name and saves (or overwrites) it under [handleOnly].
  static Future<void> saveCurrentAsTemplate({
    required BuildContext context,
    required bool handleOnly,
    required QuoteCardTemplateDraft draft,
  }) async {
    final nameController = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty) return;

    final existingTemplates = await InstagramQuoteTemplateService.getTemplates(
      handleOnly: handleOnly,
    );
    InstagramQuoteTemplate? existing;
    for (final t in existingTemplates) {
      if (t.name == name) {
        existing = t;
        break;
      }
    }

    final template = InstagramQuoteTemplate(
      id: existing?.id ?? '',
      name: name,
      displayName: draft.displayName,
      username: draft.username,
      quoteFontFamily: draft.quoteFont?.family,
      authorFontFamily: draft.authorFont?.family,
      displayNameFontFamily: draft.displayNameFont?.family,
      handleFontFamily: draft.handleFont?.family,
      backgroundColorValue: draft.backgroundColor.toARGB32(),
      quoteColorValue: draft.textColor.toARGB32(),
      authorColorValue: draft.authorColor.toARGB32(),
      displayNameColorValue: draft.displayNameColor.toARGB32(),
      usernameColorValue: draft.usernameColor.toARGB32(),
      enableQuoteShadow: draft.enableQuoteShadow,
      enableAuthorShadow: draft.enableAuthorShadow,
      enableQuoteGlow: draft.enableQuoteGlow,
      enableAuthorGlow: draft.enableAuthorGlow,
      quoteShadowColorValue: draft.quoteShadowColor.toARGB32(),
      authorShadowColorValue: draft.authorShadowColor.toARGB32(),
      quoteGlowColorValue: draft.quoteGlowColor.toARGB32(),
      authorGlowColorValue: draft.authorGlowColor.toARGB32(),
      quoteGlowRadius: draft.quoteGlowRadius,
      authorGlowRadius: draft.authorGlowRadius,
      textAlignIndex: textAlignToIndex(draft.textAlign),
      textPosX: draft.textPosition.x,
      textPosY: draft.textPosition.y,
      identityPosX: draft.identityPosition.x,
      identityPosY: draft.identityPosition.y,
      letterSpacing: draft.letterSpacing,
      fontSizeMultiplier: draft.fontSize,
      aspectIndex: draft.aspectIndex,
    );

    await InstagramQuoteTemplateService.saveTemplate(
      template,
      handleOnly: handleOnly,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "$name" saved')),
    );
  }

  /// Opens the saved templates bottom sheet and returns the selected template, if any.
  static Future<InstagramQuoteTemplate?> showTemplatePicker({
    required BuildContext context,
    required bool handleOnly,
  }) async {
    final templates = await InstagramQuoteTemplateService.getTemplates(
      handleOnly: handleOnly,
    );
    if (!context.mounted) return null;

    return showModalBottomSheet<InstagramQuoteTemplate?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        if (templates.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No templates yet. Save your current style as a template.',
                ),
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Saved templates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(null),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final t = templates[index];
                    return ListTile(
                      title: Text(t.name),
                      subtitle: t.username.isNotEmpty
                          ? Text(
                              t.username,
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(t),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => Navigator.of(sheetContext).pop(t),
                          ),
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.drive_file_rename_outline),
                            onPressed: () async {
                              final controller =
                                  TextEditingController(text: t.name);
                              final newName = await showDialog<String?>(
                                context: sheetContext,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Rename template'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Template name',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(null),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(controller.text.trim()),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              controller.dispose();

                              if (newName != null &&
                                  newName.isNotEmpty &&
                                  newName != t.name) {
                                t.name = newName;
                                await InstagramQuoteTemplateService.saveTemplate(
                                  t,
                                  handleOnly: handleOnly,
                                );
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await InstagramQuoteTemplateService
                                  .deleteTemplate(
                                t.id,
                                handleOnly: handleOnly,
                              );
                              if (sheetContext.mounted &&
                                  Navigator.of(sheetContext).canPop()) {
                                Navigator.of(sheetContext).pop(null);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

