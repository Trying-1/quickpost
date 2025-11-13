import 'package:hive/hive.dart';

part 'audio_folder.g.dart';

@HiveType(typeId: 1)
class AudioFolder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime dateCreated;

  @HiveField(4)
  int colorValue; // Store color as int

  @HiveField(5)
  String? iconName; // Icon name for display

  AudioFolder({
    required this.id,
    required this.name,
    this.description,
    required this.dateCreated,
    this.colorValue = 0xFF9C27B0, // Default purple
    this.iconName,
  });

  // Predefined folder IDs
  static const String allAudioFolderId = 'all_audio';
  static const String defaultFolderId = 'default';
  static const String motivationalFolderId = 'motivational';
  static const String calmFolderId = 'calm';
  static const String upbeatFolderId = 'upbeat';

  // Create default folders
  static List<AudioFolder> getDefaultFolders() {
    return [
      AudioFolder(
        id: allAudioFolderId,
        name: 'All Audio',
        description: 'View all extracted audio',
        dateCreated: DateTime.now(),
        colorValue: 0xFF9C27B0, // Purple
        iconName: 'library_music',
      ),
      AudioFolder(
        id: defaultFolderId,
        name: 'Uncategorized',
        description: 'Default folder for all audio',
        dateCreated: DateTime.now(),
        colorValue: 0xFF757575, // Grey
        iconName: 'folder',
      ),
      AudioFolder(
        id: motivationalFolderId,
        name: 'Motivational',
        description: 'Inspiring and energetic audio',
        dateCreated: DateTime.now(),
        colorValue: 0xFFFF5722, // Deep Orange
        iconName: 'trending_up',
      ),
      AudioFolder(
        id: calmFolderId,
        name: 'Calm',
        description: 'Relaxing and peaceful audio',
        dateCreated: DateTime.now(),
        colorValue: 0xFF03A9F4, // Light Blue
        iconName: 'spa',
      ),
      AudioFolder(
        id: upbeatFolderId,
        name: 'Fade In',
        description: 'Fun and energetic audio',
        dateCreated: DateTime.now(),
        colorValue: 0xFF009688, // Teal green
        iconName: 'music_note',
      ),
    ];
  }
}
