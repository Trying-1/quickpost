import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';

import '../../config/app_theme.dart';
import '../../services/ad_service.dart';
import '../../services/anime_post_preset_service.dart';
import '../../services/app_review_service.dart';
import 'models/anime_carousel_project.dart';
import 'models/anime_carousel_slide.dart';
import 'models/anime_custom_layout.dart';
import 'models/anime_db_entry.dart';
import 'models/anime_template_theme.dart';
import 'services/anime_asset_storage_service.dart';
import 'services/anime_carousel_export_service.dart';
import 'services/anime_database_service.dart';
import 'widgets/assets/anime_asset_library_sheet.dart';
import 'widgets/assets/anime_asset_storage_panel.dart';
import 'widgets/assets/anime_asset_upload_dialog.dart';
import 'widgets/database/anime_database_panel.dart';
import 'widgets/anime_json_import_sheet.dart';
import 'widgets/anime_layouts_panel.dart';
import 'widgets/anime_slide_preview.dart';
import 'widgets/image_reorder_sheet.dart';
import 'widgets/slide_data_editor.dart';
import 'widgets/slide_position_panel.dart';
import 'widgets/slide_selector_strip.dart';
import 'widgets/theme_styling_panel.dart';

/// Modular coordinator screen for Anime Carousel Posts.
/// Built with the authentic Quick Post UI and theme:
/// Light background (Colors.grey[100]), bottom control tabs dock,
/// expandable drawer, and high-resolution sequential export.
class AnimePostMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final AnimeCarouselProject? initialProject;
  final bool isActive;

  const AnimePostMakerScreen({
    super.key,
    this.sharedImagePaths,
    this.initialProject,
    this.isActive = true,
  });

  @override
  State<AnimePostMakerScreen> createState() => _AnimePostMakerScreenState();
}

class _AnimePostMakerScreenState extends State<AnimePostMakerScreen> {
  late AnimeCarouselProject _project;
  int _activeSlideIndex = 0;
  final GlobalKey _slideRepaintKey = GlobalKey();

  // Control tabs state matching ImagePostMakerScreen
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;
  String? _activeComponentKey = SlideComponentId.title;
  bool _isExporting = false;
  bool _isDraggingCanvas = false;
  bool _showSelectionOverlay = true;

  @override
  void initState() {
    super.initState();
    final init = widget.initialProject;
    _project = init != null
        ? init.copyWith(slides: init.slides.map((s) => s.copyWith()).toList())
        : AnimeCarouselProject.createDefault();
    _applySharedImagesIfAny();
  }

