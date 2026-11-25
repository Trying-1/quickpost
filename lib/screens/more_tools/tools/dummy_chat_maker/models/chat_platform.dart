import 'package:flutter/material.dart';

/// Supported chat platforms for generating dummy screenshots.
enum ChatPlatform {
  iMessage(
    id: 'ios_messages',
    name: 'iOS Messages',
    brandColor: Color(0xFF007AFF),
    icon: Icons.chat_bubble_rounded,
  ),
  instagramDm(
    id: 'social_dm',
    name: 'Social DM',
    brandColor: Color(0xFFE1306C),
    icon: Icons.camera_alt_rounded,
  ),
  whatsapp(
    id: 'green_chat',
    name: 'Green Chat',
    brandColor: Color(0xFF25D366),
    icon: Icons.phone_in_talk_rounded,
  );

  final String id;
  final String name;
  final Color brandColor;
  final IconData icon;

  const ChatPlatform({
    required this.id,
    required this.name,
    required this.brandColor,
    required this.icon,
  });
}

