import 'package:flutter/material.dart';

enum AudioExportFormat {
  mp3,
  wav,
  m4a,
}

extension AudioExportFormatX on AudioExportFormat {
  String get extensionName {
    switch (this) {
      case AudioExportFormat.mp3:
        return 'mp3';
      case AudioExportFormat.wav:
        return 'wav';
      case AudioExportFormat.m4a:
        return 'm4a';
    }
  }

  String get label {
    switch (this) {
      case AudioExportFormat.mp3:
        return 'MP3';
      case AudioExportFormat.wav:
        return 'WAV';
      case AudioExportFormat.m4a:
        return 'M4A / AAC';
    }
  }

  String get title {
    switch (this) {
      case AudioExportFormat.mp3:
        return 'MP3 Audio';
      case AudioExportFormat.wav:
        return 'Lossless WAV';
      case AudioExportFormat.m4a:
        return 'AAC / M4A';
    }
  }

  String get description {
    switch (this) {
      case AudioExportFormat.mp3:
        return 'Universal standard. Plays on all media players and devices.';
      case AudioExportFormat.wav:
        return 'Uncompressed 16-bit PCM. Highest fidelity for editing & DAWs.';
      case AudioExportFormat.m4a:
        return 'Modern high-efficiency AAC. Pristine quality at compact sizes.';
    }
  }

  String get mimeType {
    switch (this) {
      case AudioExportFormat.mp3:
        return 'audio/mpeg';
      case AudioExportFormat.wav:
        return 'audio/wav';
      case AudioExportFormat.m4a:
        return 'audio/mp4';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioExportFormat.mp3:
        return Icons.music_note_rounded;
      case AudioExportFormat.wav:
        return Icons.graphic_eq_rounded;
      case AudioExportFormat.m4a:
        return Icons.audiotrack_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AudioExportFormat.mp3:
        return const Color(0xFFFF7043); // Orange
      case AudioExportFormat.wav:
        return const Color(0xFF26A69A); // Teal
      case AudioExportFormat.m4a:
        return const Color(0xFF7E57C2); // Purple
    }
  }

  List<int> get availableBitrates {
    switch (this) {
      case AudioExportFormat.mp3:
        return [128, 192, 256, 320];
      case AudioExportFormat.m4a:
        return [128, 192, 256, 320];
      case AudioExportFormat.wav:
        return []; // WAV is uncompressed PCM
    }
  }
}

class ExtractedAudioResult {
  final bool success;
  final String filePath;
  final String fileName;
  final AudioExportFormat format;
  final int durationMs;
  final int fileSizeBytes;
  final int sampleRate;
  final int channels;
  final String? errorMessage;
  final DateTime createdAt;

  ExtractedAudioResult({
    required this.success,
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.durationMs,
    required this.fileSizeBytes,
    required this.sampleRate,
    required this.channels,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory ExtractedAudioResult.fromMap(Map<dynamic, dynamic> map, AudioExportFormat fallbackFormat) {
    final formatStr = (map['format'] as String? ?? fallbackFormat.extensionName).toLowerCase();
    AudioExportFormat resolvedFormat = fallbackFormat;
    for (final fmt in AudioExportFormat.values) {
      if (fmt.extensionName == formatStr) {
        resolvedFormat = fmt;
        break;
      }
    }

    return ExtractedAudioResult(
      success: map['success'] as bool? ?? false,
      filePath: map['filePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      format: resolvedFormat,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      sampleRate: (map['sampleRate'] as num?)?.toInt() ?? 44100,
      channels: (map['channels'] as num?)?.toInt() ?? 2,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

