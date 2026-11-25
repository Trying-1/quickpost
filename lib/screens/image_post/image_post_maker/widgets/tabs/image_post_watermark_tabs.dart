import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../config/app_theme.dart';
import '../image_post_shared_controls.dart';

/// Watermark Type tab panel (index 0): Standard, Vertical, Social, Wire, Minimal, Logo, None.
class ImagePostTypeTab extends StatelessWidget {
  final String watermarkType;
  final ValueChanged<String> onTypeSelected;

  const ImagePostTypeTab({
    super.key,
    required this.watermarkType,
    required this.onTypeSelected,
  });

  static const _options = [
    ('profile', 'Standard', 'Icon + Text (H)'),
    ('profile_vertical', 'Vertical', 'Icon + Text (V)'),
    ('profile_dots', 'Social', 'Standard + Menu'),
    ('wire', 'Wire', 'Line + Bottom Text'),
    ('text', 'Minimal', 'Text Only'),
    ('image', 'Logo', 'Image Only'),
    ('none', 'None', 'Disable All'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Watermark Type',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _options
                .map((opt) => _buildTypeChip(opt.$1, opt.$2, opt.$3))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, String sub) {
    final isSelected = watermarkType == type;

    return GestureDetector(
      onTap: () => onTypeSelected(type),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: _buildMiniPreview(type)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPreview(String type) {
    switch (type) {
      case 'none':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, color: Colors.grey, size: 24),
            SizedBox(height: 4),
            Text(
              'No Watermark',
              style: TextStyle(color: Colors.grey, fontSize: 8),
            ),
          ],
        );
      case 'profile':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: AppColors.primary),
            SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '@handle',
                  style: TextStyle(fontSize: 4, color: Colors.black38),
                ),
              ],
            ),
          ],
        );
      case 'profile_vertical':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 8, backgroundColor: AppColors.primary),
            SizedBox(height: 4),
            Text(
              'Username',
              style: TextStyle(
                fontSize: 5,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            Text(
              '@handle',
              style: TextStyle(fontSize: 4, color: Colors.black38),
            ),
          ],
        );
      case 'profile_dots':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 6, backgroundColor: AppColors.primary),
            const SizedBox(width: 4),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '@handle',
                  style: TextStyle(fontSize: 4, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 8),
          ],
        );
      case 'text':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Text(
            'ABC',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
            ),
          ),
        );
      case 'image':
        return const Icon(Icons.image, size: 20, color: Colors.black26);
      case 'wire':
        return Container(
          width: 30,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26, width: 0.5),
          ),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'User',
                style: TextStyle(fontSize: 4, color: Colors.black54),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Content / Branding tab panel (index 1): username, handle, profile icon, background box, story ring, verified badge.
class ImagePostProfileTab extends StatelessWidget {
  final String watermarkType;
  final TextEditingController usernameController;
  final TextEditingController handleController;
  final File? profileImage;
  final bool showBox;
  final String boxColor;
  final double boxOpacity;
  final double boxRadius;
  final bool showStoryRing;
  final bool isCustomRingColor;
  final double storyRingWidth;
  final String storyRingColor;
  final bool isVerified;
  final String verifiedBadgeAttachTo;
  final String verifiedBadgeColor;

  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onHandleChanged;
  final VoidCallback onPickProfileImage;
  final ValueChanged<bool> onShowBoxChanged;
  final ValueChanged<String> onBoxColorChanged;
  final ValueChanged<double> onBoxOpacityChanged;
  final ValueChanged<double> onBoxRadiusChanged;
  final ValueChanged<bool> onShowStoryRingChanged;
  final ValueChanged<bool> onRingStyleChanged;
  final ValueChanged<double> onStoryRingWidthChanged;
  final ValueChanged<String> onStoryRingColorChanged;
  final ValueChanged<bool> onVerifiedChanged;
  final ValueChanged<String> onVerifiedAttachToChanged;
  final ValueChanged<String> onVerifiedBadgeColorChanged;

