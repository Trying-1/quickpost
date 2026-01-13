import 'package:flutter/material.dart';

class AudioProgressDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onCancel;

  const AudioProgressDialog({
    Key? key,
    required this.title,
    required this.message,
    this.onCancel,
  }) : super(key: key);

  @override
  State<AudioProgressDialog> createState() => AudioProgressDialogState();
}

class AudioProgressDialogState extends State<AudioProgressDialog> {
  double _progress = 0.0;
  String _statusMessage = '';
  int _currentItem = 0;
  int _totalItems = 0;

  void updateProgress(double progress, String status, int current, int total) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusMessage = status;
        _currentItem = current;
        _totalItems = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
            ),
          ),
          const SizedBox(height: 12),
          // Progress text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[700],
                ),
              ),
              Text(
                '$_currentItem / $_totalItems',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status message
          if (_statusMessage.isNotEmpty)
            Text(
              _statusMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      actions: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('CANCEL'),
          ),
      ],
      actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
    );
  }
}