  @override
  void didUpdateWidget(covariant AnimePostMakerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedImagePaths != null &&
        widget.sharedImagePaths != oldWidget.sharedImagePaths) {
      _applySharedImagesIfAny();
    }
  }

  void _applySharedImagesIfAny() {
    if (widget.sharedImagePaths == null || widget.sharedImagePaths!.isEmpty) return;
    final paths = widget.sharedImagePaths!;
    final updatedSlides = <AnimeCarouselSlide>[];
    for (int i = 0; i < _project.slides.length; i++) {
      if (i < paths.length && File(paths[i]).existsSync()) {
        updatedSlides.add(_project.slides[i].copyWith(imagePath: paths[i]));
      } else {
        updatedSlides.add(_project.slides[i]);
      }
    }
    setState(() {
      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  AnimeCarouselSlide get _activeSlide => _project.slides[_activeSlideIndex];

  void _onSlideDataChanged(AnimeCarouselSlide updatedSlide) {
    setState(() {
      final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      // When sync is active and editing an anime slide, synchronize positioning offsets across all anime slides
      if (_project.theme.syncAnimeSlideLayoutAndPosition && updatedSlide.type == SlideType.anime) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.anime && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWith(
              contentOffsetX: updatedSlide.contentOffsetX,
              contentOffsetY: updatedSlide.contentOffsetY,
              headerOffsetY: updatedSlide.headerOffsetY,
              componentOffsets: Map<String, Offset>.from(updatedSlide.componentOffsets),
            );
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _onDragComponent(String componentKey, Offset delta) {
    setState(() {
      _activeComponentKey = componentKey;
      final currentOffset = _activeSlide.getComponentOffset(componentKey);
      final newX = (currentOffset.dx + delta.dx).clamp(-360.0, 360.0);
      final newY = (currentOffset.dy + delta.dy).clamp(-640.0, 640.0);

      final updatedSlide = _activeSlide.copyWithComponentOffset(
        componentKey,
        Offset(newX, newY),
      );

      final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      // When sync is active and dragging on an anime slide, synchronize position to all other anime slides
      if (_project.theme.syncAnimeSlideLayoutAndPosition && _activeSlide.type == SlideType.anime) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.anime && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWithComponentOffset(
              componentKey,
              Offset(newX, newY),
            );
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _onDragContent(Offset delta) {
    _onDragComponent(SlideComponentId.allContent, delta);
  }

  void _onDragHeader(Offset delta) {
    _onDragComponent(SlideComponentId.pageHandle, delta);
  }

  void _onToggleSyncLayoutAndPosition(bool sync) {
    setState(() {
      var updatedProject = _project.copyWith(
        theme: _project.theme.copyWith(syncAnimeSlideLayoutAndPosition: sync),
      );
      if (sync && _activeSlide.type == SlideType.anime) {
        final activeLayout = _activeSlide.getEffectiveLayout(_project.theme);
        final updatedSlides = updatedProject.slides.map((s) {
          if (s.type == SlideType.anime) {
            return s.copyWith(
              contentOffsetX: _activeSlide.contentOffsetX,
              contentOffsetY: _activeSlide.contentOffsetY,
              headerOffsetY: _activeSlide.headerOffsetY,
              componentOffsets: Map<String, Offset>.from(_activeSlide.componentOffsets),
              customLayout: activeLayout,
            );
          }
          return s;
        }).toList();
        updatedProject = updatedProject.copyWith(
          slides: updatedSlides,
          theme: updatedProject.theme.copyWith(slideLayout: activeLayout),
        );
      }
      _project = updatedProject;
    });
  }

  void _onSelectSlideLayout(SlideLayout layout) {
    setState(() {
      if (_project.theme.syncAnimeSlideLayoutAndPosition) {
        _project = _project.copyWith(
          theme: _project.theme.copyWith(slideLayout: layout),
        );
      } else {
        if (_activeSlide.type == SlideType.anime) {
          final updated = List<AnimeCarouselSlide>.from(_project.slides);
          updated[_activeSlideIndex] = updated[_activeSlideIndex].copyWith(customLayout: layout);
          _project = _project.copyWith(slides: updated);
        } else {
          _project = _project.copyWith(
            theme: _project.theme.copyWith(slideLayout: layout),
          );
        }
      }
    });
  }

  void _applyCustomLayout(AnimeCustomLayout layout) {
    setState(() {
      final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);
      final shouldSync = _project.theme.syncAnimeSlideLayoutAndPosition;

      for (int i = 0; i < updatedSlides.length; i++) {
        if (i == _activeSlideIndex || (shouldSync && updatedSlides[i].type == SlideType.anime)) {
          updatedSlides[i] = updatedSlides[i].copyWith(
            contentOffsetX: layout.contentOffsetX,
            contentOffsetY: layout.contentOffsetY,
            headerOffsetY: layout.headerOffsetY,
            componentOffsets: Map<String, Offset>.from(layout.componentOffsets),
            customLayout: SlideLayout.defaultLayout,
          );
        }
      }

      final updatedTheme = _project.theme.copyWith(
        slideLayout: SlideLayout.defaultLayout,
        showRankBadge: layout.showRankBadge,
        showRating: layout.showRating,
        showSeasons: layout.showSeasons,
        showEpisodes: layout.showEpisodes,
        showStudio: layout.showStudio,
        showGenres: layout.showGenres,
        showSynopsis: layout.showSynopsis,
        showWatermark: layout.showWatermark,
        showSlideCounter: layout.showSlideCounter,
        showHookTag: layout.showHookTag,
        showJapaneseTitle: layout.showJapaneseTitle,
        cardStyle: layout.cardStyle,
        showCardBackdrop: layout.showCardBackdrop,
        showCardBorder: layout.showCardBorder,
        rankBadgeStyle: layout.rankBadgeStyle,
        metadataPillStyle: layout.metadataPillStyle,
        synopsisCardStyle: layout.synopsisCardStyle,
        titleCardStyle: layout.titleCardStyle,
        componentFonts: layout.componentFonts.isNotEmpty ? layout.componentFonts : null,
        componentColors: layout.componentColors.isNotEmpty ? layout.componentColors : null,
        componentBgColors: layout.componentBgColors.isNotEmpty ? layout.componentBgColors : null,
        componentBgOpacities: layout.componentBgOpacities.isNotEmpty ? layout.componentBgOpacities : null,
        componentBorderColors: layout.componentBorderColors.isNotEmpty ? layout.componentBorderColors : null,
        componentBorderWidths: layout.componentBorderWidths.isNotEmpty ? layout.componentBorderWidths : null,
        componentBorderRadii: layout.componentBorderRadii.isNotEmpty ? layout.componentBorderRadii : null,
        componentFontSizes: layout.componentFontSizes.isNotEmpty ? layout.componentFontSizes : null,
        componentFontWeights: layout.componentFontWeights.isNotEmpty ? layout.componentFontWeights : null,
        componentLetterSpacings: layout.componentLetterSpacings.isNotEmpty ? layout.componentLetterSpacings : null,
        componentPaddings: layout.componentPaddings.isNotEmpty ? layout.componentPaddings : null,
        componentShadows: layout.componentShadows.isNotEmpty ? layout.componentShadows : null,
        componentTextStrokeOnly: layout.componentTextStrokeOnly.isNotEmpty ? layout.componentTextStrokeOnly : null,
        componentTextStrokeWidths: layout.componentTextStrokeWidths.isNotEmpty ? layout.componentTextStrokeWidths : null,
        componentTextStrokeColors: layout.componentTextStrokeColors.isNotEmpty ? layout.componentTextStrokeColors : null,
        enableAmbientGlow: layout.enableAmbientGlow,
        ambientGlowIntensity: layout.ambientGlowIntensity,
        ambientGlowBlur: layout.ambientGlowBlur,
        ambientGlowSpread: layout.ambientGlowSpread,
        enableFilmGrain: layout.enableFilmGrain,
        filmGrainIntensity: layout.filmGrainIntensity,
        enableVignette: layout.enableVignette,
        vignetteIntensity: layout.vignetteIntensity,
      );

      _project = _project.copyWith(slides: updatedSlides, theme: updatedTheme);
    });
  }

  void _resetToDefaultLayout() {
    _resetSlidePosition();
    setState(() {
      _project = _project.copyWith(
        theme: _project.theme.copyWith(slideLayout: SlideLayout.defaultLayout),
      );
    });
  }

  void _applyPositionToAllSlides() {
    setState(() {
      final updatedSlides = _project.slides.map((s) {
        return s.copyWith(
          contentOffsetX: _activeSlide.contentOffsetX,
          contentOffsetY: _activeSlide.contentOffsetY,
          headerOffsetY: _activeSlide.headerOffsetY,
          componentOffsets: Map<String, Offset>.from(_activeSlide.componentOffsets),
        );
      }).toList();
      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _resetSlidePosition({String? componentKey}) {
    setState(() {
      final updatedSlide = _activeSlide.copyWithResetOffsets(specificKey: componentKey);
      final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      if (_project.theme.syncAnimeSlideLayoutAndPosition && _activeSlide.type == SlideType.anime) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.anime && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWithResetOffsets(specificKey: componentKey);
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _onThemeChanged(AnimeTemplateTheme updatedTheme) {
    setState(() {
      _project = _project.copyWith(theme: updatedTheme);
    });
  }

  void _onSelectSlide(int index) {
    if (index >= 0 && index < _project.slides.length) {
      setState(() => _activeSlideIndex = index);
    }
  }

  Future<void> _pickImageForActiveSlide() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (picked != null) {
        _onSlideDataChanged(_activeSlide.copyWith(imagePath: picked.path));
      }
    } catch (e) {
      // Pick image error silently handled
    }
  }

  Future<void> _pickBulkImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (pickedFiles.isEmpty) return;

      setState(() {
        final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);

        for (int i = 0; i < pickedFiles.length; i++) {
          final file = pickedFiles[i];
          if (i < updatedSlides.length) {
            updatedSlides[i] = updatedSlides[i].copyWith(imagePath: file.path);
          } else {
            // Automatically append new anime slide if more images are selected than slides
            final animeCount = updatedSlides.where((s) => s.type == SlideType.anime).length;
            final newRank = animeCount + 1;
            final newSlide = AnimeCarouselSlide(
              id: 'slide_${DateTime.now().millisecondsSinceEpoch}_$i',
              type: SlideType.anime,
              rank: newRank,
              bgImagePath: file.path,
              animeName: 'New Anime Recommendation #$newRank',
              japaneseName: '',
              rating: '8.5 / 10',
              seasons: '1 Season',
              episodes: '12 Episodes',
              studio: '',
              genres: 'Action, Fantasy',
              synopsis: '',
            );
            final ctaIndex = updatedSlides.indexWhere((s) => s.type == SlideType.cta);
            if (ctaIndex != -1) {
              updatedSlides.insert(ctaIndex, newSlide);
            } else {
              updatedSlides.add(newSlide);
            }
          }
        }

        _project = _project.copyWith(slides: updatedSlides);
      });
    } catch (e) {
      // Bulk import error silently handled
    }
  }

  void _showImageReorderSheet() {
    ImageReorderSheet.show(
      context: context,
      slides: _project.slides,
      onApplyReorderedImages: (newPaths) {
        setState(() {
          final updated = List<AnimeCarouselSlide>.from(_project.slides);
          for (int i = 0; i < updated.length && i < newPaths.length; i++) {
            if (newPaths[i] == null) {
              updated[i] = updated[i].copyWith(clearImagePath: true);
            } else {
              updated[i] = updated[i].copyWith(imagePath: newPaths[i]);
            }
          }
          _project = _project.copyWith(slides: updated);
        });
      },
    );
  }

  void _swapSlideImages(int indexA, int indexB) {
    if (indexA == indexB) return;
    if (indexA < 0 || indexA >= _project.slides.length) return;
    if (indexB < 0 || indexB >= _project.slides.length) return;

    setState(() {
      final updated = List<AnimeCarouselSlide>.from(_project.slides);
      final pathA = updated[indexA].imagePath;
      final pathB = updated[indexB].imagePath;

      updated[indexA] = pathB != null
          ? updated[indexA].copyWith(imagePath: pathB)
          : updated[indexA].copyWith(clearImagePath: true);

      updated[indexB] = pathA != null
          ? updated[indexB].copyWith(imagePath: pathA)
          : updated[indexB].copyWith(clearImagePath: true);

      _project = _project.copyWith(slides: updated);
    });
  }

  Future<void> _openAssetLibrary() async {
    final suggestions = _project.slides
        .where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final selectedPath = await AnimeAssetLibrarySheet.show(
      context,
      initialCategory: _activeSlide.type == SlideType.anime ? _activeSlide.animeName : null,
      suggestedAnimeNames: suggestions,
    );
    if (selectedPath != null && selectedPath.isNotEmpty) {
      _onSlideDataChanged(_activeSlide.copyWith(imagePath: selectedPath));
    }
  }

  Future<void> _saveActiveSlideToAssetStorage() async {
    if (_activeSlide.imagePath == null) return;
    final suggestions = _project.slides
        .where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final imported = await AnimeAssetUploadDialog.show(
      context,
      initialCategory: _activeSlide.type == SlideType.anime ? _activeSlide.animeName : null,
      initialSourceFilePaths: [_activeSlide.imagePath!],
      suggestedAnimeNames: suggestions,
    );
    if (imported != null && imported.isNotEmpty) {
      _showToast('Tagged & saved image to "${imported.first.animeName}" in Asset Storage!', isSuccess: true);
    }
  }

  /// Automatically matches and populates slide images based on anime name tags.
  Future<void> _autoMatchImagesByAnimeTags() async {
    try {
      final matches = await AnimeAssetStorageService.instance.autoMatchAssetsForSlides(_project.slides);
      if (matches.isEmpty) {
        final animeSlides = _project.slides.where((s) => s.type == SlideType.anime).toList();
        final suggestions = animeSlides
            .map((s) => s.animeName.trim())
            .where((s) => s.isNotEmpty && s != 'New Anime Recommendation')
            .toSet()
            .toList();

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
                  SizedBox(width: 8),
                  Text('Auto-Match Anime Images', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                suggestions.isNotEmpty
                    ? 'No stored images matched your slide anime titles (${suggestions.take(3).join(', ')}${suggestions.length > 3 ? '...' : ''}).\n\nWould you like to upload images and tag them now?'
                    : 'No stored images matched your slide anime titles.\n\nUpload images and tag them with anime names to auto-populate slides!',
                style: const TextStyle(fontSize: 12.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openUploadWithSuggestions();
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('Upload & Tag Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);
        for (final entry in matches.entries) {
          final idx = entry.key;
          final asset = entry.value;
          if (idx >= 0 && idx < updatedSlides.length) {
            updatedSlides[idx] = updatedSlides[idx].copyWith(imagePath: asset.filePath);
          }
        }
        _project = _project.copyWith(slides: updatedSlides);
      });
    } catch (e) {
      // Auto-match error silently handled
    }
  }

  Future<void> _openUploadWithSuggestions() async {
    final suggestions = _project.slides
        .where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final imported = await AnimeAssetUploadDialog.show(
      context,
      initialCategory: _activeSlide.type == SlideType.anime ? _activeSlide.animeName : null,
      suggestedAnimeNames: suggestions,
    );
    if (imported != null && imported.isNotEmpty) {
      await _autoMatchImagesByAnimeTags();
    }
  }

  // ===========================================================================
  // ANIME DATABASE INTEGRATION
  // ===========================================================================

  Future<void> _applyDbEntryToSlide(AnimeDbEntry entry) async {
    setState(() {
      final updated = _activeSlide.copyWith(
        animeName: entry.name,
        japaneseName: entry.japaneseName.isNotEmpty ? entry.japaneseName : _activeSlide.japaneseName,
        rating: entry.rating.isNotEmpty ? entry.rating : _activeSlide.rating,
        seasons: entry.seasons.isNotEmpty ? entry.seasons : _activeSlide.seasons,
        episodes: entry.episodes.isNotEmpty ? entry.episodes : _activeSlide.episodes,
        studio: entry.studio.isNotEmpty ? entry.studio : _activeSlide.studio,
        genres: entry.genres.isNotEmpty ? entry.genres : _activeSlide.genres,
        synopsis: entry.synopsis.isNotEmpty ? entry.synopsis : _activeSlide.synopsis,
      );
      _onSlideDataChanged(updated);
    });

    // Check if an image is already tagged for this anime in Assets!
    final matches = await AnimeAssetStorageService.instance.findAssetsForAnime(entry.name);
    if (matches.isNotEmpty && (_activeSlide.imagePath == null || _activeSlide.imagePath!.isEmpty)) {
      _onSlideDataChanged(_activeSlide.copyWith(imagePath: matches.first.filePath));
    }
  }

  Future<void> _addDbEntryAsSlide(AnimeDbEntry entry) async {
    final animeCount = _project.slides.where((s) => s.type == SlideType.anime).length;
    final newRank = animeCount + 1;

    // Check if matching image exists in storage
    final matches = await AnimeAssetStorageService.instance.findAssetsForAnime(entry.name);
    final imagePath = matches.isNotEmpty ? matches.first.filePath : null;

    final newSlide = AnimeCarouselSlide(
      id: 'slide_${DateTime.now().millisecondsSinceEpoch}',
      type: SlideType.anime,
      rank: newRank,
      bgImagePath: imagePath,
      animeName: entry.name,
      japaneseName: entry.japaneseName,
      rating: entry.rating.isNotEmpty ? entry.rating : '8.5 / 10',
      seasons: entry.seasons.isNotEmpty ? entry.seasons : '1 Season',
      episodes: entry.episodes.isNotEmpty ? entry.episodes : '12 Episodes',
      studio: entry.studio.isNotEmpty ? entry.studio : '',
      genres: entry.genres.isNotEmpty ? entry.genres : 'Action, Fantasy',
      synopsis: entry.synopsis.isNotEmpty ? entry.synopsis : '',
    );

    setState(() {
      final updated = List<AnimeCarouselSlide>.from(_project.slides);
      final ctaIndex = updated.indexWhere((s) => s.type == SlideType.cta);
      if (ctaIndex != -1) {
        updated.insert(ctaIndex, newSlide);
        _activeSlideIndex = ctaIndex;
      } else {
        updated.add(newSlide);
        _activeSlideIndex = updated.length - 1;
      }
      _project = _project.copyWith(slides: updated);
    });
  }

  Future<void> _fillAllSlidesFromDb() async {
    int updatedCount = 0;
    final updatedSlides = List<AnimeCarouselSlide>.from(_project.slides);

    for (int i = 0; i < updatedSlides.length; i++) {
      final s = updatedSlides[i];
      if (s.type != SlideType.anime || s.animeName.trim().isEmpty) continue;
      final entry = await AnimeDatabaseService.instance.findByName(s.animeName);
      if (entry != null) {
        updatedSlides[i] = s.copyWith(
          animeName: entry.name,
          japaneseName: entry.japaneseName.isNotEmpty ? entry.japaneseName : s.japaneseName,
          rating: entry.rating.isNotEmpty ? entry.rating : s.rating,
          seasons: entry.seasons.isNotEmpty ? entry.seasons : s.seasons,
          episodes: entry.episodes.isNotEmpty ? entry.episodes : s.episodes,
          studio: entry.studio.isNotEmpty ? entry.studio : s.studio,
          genres: entry.genres.isNotEmpty ? entry.genres : s.genres,
          synopsis: entry.synopsis.isNotEmpty ? entry.synopsis : s.synopsis,
        );
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      setState(() {
        _project = _project.copyWith(slides: updatedSlides);
      });
    }
  }

  void _showJsonImportSheet() {
    AnimeJsonImportSheet.show(
      context: context,
      currentProject: _project,
      onProjectImported: (newProject) {
        setState(() {
          _project = newProject;
          _activeSlideIndex = 0;
          _activeComponentKey = null;
        });
      },
      onShowToast: (msg) => _showToast(msg),
    );
  }

  void _showImageOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              title: const Text('AI Auto-Fill with JSON', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Paste ChatGPT/Gemini JSON to populate all slides instantly'),
              onTap: () {
                Navigator.pop(ctx);
                _showJsonImportSheet();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              title: const Text('Auto-Match Images by Anime Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Automatically set slide images from tagged library assets'),
              onTap: () {
                Navigator.pop(ctx);
                _autoMatchImagesByAnimeTags();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Pick Image for Slide ${_activeSlideIndex + 1}'),
              subtitle: const Text('Select a single visual background from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForActiveSlide();
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_rounded, color: Colors.indigo),
              title: const Text('Bulk Import Images (All Slides)'),
              subtitle: const Text('Select multiple images to auto-fill slides in order'),
              onTap: () {
                Navigator.pop(ctx);
                _pickBulkImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded, color: Colors.deepOrange),
              title: const Text('Rearrange Slide Images'),
              subtitle: const Text('Drag and align mismatched images across slides'),
              onTap: () {
                Navigator.pop(ctx);
                _showImageReorderSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onAddAnimeSlide() {
    final animeCount = _project.slides.where((s) => s.type == SlideType.anime).length;
    final newRank = animeCount + 1;
    final newSlide = AnimeCarouselSlide(
      id: 'slide_${DateTime.now().millisecondsSinceEpoch}',
      type: SlideType.anime,
      rank: newRank,
      animeName: 'New Anime Recommendation',
      japaneseName: 'Title in Japanese',
      rating: '8.5 / 10',
      seasons: '1 Season',
      episodes: '12 Episodes',
      studio: 'Studio Name',
      genres: 'Action, Fantasy',
      synopsis: 'Add a compelling synopsis or review snippet here...',
    );

    setState(() {
      final updated = List<AnimeCarouselSlide>.from(_project.slides);
      final ctaIndex = updated.indexWhere((s) => s.type == SlideType.cta);
      if (ctaIndex != -1) {
        updated.insert(ctaIndex, newSlide);
        _activeSlideIndex = ctaIndex;
      } else {
        updated.add(newSlide);
        _activeSlideIndex = updated.length - 1;
      }
      _project = _project.copyWith(slides: updated);
    });
  }

  void _onDeleteSlide(int index) {
    if (_project.slides.length <= 3) {
      return;
    }

    setState(() {
      final updated = List<AnimeCarouselSlide>.from(_project.slides);
      updated.removeAt(index);

      // Re-index ranks
      int rank = 1;
      for (int i = 0; i < updated.length; i++) {
        if (updated[i].type == SlideType.anime) {
          updated[i] = updated[i].copyWith(rank: rank);
          rank++;
        }
      }

      _project = _project.copyWith(slides: updated);
      if (_activeSlideIndex >= updated.length) {
        _activeSlideIndex = updated.length - 1;
      }
    });
  }

  Future<void> _exportCarousel() async {
    setState(() => _isExporting = true);

    final progressNotifier = ValueNotifier<(int, int, String)>(
      (0, _project.slides.length, 'Starting export...'),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ValueListenableBuilder<(int, int, String)>(
              valueListenable: progressNotifier,
              builder: (ctx, progress, _) {
                final current = progress.$1;
                final total = progress.$2;
                final status = progress.$3;
                final progressVal = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Exporting Carousel Post',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(
                      value: progressVal,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      status,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$current of $total slides',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    try {
      final savedPaths = await AnimeCarouselExportService.exportAllSlides(
        project: _project,
        repaintKey: _slideRepaintKey,
        onSwitchSlide: (targetIdx) async {
          setState(() => _activeSlideIndex = targetIdx);
        },
        onProgress: (current, total, status) {
          progressNotifier.value = (current, total, status);
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (savedPaths.isNotEmpty) {
        AdService().showInterstitialAd();
        AppReviewService().incrementExportCount();
        AppReviewService().checkAndRequestReview();

        _showToast(
          'Exported ${savedPaths.length} slides to Downloads/Quick Post Backup & Gallery!',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportSingleSlide() async {
    setState(() => _isExporting = true);
    try {
      final path = await AnimeCarouselExportService.exportSingleSlide(
        project: _project,
        slideIndex: _activeSlideIndex,
        repaintKey: _slideRepaintKey,
      );
      if (path != null) {
        AdService().showInterstitialAd();
        _showToast('Current slide exported to Downloads/Quick Post Backup!', isSuccess: true);
      }
    } catch (e) {
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportPresetsZip() async {
    try {
      final path = await AnimePostPresetService.exportPresetsToFile();
      _showToast('Presets exported to $path', isSuccess: true);
    } catch (e) {
      _showToast('Export preset failed: $e', isError: true);
    }
  }

  Future<void> _importPresetsZip() async {
    try {
      await AnimePostPresetService.importPresetsFromFile();
    } catch (e) {
      // Import error silently handled
    }
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reset Carousel?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will reset all slides and template styles back to default "Top 5 Action Anime of All Time".',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _project = AnimeCarouselProject.createDefault();
                _activeSlideIndex = 0;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      type: isError
          ? ToastificationType.error
          : (isSuccess ? ToastificationType.success : ToastificationType.info),
      style: ToastificationStyle.fillColored,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _project.theme;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Live Interactive Preview Canvas (Direct 100% lag-free element dragging)
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      physics: _isDraggingCanvas
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: AnimeSlidePreview(
                        repaintKey: _slideRepaintKey,
                        slide: _activeSlide,
                        theme: theme,
                        slideIndex: _activeSlideIndex,
                        totalSlides: _project.slides.length,
                        isInteractive: !_isExporting,
                        activeComponentKey: _isExporting ? null : _activeComponentKey,
                        showSelectionOverlay: _showSelectionOverlay,
                        onSelectComponent: (key) => setState(() => _activeComponentKey = key),
                        onDragComponent: _onDragComponent,
                        onDragContent: _onDragContent,
                        onDragHeader: _onDragHeader,
                        onDragStart: () => setState(() => _isDraggingCanvas = true),
                        onDragEnd: () => setState(() => _isDraggingCanvas = false),
                        onTapCanvas: () {
                          if (_activeComponentKey != null) {
                            setState(() => _activeComponentKey = null);
                          }
                        },
                      ),
                    ),
                  ),
                  // Floating Toggle: Clean Preview / Selection Box
                  Positioned(
                    top: 10,
                    right: 14,
                    child: _buildSelectionOverlayToggle(),
                  ),
                ],
              ),
            ),

            // 2. Slide Selector Strip (Ribbon of slides + Add Slide button)
            SlideSelectorStrip(
              slides: _project.slides,
              activeIndex: _activeSlideIndex,
              theme: theme,
              onSelectSlide: _onSelectSlide,
              onAddAnimeSlide: _onAddAnimeSlide,
              onDeleteSlide: _onDeleteSlide,
            ),

            // 3. Bottom Controls Section matching ImagePostMakerScreen
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOverlayToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showSelectionOverlay = !_showSelectionOverlay;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _showSelectionOverlay
                ? Colors.white.withValues(alpha: 0.92)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _showSelectionOverlay
                  ? Colors.grey.shade300
                  : AppColors.primaryDark,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showSelectionOverlay ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 13,
                color: _showSelectionOverlay ? AppColors.textPrimary : Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                _showSelectionOverlay ? 'Selection Box' : 'Clean Preview',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _showSelectionOverlay ? AppColors.textPrimary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expandable drawer panel
          if (_isTabContentExpanded)
            Container(
              height: 230,
              color: Colors.white,
              child: _buildActiveTabContent(),
            ),

          // Control Tabs Ribbon matching ImagePostMakerScreen
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Export button on left
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              onPressed: _exportCarousel,
              icon: const Icon(Icons.file_download_rounded, size: 16),
              label: const Text('Export All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),

          // Scrollable control tabs
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(11, Icons.auto_awesome, 'AI JSON', Colors.purple, customOnTap: _showJsonImportSheet),
                _buildTabItem(15, Icons.storage_rounded, 'Database', Colors.indigo),
                _buildTabItem(0, Icons.edit_note, 'Content', Colors.indigo),
                _buildTabItem(1, Icons.photo_library, 'Image', AppColors.primary),
                _buildTabItem(14, Icons.collections_bookmark_rounded, 'Assets', Colors.teal),
                _buildTabItem(2, Icons.dashboard_customize_rounded, 'Layouts', Colors.purple),
                _buildTabItem(3, Icons.view_quilt_rounded, 'Elements', Colors.teal),
                _buildTabItem(16, Icons.style_rounded, 'Elem Styles', Colors.deepOrange),
                _buildTabItem(4, Icons.open_with_rounded, 'Position', Colors.blue),
                _buildTabItem(12, Icons.font_download_rounded, 'Fonts', Colors.deepPurple),
                _buildTabItem(13, Icons.palette_rounded, 'Colors', Colors.pinkAccent),
                _buildTabItem(5, Icons.layers_rounded, 'Card & Box', Colors.indigo),
                _buildTabItem(6, Icons.branding_watermark_rounded, 'Branding', Colors.amber),
                _buildTabItem(7, Icons.aspect_ratio_rounded, 'Canvas', AppColors.primary),
                _buildTabItem(8, Icons.stars_rounded, 'Presets', Colors.pink),
                _buildTabItem(9, Icons.image_outlined, 'Exp Slide', Colors.blueGrey, customOnTap: _exportSingleSlide),
                _buildTabItem(10, Icons.refresh_rounded, 'Reset', Colors.redAccent, customOnTap: _resetToDefault),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    IconData icon,
    String label,
    Color accent, {
    VoidCallback? customOnTap,
  }) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        if (customOnTap != null) {
          customOnTap();
          return;
        }
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
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accent : Colors.grey.shade600,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accent : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return SlideDataEditor(
          slide: _activeSlide,
          slideIndex: _activeSlideIndex,
          allSlides: _project.slides,
          theme: _project.theme,
          onSlideChanged: _onSlideDataChanged,
          onBulkImportImages: _pickBulkImages,
          onRearrangeImages: _showImageReorderSheet,
          onSwapWithSlide: (targetIdx) => _swapSlideImages(_activeSlideIndex, targetIdx),
          onOpenAiImportSheet: _showJsonImportSheet,
          onAutoMatchAllSlides: _autoMatchImagesByAnimeTags,
        );

      case 15:
        return AnimeDatabasePanel(
          onApplyToSlide: _applyDbEntryToSlide,
          onAddAsSlide: _addDbEntryAsSlide,
          onFillAllSlides: _fillAllSlidesFromDb,
          onShowToast: (msg, {isError = false, isSuccess = false}) =>
              _showToast(msg, isError: isError, isSuccess: isSuccess),
        );

      case 1:
        return _buildImageTabContent();

      case 14:
        return AnimeAssetStoragePanel(
          activeSlide: _activeSlide,
          allSlides: _project.slides,
          onSelectImage: (path) {
            _onSlideDataChanged(_activeSlide.copyWith(imagePath: path));
          },
          onOpenFullLibrary: _openAssetLibrary,
          onAutoMatchSlides: _autoMatchImagesByAnimeTags,
          onShowToast: (msg, {isError = false, isSuccess = false}) =>
              _showToast(msg, isError: isError, isSuccess: isSuccess),
        );

      case 2:
        return AnimeLayoutsPanel(
          activeSlide: _activeSlide,
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          onApplyLayout: _applyCustomLayout,
          onResetToDefault: _resetToDefaultLayout,
          onToggleSync: _onToggleSyncLayoutAndPosition,
          onSelectSlideLayout: _onSelectSlideLayout,
          onShowToast: (msg) => _showToast(msg),
        );

      case 3:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.components,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 16:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.elementStyles,
          activeSlide: _activeSlide,
          activeComponentKey: _isExporting ? null : _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          showSelectionOverlay: _showSelectionOverlay,
          onToggleSelectionOverlay: (val) => setState(() => _showSelectionOverlay = val),
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 4:
        return SlidePositionPanel(
          slide: _activeSlide,
          theme: _project.theme,
          activeComponentKey: _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          onSlideChanged: _onSlideDataChanged,
          onApplyToAll: _applyPositionToAllSlides,
          onReset: () => _resetSlidePosition(),
          onResetComponent: (key) => _resetSlidePosition(componentKey: key),
          syncAnimeSlideLayoutAndPosition: _project.theme.syncAnimeSlideLayoutAndPosition,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 5:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.card,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 12:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.fonts,
          activeSlide: _activeSlide,
          activeComponentKey: _isExporting ? null : _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          showSelectionOverlay: _showSelectionOverlay,
          onToggleSelectionOverlay: (val) => setState(() => _showSelectionOverlay = val),
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 13:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.colors,
          activeSlide: _activeSlide,
          activeComponentKey: _isExporting ? null : _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          showSelectionOverlay: _showSelectionOverlay,
          onToggleSelectionOverlay: (val) => setState(() => _showSelectionOverlay = val),
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 6:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.branding,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 7:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.canvas,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 8:
        return _buildPresetsTabContent();

      default:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.all,
          activeSlide: _activeSlide,
          onSelectSlideLayout: _onSelectSlideLayout,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );
    }
  }

  Widget _buildImageTabContent() {
    final hasImage = _activeSlide.imagePath != null && File(_activeSlide.imagePath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Slide Image Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade200,
                    child: hasImage
                        ? Image.file(File(_activeSlide.imagePath!), fit: BoxFit.cover)
                        : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Slide ${_activeSlideIndex + 1} Image',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasImage ? File(_activeSlide.imagePath!).path.split('/').last : 'No image loaded',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageForActiveSlide,
                  icon: const Icon(Icons.photo_library_outlined, size: 14),
                  label: Text(hasImage ? 'Change' : 'Pick Image', style: const TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.primary, size: 20),
                    tooltip: 'Tag & Save to Storage',
                    onPressed: _saveActiveSlideToAssetStorage,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'Remove Image',
                    onPressed: () {
                      _onSlideDataChanged(_activeSlide.copyWith(clearImagePath: true));
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                  tooltip: 'Image Options',
                  onPressed: _showImageOptionsSheet,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Shortcut to Assets Tab
          InkWell(
            onTap: () {
              setState(() {
                _selectedTabIndex = 14;
                _isTabContentExpanded = true;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.collections_bookmark_rounded, size: 16, color: Colors.teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Browse Anime Asset Storage Library',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.teal),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.teal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Auto-Match, Bulk Import & Rearrange
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _autoMatchImagesByAnimeTags,
                  icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B5CF6)),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Auto-Match', style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickBulkImages,
                  icon: const Icon(Icons.collections_rounded, size: 14, color: Colors.indigo),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Bulk Import', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.indigo.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImageReorderSheet,
                  icon: const Icon(Icons.swap_vert_rounded, size: 15, color: Colors.deepOrange),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Rearrange', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Background Blur Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Background Image Blur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(4)),
                child: Text('${_project.theme.backgroundBlur.toInt()}px', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Slider(
            value: _project.theme.backgroundBlur.clamp(0.0, 20.0),
            min: 0.0,
            max: 20.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) {
              _onThemeChanged(_project.theme.copyWith(backgroundBlur: val));
            },
          ),

          // Vignette Darkness Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cinematic Dark Overlay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(4)),
                child: Text('${(_project.theme.gradientDarkness * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Slider(
            value: _project.theme.gradientDarkness.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) {
              _onThemeChanged(_project.theme.copyWith(gradientDarkness: val));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preset Management & Backup',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _exportPresetsZip,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.pink.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.file_upload_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Zip',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Save presets to file',
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _importPresetsZip,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.file_download_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Import Zip',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Load preset files',
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Visual Theme Presets',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickPresetChip(
                  label: 'Clean Minimal',
                  icon: Icons.light_mode_outlined,
                  color: Colors.teal,
                  onTap: () {
                    _onThemeChanged(_project.theme.copyWith(
                      canvasBgColor: Colors.white,
                      cardStyle: CardStyle.none,
                      showCardBackdrop: false,
                      accentColor: const Color(0xFF009688),
                      titleFontFamily: 'Poppins',
                      bodyFontFamily: 'Poppins',
                      titleTextColor: const Color(0xFF1E293B),
                      bodyTextColor: const Color(0xFF475569),
                      rankBadgeStyle: RankBadgeStyle.minimalOutlined,
                      metadataPillStyle: MetadataPillStyle.minimalClean,
                      synopsisCardStyle: SynopsisCardStyle.cleanMinimalQuote,
                      titleCardStyle: TitleCardStyle.pureText,
                    ));
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPresetChip(
                  label: 'Frosted Glass',
                  icon: Icons.blur_on_rounded,
                  color: Colors.blue,
                  onTap: () {
                    _onThemeChanged(_project.theme.copyWith(
                      cardStyle: CardStyle.glassmorphismBottom,
                      showCardBackdrop: true,
                      cardBgColor: const Color(0xFF0D0D12),
                      cardOpacity: 0.82,
                      cardBlur: 14.0,
                      accentColor: const Color(0xFF00E5FF),
                      rankBadgeStyle: RankBadgeStyle.glassPill,
                      metadataPillStyle: MetadataPillStyle.frostedGlass,
                      synopsisCardStyle: SynopsisCardStyle.frostedGlassCard,
                      titleCardStyle: TitleCardStyle.pureText,
                    ));
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPresetChip(
                  label: 'Editorial Mag',
                  icon: Icons.menu_book_rounded,
                  color: Colors.deepOrange,
                  onTap: () {
                    _onThemeChanged(_project.theme.copyWith(
                      cardStyle: CardStyle.editorialMagazine,
                      showCardBackdrop: true,
                      cardBgColor: const Color(0xFF111827),
                      accentColor: const Color(0xFFFF5722),
                      titleCardStyle: TitleCardStyle.accentUnderline,
                      rankBadgeStyle: RankBadgeStyle.boldRibbon,
                      metadataPillStyle: MetadataPillStyle.outlinedChip,
                      synopsisCardStyle: SynopsisCardStyle.editorialStrip,
                    ));
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPresetChip(
                  label: 'Solid Accent',
                  icon: Icons.palette_outlined,
                  color: Colors.purple,
                  onTap: () {
                    _onThemeChanged(_project.theme.copyWith(
                      accentColor: const Color(0xFF8B5CF6),
                      rankBadgeStyle: RankBadgeStyle.modernGradient,
                      metadataPillStyle: MetadataPillStyle.solidAccent,
                      synopsisCardStyle: SynopsisCardStyle.accentBorderLeft,
                      titleCardStyle: TitleCardStyle.pureText,
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
