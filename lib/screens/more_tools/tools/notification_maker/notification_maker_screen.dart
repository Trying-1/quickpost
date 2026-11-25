import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/notification_model.dart';
import 'services/notification_service.dart';
import 'widgets/notification_canvas_view.dart';

/// Push Notification & Lock Screen Studio:
/// - Generates realistic iOS / modern push notification alerts for hook videos & stories
/// - Watermark-screen-style integrated control tabs (Alerts, LockScreen, Style, Format, Wallpaper)
/// - Multiple aspect ratios: 9:16 Lock Screen, 4:5 Feed Portrait, 1:1 Square, or Card Only for video overlays
/// - Realistic banking deposit alerts, direct messages, subscriber milestones & viral hooks
/// - Multiple stacked notifications effect
/// - Customizable clock, date header, dynamic island cutout, and bottom lock screen shortcuts
/// - Uncompressed 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Notifications
class NotificationMakerScreen extends StatefulWidget {
  const NotificationMakerScreen({super.key});

  @override
  State<NotificationMakerScreen> createState() => _NotificationMakerScreenState();
}

class _NotificationMakerScreenState extends State<NotificationMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  NotificationPost _post = NotificationPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;
  int _activeItemIndex = 0;

  // Text controllers
  late TextEditingController _clockTimeController;
  late TextEditingController _clockDateController;
  late TextEditingController _appNameController;
  late TextEditingController _timeHeaderController;
  late TextEditingController _titleController;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Notification Studio');
    _clockTimeController = TextEditingController(text: _post.clockTime);
    _clockDateController = TextEditingController(text: _post.clockDate);
    _initActiveItemControllers();
  }

  void _initActiveItemControllers() {
    final activeItem = _activeItem;
    _appNameController = TextEditingController(text: activeItem.customAppName);
    _timeHeaderController = TextEditingController(text: activeItem.timeHeader);
    _titleController = TextEditingController(text: activeItem.title);
    _messageController = TextEditingController(text: activeItem.message);
  }

  NotificationItem get _activeItem {
    if (_activeItemIndex >= _post.items.length) {
      _activeItemIndex = _post.items.isNotEmpty ? _post.items.length - 1 : 0;
    }
    return _post.items.isNotEmpty
        ? _post.items[_activeItemIndex]
        : const NotificationItem(id: 'default');
  }

  void _syncActiveItemControllers() {
    final activeItem = _activeItem;
    _appNameController.text = activeItem.customAppName;
    _timeHeaderController.text = activeItem.timeHeader;
    _titleController.text = activeItem.title;
    _messageController.text = activeItem.message;
  }

  void _syncAllFromPost(NotificationPost post) {
    _clockTimeController.text = post.clockTime;
    _clockDateController.text = post.clockDate;
    _activeItemIndex = 0;
    _syncActiveItemControllers();
  }

  @override
  void dispose() {
    _clockTimeController.dispose();
    _clockDateController.dispose();
    _appNameController.dispose();
    _timeHeaderController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _updateActiveItem(NotificationItem Function(NotificationItem) update) {
    if (_post.items.isEmpty) return;
    final updatedList = List<NotificationItem>.from(_post.items);
    updatedList[_activeItemIndex] = update(updatedList[_activeItemIndex]);
    setState(() {
      _post = _post.copyWith(items: updatedList);
    });
  }

  void _addNewNotification() {
    if (_post.items.length >= 4) return;
    final newItem = NotificationItem(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      appType: NotificationAppType.social,
      timeHeader: 'now',
      title: 'New Notification 🔔',
      message: 'Tap to view new activity update on your channel.',
    );
    setState(() {
      _post = _post.copyWith(items: [..._post.items, newItem]);
      _activeItemIndex = _post.items.length - 1;
      _syncActiveItemControllers();
    });
  }

  void _removeActiveNotification() {
    if (_post.items.length <= 1) return;
    final updatedList = List<NotificationItem>.from(_post.items);
    updatedList.removeAt(_activeItemIndex);
    setState(() {
      _post = _post.copyWith(items: updatedList);
      if (_activeItemIndex >= updatedList.length) {
        _activeItemIndex = updatedList.length - 1;
      }
      _syncActiveItemControllers();
    });
  }

  Future<void> _pickWallpaper() async {
    final file = await NotificationService().pickWallpaper();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(customWallpaperPath: file.path);
      });
    }
  }

  Future<void> _exportNotification() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await NotificationService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await NotificationService().saveNotificationToGallery(
        pngBytes,
        _post.items.isNotEmpty ? _post.items.first.title : 'Notification',
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
                    'Notification graphic saved to Gallery! (Pictures/Quick Post Notifications)',
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
      debugPrint('Error exporting notification: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareNotification() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await NotificationService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await NotificationService().saveNotificationToGallery(
          pngBytes,
          _post.items.isNotEmpty ? _post.items.first.title : 'Notification',
        );
      }
    }

    if (_lastSavedPath != null) {
      await NotificationService().shareNotification(_lastSavedPath!);
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
          'Push Notification Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<NotificationPost>(
            tooltip: 'Load Viral Notification Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _post = template;
                _syncAllFromPost(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL HOOK PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...NotificationPost.viralTemplates.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.items.first.appType.iconColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preset.items.first.title,
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
                    child: NotificationCanvasView(
                      post: _post,
                      onEditRequested: () {
                        setState(() {
                          _selectedTabIndex = 0;
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
          _buildTabItem(0, Icons.notifications_active_rounded, 'Alerts', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.lock_clock_rounded, 'LockScreen', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.tune_rounded, 'Style', const Color(0xFF8B5CF6)),
          _buildTabItem(3, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(4, Icons.wallpaper_rounded, 'Wallpaper', const Color(0xFFEC4899)),
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
        width: 76,
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
        return _buildAlertsTab();
      case 1:
        return _buildLockScreenTab();
      case 2:
        return _buildStyleTab();
      case 3:
        return _buildFormatTab();
      case 4:
        return _buildWallpaperTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Stacked Alerts Management ───
  Widget _buildAlertsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notification Item Selector Bar
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_post.items.length, (i) {
                    final isSelected = _activeItemIndex == i;
                    final item = _post.items[i];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _activeItemIndex = i;
                          _syncActiveItemControllers();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primarySurface : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(item.appType.icon, size: 14, color: item.appType.iconColor),
                            const SizedBox(width: 5),
                            Text(
                              'Alert #${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (_post.items.length < 4)
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                tooltip: 'Add stacked alert',
                onPressed: _addNewNotification,
              ),
            if (_post.items.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Delete this alert',
                onPressed: _removeActiveNotification,
              ),
          ],
        ),
        const SizedBox(height: 10),

        // App Archetype Selector
        const Text(
          'APP ARCHETYPE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: NotificationAppType.values.map((type) {
            final isSelected = _activeItem.appType == type;
            return ChoiceChip(
              avatar: Icon(type.icon, size: 14, color: type.iconColor),
              label: Text(type.name, style: const TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                _updateActiveItem((it) => it.copyWith(appType: type));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Title and Time Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Alert Title',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => _updateActiveItem((it) => it.copyWith(title: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _timeHeaderController,
                decoration: InputDecoration(
                  labelText: 'Time (e.g. now)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                onChanged: (val) => _updateActiveItem((it) => it.copyWith(timeHeader: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Body Message
        TextField(
          controller: _messageController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Alert Message Content',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => _updateActiveItem((it) => it.copyWith(message: val)),
        ),
      ],
    );
  }

  // ─── Tab 1: LockScreen Details ───
  Widget _buildLockScreenTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Lock & Clock Header', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.showLockHeader,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showLockHeader: val)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _clockTimeController,
                decoration: InputDecoration(
                  labelText: 'Clock Time',
                  labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(clockTime: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _clockDateController,
                decoration: InputDecoration(
                  labelText: 'Clock Date',
                  labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(clockDate: val)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 2: Style & Glassmorphism ───
  Widget _buildStyleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frosted Glassmorphism', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                Text('Realistic iOS blurred glass overlay', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ],
            ),
            Switch(
              value: _post.isGlassmorphic,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(isGlassmorphic: val)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 3: Aspect Ratio / Format ───
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
          children: NotificationRatio.values.map((ratio) {
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
      ],
    );
  }

  // ─── Tab 4: Wallpaper & Background ───
  Widget _buildWallpaperTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOCK SCREEN WALLPAPERS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: NotificationWallpaperPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = NotificationWallpaperPreset.presets[index];
              final isSelected = _post.wallpaperIndex == index && _post.customWallpaperPath == null;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _post = _post.copyWith(wallpaperIndex: index, clearWallpaper: true);
                  });
                },
                child: Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: preset.colors,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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
                  _post.customWallpaperPath != null ? 'Change Custom Wallpaper' : 'Custom Photo Wallpaper',
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
                  _post = NotificationPost.initialDefault;
                  _syncAllFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share notification',
              onPressed: _isSaving ? null : _shareNotification,
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
                onPressed: _isSaving ? null : _exportNotification,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
