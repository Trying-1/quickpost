import 'package:hive/hive.dart';

part 'audio_file.g.dart';

@HiveType(typeId: 0)
class AudioFile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String audioPath;

  @HiveField(3)
  int durationMs;

  @HiveField(4)
  DateTime dateExtracted;

  @HiveField(5)
  String? thumbnailPath;

  @HiveField(6)
  String? originalVideoPath;

  @HiveField(7)
  int fileSizeBytes;

  @HiveField(8)
  String folderId; // Folder/category ID

  AudioFile({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.durationMs,
    required this.dateExtracted,
    this.thumbnailPath,
    this.originalVideoPath,
    required this.fileSizeBytes,
    this.folderId = 'default', // Default to uncategorized
  });

  String get durationFormatted {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get dateFormatted {
    final now = DateTime.now();
    final difference = now.difference(dateExtracted);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateExtracted.day}/${dateExtracted.month}/${dateExtracted.year}';
    }
  }
}
