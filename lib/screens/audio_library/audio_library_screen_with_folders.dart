import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../audio_extraction/audio_extraction_screen.dart';
import '../../models/audio_file.dart';
import '../../models/audio_folder.dart';
import '../../services/audio_library_service.dart';
import '../../services/audio_backup_service.dart';
import '../../widgets/audio_progress_dialog.dart';
import '../../services/analytics_service.dart';

class AudioLibraryScreenWithFolders extends StatefulWidget {
  final Function(AudioFile)? onAudioSelected;
  final bool isActive;

  const AudioLibraryScreenWithFolders({
    Key? key,
    this.onAudioSelected,
    this.isActive = true,
  }) : super(key: key);

  @override
  State<AudioLibraryScreenWithFolders> createState() => _AudioLibraryScreenWithFoldersState();
}

class _AudioLibraryScreenWithFoldersState extends State<AudioLibraryScreenWithFolders> with WidgetsBindingObserver {
  List<AudioFolder> _folders = [];
  List<AudioFile> _audioFiles = [];
  String? _selectedFolderId;
  bool _isLoading = true;
  VideoPlayerController? _previewController;
  String? _playingAudioId;
  bool _showFolderView = true;
  bool _isBackupOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    AnalyticsService().setCurrentScreen(screenName: 'Audio Library');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AudioLibraryScreenWithFolders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _stopAudio();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopAudio();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final folders = AudioLibraryService.getAllFolders();
      
