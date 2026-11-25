/// Represents an individual chat message inside the dummy conversation.
class ChatMessage {
  final String id;
  final String text;
  final bool isOutgoing; // true = Me (right side), false = Contact (left side)
  final String time;
  final String status; // 'Delivered', 'Read', 'Seen', 'Sent'
  final String? imagePath; // Optional attached photo
  final String? reaction; // e.g. '❤️', '😂', '🔥', '👍'
  final bool isSystemDivider; // e.g. 'Today 9:41 PM'

  const ChatMessage({
    required this.id,
    required this.text,
    this.isOutgoing = true,
    this.time = '9:41 PM',
    this.status = 'Delivered',
    this.imagePath,
    this.reaction,
    this.isSystemDivider = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isOutgoing,
    String? time,
    String? status,
    String? imagePath,
    String? reaction,
    bool? isSystemDivider,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      time: time ?? this.time,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      reaction: reaction ?? this.reaction,
      isSystemDivider: isSystemDivider ?? this.isSystemDivider,
    );
  }
}

