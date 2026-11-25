import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/chat_conversation.dart';
import 'models/chat_message.dart';
import 'models/chat_platform.dart';
import 'services/dummy_chat_service.dart';
import 'widgets/chat_canvas_view.dart';

/// Dummy Chat Creator Studio:
/// - Generates pixel-perfect mockups of iMessage, Instagram DMs, and WhatsApp
/// - Watermark-screen-style integrated control tabs (Profile, Add Msg, Platform, Messages)
/// - Custom avatars, contact names, verified badges, battery level, status timestamps
/// - Left (received) vs Right (sent) message bubbles with photo attachments & emoji reactions
/// - High-resolution 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Dummy Chats
class DummyChatMakerScreen extends StatefulWidget {
  const DummyChatMakerScreen({super.key});

  @override
  State<DummyChatMakerScreen> createState() => _DummyChatMakerScreenState();
}

class _DummyChatMakerScreenState extends State<DummyChatMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  ChatConversation _conversation = ChatConversation.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Header/Profile Controllers
  late TextEditingController _contactNameController;
  late TextEditingController _statusSubtextController;
  late TextEditingController _clockTimeController;

  // New Message Composer Controllers
  late TextEditingController _msgTextController;
  late TextEditingController _msgTimeController;
  late TextEditingController _msgStatusController;
  bool _newMsgIsOutgoing = false;
  String? _newMsgReaction;
  String? _newMsgImagePath;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Dummy Chat Creator');
    _contactNameController = TextEditingController(text: _conversation.contactName);
    _statusSubtextController = TextEditingController(text: _conversation.statusSubtext);
    _clockTimeController = TextEditingController(text: _conversation.clockTime);

    _msgTextController = TextEditingController();
    _msgTimeController = TextEditingController(text: '9:41 PM');
    _msgStatusController = TextEditingController();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _statusSubtextController.dispose();
    _clockTimeController.dispose();
    _msgTextController.dispose();
    _msgTimeController.dispose();
    _msgStatusController.dispose();
    super.dispose();
  }

  void _syncAllFromConversation(ChatConversation conv) {
    _contactNameController.text = conv.contactName;
    _statusSubtextController.text = conv.statusSubtext;
    _clockTimeController.text = conv.clockTime;
  }

  Future<void> _pickAvatar() async {
    final file = await DummyChatService().pickImage();
    if (file != null && mounted) {
      setState(() => _conversation = _conversation.copyWith(contactAvatarPath: file.path));
    }
  }

  Future<void> _pickMsgAttachment() async {
    final file = await DummyChatService().pickImage();
    if (file != null && mounted) {
      setState(() => _newMsgImagePath = file.path);
    }
  }

  void _addMessage() {
    if (_msgTextController.text.trim().isEmpty && _newMsgImagePath == null) return;
    HapticFeedback.selectionClick();

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: _msgTextController.text.trim(),
      isOutgoing: _newMsgIsOutgoing,
      time: _msgTimeController.text.trim().isNotEmpty ? _msgTimeController.text.trim() : '9:41 PM',
      status: _newMsgIsOutgoing && _msgStatusController.text.trim().isNotEmpty
          ? _msgStatusController.text.trim()
          : 'Delivered',
      reaction: _newMsgReaction,
      imagePath: _newMsgImagePath,
    );

    setState(() {
      _conversation = _conversation.copyWith(
        messages: [..._conversation.messages, newMsg],
      );
      _msgTextController.clear();
      _newMsgImagePath = null;
      _newMsgReaction = null;
    });
  }

  void _deleteMessage(ChatMessage message) {
    HapticFeedback.selectionClick();
    setState(() {
      _conversation = _conversation.copyWith(
        messages: _conversation.messages.where((m) => m.id != message.id).toList(),
      );
    });
  }

  Future<void> _exportScreenshot() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await DummyChatService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await DummyChatService().saveChatScreenshotToGallery(
        pngBytes,
        _conversation.contactName,
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
                    'Chat screenshot saved to Gallery! (Pictures/Quick Post Dummy Chats)',
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
      debugPrint('Error capturing screenshot: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareScreenshot() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await DummyChatService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await DummyChatService().saveChatScreenshotToGallery(
          pngBytes,
          _conversation.contactName,
        );
      }
    }

    if (_lastSavedPath != null) {
      await DummyChatService().shareChatScreenshot(_lastSavedPath!);
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
          'Dummy Chat Creator',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<ChatConversation>(
            tooltip: 'Load Viral Story Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _conversation = template;
                _syncAllFromConversation(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL STORY PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...ChatConversation.samplePresets.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Icon(preset.platform.icon, size: 16, color: preset.platform.brandColor),
                      const SizedBox(width: 10),
                      Text(preset.contactName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
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
                  constraints: const BoxConstraints(maxWidth: 390, maxHeight: 600),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 360,
                        height: 620,
                        child: ChatCanvasView(
                          conversation: _conversation,
                          onEditMessage: (_) {},
                          onDeleteMessage: _deleteMessage,
                        ),
                      ),
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
          _buildTabItem(0, Icons.person_pin_rounded, 'Profile', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.add_comment_rounded, 'Add Msg', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.devices_rounded, 'Platform', const Color(0xFF8B5CF6)),
          _buildTabItem(3, Icons.format_list_bulleted_rounded, 'Messages', const Color(0xFFF59E0B)),
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
        width: 84,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
        return _buildProfileTab();
      case 1:
        return _buildAddMessageTab();
      case 2:
        return _buildPlatformTab();
      case 3:
        return _buildMessagesListTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Profile & Status Header ───
  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _conversation.contactAvatarPath != null && File(_conversation.contactAvatarPath!).existsSync()
                        ? FileImage(File(_conversation.contactAvatarPath!))
                        : null,
                    child: _conversation.contactAvatarPath == null
                        ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 22)
                        : null,
                  ),
                  if (_conversation.contactAvatarPath != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _conversation = _conversation.copyWith(contactAvatarPath: null));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _contactNameController,
                    decoration: InputDecoration(
                      labelText: 'Contact Name / Title',
                      labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _conversation = _conversation.copyWith(contactName: val)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _statusSubtextController,
                    decoration: InputDecoration(
                      labelText: 'Status Subtext (e.g. Active now, online)',
                      labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _conversation = _conversation.copyWith(statusSubtext: val)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Verified Blue Badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _conversation.isVerified,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _conversation = _conversation.copyWith(isVerified: val)),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _clockTimeController,
                decoration: InputDecoration(
                  labelText: 'Clock Time (e.g. 9:41)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _conversation = _conversation.copyWith(clockTime: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Text('Battery: ${_conversation.batteryPercent}%', style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                  Expanded(
                    child: Slider(
                      value: _conversation.batteryPercent.toDouble(),
                      min: 1,
                      max: 100,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _conversation = _conversation.copyWith(batteryPercent: val.round())),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 1: Add New Message Composer ───
  Widget _buildAddMessageTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Them (Left Bubble)', style: TextStyle(fontSize: 11, fontFamily: 'Poppins'))),
                selected: !_newMsgIsOutgoing,
                selectedColor: AppColors.primarySurface,
                onSelected: (_) => setState(() => _newMsgIsOutgoing = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Me (Right Bubble)', style: TextStyle(fontSize: 11, fontFamily: 'Poppins'))),
                selected: _newMsgIsOutgoing,
                selectedColor: AppColors.primarySurface,
                onSelected: (_) => setState(() => _newMsgIsOutgoing = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _msgTextController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Message text...',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgTimeController,
                decoration: InputDecoration(
                  labelText: 'Time (e.g. 9:41 PM)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
              ),
            ),
            const SizedBox(width: 8),
            if (_newMsgIsOutgoing) ...[
              Expanded(
                child: TextField(
                  controller: _msgStatusController,
                  decoration: InputDecoration(
                    labelText: 'Status (e.g. Read)',
                    labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: Text(_newMsgImagePath != null ? 'Photo Attached' : 'Photo', style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: _pickMsgAttachment,
            ),
            if (_newMsgImagePath != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                onPressed: () => setState(() => _newMsgImagePath = null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Reaction:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(width: 6),
            ...['❤️', '🔥', '😂', '👍', '😮'].map((emoji) {
              final isSelected = _newMsgReaction == emoji;
              return GestureDetector(
                onTap: () => setState(() => _newMsgReaction = isSelected ? null : emoji),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _addMessage,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 2: Platform & Appearance ───
  Widget _buildPlatformTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MESSAGING PLATFORM',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: ChatPlatform.values.map((p) {
            final isSelected = _conversation.platform == p;
            return ChoiceChip(
              avatar: Icon(p.icon, size: 16, color: isSelected ? AppColors.primary : p.brandColor),
              label: Text(p.name, style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) => setState(() => _conversation = _conversation.copyWith(platform: p)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode Interface', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                Text('Toggle OLED dark or clean light chat theme', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ],
            ),
            Switch(
              value: _conversation.isDarkMode,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _conversation = _conversation.copyWith(isDarkMode: val)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 3: Messages List Management ───
  Widget _buildMessagesListTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Conversation Messages (${_conversation.messages.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            if (_conversation.messages.isNotEmpty)
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _conversation = _conversation.copyWith(messages: []));
                },
                child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Poppins')),
              ),
          ],
        ),
        if (_conversation.messages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No messages yet. Use the "Add Msg" tab to start chatting!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Poppins')),
            ),
          )
        else
          ..._conversation.messages.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.isOutgoing ? AppColors.primarySurface : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      m.isOutgoing ? 'Me' : 'Them',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: m.isOutgoing ? AppColors.primary : Colors.grey.shade800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.text.isNotEmpty ? m.text : '[Photo Attachment]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                    ),
                  ),
                  if (m.reaction != null) ...[
                    Text(m.reaction!, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    onPressed: () => _deleteMessage(m),
                  ),
                ],
              ),
            );
          }),
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
                  _conversation = ChatConversation.initialDefault;
                  _syncAllFromConversation(_conversation);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share screenshot',
              onPressed: _isSaving ? null : _shareScreenshot,
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
                onPressed: _isSaving ? null : _exportScreenshot,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