      // Sort folders: All Audio first, then Uncategorized, then others
      folders.sort((a, b) {
        if (a.id == 'all_audio') return -1;
        if (b.id == 'all_audio') return 1;
        if (a.id == 'default') return -1;
        if (b.id == 'default') return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading library: $e')),
        );
      }
    }
  }

  Future<void> _loadAudioFiles(String folderId) async {
    setState(() {
      _isLoading = true;
      _selectedFolderId = folderId;
      _showFolderView = false;
    });
    
    try {
      // If "All Audio" folder, get all audio files, otherwise get by folder
      final files = folderId == 'all_audio'
          ? AudioLibraryService.getAllAudioFiles()
          : AudioLibraryService.getAudioFilesByFolder(folderId);
      setState(() {
        _audioFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  void _backToFolders() {
    setState(() {
      _showFolderView = true;
      _selectedFolderId = null;
      _audioFiles = [];
    });
    _stopAudio();
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    await _previewController?.pause();
    await _previewController?.dispose();

    setState(() => _playingAudioId = audioFile.id);

    try {
      _previewController = VideoPlayerController.file(File(audioFile.audioPath));
      await _previewController!.initialize();
      await _previewController!.play();

      _previewController!.addListener(() {
        if (_previewController!.value.position >= _previewController!.value.duration) {
          setState(() => _playingAudioId = null);
        }
      });
    } catch (e) {
      setState(() => _playingAudioId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _previewController?.pause();
    await _previewController?.dispose();
    _previewController = null;
    setState(() => _playingAudioId = null);
  }

  Future<void> _deleteAudio(AudioFile audioFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio'),
        content: Text('Delete "${audioFile.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (_playingAudioId == audioFile.id) {
          await _stopAudio();
        }
        await AudioLibraryService.deleteAudioFile(audioFile.id);
        AnalyticsService().logEvent(name: 'audio_deleted');
        if (_selectedFolderId != null) {
          await _loadAudioFiles(_selectedFolderId!);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting audio: $e')),
          );
        }
      }
    }
  }

  Future<void> _moveAudioToFolder(AudioFile audioFile) async {
    final targetFolder = await showDialog<AudioFolder>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _folders.map((folder) {
                final isCurrentFolder = folder.id == audioFile.folderId;
                
                return ListTile(
                  leading: _isEmoji(folder.iconName)
                      ? Text(folder.iconName ?? '📁', style: const TextStyle(fontSize: 24))
                      : Icon(
                          _getIconData(folder.iconName),
                          color: Color(folder.colorValue),
                        ),
                  title: Text(folder.name),
                  subtitle: folder.description != null 
                      ? Text(folder.description!, style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: isCurrentFolder 
                      ? const Icon(Icons.check_circle, color: Colors.green) 
                      : null,
                  enabled: !isCurrentFolder,
                  onTap: isCurrentFolder ? null : () => Navigator.pop(context, folder),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );

    if (targetFolder != null) {
      try {
        await AudioLibraryService.moveAudioToFolder(audioFile.id, targetFolder.id);
        AnalyticsService().logEvent(
          name: 'audio_moved',
          parameters: {'target_folder': targetFolder.name}
        );
        if (_selectedFolderId != null) {
          await _loadAudioFiles(_selectedFolderId!);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved to ${targetFolder.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error moving audio: $e')),
          );
        }
      }
    }
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedColor = 0xFF9C27B0;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Folder'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'e.g., Motivational',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., Inspiring audio',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    0xFF9C27B0, // Purple
                    0xFFFF5722, // Deep Orange
                    0xFF03A9F4, // Light Blue
                    0xFFFFEB3B, // Yellow
                    0xFF4CAF50, // Green
                    0xFFE91E63, // Pink
                    0xFF00BCD4, // Cyan
                    0xFFFF9800, // Orange
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selectedColor == color
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await AudioLibraryService.createFolder(
          name: nameController.text,
          description: descController.text.isEmpty ? null : descController.text,
          colorValue: selectedColor,
          iconName: 'folder',
        );
        AnalyticsService().logEvent(name: 'audio_folder_created');
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder created')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _showFolderOptions(AudioFolder folder) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(folder.colorValue).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isEmoji(folder.iconName)
                        ? Text(
                            folder.iconName ?? '📁',
                            style: const TextStyle(fontSize: 24),
                          )
                        : Icon(
                            _getIconData(folder.iconName),
                            color: Color(folder.colorValue),
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (folder.description != null)
                          Text(
                            folder.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              subtitle: const Text('Name, icon & color'),
              onTap: () {
                Navigator.pop(context, 'rename');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context, 'delete');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == 'rename') {
      await _renameFolder(folder);
    } else if (result == 'delete') {
      await _deleteFolder(folder);
    }
  }

  Future<void> _renameFolder(AudioFolder folder) async {
    final nameController = TextEditingController(text: folder.name);
    final descController = TextEditingController(text: folder.description ?? '');
    final hexColorController = TextEditingController(
      text: folder.colorValue.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2),
    );
    String selectedIcon = folder.iconName ?? 'folder';
    int selectedColor = folder.colorValue;
    final iconSearchController = TextEditingController(text: folder.iconName ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Folder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Icon:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: iconSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Enter emoji or icon name',
                    hintText: '🎵 or music_note',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setDialogState(() => selectedIcon = value.trim());
                    }
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['🎵', '🎶', '🎧', '🎤', '🎸', '🎹', '🎺', '🎻', '🥁', '📁', '⭐', '❤️', '🔥', '💎', '🌟', '✨', '🎯', '🚀']
                    .map((emoji) => GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedIcon = emoji;
                          iconSearchController.text = emoji;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedIcon == emoji ? Color(selectedColor).withOpacity(0.2) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedIcon == emoji ? Color(selectedColor) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ))
                    .toList(),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Color:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hexColorController,
                        decoration: const InputDecoration(
                          labelText: 'Hex Color (e.g., 9C27B0)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixText: '#',
                        ),
                        maxLength: 6,
                        onChanged: (value) {
                          if (value.length == 6) {
                            try {
                              final color = int.parse('FF$value', radix: 16);
                              setDialogState(() => selectedColor = color);
                            } catch (e) {
                              // Invalid hex
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(selectedColor),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quick colors:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    0xFF9C27B0, // Purple
                    0xFFFF5722, // Deep Orange
                    0xFF03A9F4, // Light Blue
                    0xFF4CAF50, // Green
                    0xFFE91E63, // Pink
                    0xFF00BCD4, // Cyan
                    0xFFFF9800, // Orange
                    0xFF673AB7, // Deep Purple
                    0xFFF44336, // Red
                    0xFF009688, // Teal
                    0xFFFFEB3B, // Yellow
                    0xFF795548, // Brown
                  ].map((color) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = color;
                          hexColorController.text = color.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2);
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color ? Colors.black : Colors.grey[300]!,
                            width: selectedColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text,
                'description': descController.text,
                'icon': selectedIcon,
                'color': selectedColor,
              }),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      try {
        final updatedFolder = AudioFolder(
          id: folder.id,
          name: result['name'],
          description: result['description'].isEmpty ? null : result['description'],
          dateCreated: folder.dateCreated,
          colorValue: result['color'],
          iconName: result['icon'],
        );
        await AudioLibraryService.updateFolder(updatedFolder);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _changeFolderColor(AudioFolder folder) async {
    int selectedColor = folder.colorValue;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Color'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              0xFF9C27B0, // Purple
              0xFFFF5722, // Deep Orange
              0xFF03A9F4, // Light Blue
              0xFFFFEB3B, // Yellow
              0xFF4CAF50, // Green
              0xFFE91E63, // Pink
              0xFF00BCD4, // Cyan
              0xFFFF9800, // Orange
              0xFF673AB7, // Deep Purple
              0xFFF44336, // Red
              0xFF009688, // Teal
              0xFFCDDC39, // Lime
            ].map((color) {
              return GestureDetector(
                onTap: () {
                  setDialogState(() => selectedColor = color);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedColor),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final updatedFolder = AudioFolder(
          id: folder.id,
          name: folder.name,
          description: folder.description,
          dateCreated: folder.dateCreated,
          colorValue: result,
          iconName: folder.iconName,
        );
        await AudioLibraryService.updateFolder(updatedFolder);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Color changed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error changing color: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteFolder(AudioFolder folder) async {
    if (folder.id == 'default' || folder.id == 'all_audio') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete system folder')),
      );
      return;
    }

    final count = AudioLibraryService.getAudioCountByFolder(folder.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${folder.name}"?\n\n$count audio file(s) will be moved to Uncategorized folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AudioLibraryService.deleteFolder(folder.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting folder: $e')),
          );
        }
      }
    }
  }

  bool _isEmoji(String? text) {
    if (text == null || text.isEmpty) return false;
    final runes = text.runes;
    if (runes.isEmpty) return false;
    final firstRune = runes.first;
    // Check if it's in emoji ranges
    return (firstRune >= 0x1F300 && firstRune <= 0x1F9FF) || // Misc Symbols and Pictographs, Emoticons, Transport
           (firstRune >= 0x2600 && firstRune <= 0x26FF) ||   // Misc symbols
           (firstRune >= 0x2700 && firstRune <= 0x27BF);     // Dingbats
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'library_music':
        return Icons.library_music;
      case 'trending_up':
        return Icons.trending_up;
      case 'spa':
        return Icons.spa;
      case 'music_note':
        return Icons.music_note;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'headphones':
        return Icons.headphones;
      case 'audiotrack':
        return Icons.audiotrack;
      case 'mic':
        return Icons.mic;
      default:
        return Icons.folder;
    }
  }

  Future<void> _exportLibrary() async {
    try {
      _isBackupOperationInProgress = true;

      final dialogKey = GlobalKey<AudioProgressDialogState>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AudioProgressDialog(
          key: dialogKey,
          title: 'Exporting Library',
          message: 'Preparing audio backup...',
          onCancel: () {
            AudioBackupService.cancelCurrentOperation();
            Navigator.of(context).pop();
          },
        ),
      );
      AnalyticsService().logEvent(name: 'audio_library_exported');

      final exportPath = await AudioBackupService.exportAudioLibrary(
        onProgress: (progress, status, current, total) {
          dialogKey.currentState?.updateProgress(progress, status, current, total);
        },
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your audio library has been exported to:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  exportPath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can find it in:\nDownloads/Quick Post Backup/',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      try {
        Navigator.pop(context); // Close progress dialog if open
      } catch (_) {}

      if (e.toString().contains('CANCELLED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isBackupOperationInProgress = false;
    }
  }

  Future<void> _importLibrary() async {
    try {
      // Get available backups
      final backups = await AudioBackupService.getAvailableBackups();
      
      if (!mounted) return;
      
      if (backups.isEmpty) {
        // Fallback: let user pick a backup folder via SAF and import natively
        final treeUri = await AudioBackupService.pickBackupFolder();
        if (treeUri == null || !mounted) return;

        _isBackupOperationInProgress = true;

        final safDialogKey = GlobalKey<AudioProgressDialogState>();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AudioProgressDialog(
            key: safDialogKey,
            title: 'Importing Library',
            message: 'Reading backup...',
            onCancel: () {
              AudioBackupService.cancelCurrentOperation();
              Navigator.of(context).pop();
            },
          ),
        );

        final result = await AudioBackupService.importAudioLibraryFromSafUri(
          treeUri,
          onProgress: (progress, status, current, total) {
            safDialogKey.currentState?.updateProgress(progress, status, current, total);
          },
        );

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        // Reload data
        await _loadData();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✓ ${result.importedCount} audio files imported'),
                if (result.foldersCreated > 0)
                  Text('✓ ${result.foldersCreated} folders created'),
                if (result.skippedCount > 0)
                  Text('⚠ ${result.skippedCount} files skipped', 
                      style: const TextStyle(color: Colors.orange)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show backup selection dialog
      final selectedBackup = await showDialog<BackupInfo>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Backup to Import'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: Text(
                    '${backup.audioCount} audio files',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${backup.folderCount} folders\n'
                    '${_formatDate(backup.exportDate)}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(context, backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedBackup == null || !mounted) return;

      _isBackupOperationInProgress = true;

      final dialogKey = GlobalKey<AudioProgressDialogState>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AudioProgressDialog(
          key: dialogKey,
          title: 'Importing Library',
          message: 'Reading backup...',
          onCancel: () {
            AudioBackupService.cancelCurrentOperation();
            Navigator.of(context).pop();
          },
        ),
      );
      AnalyticsService().logEvent(name: 'audio_library_imported');

      final result = await AudioBackupService.importAudioLibrary(
        selectedBackup.path,
        onProgress: (progress, status, current, total) {
          dialogKey.currentState?.updateProgress(progress, status, current, total);
        },
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Reload data
      await _loadData();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Import Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✓ ${result.importedCount} audio files imported'),
              if (result.foldersCreated > 0)
                Text('✓ ${result.foldersCreated} folders created'),
              if (result.skippedCount > 0)
                Text('⚠ ${result.skippedCount} files skipped', 
                  style: const TextStyle(color: Colors.orange)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      try {
        Navigator.pop(context); // Close loading dialog if open
      } catch (_) {}
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isBackupOperationInProgress = false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isBackupOperationInProgress) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please wait, audio backup is in progress...')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_showFolderView ? 'Audio Library' : _folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => _folders.first).name),
        leading: _showFolderView
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToFolders,
              ),
          actions: [
            if (_showFolderView) ...[
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AudioExtractionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Extract New'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportLibrary();
                      break;
                    case 'import':
                      _importLibrary();
                      break;
                    case 'create_folder':
                      _createFolder();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.upload, size: 20),
                        SizedBox(width: 12),
                        Text('Export Library'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 12),
                        Text('Import Library'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'create_folder',
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder, size: 20),
                        SizedBox(width: 12),
                        Text('Create Folder'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: WillPopScope(
          onWillPop: () async {
            if (_isBackupOperationInProgress) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please wait, audio backup is in progress...')),
              );
              return false;
            }
            return true;
          },
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showFolderView
                  ? _buildFolderView()
                  : _buildAudioListView(),
        ),
      ),
    );
  }

  Widget _buildFolderView() {
    if (_folders.isEmpty) {
      return const Center(child: Text('No folders'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: 2 columns on small screens, 3 on medium, 4 on large
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _folders.length,
          itemBuilder: (context, index) {
            final folder = _folders[index];
            // For "All Audio" folder, show total count, otherwise show folder count
            final count = folder.id == 'all_audio'
                ? AudioLibraryService.getAllAudioFiles().length
                : AudioLibraryService.getAudioCountByFolder(folder.id);

            return GestureDetector(
              onTap: () => _loadAudioFiles(folder.id),
              onLongPress: () => _deleteFolder(folder),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(folder.colorValue),
                      Color(folder.colorValue).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(folder.colorValue).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _loadAudioFiles(folder.id),
                    onLongPress: () => _deleteFolder(folder),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isEmoji(folder.iconName)
                                  ? Text(
                                      folder.iconName ?? '📁',
                                      style: const TextStyle(fontSize: 48),
                                    )
                                  : Icon(
                                      _getIconData(folder.iconName),
                                      size: 48,
                                      color: Colors.white,
                                    ),
                              const SizedBox(height: 12),
                              Text(
                                folder.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Three-dot menu (only for non-system folders)
                        if (folder.id != 'all_audio' && folder.id != 'default')
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showFolderOptions(folder),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioListView() {
    if (_audioFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No audio in this folder',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _audioFiles.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final audioFile = _audioFiles[index];
        final isPlaying = _playingAudioId == audioFile.id;

        // Get folder info for this audio
        final audioFolder = AudioLibraryService.getFolder(audioFile.folderId);
        final isAllAudioView = _selectedFolderId == 'all_audio';

        return ListTile(
          leading: _buildThumbnail(audioFile),
          title: Text(
            audioFile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(audioFile.durationFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.storage, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(audioFile.fileSizeFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              // Show folder name if viewing "All Audio"
              if (isAllAudioView && audioFolder != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    _isEmoji(audioFolder.iconName)
                        ? Text(audioFolder.iconName ?? '📁', style: const TextStyle(fontSize: 12))
                        : Icon(
                            _getIconData(audioFolder.iconName),
                            size: 12,
                            color: Color(audioFolder.colorValue),
                          ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(audioFolder.colorValue).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(audioFolder.colorValue).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        audioFolder.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(audioFolder.colorValue),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                color: isPlaying ? Colors.red : Colors.purple,
                onPressed: () {
                  if (isPlaying) {
                    _stopAudio();
                  } else {
                    _playAudio(audioFile);
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'move') {
                    _moveAudioToFolder(audioFile);
                  } else if (value == 'delete') {
                    _deleteAudio(audioFile);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move, size: 20),
                        SizedBox(width: 8),
                        Text('Move to folder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: widget.onAudioSelected != null
              ? () {
                  Navigator.pop(context);
                  widget.onAudioSelected!(audioFile);
                }
              : null,
        );
      },
    );
  }

  Widget _buildThumbnail(AudioFile audioFile) {
    if (audioFile.thumbnailPath != null && File(audioFile.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(audioFile.thumbnailPath!),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: Colors.purple[700]),
    );
  }
}
