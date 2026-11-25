import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_platform.dart';

/// Pixel-perfect phone frame mock canvas rendering iMessage, Instagram DM, or WhatsApp conversations.
class ChatCanvasView extends StatelessWidget {
  final ChatConversation conversation;
  final Function(ChatMessage) onEditMessage;
  final Function(ChatMessage) onDeleteMessage;

  const ChatCanvasView({
    super.key,
    required this.conversation,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = conversation.isDarkMode;
    final bgColor = isDark
        ? (conversation.platform == ChatPlatform.whatsapp ? const Color(0xFF0B141A) : const Color(0xFF000000))
        : (conversation.platform == ChatPlatform.whatsapp ? const Color(0xFFEFEAE2) : const Color(0xFFFFFFFF));

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Phone Status Bar (Clock, Notch, Battery)
          _buildStatusBar(textColor, isDark),

          // 2. Platform Navigation Bar
          _buildPlatformHeader(textColor, isDark),

          // 3. Message List Canvas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                return _buildMessageItem(context, message, isDark);
              },
            ),
          ),

          // 4. Platform Bottom Input Bar
          _buildPlatformBottomBar(isDark),
        ],
      ),
    );
  }

  // ─── Status Bar ───
  Widget _buildStatusBar(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            conversation.clockTime,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          // Dynamic Island / Camera cutout
          Container(
            width: 72,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF000000),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar_rounded, size: 14, color: textColor),
              const SizedBox(width: 4),
              Icon(Icons.wifi, size: 14, color: textColor),
              const SizedBox(width: 6),
              // Battery pill
              Container(
                width: 22,
                height: 11,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  border: Border.all(color: textColor, width: 1.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: (20 * (conversation.batteryPercent / 100)).clamp(2.0, 18.0),
                  decoration: BoxDecoration(
                    color: conversation.batteryPercent < 20 ? const Color(0xFFEF4444) : textColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Platform Header ───
  Widget _buildPlatformHeader(Color textColor, bool isDark) {
    switch (conversation.platform) {
      case ChatPlatform.iMessage:
        return _buildIMessageHeader(textColor, isDark);
      case ChatPlatform.instagramDm:
        return _buildInstagramHeader(textColor, isDark);
      case ChatPlatform.whatsapp:
        return _buildWhatsAppHeader(textColor, isDark);
    }
  }

  Widget _buildIMessageHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : const Color(0xFFF6F6F6),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          Row(
            children: const [
              Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF007AFF), size: 18),
              SizedBox(width: 2),
              Text('24', style: TextStyle(color: Color(0xFF007AFF), fontSize: 15, fontFamily: 'Poppins')),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                _buildAvatar(radius: 17),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        conversation.contactName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF38BDF8)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.videocam_rounded, color: Color(0xFF007AFF), size: 24),
        ],
      ),
    );
  }

  Widget _buildInstagramHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F11) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
          const SizedBox(width: 10),
          _buildAvatar(radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conversation.contactName,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5, fontFamily: 'Poppins'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF38BDF8)),
                    ],
                  ],
                ),
                Text(
                  conversation.statusSubtext,
                  style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 10.5, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          Icon(Icons.call_outlined, color: textColor, size: 20),
          const SizedBox(width: 14),
          Icon(Icons.videocam_outlined, color: textColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildWhatsAppHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 14, 10),
      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
      child: Row(
        children: [
          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          _buildAvatar(radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conversation.contactName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF00E5FF)),
                    ],
                  ],
                ),
                Text(
                  conversation.statusSubtext,
                  style: const TextStyle(color: Color(0xFF8696A0), fontSize: 11, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          const Icon(Icons.call_rounded, color: Colors.white, size: 19),
          const SizedBox(width: 12),
          const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double radius}) {
    if (conversation.contactAvatarPath != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(conversation.contactAvatarPath!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF007AFF),
      child: Text(
        conversation.contactName.isNotEmpty ? conversation.contactName.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  // ─── Message Item Builder ───
  Widget _buildMessageItem(BuildContext context, ChatMessage message, bool isDark) {
    final isMe = message.isOutgoing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => onEditMessage(message),
          onLongPress: () => onDeleteMessage(message),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: _getBubbleDecoration(isMe, isDark),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Optional Attached Photo
                    if (message.imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(message.imagePath!),
                          fit: BoxFit.cover,
                          height: 140,
                          width: double.infinity,
                        ),
                      ),
                      if (message.text.isNotEmpty) const SizedBox(height: 6),
                    ],

                    // Message Text Content
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: _getTextColor(isMe, isDark),
                          fontSize: 13.5,
                          fontFamily: 'Poppins',
                          height: 1.35,
                        ),
                      ),

                    // WhatsApp timestamp inside bubble
                    if (conversation.platform == ChatPlatform.whatsapp) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.time,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.black54,
                              fontSize: 9.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF53BDEB)),
                          ],
                        ],
                      ),
                    ],

                    // iMessage read receipt under outgoing bubble
                    if (conversation.platform == ChatPlatform.iMessage && isMe && message.status.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.status,
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 9.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Emoji Reaction Floating Badge
              if (message.reaction != null)
                Positioned(
                  bottom: -8,
                  right: isMe ? 4 : null,
                  left: isMe ? null : 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(message.reaction!, style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _getBubbleDecoration(bool isMe, bool isDark) {
    switch (conversation.platform) {
      case ChatPlatform.iMessage:
        return BoxDecoration(
          color: isMe
              ? const Color(0xFF007AFF) // Classic iOS blue
              : (isDark ? const Color(0xFF26252A) : const Color(0xFFE9E9EB)),
          borderRadius: BorderRadius.circular(18),
        );

      case ChatPlatform.instagramDm:
        return BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : (isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF)),
          borderRadius: BorderRadius.circular(18),
        );

      case ChatPlatform.whatsapp:
        return BoxDecoration(
          color: isMe
              ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
              : (isDark ? const Color(0xFF202C33) : Colors.white),
          borderRadius: BorderRadius.circular(12),
        );
    }
  }

  Color _getTextColor(bool isMe, bool isDark) {
    if (isMe) {
      if (conversation.platform == ChatPlatform.whatsapp && !isDark) {
        return const Color(0xFF111B21);
      }
      return Colors.white;
    }
    return isDark ? Colors.white : const Color(0xFF0F172A);
  }

  // ─── Platform Bottom Bar ───
  Widget _buildPlatformBottomBar(bool isDark) {
    final barBg = isDark ? const Color(0xFF161618) : const Color(0xFFF6F6F6);
    final inputBg = isDark ? const Color(0xFF26252A) : Colors.white;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    switch (conversation.platform) {
      case ChatPlatform.iMessage:
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          color: barBg,
          child: Row(
            children: [
              const Icon(Icons.add_circle_rounded, color: Color(0xFF007AFF), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Text('Message', style: TextStyle(color: hintColor, fontSize: 13, fontFamily: 'Poppins')),
                      const Spacer(),
                      Icon(Icons.mic_rounded, color: hintColor, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case ChatPlatform.instagramDm:
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          color: isDark ? const Color(0xFF0F0F11) : Colors.white,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Message...', style: TextStyle(color: hintColor, fontSize: 13, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.mic_none_rounded, color: hintColor, size: 20),
              const SizedBox(width: 8),
              Icon(Icons.image_outlined, color: hintColor, size: 20),
            ],
          ),
        );

      case ChatPlatform.whatsapp:
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A3942) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sentiment_satisfied_alt_rounded, color: hintColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Message', style: TextStyle(color: hintColor, fontSize: 13, fontFamily: 'Poppins')),
                      const Spacer(),
                      Icon(Icons.attach_file_rounded, color: hintColor, size: 18),
                      const SizedBox(width: 8),
                      Icon(Icons.camera_alt_rounded, color: hintColor, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                child: const Icon(Icons.mic, color: Colors.white, size: 18),
              ),
            ],
          ),
        );
    }
  }
}