  const ImagePostProfileTab({
    super.key,
    required this.watermarkType,
    required this.usernameController,
    required this.handleController,
    required this.profileImage,
    required this.showBox,
    required this.boxColor,
    required this.boxOpacity,
    required this.boxRadius,
    required this.showStoryRing,
    required this.isCustomRingColor,
    required this.storyRingWidth,
    required this.storyRingColor,
    required this.isVerified,
    required this.verifiedBadgeAttachTo,
    required this.verifiedBadgeColor,
    required this.onUsernameChanged,
    required this.onHandleChanged,
    required this.onPickProfileImage,
    required this.onShowBoxChanged,
    required this.onBoxColorChanged,
    required this.onBoxOpacityChanged,
    required this.onBoxRadiusChanged,
    required this.onShowStoryRingChanged,
    required this.onRingStyleChanged,
    required this.onStoryRingWidthChanged,
    required this.onStoryRingColorChanged,
    required this.onVerifiedChanged,
    required this.onVerifiedAttachToChanged,
    required this.onVerifiedBadgeColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool showText = watermarkType == 'profile' ||
        watermarkType == 'profile_vertical' ||
        watermarkType == 'text' ||
        watermarkType == 'wire';
    final bool showHandle =
        watermarkType == 'profile' || watermarkType == 'profile_vertical';
    final bool showImage = watermarkType == 'profile' ||
        watermarkType == 'profile_vertical' ||
        watermarkType == 'image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Content Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (showText) ...[
          TextField(
            decoration: InputDecoration(
              labelText: watermarkType == 'text' ? 'Watermark Text' : 'Username',
              border: const OutlineInputBorder(),
            ),
            onChanged: onUsernameChanged,
            controller: usernameController,
          ),
          const SizedBox(height: 12),
        ],
        if (showHandle) ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Handle (@name)',
              border: OutlineInputBorder(),
            ),
            onChanged: onHandleChanged,
            controller: handleController,
          ),
          const SizedBox(height: 12),
        ],
        if (showImage)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: profileImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      profileImage!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.image, size: 40),
            title: Text(
              watermarkType == 'image' ? 'Select Logo Image' : 'Profile Icon',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onPickProfileImage,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Background Box',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Switch(value: showBox, onChanged: onShowBoxChanged),
          ],
        ),
        if (showBox) ...[
          const Text('Box Color'),
          const SizedBox(height: 8),
          ImagePostColorPicker(
            currentColor: boxColor,
            onPick: onBoxColorChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Opacity: ${(boxOpacity * 100).toInt()}%'),
                    ImagePostSliderWithButtons(
                      value: boxOpacity,
                      min: 0,
                      max: 1,
                      onChanged: onBoxOpacityChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Corner Radius: ${boxRadius.toInt()}'),
                    ImagePostSliderWithButtons(
                      value: boxRadius,
                      min: 0,
                      max: 100,
                      onChanged: onBoxRadiusChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        const ImagePostSectionHeader(title: 'Branding', icon: Icons.stars),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text(
            'Show Story Ring',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            isCustomRingColor
                ? 'Custom solid color circle'
                : 'Purple-Orange gradient circle',
            style: const TextStyle(fontSize: 12),
          ),
          value: showStoryRing,
          onChanged: onShowStoryRingChanged,
          secondary: const Icon(Icons.circle_outlined, color: AppColors.primary),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (showStoryRing)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pillButton(
                      isSelected: !isCustomRingColor,
                      label: 'Gradient',
                      onTap: () => onRingStyleChanged(false),
                    ),
                    const SizedBox(width: 8),
                    _pillButton(
                      isSelected: isCustomRingColor,
                      label: 'Custom',
                      onTap: () => onRingStyleChanged(true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ImagePostControlSlider(
                  label: 'Ring Width',
                  value: storyRingWidth,
                  min: 1.0,
                  max: 20.0,
                  onChanged: onStoryRingWidthChanged,
                ),
                if (isCustomRingColor) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Ring Color',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImagePostColorPicker(
                    currentColor: storyRingColor,
                    onPick: onStoryRingColorChanged,
                  ),
                ],
              ],
            ),
          ),
        SwitchListTile(
          title: const Text(
            'Verified Badge',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Blue tick indicator for your profile',
            style: TextStyle(fontSize: 12),
          ),
          value: isVerified,
          onChanged: onVerifiedChanged,
          secondary: const Icon(Icons.verified, color: AppColors.primary),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (isVerified)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Position',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _pillButton(
                      isSelected: verifiedBadgeAttachTo == 'username',
                      label: 'Username',
                      onTap: () => onVerifiedAttachToChanged('username'),
                    ),
                    const SizedBox(width: 8),
                    _pillButton(
                      isSelected: verifiedBadgeAttachTo == 'handle',
                      label: 'Handle',
                      onTap: () => onVerifiedAttachToChanged('handle'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Badge Color',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ImagePostColorPicker(
                  currentColor: verifiedBadgeColor,
                  onPick: onVerifiedBadgeColorChanged,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pillButton({
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

/// Watermark Position & Sizing tab panel (index 2).
class ImagePostPositionTab extends StatelessWidget {
  final String watermarkType;
  final double watermarkX;
  final double watermarkY;
  final double iconSize;
  final double usernameSize;
  final double handleSize;
  final double watermarkScale;

  final ValueChanged<double> onWatermarkXChanged;
  final ValueChanged<double> onWatermarkYChanged;
  final ValueChanged<double> onIconSizeChanged;
  final ValueChanged<double> onUsernameSizeChanged;
  final ValueChanged<double> onHandleSizeChanged;
  final ValueChanged<double> onWatermarkScaleChanged;

  const ImagePostPositionTab({
    super.key,
    required this.watermarkType,
    required this.watermarkX,
    required this.watermarkY,
    required this.iconSize,
    required this.usernameSize,
    required this.handleSize,
    required this.watermarkScale,
    required this.onWatermarkXChanged,
    required this.onWatermarkYChanged,
    required this.onIconSizeChanged,
    required this.onUsernameSizeChanged,
    required this.onHandleSizeChanged,
    required this.onWatermarkScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Alignment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _alignBtn(Icons.align_horizontal_left, 'Left', 0.15, true),
            _alignBtn(Icons.align_horizontal_center, 'Center', 0.5, true),
            _alignBtn(Icons.align_horizontal_right, 'Right', 0.85, true),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _alignBtn(Icons.vertical_align_top, 'Top', 0.15, false),
            _alignBtn(Icons.vertical_align_center, 'Middle', 0.5, false),
            _alignBtn(Icons.vertical_align_bottom, 'Bottom', 0.85, false),
          ],
        ),
        const Divider(height: 32),
        const Text(
          'Manual Sizing',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text('Icon Size: ${iconSize.toInt()}'),
        ImagePostSliderWithButtons(
          value: iconSize,
          min: 40,
          max: 400,
          onChanged: onIconSizeChanged,
        ),
        ImagePostControlSlider(
          label: 'Username Size',
          value: usernameSize,
          min: 20,
          max: 200,
          onChanged: onUsernameSizeChanged,
        ),
        ImagePostControlSlider(
          label: 'Handle Size',
          value: handleSize,
          min: 20,
          max: 200,
          onChanged: onHandleSizeChanged,
        ),
        const SizedBox(height: 8),
        Text('Master Scale: ${watermarkScale.toStringAsFixed(2)}'),
        ImagePostSliderWithButtons(
          value: watermarkScale,
          min: 0.5,
          max: 2.5,
          onChanged: onWatermarkScaleChanged,
        ),
        const SizedBox(height: 16),
        const Text(
          'Manual Coordinates (Fine-tune)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (watermarkType != 'wire') ...[
          ImagePostControlSlider(
            label: 'Horizontal Position (X)',
            value: watermarkX,
            min: 0,
            max: 1,
            onChanged: onWatermarkXChanged,
          ),
          ImagePostControlSlider(
            label: 'Vertical Position (Y)',
            value: watermarkY,
            min: 0,
            max: 1,
            onChanged: onWatermarkYChanged,
          ),
        ],
      ],
    );
  }

  Widget _alignBtn(IconData icon, String label, double target, bool isX) {
    final isSelected = ((isX ? watermarkX : watermarkY) - target).abs() < 0.05;
    return InkWell(
      onTap: () => isX ? onWatermarkXChanged(target) : onWatermarkYChanged(target),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Watermark & Main Image Style tab panel (index 3): Username, Handle, Icon, Main Image, and Wire styling.
class ImagePostStyleTab extends StatelessWidget {
  final String watermarkType;
  final int selectedStyleSubTab;
  final ValueChanged<int> onSubTabChanged;

  // Username
  final String textColor;
  final double usernameOpacity;
  final bool showUsernameShadow;
  final String usernameShadowColor;
  final double usernameShadowBlur;
  final double usernameShadowOffsetX;
  final double usernameShadowOffsetY;
  final ValueChanged<String> onTextColorChanged;
  final ValueChanged<double> onUsernameOpacityChanged;
  final ValueChanged<bool> onShowUsernameShadowChanged;
  final ValueChanged<String> onUsernameShadowColorChanged;
  final ValueChanged<double> onUsernameShadowBlurChanged;
  final ValueChanged<double> onUsernameShadowOffsetXChanged;
  final ValueChanged<double> onUsernameShadowOffsetYChanged;

  // Handle
  final String accentColor;
  final double handleOpacity;
  final bool showHandleShadow;
  final String handleShadowColor;
  final double handleShadowBlur;
  final double handleShadowOffsetX;
  final double handleShadowOffsetY;
  final ValueChanged<String> onAccentColorChanged;
  final ValueChanged<double> onHandleOpacityChanged;
  final ValueChanged<bool> onShowHandleShadowChanged;
  final ValueChanged<String> onHandleShadowColorChanged;
  final ValueChanged<double> onHandleShadowBlurChanged;
  final ValueChanged<double> onHandleShadowOffsetXChanged;
  final ValueChanged<double> onHandleShadowOffsetYChanged;

  // Icon
  final bool showIconShadow;
  final String iconShadowColor;
  final double iconShadowBlur;
  final double iconShadowOffsetX;
  final double iconShadowOffsetY;
  final ValueChanged<bool> onShowIconShadowChanged;
  final ValueChanged<String> onIconShadowColorChanged;
  final ValueChanged<double> onIconShadowBlurChanged;
  final ValueChanged<double> onIconShadowOffsetXChanged;
  final ValueChanged<double> onIconShadowOffsetYChanged;

  // Main Image
  final bool showVideoShadow;
  final String videoShadowColor;
  final double videoShadowBlur;
  final double videoShadowOffsetX;
  final double videoShadowOffsetY;
  final double videoShadowSpread;
  final double videoScale;
  final double videoRadius;
  final double videoBorderWidth;
  final String videoBorderColor;
  final ValueChanged<bool> onShowVideoShadowChanged;
  final ValueChanged<String> onVideoShadowColorChanged;
  final ValueChanged<double> onVideoShadowBlurChanged;
  final ValueChanged<double> onVideoShadowOffsetXChanged;
  final ValueChanged<double> onVideoShadowOffsetYChanged;
  final ValueChanged<double> onVideoShadowSpreadChanged;
  final ValueChanged<double> onVideoScaleChanged;
  final ValueChanged<double> onVideoRadiusChanged;
  final ValueChanged<double> onVideoBorderWidthChanged;
  final ValueChanged<String> onVideoBorderColorChanged;

  // Wire
  final double wireInset;
  final double wireRadius;
  final double wireWidth;
  final String wireColor;
  final bool wireCutout;
  final bool wireCutoutDots;
  final String wireTextPosition;
  final double wireGap;
  final ValueChanged<double> onWireInsetChanged;
  final ValueChanged<double> onWireRadiusChanged;
  final ValueChanged<double> onWireWidthChanged;
  final ValueChanged<String> onWireColorChanged;
  final ValueChanged<bool> onWireCutoutChanged;
  final ValueChanged<bool> onWireCutoutDotsChanged;
  final ValueChanged<String> onWireTextPositionChanged;
  final ValueChanged<double> onWireGapChanged;

  const ImagePostStyleTab({
    super.key,
    required this.watermarkType,
    required this.selectedStyleSubTab,
    required this.onSubTabChanged,
    required this.textColor,
    required this.usernameOpacity,
    required this.showUsernameShadow,
    required this.usernameShadowColor,
    required this.usernameShadowBlur,
    required this.usernameShadowOffsetX,
    required this.usernameShadowOffsetY,
    required this.onTextColorChanged,
    required this.onUsernameOpacityChanged,
    required this.onShowUsernameShadowChanged,
    required this.onUsernameShadowColorChanged,
    required this.onUsernameShadowBlurChanged,
    required this.onUsernameShadowOffsetXChanged,
    required this.onUsernameShadowOffsetYChanged,
    required this.accentColor,
    required this.handleOpacity,
    required this.showHandleShadow,
    required this.handleShadowColor,
    required this.handleShadowBlur,
    required this.handleShadowOffsetX,
    required this.handleShadowOffsetY,
    required this.onAccentColorChanged,
    required this.onHandleOpacityChanged,
    required this.onShowHandleShadowChanged,
    required this.onHandleShadowColorChanged,
    required this.onHandleShadowBlurChanged,
    required this.onHandleShadowOffsetXChanged,
    required this.onHandleShadowOffsetYChanged,
    required this.showIconShadow,
    required this.iconShadowColor,
    required this.iconShadowBlur,
    required this.iconShadowOffsetX,
    required this.iconShadowOffsetY,
    required this.onShowIconShadowChanged,
    required this.onIconShadowColorChanged,
    required this.onIconShadowBlurChanged,
    required this.onIconShadowOffsetXChanged,
    required this.onIconShadowOffsetYChanged,
    required this.showVideoShadow,
    required this.videoShadowColor,
    required this.videoShadowBlur,
    required this.videoShadowOffsetX,
    required this.videoShadowOffsetY,
    required this.videoShadowSpread,
    required this.videoScale,
    required this.videoRadius,
    required this.videoBorderWidth,
    required this.videoBorderColor,
    required this.onShowVideoShadowChanged,
    required this.onVideoShadowColorChanged,
    required this.onVideoShadowBlurChanged,
    required this.onVideoShadowOffsetXChanged,
    required this.onVideoShadowOffsetYChanged,
    required this.onVideoShadowSpreadChanged,
    required this.onVideoScaleChanged,
    required this.onVideoRadiusChanged,
    required this.onVideoBorderWidthChanged,
    required this.onVideoBorderColorChanged,
    required this.wireInset,
    required this.wireRadius,
    required this.wireWidth,
    required this.wireColor,
    required this.wireCutout,
    required this.wireCutoutDots,
    required this.wireTextPosition,
    required this.wireGap,
    required this.onWireInsetChanged,
    required this.onWireRadiusChanged,
    required this.onWireWidthChanged,
    required this.onWireColorChanged,
    required this.onWireCutoutChanged,
    required this.onWireCutoutDotsChanged,
    required this.onWireTextPositionChanged,
    required this.onWireGapChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSubTabButton(0, 'Username', Icons.person_outline),
            _buildSubTabButton(1, 'Handle', Icons.alternate_email),
            _buildSubTabButton(2, 'Icon', Icons.image_outlined),
            _buildSubTabButton(3, 'Main Image', Icons.image_search),
            if (watermarkType == 'wire')
              _buildSubTabButton(4, 'Wire', Icons.border_outer),
          ],
        ),
        const SizedBox(height: 20),
        IndexedStack(
          index: selectedStyleSubTab,
          children: [
            // --- Username Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Username Color',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ImagePostColorPicker(
                  currentColor: textColor,
                  onPick: onTextColorChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Username Opacity',
                  value: usernameOpacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onUsernameOpacityChanged,
                ),
                const Divider(height: 32),
                ImagePostShadowControlSection(
                  title: 'Username Shadow',
                  showShadow: showUsernameShadow,
                  onToggleShadow: onShowUsernameShadowChanged,
                  shadowColor: usernameShadowColor,
                  onColorChanged: onUsernameShadowColorChanged,
                  blur: usernameShadowBlur,
                  onBlurChanged: onUsernameShadowBlurChanged,
                  offsetX: usernameShadowOffsetX,
                  onOffsetXChanged: onUsernameShadowOffsetXChanged,
                  offsetY: usernameShadowOffsetY,
                  onOffsetYChanged: onUsernameShadowOffsetYChanged,
                ),
              ],
            ),
            // --- Handle Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Handle Color',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ImagePostColorPicker(
                  currentColor: accentColor,
                  onPick: onAccentColorChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Handle Opacity',
                  value: handleOpacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onHandleOpacityChanged,
                ),
                const Divider(height: 32),
                ImagePostShadowControlSection(
                  title: 'Handle Shadow',
                  showShadow: showHandleShadow,
                  onToggleShadow: onShowHandleShadowChanged,
                  shadowColor: handleShadowColor,
                  onColorChanged: onHandleShadowColorChanged,
                  blur: handleShadowBlur,
                  onBlurChanged: onHandleShadowBlurChanged,
                  offsetX: handleShadowOffsetX,
                  onOffsetXChanged: onHandleShadowOffsetXChanged,
                  offsetY: handleShadowOffsetY,
                  onOffsetYChanged: onHandleShadowOffsetYChanged,
                ),
              ],
            ),
            // --- Icon Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Icon Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ImagePostShadowControlSection(
                  title: 'Icon Shadow',
                  showShadow: showIconShadow,
                  onToggleShadow: onShowIconShadowChanged,
                  shadowColor: iconShadowColor,
                  onColorChanged: onIconShadowColorChanged,
                  blur: iconShadowBlur,
                  onBlurChanged: onIconShadowBlurChanged,
                  offsetX: iconShadowOffsetX,
                  onOffsetXChanged: onIconShadowOffsetXChanged,
                  offsetY: iconShadowOffsetY,
                  onOffsetYChanged: onIconShadowOffsetYChanged,
                ),
              ],
            ),
            // --- Main Image Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Main Image Canvas Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ImagePostShadowControlSection(
                  title: 'Main Image Drop Shadow',
                  showShadow: showVideoShadow,
                  onToggleShadow: onShowVideoShadowChanged,
                  shadowColor: videoShadowColor,
                  onColorChanged: onVideoShadowColorChanged,
                  blur: videoShadowBlur,
                  onBlurChanged: onVideoShadowBlurChanged,
                  offsetX: videoShadowOffsetX,
                  onOffsetXChanged: onVideoShadowOffsetXChanged,
                  offsetY: videoShadowOffsetY,
                  onOffsetYChanged: onVideoShadowOffsetYChanged,
                  spread: videoShadowSpread,
                  onSpreadChanged: onVideoShadowSpreadChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Image Scale',
                  value: videoScale,
                  min: 0.1,
                  max: 3.0,
                  onChanged: onVideoScaleChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Corner Radius',
                  value: videoRadius,
                  min: 0.0,
                  max: 200.0,
                  onChanged: onVideoRadiusChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Border Width',
                  value: videoBorderWidth,
                  min: 0.0,
                  max: 50.0,
                  onChanged: onVideoBorderWidthChanged,
                ),
                if (videoBorderWidth > 0) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Border Color',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ImagePostColorPicker(
                    currentColor: videoBorderColor,
                    onPick: onVideoBorderColorChanged,
                  ),
                ],
              ],
            ),
            // --- Wire Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wire Frame Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Wire Inset (Margin)',
                  value: wireInset,
                  min: 0.0,
                  max: 150.0,
                  onChanged: onWireInsetChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Wire Corner Radius',
                  value: wireRadius,
                  min: 0.0,
                  max: 100.0,
                  onChanged: onWireRadiusChanged,
                ),
                const SizedBox(height: 16),
                ImagePostControlSlider(
                  label: 'Wire Width (Thickness)',
                  value: wireWidth,
                  min: 0.5,
                  max: 10.0,
                  onChanged: onWireWidthChanged,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wire Color',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ImagePostColorPicker(
                  currentColor: wireColor,
                  onPick: onWireColorChanged,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cutout text from wire',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: wireCutout,
                      activeThumbColor: AppColors.primary,
                      onChanged: onWireCutoutChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Show dots on cutout ends',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: wireCutout ? Colors.black : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: wireCutoutDots,
                      activeThumbColor: AppColors.primary,
                      onChanged: wireCutout ? onWireCutoutDotsChanged : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Text Position on Wire',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['top', 'bottom', 'left', 'right'].map((pos) {
                    final isSelected = wireTextPosition == pos;
                    return ChoiceChip(
                      label: Text(
                        pos[0].toUpperCase() + pos.substring(1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey[200],
                      onSelected: (selected) {
                        if (selected) onWireTextPositionChanged(pos);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Wire Cutout Gap: ${wireGap.toStringAsFixed(0)} px',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: wireCutout ? Colors.black : Colors.grey,
                  ),
                ),
                Slider(
                  value: wireGap.clamp(0.0, 100.0),
                  min: 0.0,
                  max: 100.0,
                  divisions: 100,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey[200],
                  onChanged: wireCutout ? onWireGapChanged : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isSelected = selectedStyleSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSubTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

