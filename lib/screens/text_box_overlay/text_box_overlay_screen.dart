import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';

class TextBoxOverlayScreen extends StatefulWidget {
  const TextBoxOverlayScreen({Key? key}) : super(key: key);

  @override
  State<TextBoxOverlayScreen> createState() => _TextBoxOverlayScreenState();
}

class _TextBoxOverlayScreenState extends State<TextBoxOverlayScreen> {
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  // State
  File? _selectedVideo;
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _outputPath;
  Timer? _progressTimer;
  
  // Text box settings
  String _textContent = "Your text here...";
  double _fontSize = 40.0;
  double _boxHeight = 80.0;
  String _textColor = "#000000"; // default black
  String _boxColor = "#FFFFFF";  // default white
  double _boxOpacity = 1.0;
  String _textBoxPosition = 'top'; // 'top' or 'bottom'
  
  // Encoding settings
  String _preset = 'veryfast';
  double _crf = 23.0;
  
  // Controllers
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _textColorController = TextEditingController();
  final TextEditingController _boxColorController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _textController.text = _textContent;
    _textColorController.text = _textColor.replaceFirst('#', '');
    _boxColorController.text = _boxColor.replaceFirst('#', '');
    _setupMethodCallHandler();
  }
  
  @override
  void dispose() {
    _progressTimer?.cancel();
    _textController.dispose();
    _textColorController.dispose();
    _boxColorController.dispose();
    super.dispose();
  }
  
  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onProgress':
          setState(() {
            _progress = call.arguments as double;
          });
          break;
      }
    });
  }
  
  Future<void> _selectVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Error selecting video', e.toString());
    }
  }
  
  Future<void> _processVideo() async {
    if (_selectedVideo == null) {
      _showErrorDialog('No Video Selected', 'Please select a video first.');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    
    try {
      debugPrint('[TextBoxOverlay] Starting addTextToVideo');

      _progressTimer?.cancel();
      final startTime = DateTime.now();
      const estimatedDuration = Duration(seconds: 20);
      _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isProcessing) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime);
        final ratio = elapsed.inMilliseconds / estimatedDuration.inMilliseconds;
        setState(() {
          _progress = ratio.clamp(0.0, 0.99);
        });
      });

      // Get an output path from the native side
      final outputPath = await platform.invokeMethod<String>('getVideoOutputPath', {
        'filename': 'TextBox_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });

      if (outputPath == null) {
        throw Exception('Failed to get output path for processed video');
      }

      // Temporary font path for testing; later we can map to app fonts
      const String testFontPath = '/system/fonts/Roboto-Regular.ttf';

      debugPrint('[TextBoxOverlay] Calling addTextToVideo with input=${_selectedVideo!.path}, output=$outputPath, font=$testFontPath');

      final result = await platform.invokeMethod<String>('addTextToVideo', {
        'inputPath': _selectedVideo!.path,
        'outputPath': outputPath,
        'text': _textContent,
        'x': 50,
        'y': 50,
        'fontSize': _fontSize.toInt(),
        'fontColor': _textColor,
        'boxColor': _boxColor,
        'position': _textBoxPosition,
        'fontPath': testFontPath,
        'preset': _preset,
        'crf': _crf.toInt(),
      });
      
      setState(() {
        _isProcessing = false;
        _outputPath = result ?? outputPath;
        _progress = 1.0;
      });
      
      _progressTimer?.cancel();
      
      debugPrint('[TextBoxOverlay] Processing completed, output=$_outputPath');
      _showSuccessDialog();
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      _progressTimer?.cancel();
      
      debugPrint('[TextBoxOverlay] Error during processing: $e');
      _showErrorDialog('Processing Failed', e.toString());
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _parseHexColor(String value, Color fallback) {
    try {
      var v = value.trim();
      if (v.isEmpty) return fallback;
      if (v.startsWith('#')) {
        v = v.substring(1);
      }
      if (v.length == 6) {
        v = 'FF$v';
      }
      if (v.length != 8) return fallback;
      final intColor = int.parse(v, radix: 16);
      return Color(intColor);
    } catch (_) {
      return fallback;
    }
  }
  
  String _colorToHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    // Drop alpha, keep RRGGBB
    return '#${value.substring(2)}';
  }

  Future<void> _pickColor({required bool isText}) async {
    final initial = _parseHexColor(
      isText ? _textColor : _boxColor,
      isText ? Colors.black : Colors.white,
    );

    Color tempColor = initial;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isText ? 'Pick Text Color' : 'Pick Box Color'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tempColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildColorSlider('R', tempColor.red, Colors.red, (v) {
                    setStateDialog(() {
                      tempColor = tempColor.withRed(v);
                    });
                  }),
                  _buildColorSlider('G', tempColor.green, Colors.green, (v) {
                    setStateDialog(() {
                      tempColor = tempColor.withGreen(v);
                    });
                  }),
                  _buildColorSlider('B', tempColor.blue, Colors.blue, (v) {
                    setStateDialog(() {
                      tempColor = tempColor.withBlue(v);
                    });
                  }),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final hex = _colorToHex(tempColor);
                  if (isText) {
                    _textColor = hex;
                    final digits = hex.replaceFirst('#', '');
                    _textColorController.value = TextEditingValue(
                      text: digits,
                      selection: TextSelection.collapsed(offset: digits.length),
                    );
                  } else {
                    _boxColor = hex;
                    final digits = hex.replaceFirst('#', '');
                    _boxColorController.value = TextEditingValue(
                      text: digits,
                      selection: TextSelection.collapsed(offset: digits.length),
                    );
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorSlider(
    String label,
    int value,
    Color activeColor,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toString().padLeft(3, ' '),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Success!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text box overlay added successfully!'),
            if (_outputPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved to: ${_outputPath!.split('/').last}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          if (_outputPath != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                OpenFile.open(_outputPath!);
              },
              child: const Text('Open Video'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Text Box Overlay'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Video Selection Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📹 Select Video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedVideo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.video_file, color: Colors.green[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedVideo!.path.split('/').last,
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _selectVideo,
                        icon: const Icon(Icons.video_library),
                        label: Text(_selectedVideo == null ? 'Select Video' : 'Change Video'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Encoding Settings Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚙️ Encoding Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Text Box Position
                    const Text(
                      'Text Box Position:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Top'),
                          selected: _textBoxPosition == 'top',
                          onSelected: _isProcessing
                              ? null
                              : (selected) {
                                  if (!selected) return;
                                  setState(() {
                                    _textBoxPosition = 'top';
                                  });
                                },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Bottom'),
                          selected: _textBoxPosition == 'bottom',
                          onSelected: _isProcessing
                              ? null
                              : (selected) {
                                  if (!selected) return;
                                  setState(() {
                                    _textBoxPosition = 'bottom';
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Preset dropdown
                    const Text(
                      'x264 Preset (speed vs quality):',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _preset,
                      isExpanded: true,
                      items: const [
                        'ultrafast',
                        'superfast',
                        'veryfast',
                        'faster',
                        'fast',
                        'medium',
                      ].map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.toUpperCase()),
                          ))
                          .toList(),
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _preset = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    
                    // CRF slider
                    Text(
                      'CRF (quality, lower = better): ${_crf.toInt()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Slider(
                      value: _crf,
                      min: 18,
                      max: 30,
                      divisions: 12,
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              setState(() {
                                _crf = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              
              // Text Settings Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✏️ Text Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Text Content
                    const Text(
                      'Text Content:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      enabled: !_isProcessing,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter your text here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _textContent = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Font Size
                    Text(
                      'Font Size: ${_fontSize.toInt()}px',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Slider(
                      value: _fontSize,
                      min: 20,
                      max: 80,
                      divisions: 12,
                      onChanged: _isProcessing ? null : (value) {
                        setState(() {
                          _fontSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Box Height
                    Text(
                      'Box Height: ${_boxHeight.toInt()}px',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Slider(
                      value: _boxHeight,
                      min: 50,
                      max: 150,
                      divisions: 10,
                      onChanged: _isProcessing ? null : (value) {
                        setState(() {
                          _boxHeight = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Color Settings Card
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎨 Color Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Text Color (HEX):',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _isProcessing ? null : () => _pickColor(isText: true),
                                        child: Container(
                                          width: 40,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            color: _parseHexColor(_textColor, Colors.black),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              bottomLeft: Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          enabled: !_isProcessing,
                                          decoration: const InputDecoration(
                                            prefixText: '#',
                                            hintText: '000000',
                                            border: InputBorder.none,
                                            isCollapsed: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                          ),
                                          controller: _textColorController,
                                          onChanged: (value) {
                                            setState(() {
                                              final cleaned = value.replaceAll('#', '').trim().toUpperCase();
                                              final withHash = cleaned.isEmpty ? '#000000' : '#$cleaned';
                                              _textColor = withHash;
                                              _textColorController.value = TextEditingValue(
                                                text: cleaned,
                                                selection: TextSelection.collapsed(offset: cleaned.length),
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Box Color (HEX):',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _isProcessing ? null : () => _pickColor(isText: false),
                                        child: Container(
                                          width: 40,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            color: _parseHexColor(_boxColor, Colors.white),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              bottomLeft: Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          enabled: !_isProcessing,
                                          decoration: const InputDecoration(
                                            prefixText: '#',
                                            hintText: 'FFFFFF',
                                            border: InputBorder.none,
                                            isCollapsed: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                          ),
                                          controller: _boxColorController,
                                          onChanged: (value) {
                                            setState(() {
                                              final cleaned = value.replaceAll('#', '').trim().toUpperCase();
                                              final withHash = cleaned.isEmpty ? '#FFFFFF' : '#$cleaned';
                                              _boxColor = withHash;
                                              _boxColorController.value = TextEditingValue(
                                                text: cleaned,
                                                selection: TextSelection.collapsed(offset: cleaned.length),
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Process Button
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: [
                    if (_isProcessing) ...[
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Processing... ${(_progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_selectedVideo != null && !_isProcessing) ? _processVideo : null,
                        icon: _isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                        label: Text(_isProcessing ? 'Processing...' : 'Add Text Box Overlay'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
