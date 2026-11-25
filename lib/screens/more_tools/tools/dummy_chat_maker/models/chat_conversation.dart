import 'chat_message.dart';
import 'chat_platform.dart';

/// Full conversation model configuring the entire dummy chat mockup.
class ChatConversation {
  final String contactName;
  final String? contactAvatarPath;
  final bool isVerified;
  final String statusSubtext;
  final ChatPlatform platform;
  final bool isDarkMode;
  final String clockTime;
  final int batteryPercent;
  final List<ChatMessage> messages;

  const ChatConversation({
    this.contactName = 'Sarah 💖',
    this.contactAvatarPath,
    this.isVerified = false,
    this.statusSubtext = 'Active now',
    this.platform = ChatPlatform.iMessage,
    this.isDarkMode = true,
    this.clockTime = '9:41',
    this.batteryPercent = 85,
    required this.messages,
  });

  ChatConversation copyWith({
    String? contactName,
    String? contactAvatarPath,
    bool? isVerified,
    String? statusSubtext,
    ChatPlatform? platform,
    bool? isDarkMode,
    String? clockTime,
    int? batteryPercent,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      contactName: contactName ?? this.contactName,
      contactAvatarPath: contactAvatarPath ?? this.contactAvatarPath,
      isVerified: isVerified ?? this.isVerified,
      statusSubtext: statusSubtext ?? this.statusSubtext,
      platform: platform ?? this.platform,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      clockTime: clockTime ?? this.clockTime,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      messages: messages ?? List.from(this.messages),
    );
  }

  /// Default starting conversation template
  static ChatConversation get initialDefault => const ChatConversation(
        contactName: 'Sarah 💖',
        isVerified: false,
        statusSubtext: 'Active now',
        platform: ChatPlatform.iMessage,
        isDarkMode: true,
        clockTime: '9:41',
        batteryPercent: 88,
        messages: [
          ChatMessage(
            id: 'm1',
            text: 'Hey! Did you see the new video you posted? 😱',
            isOutgoing: false,
            time: '9:38 PM',
          ),
          ChatMessage(
            id: 'm2',
            text: 'Yeah!! It already hit 500k views in 2 hours!',
            isOutgoing: true,
            time: '9:39 PM',
            reaction: '🔥',
          ),
          ChatMessage(
            id: 'm3',
            text: 'NO WAY!! That is literally insane omg 🎉',
            isOutgoing: false,
            time: '9:40 PM',
            reaction: '❤️',
          ),
          ChatMessage(
            id: 'm4',
            text: 'Tell me your secret right now 😂',
            isOutgoing: false,
            time: '9:40 PM',
          ),
          ChatMessage(
            id: 'm5',
            text: 'Made the whole thing with Quick Post app 🤫',
            isOutgoing: true,
            time: '9:41 PM',
            status: 'Read 9:41 PM',
          ),
        ],
      );

  /// Sample viral presets for 1-tap loading
  static List<ChatConversation> get samplePresets => [
        // 1. Savage Mom
        const ChatConversation(
          contactName: 'Mom ❤️',
          isVerified: false,
          statusSubtext: 'Messages',
          platform: ChatPlatform.iMessage,
          isDarkMode: true,
          clockTime: '8:15',
          batteryPercent: 92,
          messages: [
            ChatMessage(id: 'sm1', text: 'Where are you?', isOutgoing: false, time: '8:10 PM'),
            ChatMessage(id: 'sm2', text: 'Studying at the library mom!', isOutgoing: true, time: '8:12 PM'),
            ChatMessage(id: 'sm3', text: 'Then why is your location at McDonald\'s? 🤨', isOutgoing: false, time: '8:14 PM'),
            ChatMessage(id: 'sm4', text: '...the library moved', isOutgoing: true, time: '8:15 PM', status: 'Delivered'),
          ],
        ),

        // 2. Verified Celebrity VIP
        const ChatConversation(
          contactName: 'Celebrity VIP ⭐',
          isVerified: true,
          statusSubtext: 'Active now',
          platform: ChatPlatform.instagramDm,
          isDarkMode: true,
          clockTime: '3:33',
          batteryPercent: 100,
          messages: [
            ChatMessage(id: 'em1', text: 'Loved your latest viral video edit! 🎬', isOutgoing: false, time: '3:30 AM'),
            ChatMessage(id: 'em2', text: 'Wait is this actually real?! 😱', isOutgoing: true, time: '3:31 AM'),
            ChatMessage(id: 'em3', text: 'Yes! How did you edit that so clean?', isOutgoing: false, time: '3:32 AM', reaction: '🔥'),
            ChatMessage(id: 'em4', text: 'Quick Post app! All in one studio 🫡', isOutgoing: true, time: '3:33 AM', status: 'Seen'),
          ],
        ),

        // 3. Plot Twist
        const ChatConversation(
          contactName: 'Crush 😉',
          isVerified: false,
          statusSubtext: 'online',
          platform: ChatPlatform.whatsapp,
          isDarkMode: true,
          clockTime: '11:11',
          batteryPercent: 42,
          messages: [
            ChatMessage(id: 'pt1', text: 'I have to tell you something...', isOutgoing: true, time: '11:09 PM'),
            ChatMessage(id: 'pt2', text: 'What is it?? You\'re scaring me 😳', isOutgoing: false, time: '11:10 PM'),
            ChatMessage(id: 'pt3', text: 'I\'ve liked you since day one.', isOutgoing: true, time: '11:10 PM'),
            ChatMessage(id: 'pt4', text: 'I was waiting for you to say that ❤️', isOutgoing: false, time: '11:11 PM'),
          ],
        ),
      ];
}

