import 'package:flutter/material.dart';
import '../models/audio_export_format.dart';
import '../services/audio_extractor_service.dart';

class AudioExtractorSuccessSheet extends StatefulWidget {
  final ExtractedAudioResult? result;
  final List<ExtractedAudioResult>? batchResults;
  final String? videoThumbnailPath;
  final String? originalVideoPath;

  const AudioExtractorSuccessSheet({
    super.key,
    this.result,
    this.batchResults,
    this.videoThumbnailPath,
    this.originalVideoPath,
  });

  static Future<void> show(
    BuildContext context, {
    required ExtractedAudioResult result,
    String? videoThumbnailPath,
    String? originalVideoPath,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AudioExtractorSuccessSheet(
        result: result,
        videoThumbnailPath: videoThumbnailPath,
        originalVideoPath: originalVideoPath,
      ),
    );
  }

  static Future<void> showBatch(
    BuildContext context, {
    required List<ExtractedAudioResult> batchResults,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AudioExtractorSuccessSheet(
        batchResults: batchResults,
      ),
    );
  }

  @override
  State<AudioExtractorSuccessSheet> createState() => _AudioExtractorSuccessSheetState();
}

class _AudioExtractorSuccessSheetState extends State<AudioExtractorSuccessSheet> {
  bool _addedToLibrary = false;
  bool _isAdding = false;

  bool get _isBatch => (widget.batchResults != null && widget.batchResults!.length > 1);

  Future<void> _handleAddToLibrary() async {
    if (_addedToLibrary || _isAdding) return;
    setState(() => _isAdding = true);

    if (_isBatch) {
      for (final res in widget.batchResults!) {
        await AudioExtractorService.addToAudioLibrary(result: res);
      }
    } else if (widget.result != null) {
      await AudioExtractorService.addToAudioLibrary(
        result: widget.result!,
        thumbnailPath: widget.videoThumbnailPath,
        originalVideoPath: widget.originalVideoPath,
      );
    }

    if (mounted) {
      setState(() {
        _isAdding = false;
        _addedToLibrary = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Quick Post Audio Library!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Success badge
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 34,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _isBatch
                  ? '${widget.batchResults!.length} Audios Extracted Successfully!'
                  : 'Audio Extracted Successfully!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved to device Music gallery (MediaStore)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 14),

            // Content body: Single card or Scrollable batch list
            Flexible(
              child: _isBatch
                  ? _buildBatchList(theme, isDark)
                  : _buildSingleDetailCard(theme, isDark),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (_isBatch) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text('Share All (${widget.batchResults!.length} Files)'),
                  onPressed: () {
                    final paths = widget.batchResults!
                        .map((r) => r.filePath)
                        .where((p) => p.isNotEmpty)
                        .toList();
                    AudioExtractorService.shareMultipleAudioFiles(paths);
                  },
                ),
              ),
            ] else if (widget.result != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Open Player'),
                      onPressed: () => AudioExtractorService.openAudioFile(widget.result!.filePath),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                      onPressed: () => AudioExtractorService.shareAudioFile(
                        widget.result!.filePath,
                        fileName: widget.result!.fileName,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Add to library button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _addedToLibrary ? const Color(0xFF2E7D32) : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  _addedToLibrary ? Icons.check_circle_rounded : Icons.library_music_rounded,
                  size: 20,
                ),
                label: Text(
                  _addedToLibrary
                      ? 'Saved to Creator Library'
                      : (_isAdding
                          ? 'Adding...'
                          : (_isBatch ? 'Add All to Creator Audio Library' : 'Add to Creator Audio Library')),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _addedToLibrary ? null : _handleAddToLibrary,
              ),
            ),
            const SizedBox(height: 6),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDetailCard(ThemeData theme, bool isDark) {
    final result = widget.result!;
    final format = result.format;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: format.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  format.label,
                  style: TextStyle(
                    color: format.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: result.formattedDuration,
                isDark: isDark,
              ),
              _buildInfoItem(
                icon: Icons.sd_storage_outlined,
                label: 'Size',
                value: result.formattedSize,
                isDark: isDark,
              ),
              _buildInfoItem(
                icon: Icons.graphic_eq_rounded,
                label: 'Sampling',
                value: '${(result.sampleRate / 1000).toStringAsFixed(1)} kHz',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchList(ThemeData theme, bool isDark) {
    final results = widget.batchResults!;
    return ListView.separated(
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final res = results[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: res.format.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  res.format.label,
                  style: TextStyle(
                    color: res.format.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${res.formattedDuration} • ${res.formattedSize}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => AudioExtractorService.openAudioFile(res.filePath),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => AudioExtractorService.shareAudioFile(res.filePath, fileName: res.fileName),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
