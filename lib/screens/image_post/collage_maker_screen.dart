import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../utils/image_generator.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../services/app_review_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GridCell {
  final Rect rect; // Normalized 0.0 to 1.0
  GridCell(this.rect);
}

class GridLayoutDefinition {
  final String name;
  final IconData icon;
  final List<GridCell> cells;
  GridLayoutDefinition({required this.name, required this.icon, required this.cells});
}

class CollageMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const CollageMakerScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<CollageMakerScreen> createState() => _CollageMakerScreenState();
}

class CenteredSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    // Visual center of the track
    final double center = trackRect.left + trackRect.width / 2;
    
    // Draw inactive track (full background)
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2)),
      inactivePaint,
    );

    // Draw active track from center to thumb
    final double left = thumbCenter.dx < center ? thumbCenter.dx : center;
    final double right = thumbCenter.dx < center ? center : thumbCenter.dx;
    
    if (right > left) {
      context.canvas.drawRect(
        Rect.fromLTRB(left, trackRect.top - (additionalActiveTrackHeight / 2), right, trackRect.bottom + (additionalActiveTrackHeight / 2)),
        activePaint,
      );
    }
  }
}

class _LayoutSnapshot {
  final List<Rect> cells;
  final List<File?> images;
  final List<double> radii;
  final List<bool> flippedH;
  final List<bool> flippedV;
  _LayoutSnapshot({
    required this.cells,
    required this.images,
    required this.radii,
    required this.flippedH,
    required this.flippedV,
  });
}

class _CollageMakerScreenState extends State<CollageMakerScreen> {
  List<File?> _images = [];
  List<TransformationController> _controllers = [];
  final int _maxPossibleImages = 50;
  late List<double> _saturations;
  late List<double> _brightnesses;
  late List<double> _blurs;
  late List<double> _cellCornerRadii;
  int _selectedLayoutIndex = 15; // Point to Dynamic Grid by default
  
  double _spacing = 4.0;
  bool _showEdgeSpacing = true;
  Color _bgColor = Colors.white;
  int _selectedAspectIndex = 0; // 0: 4:5, 1: 1:1, 2: 9:16, 3: 16:9
  List<bool> _cellFlippedH = [];
  List<bool> _cellFlippedV = [];
  
  // Custom Layout State
  bool _isLayoutEditingMode = false;
  bool _isTiledMode = false; // Tiling (Single Layer) vs Freeform
  int _customGridRows = 2;
  int _customGridCols = 2;
  List<double?> _imageAspectRatios = [];
  Map<int, Size> _lastCellSizes = {};
  int? _mergingSlotIndex;
  int _customEditorSubTab = 0; // 0: Fine Tune, 1: Order
  List<Rect> _customCells = [const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8)];
  int? _activeHandleIndex; // 0-7 for resize, 8 for move
  int? _activeCellIndex;
  List<List<Rect>> _customPresets = [];
  static const String _presetsKey = 'collage_custom_presets';

  final List<_LayoutSnapshot> _undoStack = [];
  final List<_LayoutSnapshot> _redoStack = [];

  void _saveSnapshot() {
    _undoStack.add(_LayoutSnapshot(
      cells: List.from(_customCells),
      images: List.from(_images),
      radii: List.from(_cellCornerRadii),
      flippedH: List.from(_cellFlippedH),
      flippedV: List.from(_cellFlippedV),
    ));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_LayoutSnapshot(
        cells: List.from(_customCells),
        images: List.from(_images),
        radii: List.from(_cellCornerRadii),
        flippedH: List.from(_cellFlippedH),
        flippedV: List.from(_cellFlippedV),
      ));
      final snap = _undoStack.removeLast();
      _customCells = snap.cells;
      _images = snap.images;
      _cellCornerRadii = snap.radii;
      _cellFlippedH = snap.flippedH;
      _cellFlippedV = snap.flippedV;
      _selectedCellIndex = null;
      _mergingSlotIndex = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_LayoutSnapshot(
        cells: List.from(_customCells),
        images: List.from(_images),
        radii: List.from(_cellCornerRadii),
        flippedH: List.from(_cellFlippedH),
        flippedV: List.from(_cellFlippedV),
      ));
      final snap = _redoStack.removeLast();
      _customCells = snap.cells;
      _images = snap.images;
      _cellCornerRadii = snap.radii;
      _cellFlippedH = snap.flippedH;
      _cellFlippedV = snap.flippedV;
      _selectedCellIndex = null;
      _mergingSlotIndex = null;
    });
  }

  final GlobalKey _previewKey = GlobalKey();
  int _selectedTabIndex = 0; // 0: Layout, 1: Images, 2: Style, 3: Config
  int _selectedLayoutSubTab = 0; // 0: Basics, 1: Bento
  bool _isTabContentExpanded = true;

  int _columns = 3;
  int _rows = 3;
  bool _autoHeight = false;
  double _cornerRadius = 0.0;

  late TextEditingController _colsController;
  late TextEditingController _rowsController;
  late TextEditingController _customColsController;
  late TextEditingController _customRowsController;
  int? _selectedCellIndex;
  BoxConstraints? _lastConstraints;
  bool _isSwapMode = false;
  bool _isMultiSelectMode = false;
  final Set<int> _selectedIndices = {};
  bool _isExporting = false;
  static const _collageChannel = MethodChannel('com.quickpost.app/collage_renderer');

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Changes?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to exit? Your current collage progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  final List<GridLayoutDefinition> _layouts = [
    GridLayoutDefinition(
      name: '2x2 Grid',
      icon: Icons.grid_view_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.5, 0.5)),
        GridCell(const Rect.fromLTRB(0.5, 0, 1.0, 0.5)),
        GridCell(const Rect.fromLTRB(0, 0.5, 0.5, 1.0)),
        GridCell(const Rect.fromLTRB(0.5, 0.5, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '1+2 Vertical',
      icon: Icons.view_quilt_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.5, 1.0)),
        GridCell(const Rect.fromLTRB(0.5, 0, 1.0, 0.5)),
        GridCell(const Rect.fromLTRB(0.5, 0.5, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '1+2 Horizontal',
      icon: Icons.view_compact_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 1.0, 0.5)),
        GridCell(const Rect.fromLTRB(0, 0.5, 0.5, 1.0)),
        GridCell(const Rect.fromLTRB(0.5, 0.5, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '3x3 Grid',
      icon: Icons.grid_on_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.333, 0.333)),
        GridCell(const Rect.fromLTRB(0.333, 0, 0.666, 0.333)),
        GridCell(const Rect.fromLTRB(0.666, 0, 1.0, 0.333)),
        GridCell(const Rect.fromLTRB(0, 0.333, 0.333, 0.666)),
        GridCell(const Rect.fromLTRB(0.333, 0.333, 0.666, 0.666)),
        GridCell(const Rect.fromLTRB(0.666, 0.333, 1.0, 0.666)),
        GridCell(const Rect.fromLTRB(0, 0.666, 0.333, 1.0)),
        GridCell(const Rect.fromLTRB(0.333, 0.666, 0.666, 1.0)),
        GridCell(const Rect.fromLTRB(0.666, 0.666, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '2 Vertical',
      icon: Icons.view_column_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.5, 1.0)),
        GridCell(const Rect.fromLTRB(0.5, 0, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '2 Horizontal',
      icon: Icons.view_agenda_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 1.0, 0.5)),
        GridCell(const Rect.fromLTRB(0, 0.5, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: 'Bento Modern',
      icon: Icons.dashboard_customize_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.66, 0.66)), // Large Main
        GridCell(const Rect.fromLTRB(0.66, 0, 1.0, 0.33)), // Top Right
        GridCell(const Rect.fromLTRB(0.66, 0.33, 1.0, 0.66)), // Mid Right
        GridCell(const Rect.fromLTRB(0, 0.66, 0.5, 1.0)), // Bottom Left
        GridCell(const Rect.fromLTRB(0.5, 0.66, 1.0, 1.0)), // Bottom Right
      ],
    ),
    GridLayoutDefinition(
      name: 'Bento Tall',
      icon: Icons.view_sidebar_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.4, 1.0)), // Left Tall
        GridCell(const Rect.fromLTRB(0.4, 0, 1.0, 0.5)), // Top Square
        GridCell(const Rect.fromLTRB(0.4, 0.5, 1.0, 1.0)), // Bottom Square
      ],
    ),
    GridLayoutDefinition(
      name: 'Bento Wide',
      icon: Icons.view_day_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 1.0, 0.4)), // Top Wide
        GridCell(const Rect.fromLTRB(0, 0.4, 0.5, 1.0)), // Bottom Left
        GridCell(const Rect.fromLTRB(0.5, 0.4, 1.0, 1.0)), // Bottom Right
      ],
    ),
    GridLayoutDefinition(
      name: 'Bento Mix',
      icon: Icons.auto_awesome_mosaic_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.5, 0.4)), // High Left
        GridCell(const Rect.fromLTRB(0.5, 0, 1.0, 0.6)), // High Right
        GridCell(const Rect.fromLTRB(0, 0.4, 0.5, 0.7)), // Mid Left
        GridCell(const Rect.fromLTRB(0.5, 0.6, 1.0, 1.0)), // Low Right
        GridCell(const Rect.fromLTRB(0, 0.7, 0.25, 1.0)), // Bottom Tiny 1
        GridCell(const Rect.fromLTRB(0.25, 0.7, 0.5, 1.0)), // Bottom Tiny 2
      ],
    ),
    GridLayoutDefinition(
      name: 'Golden Ratio',
      icon: Icons.filter_frames_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.618, 1.0)), // Large Left
        GridCell(const Rect.fromLTRB(0.618, 0, 1.0, 0.382)), // Top Right
        GridCell(const Rect.fromLTRB(0.618, 0.382, 1.0, 0.618)), // Mid Right
        GridCell(const Rect.fromLTRB(0.618, 0.618, 1.0, 1.0)), // Bottom Right
      ],
    ),
    GridLayoutDefinition(
      name: 'Panorama Focus',
      icon: Icons.panorama_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 1.0, 0.2)), // Top Strip
        GridCell(const Rect.fromLTRB(0, 0.2, 1.0, 0.8)), // Large Panorama
        GridCell(const Rect.fromLTRB(0, 0.8, 1.0, 1.0)), // Bottom Strip
      ],
    ),
    GridLayoutDefinition(
      name: 'Focus Center',
      icon: Icons.center_focus_strong_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0.25, 0.25, 0.75, 0.75)), // Hero Center
        GridCell(const Rect.fromLTRB(0, 0, 0.25, 0.25)), // TL
        GridCell(const Rect.fromLTRB(0.25, 0, 0.75, 0.25)), // TC
        GridCell(const Rect.fromLTRB(0.75, 0, 1.0, 0.25)), // TR
        GridCell(const Rect.fromLTRB(0, 0.25, 0.25, 0.75)), // ML
        GridCell(const Rect.fromLTRB(0.75, 0.25, 1.0, 0.75)), // MR
        GridCell(const Rect.fromLTRB(0, 0.75, 0.25, 1.0)), // BL
        GridCell(const Rect.fromLTRB(0.25, 0.75, 0.75, 1.0)), // BC
        GridCell(const Rect.fromLTRB(0.75, 0.75, 1.0, 1.0)), // BR
      ],
    ),
    GridLayoutDefinition(
      name: '3 Slits Tall',
      icon: Icons.view_week_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 0.33, 1.0)),
        GridCell(const Rect.fromLTRB(0.33, 0, 0.67, 1.0)),
        GridCell(const Rect.fromLTRB(0.67, 0, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: '3 Slits Wide',
      icon: Icons.view_stream_rounded,
      cells: [
        GridCell(const Rect.fromLTRB(0, 0, 1.0, 0.33)),
        GridCell(const Rect.fromLTRB(0, 0.33, 1.0, 0.67)),
        GridCell(const Rect.fromLTRB(0, 0.67, 1.0, 1.0)),
      ],
    ),
    GridLayoutDefinition(
      name: 'Dynamic Grid',
      icon: Icons.all_inclusive_rounded,
      cells: [], // Dynamic calculation
    ),
  ];

  double get _currentAspectRatio {
    if (_autoHeight) {
      return _columns / _rows.clamp(1, 100);
    }
    switch (_selectedAspectIndex) {
      case 1: return 1 / 1;
      case 2: return 9 / 16;
      case 3: return 16 / 9;
      case 0:
      default: return 4 / 5;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPresets();
    _colsController = TextEditingController(text: _columns.toString());
    _rowsController = TextEditingController(text: _rows.toString());
    _customColsController = TextEditingController(text: _customGridCols.toString());
    _customRowsController = TextEditingController(text: _customGridRows.toString());
    _saturations = List.filled(_maxPossibleImages, 1.0);
    _brightnesses = List.filled(_maxPossibleImages, 0.0);
    _blurs = List.filled(_maxPossibleImages, 0.0);
    _cellCornerRadii = List.filled(_maxPossibleImages, 0.0);
    _cellFlippedH = List.filled(_maxPossibleImages, false);
    _cellFlippedV = List.filled(_maxPossibleImages, false);
    _imageAspectRatios = List.filled(_maxPossibleImages, null);
    _initializeImageData();
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _loadSharedImages();
    }
  }

  void _initializeImageData() {
    // Expand to support more images for infinite grid
    for (int i = 0; i < _maxPossibleImages; i++) {
      _images.add(null);
      final controller = TransformationController();
      controller.addListener(() {
        if (_selectedCellIndex == i && _selectedTabIndex == 3) {
          setState(() {});
        }
      });
      _controllers.add(controller);
    }
  }

  void _loadSharedImages() {
    setState(() {
      for (int i = 0; i < widget.sharedImagePaths!.length && i < _maxPossibleImages; i++) {
        _images[i] = File(widget.sharedImagePaths![i]);
        _loadImageDimensions(i);
      }
      
      // Auto-select Dynamic Grid by default
      _selectedLayoutIndex = _layouts.indexWhere((l) => l.name == 'Dynamic Grid');
      if (_selectedLayoutIndex == -1) _selectedLayoutIndex = 15;
      _updateGridDimensions(widget.sharedImagePaths!.length);
    });
  }

  void _updateGridDimensions(int count) {
    if (count <= 0) return;
    
    int cols = (count <= 3) ? count : (count <= 6) ? 3 : (count <= 12) ? 4 : (count <= 20) ? 5 : 6;
    
    if (count > 3) {
      if (count <= 4) cols = 2;
      else if (count <= 9) cols = 3;
      else if (count <= 16) cols = 4;
      else if (count <= 25) cols = 5;
      else cols = 6;
    } else {
      cols = count;
    }
    
    int rows = (count / cols).ceil();
    
    _columns = cols;
    _rows = rows;
    _colsController.text = _columns.toString();
    _rowsController.text = _rows.toString();
  }

  Size _getCellSize(int index, BoxConstraints constraints) {
    if (_layouts[_selectedLayoutIndex].name == 'Dynamic Grid') {
      final double cellW = (constraints.maxWidth - (_columns - 1) * _spacing) / _columns;
      final double cellH = _autoHeight ? cellW : (constraints.maxHeight - (_rows - 1) * _spacing) / _rows;
      return Size(cellW, cellH);
    } else {
      final rect = _layouts[_selectedLayoutIndex].cells[index].rect;
      final bool showEdge = _showEdgeSpacing;
      final double leftOffset = (rect.left == 0 && !showEdge) ? 0 : _spacing / 2;
      final double topOffset = (rect.top == 0 && !showEdge) ? 0 : _spacing / 2;
      final double rightOffset = (rect.right == 1.0 && !showEdge) ? 0 : _spacing / 2;
      final double bottomOffset = (rect.bottom == 1.0 && !showEdge) ? 0 : _spacing / 2;

      final double left = rect.left * constraints.maxWidth + leftOffset;
      final double top = rect.top * constraints.maxHeight + topOffset;
      final double right = rect.right * constraints.maxWidth - rightOffset;
      final double bottom = rect.bottom * constraints.maxHeight - bottomOffset;
      
      return Size(right - left, bottom - top);
    }
  }

  @override
  void dispose() {
    _colsController.dispose();
    _rowsController.dispose();
    _customColsController.dispose();
    _customRowsController.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleSwap(int index) {
    if (index < 0 || index >= _images.length) return;
    if (_selectedCellIndex == null || _selectedCellIndex == index || _selectedCellIndex! < 0 || _selectedCellIndex! >= _images.length) {
      setState(() => _selectedCellIndex = index);
      return;
    }

    setState(() {
      // Swap images
      final tempImage = _images[_selectedCellIndex!];
      _images[_selectedCellIndex!] = _images[index];
      _images[index] = tempImage;

      // Swap transformation matrices
      final tempMatrix = _controllers[_selectedCellIndex!].value;
      _controllers[_selectedCellIndex!].value = _controllers[index].value;
      _controllers[index].value = tempMatrix;

      // Swap saturations
      final tempSaturation = _saturations[_selectedCellIndex!];
      _saturations[_selectedCellIndex!] = _saturations[index];
      _saturations[index] = tempSaturation;

      // Swap brightnesses
      final tempBrightness = _brightnesses[_selectedCellIndex!];
      _brightnesses[_selectedCellIndex!] = _brightnesses[index];
      _brightnesses[index] = tempBrightness;

      // Swap blurs
      final tempBlur = _blurs[_selectedCellIndex!];
      _blurs[_selectedCellIndex!] = _blurs[index];
      _blurs[index] = tempBlur;

      _selectedCellIndex = index;
      _isSwapMode = false;
    });
  }

  void _isSwapModeReset() {
    setState(() {
      _isSwapMode = false;
    });
  }

  Future<void> _loadImageDimensions(int index) async {
    final file = _images[index];
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (mounted) {
        setState(() {
          _imageAspectRatios[index] = img.height > 0 ? (img.width / img.height) : 1.0;
          // Clear last size to force re-centering for new image
          _lastCellSizes.remove(index);
          // Reset transformation to identity so it starts at the new centered position
          _controllers[index].value = Matrix4.identity();
        });
      }
    } catch (e) {
      debugPrint('Error loading image dimensions: $e');
    }
  }

  Future<void> _pickImages({int? startIndex}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          int start = startIndex ?? 0;
          
          // If we are starting from scratch or picking for the first time
          if (startIndex == null || startIndex == 0) {
             // If we pick more than we have room for, we might need to expand
             int requiredCount = start + pickedFiles.length;
             // Cap at 50
             if (requiredCount > _maxPossibleImages) requiredCount = _maxPossibleImages;
             
             // Expand property lists to match the number of pickable slots if needed
             while (_images.length < requiredCount) {
               _images.add(null);
               _controllers.add(TransformationController());
               _saturations.add(1.0);
               _brightnesses.add(0.0);
               _blurs.add(0.0);
               _cellCornerRadii.add(_cornerRadius);
               _cellFlippedH.add(false);
               _cellFlippedV.add(false);
             }
          }

          // Now safely assign images (only up to the current list lengths to be extra safe)
          for (int i = 0; i < pickedFiles.length && (start + i) < _images.length; i++) {
            final idx = start + i;
            _images[idx] = File(pickedFiles[idx - start].path);
            if (_controllers[idx].value == Matrix4.identity()) {
               _controllers[idx] = TransformationController();
            }
            _loadImageDimensions(idx);
          }
          
          int totalCount = _images.where((img) => img != null).length;
          _selectedLayoutIndex = _layouts.indexWhere((l) => l.name == 'Dynamic Grid');
          if (_selectedLayoutIndex == -1) _selectedLayoutIndex = 15;
          _updateGridDimensions(totalCount);
          
          // Sync _customCells to match if in Dynamic Grid
          if (_layouts[_selectedLayoutIndex].name == 'Dynamic Grid') {
              _generateTiledGrid(_customGridRows, _customGridCols);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _exportCollage() async {
    if (_images.every((img) => img == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one image')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
    );

    try {
      const double exportWidth = 1080.0;
      final double exportHeight = exportWidth / _currentAspectRatio;

      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
          await ImageGenerator.savePostToGallery(
            text: '',
            templateKey: _previewKey,
            outputWidth: exportWidth.toInt(),
            outputHeight: exportHeight.toInt(),
          );

          if (mounted) {
            Navigator.pop(context); // Close progress
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collage saved to gallery!')));
            AppReviewService().incrementExportCount();
            AppReviewService().checkAndRequestReview();
          }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitDialog();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Hero(
                        tag: 'collage_preview',
                        child: AspectRatio(
                          aspectRatio: _currentAspectRatio,
                          child: RepaintBoundary(
                            key: _previewKey,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _bgColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  _lastConstraints = constraints;
                                  if (_selectedLayoutSubTab == 2) {
                                    return GestureDetector(
                                      onTapDown: (details) {
                                        if (!_isLayoutEditingMode) return;
                                        final double lX = details.localPosition.dx / constraints.maxWidth;
                                        final double lY = details.localPosition.dy / constraints.maxHeight;

                                        // Find all cells that contain this point
                                        final List<int> containingIndices = [];
                                        for (int i = 0; i < _customCells.length; i++) {
                                          if (_customCells[i].contains(Offset(lX, lY))) {
                                            containingIndices.add(i);
                                          }
                                        }

                                        if (containingIndices.isNotEmpty) {
                                          setState(() {
                                            // Always select the topmost visible cell (last in Stack order)
                                            _selectedCellIndex = containingIndices.last;
                                          });
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          _buildCustomGridLayout(constraints),
                                          if (_isLayoutEditingMode) 
                                            _buildLayoutEditorOverlay(constraints),
                                        ],
                                      ),
                                    );
                                  }
                                  if (_layouts[_selectedLayoutIndex].name == 'Dynamic Grid') {
                                    return _buildDynamicGridLayout(constraints);
                                  }
                                  return _buildGridLayout(constraints);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildControlsSection(),
              ],
            ),
            if (_isExporting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      SizedBox(height: 16),
                      Text('Rendering high-res collage...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDynamicGridLayout(BoxConstraints constraints) {
    final int rowsOverride = _rows;
    final int colsOverride = _columns;
    final int totalSlots = rowsOverride * colsOverride;

    final bool showEdge = _showEdgeSpacing;
    final double totalHGap = (colsOverride - 1 + (showEdge ? 1 : 0)) * _spacing;
    final double totalVGap = (rowsOverride - 1 + (showEdge ? 1 : 0)) * _spacing;

    final double cellW = (constraints.maxWidth - totalHGap) / colsOverride;
    final double cellH = _autoHeight 
        ? cellW 
        : (constraints.maxHeight - totalVGap) / rowsOverride;

    return Stack(
      children: List.generate(totalSlots, (index) {
        final int row = index ~/ colsOverride;
        final int col = index % colsOverride;
        
        // Find if we have an image for this slot
        // Currently we just pack them sequentially
        final activeImages = _images.asMap().entries.where((e) => e.value != null).toList();
        final bool hasImage = index < activeImages.length;
        final originalIndex = hasImage ? activeImages[index].key : -1;

        final double left = col * (cellW + _spacing) + (showEdge ? _spacing / 2 : 0);
        final double top = row * (cellH + _spacing) + (showEdge ? _spacing / 2 : 0);

        final bool isSelectedCell = _selectedCellIndex == originalIndex;

        return Positioned(
          left: left,
          top: top,
          width: cellW,
          height: cellH,
          child: GestureDetector(
            onTap: () {
              if (_isSwapMode) {
                if (originalIndex != -1) _handleSwap(originalIndex);
                return;
              }
              if (originalIndex == -1) {
                _pickImages(startIndex: activeImages.length);
                return;
              }

              setState(() {
                if (_isMultiSelectMode) {
                  if (_selectedIndices.contains(originalIndex)) {
                    _selectedIndices.remove(originalIndex);
                    if (_selectedCellIndex == originalIndex) {
                      _selectedCellIndex = _selectedIndices.isNotEmpty ? _selectedIndices.first : null;
                    }
                  } else {
                    _selectedIndices.add(originalIndex);
                    _selectedCellIndex = originalIndex;
                  }
                } else {
                  _selectedCellIndex = originalIndex;
                  _selectedIndices.clear();
                  _selectedIndices.add(originalIndex);
                }
              });
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(originalIndex == -1 ? _cornerRadius : _cellCornerRadii[originalIndex]),
                    child: Container(
                      color: hasImage ? Colors.grey[200] : _getEmptySlotColor(index),
                      child: hasImage
                          ? InteractiveViewer(
                              transformationController: _controllers[originalIndex],
                              minScale: 0.1,
                              maxScale: 10.0,
                              clipBehavior: Clip.none,
                              onInteractionStart: (_) {
                                setState(() {
                                  _selectedCellIndex = originalIndex;
                                  _selectedTabIndex = 3;
                                  _isTabContentExpanded = true;
                                });
                              },
                              child: SizedBox.expand(
                                child: _buildImageWithEffects(
                                  originalIndex,
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.diagonal3Values(
                                      _cellFlippedH[originalIndex] ? -1.0 : 1.0,
                                      _cellFlippedV[originalIndex] ? -1.0 : 1.0,
                                      1.0,
                                    ),
                                    child: Image.file(
                                      activeImages[index].value!, 
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: cellW / 3),
                            ),
                    ),
                  ),
                ),
                if (_isMultiSelectMode ? _selectedIndices.contains(originalIndex) : isSelectedCell)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(originalIndex == -1 ? _cornerRadius : _cellCornerRadii[originalIndex]),
                          border: Border.all(
                            color: _isSwapMode ? Colors.orange : const Color(0xFF6C63FF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridLayout(BoxConstraints constraints) {
    final layout = _layouts[_selectedLayoutIndex];
    final double totalW = constraints.maxWidth;
    final double totalH = constraints.maxHeight;

    return Stack(
      children: List.generate(layout.cells.length, (index) {
        final cell = layout.cells[index];
        final rect = cell.rect;
        
        final bool showEdge = _showEdgeSpacing;
        final double leftOffset = (rect.left == 0 && !showEdge) ? 0 : _spacing / 2;
        final double topOffset = (rect.top == 0 && !showEdge) ? 0 : _spacing / 2;
        final double rightOffset = (rect.right == 1.0 && !showEdge) ? 0 : _spacing / 2;
        final double bottomOffset = (rect.bottom == 1.0 && !showEdge) ? 0 : _spacing / 2;

        final double left = rect.left * totalW + leftOffset;
        final double top = rect.top * totalH + topOffset;
        final double right = rect.right * totalW - rightOffset;
        final double bottom = rect.bottom * totalH - bottomOffset;
        
        final double width = right - left;
        final double height = bottom - top;

        final bool isSelectedCell = _selectedCellIndex == index;

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: () {
              if (_isSwapMode) {
                _handleSwap(index);
                return;
              }
              
              setState(() {
                if (_isMultiSelectMode) {
                  if (_selectedIndices.contains(index)) {
                    _selectedIndices.remove(index);
                    if (_selectedCellIndex == index) {
                      _selectedCellIndex = _selectedIndices.isNotEmpty ? _selectedIndices.first : null;
                    }
                  } else {
                    _selectedIndices.add(index);
                    _selectedCellIndex = index;
                  }
                } else {
                  _selectedCellIndex = index;
                  _selectedIndices.clear();
                  _selectedIndices.add(index);
                }
              });

              if (_images[index] == null && !_isMultiSelectMode) {
                _pickImages(startIndex: index);
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_cellCornerRadii[index]),
                    child: Container(
                      color: _images[index] != null ? Colors.grey[200] : _getEmptySlotColor(index),
                      child: _images[index] != null
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final double cellWidth = constraints.maxWidth;
                                final double cellHeight = constraints.maxHeight;
                                
                                if (_imageAspectRatios[index] == null) {
                                  return InteractiveViewer(
                                    transformationController: _controllers[index],
                                    minScale: 0.1,
                                    maxScale: 10.0,
                                    clipBehavior: Clip.none,
                                    onInteractionStart: (_) {
                                      setState(() {
                                        _selectedCellIndex = index;
                                        _selectedTabIndex = 3;
                                        _isTabContentExpanded = true;
                                      });
                                    },
                                    child: SizedBox.expand(
                                      child: Image.file(_images[index]!, fit: BoxFit.cover),
                                    ),
                                  );
                                }

                                  final double imgAspect = _imageAspectRatios[index]!;
                                  final double cellAspect = cellWidth / (cellHeight > 0 ? cellHeight : 1);
                                  
                                  double drawWidth, drawHeight;
                                  if (imgAspect > cellAspect) {
                                    drawHeight = cellHeight;
                                    drawWidth = cellHeight * imgAspect;
                                  } else {
                                    drawWidth = cellWidth;
                                    drawHeight = cellWidth / imgAspect;
                                  }

                                  // Initial centering via Transform.translate instead of matrix overwriting
                                  final double dx = (cellWidth - drawWidth) / 2;
                                  final double dy = (cellHeight - drawHeight) / 2;

                                  // Re-clamp transformation if cell size changed 
                                  // (e.g. due to spacing adjustment)
                                  final Size currentSize = Size(cellWidth, cellHeight);
                                  if (_lastCellSizes[index] != currentSize) {
                                    _lastCellSizes[index] = currentSize;
                                    // We use a post-frame callback to ensure IV has settled? 
                                    // Actually, updating the value here is fine as it triggers a repaint correctly.
                                    _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                  }

                                  return InteractiveViewer(
                                    transformationController: _controllers[index],
                                    minScale: 1.0, // Force cover minimum
                                    maxScale: 10.0,
                                    clipBehavior: Clip.none,
                                    constrained: false,
                                    onInteractionStart: (_) {
                                      setState(() {
                                        _selectedCellIndex = index;
                                        _selectedTabIndex = 3;
                                        _isTabContentExpanded = true;
                                      });
                                    },
                                    onInteractionUpdate: (details) {
                                      _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                    },
                                    onInteractionEnd: (_) {
                                       _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                    },
                                  child: Transform.translate(
                                    offset: Offset(dx, dy),
                                    child: SizedBox(
                                      width: drawWidth,
                                      height: drawHeight,
                                      child: _buildImageWithEffects(
                                        index,
                                        Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.diagonal3Values(
                                            _cellFlippedH[index] ? -1.0 : 1.0,
                                            _cellFlippedV[index] ? -1.0 : 1.0,
                                            1.0,
                                          ),
                                          child: Image.file(_images[index]!, fit: BoxFit.fill),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 32),
                                  const SizedBox(height: 4),
                                  Text('Add', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                if (_isMultiSelectMode ? _selectedIndices.contains(index) : isSelectedCell)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_cellCornerRadii[index]),
                          border: Border.all(
                            color: _isSwapMode ? Colors.orange : const Color(0xFF6C63FF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
  /// Builds a combined saturation + brightness color filter matrix for a cell.
  List<double> _buildCellColorMatrix(int index) {
    final s = _saturations[index];
    final b = _brightnesses[index]; // -1.0 to 1.0 range, maps to -255 to 255
    final bOffset = b * 255;
    return [
      0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, bOffset,
      0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, bOffset,
      0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, bOffset,
      0, 0, 0, 1, 0,
    ];
  }

  Matrix4 _clampMatrix(int index, Matrix4 matrix, double cellW, double cellH) {
    if (index < 0 || index >= _imageAspectRatios.length) return matrix;
    final double? aspect = _imageAspectRatios[index];
    if (aspect == null || aspect <= 0 || !aspect.isFinite) return matrix;
    if (cellW <= 0 || cellH <= 0 || !cellW.isFinite || !cellH.isFinite) return matrix;
    
    // Safety: prevent processing if matrix itself has non-finite values
    if (!matrix.storage.every((v) => v.isFinite)) return Matrix4.identity();

    final double s = matrix.getMaxScaleOnAxis();
    if (s <= 0 || !s.isFinite) return matrix;

    final double imgAspect = aspect;
    final double cellAspect = cellW / (cellH > 0 ? cellH : 1);
    
    double drawW, drawH;
    if (imgAspect > cellAspect) {
      drawH = cellH;
      drawW = cellH * imgAspect;
    } else {
      drawW = cellW;
      drawH = cellW / imgAspect;
    }

    final double dx = (cellW - drawW) / 2;
    final double dy = (cellH - drawH) / 2;

    double tx = matrix.storage[12];
    double ty = matrix.storage[13];

    // Clamping tx (Horizontal)
    // The image must always cover [0, cellW] in the global cell space.
    // finalLeft = dx + tx. imgWidth = drawW * s.
    // dx + tx <= 0  => tx <= -dx
    // dx + tx + drawW * s >= cellW => tx >= cellW - dx - drawW * s
    final double txMax = -dx;
    final double txMin = cellW - dx - drawW * s;
    
    if (txMin.compareTo(txMax) <= 0) {
      tx = tx.clamp(txMin, txMax);
    } else {
      // If image is smaller than cell (forced zoom out), center it
      tx = (txMin + txMax) / 2;
    }

    // Clamping ty (Vertical)
    final double tyMax = -dy;
    final double tyMin = cellH - dy - drawH * s;
    
    if (tyMin.compareTo(tyMax) <= 0) {
      ty = ty.clamp(tyMin, tyMax);
    } else {
      ty = (tyMin + tyMax) / 2;
    }

    final newMatrix = matrix.clone();
    newMatrix.storage[12] = tx;
    newMatrix.storage[13] = ty;
    return newMatrix;
  }

  /// Wraps a child widget with color filter + optional blur for a given cell index.
  Widget _buildImageWithEffects(int index, Widget child) {
    Widget result = ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildCellColorMatrix(index)),
      child: child,
    );
    if (_blurs[index] > 0.01) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: _blurs[index],
          sigmaY: _blurs[index],
        ),
        child: result,
      );
    }
    return result;
  }

  Widget _buildCustomGridLayout(BoxConstraints constraints) {
    final double totalW = constraints.maxWidth;
    final double totalH = constraints.maxHeight;

    return Stack(
      children: List.generate(_customCells.length, (index) {
        final rect = _customCells[index];
        final bool isSelectedCell = _selectedCellIndex == index;

        return Positioned(
          left: rect.left * totalW,
          top: rect.top * totalH,
          width: rect.width * totalW,
          height: rect.height * totalH,
          child: GestureDetector(
            onTap: () => setState(() => _selectedCellIndex = index),
            onPanDown: (_) {
              if (_isLayoutEditingMode) {
                _saveSnapshot();
                setState(() => _selectedCellIndex = index);
              }
            },
            onPanUpdate: (d) {
              if (_isLayoutEditingMode) {
                _moveCell(d.delta, totalW, totalH);
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      (rect.left <= 0.01 && !_showEdgeSpacing) ? 0 : _spacing / 2,
                      (rect.top <= 0.01 && !_showEdgeSpacing) ? 0 : _spacing / 2,
                      (rect.right >= 0.99 && !_showEdgeSpacing) ? 0 : _spacing / 2,
                      (rect.bottom >= 0.99 && !_showEdgeSpacing) ? 0 : _spacing / 2,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_cellCornerRadii[index]),
                      child: Container(
                        child: _images[index] != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final double cellWidth = constraints.maxWidth;
                                  final double cellHeight = constraints.maxHeight;
                                  
                                  if (_imageAspectRatios[index] == null) {
                                    return InteractiveViewer(
                                      transformationController: _controllers[index],
                                      minScale: 0.1,
                                      maxScale: 10.0,
                                      clipBehavior: Clip.none,
                                      onInteractionStart: (_) {
                                      setState(() {
                                        _selectedCellIndex = index;
                                        _selectedTabIndex = 3;
                                        _isTabContentExpanded = true;
                                      });
                                    },
                                      child: SizedBox.expand(
                                        child: Image.file(_images[index]!, fit: BoxFit.cover),
                                      ),
                                    );
                                  }

                                  final double imgAspect = _imageAspectRatios[index]!;
                                  final double cellAspect = cellWidth / (cellHeight > 0 ? cellHeight : 1);
                                  
                                  double drawWidth, drawHeight;
                                  if (imgAspect > cellAspect) {
                                    drawHeight = cellHeight;
                                    drawWidth = cellHeight * imgAspect;
                                  } else {
                                    drawWidth = cellWidth;
                                    drawHeight = cellWidth / imgAspect;
                                  }

                                  // Initial centering via Transform.translate
                                  final double dx = (cellWidth - drawWidth) / 2;
                                  final double dy = (cellHeight - drawHeight) / 2;

                                  // Re-clamp transformation if cell size changed
                                  final Size currentSize = Size(cellWidth, cellHeight);
                                  if (_lastCellSizes[index] != currentSize) {
                                    _lastCellSizes[index] = currentSize;
                                    _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                  }

                                  return InteractiveViewer(
                                    transformationController: _controllers[index],
                                    minScale: 1.0,
                                    maxScale: 10.0,
                                    clipBehavior: Clip.none,
                                    constrained: false,
                                    onInteractionStart: (_) {
                                      setState(() {
                                        _selectedCellIndex = index;
                                        _selectedTabIndex = 3;
                                        _isTabContentExpanded = true;
                                      });
                                    },
                                    onInteractionUpdate: (details) {
                                      _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                    },
                                    onInteractionEnd: (_) {
                                       _controllers[index].value = _clampMatrix(index, _controllers[index].value, cellWidth, cellHeight);
                                    },
                                    child: Transform.translate(
                                      offset: Offset(dx, dy),
                                      child: SizedBox(
                                        width: drawWidth,
                                        height: drawHeight,
                                        child: _buildImageWithEffects(
                                          index,
                                          Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.diagonal3Values(
                                              _cellFlippedH[index] ? -1.0 : 1.0,
                                              _cellFlippedV[index] ? -1.0 : 1.0,
                                              1.0,
                                            ),
                                            child: Image.file(_images[index]!, fit: BoxFit.fill),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              )
                            : Center(
                                child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 32),
                              ),
                      ),
                    ),
                  ),
                ),
                if (isSelectedCell && !_isLayoutEditingMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_cellCornerRadii[index]),
                          border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                        ),
                      ),
                    ),
                  ),
                if (_mergingSlotIndex != null) ...[
                   // Highlight the slot being merged/deleted
                   if (_mergingSlotIndex == index)
                     Positioned.fill(
                       child: Container(
                         color: Colors.red.withOpacity(0.3),
                         child: const Center(
                           child: Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
                         ),
                       ),
                     ),
                   // Show merge target icons on valid neighbors
                   if (_mergingSlotIndex != index && _isValidMergePartner(_mergingSlotIndex!, index))
                     Positioned.fill(
                       child: GestureDetector(
                         onTap: () => _performInteractiveMerge(_mergingSlotIndex!, index),
                         child: Container(
                           color: const Color(0xFF6C63FF).withOpacity(0.4),
                           child: const Center(
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Icon(Icons.add_to_photos_rounded, color: Colors.white, size: 32),
                                 SizedBox(height: 4),
                                 Text('Merge Into', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                               ],
                             ),
                           ),
                         ),
                       ),
                     ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  bool _isValidMergePartner(int sourceIdx, int targetIdx) {
    if (sourceIdx < 0 || sourceIdx >= _customCells.length) return false;
    if (targetIdx < 0 || targetIdx >= _customCells.length) return false;
    
    final r = _customCells[sourceIdx];
    final other = _customCells[targetIdx];
    final double epsilon = 0.01;

    // Match HORIZONTAL neighbors (share top/bottom, touch left/right)
    if ((other.top - r.top).abs() < epsilon && (other.bottom - r.bottom).abs() < epsilon) {
      if ((other.right - r.left).abs() < epsilon) return true;
      if ((other.left - r.right).abs() < epsilon) return true;
    }
    // Match VERTICAL neighbors (share left/right, touch top/bottom)
    if ((other.left - r.left).abs() < epsilon && (other.right - r.right).abs() < epsilon) {
      if ((other.bottom - r.top).abs() < epsilon) return true;
      if ((other.top - r.bottom).abs() < epsilon) return true;
    }
    return false;
  }

  void _performInteractiveMerge(int sourceIdx, int targetIdx) {
     _removeCell(sourceIdx, targetNeighborIndex: targetIdx);
     setState(() {
       _mergingSlotIndex = null;
       _selectedCellIndex = null;
     });
  }

  Widget _buildLayoutEditorOverlay(BoxConstraints constraints) {
    if (_selectedCellIndex == null || _selectedCellIndex! >= _customCells.length) return const SizedBox.shrink();
    
    final rect = _customCells[_selectedCellIndex!];
    final double totalW = constraints.maxWidth;
    final double totalH = constraints.maxHeight;

    return Stack(
      children: [
        // Selection Box with Handles
        Positioned(
          left: rect.left * totalW,
          top: rect.top * totalH,
          width: rect.width * totalW,
          height: rect.height * totalH,
          child: GestureDetector(
            onPanDown: (_) => _saveSnapshot(),
            onPanUpdate: (d) => _moveCell(d.delta, totalW, totalH),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.05),
                border: Border.all(color: const Color(0xFF6C63FF), width: 2),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                   // Edge Handles
                  _buildHandle(Alignment.centerLeft, (d) => _resizeCell(d, left: true), true),
                  _buildHandle(Alignment.centerRight, (d) => _resizeCell(d, right: true), true),
                  _buildHandle(Alignment.topCenter, (d) => _resizeCell(d, top: true), false),
                  _buildHandle(Alignment.bottomCenter, (d) => _resizeCell(d, bottom: true), false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle(Alignment alignment, Function(Offset) onDrag, bool isVertical) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanDown: (_) => _saveSnapshot(),
        onPanUpdate: (d) => onDrag(d.delta),
        child: Container(
          width: isVertical ? 8 : 24,
          height: isVertical ? 24 : 8,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF6C63FF), width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTilingGridState() {
    _customColsController.text = _customGridCols.toString();
    _customRowsController.text = _customGridRows.toString();
  }

  void _resizeCell(Offset delta, {bool left = false, bool right = false, bool top = false, bool bottom = false}) {
    if (_selectedCellIndex == null || _lastConstraints == null) return;
    final totalW = _lastConstraints!.maxWidth;
    final totalH = _lastConstraints!.maxHeight;
    
    final double canvasWidth = totalW;
    final double minSize = (_spacing * 2 / canvasWidth).clamp(0.05, 0.25);

    setState(() {
      final oldRect = _customCells[_selectedCellIndex!];
      double newLeft = oldRect.left;
      double newTop = oldRect.top;
      double newWidth = oldRect.width;
      double newHeight = oldRect.height;

      final double dx = delta.dx / totalW;
      final double dy = delta.dy / totalH;

      if (left) {
        newLeft = (newLeft + dx).clamp(0.0, oldRect.right - minSize);
        newWidth = oldRect.right - newLeft;
      } else if (right) {
        newWidth = (oldRect.width + dx).clamp(minSize, 1.0 - oldRect.left);
      }

      if (top) {
        newTop = (newTop + dy).clamp(0.0, oldRect.bottom - minSize);
        newHeight = oldRect.bottom - newTop;
      } else if (bottom) {
        newHeight = (oldRect.height + dy).clamp(minSize, 1.0 - oldRect.top);
      }

      final Rect newRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
      _customCells = List.from(_customCells);
      _customCells[_selectedCellIndex!] = newRect;

      if (_isTiledMode) {
        _customCells[_selectedCellIndex!] = _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
        _settleAllCells();
      }
    });
  }

  void _moveCell(Offset delta, double totalW, double totalH) {
    if (_selectedCellIndex == null) return;
    
    setState(() {
      final Rect oldRect = _customCells[_selectedCellIndex!];
      final double dx = delta.dx / totalW;
      final double dy = delta.dy / totalH;

      double newLeft = (oldRect.left + dx).clamp(0.0, 1.0 - oldRect.width);
      double newTop = (oldRect.top + dy).clamp(0.0, 1.0 - oldRect.height);
      
      final Rect newRect = Rect.fromLTWH(newLeft, newTop, oldRect.width, oldRect.height);
      _customCells = List.from(_customCells);
      _customCells[_selectedCellIndex!] = newRect;

      if (_isTiledMode) {
        _customCells[_selectedCellIndex!] = _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
        _settleAllCells();
      }
    });
  }

  void _generateTiledGrid(int rows, int cols) {
    _saveSnapshot();
    setState(() {
      List<Rect> newCells = [];
      double cellW = 1.0 / cols;
      double cellH = 1.0 / rows;
      
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          newCells.add(Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH));
        }
      }

      _customCells = newCells;
      _syncStateLists(newCells.length);
      _selectedCellIndex = null;
    });
  }

  void _splitCell(int index, bool horizontal) {
    if (index < 0 || index >= _customCells.length) return;
    _saveSnapshot();
    setState(() {
      final r = _customCells[index];
      Rect r1, r2;
      
      if (horizontal) {
        r1 = Rect.fromLTWH(r.left, r.top, r.width / 2, r.height);
        r2 = Rect.fromLTWH(r.left + r.width / 2, r.top, r.width / 2, r.height);
      } else {
        r1 = Rect.fromLTWH(r.left, r.top, r.width, r.height / 2);
        r2 = Rect.fromLTWH(r.left, r.top + r.height / 2, r.width, r.height / 2);
      }

      _customCells[index] = r1;
      _customCells.add(r2);
      _syncStateLists(_customCells.length);
      _selectedCellIndex = _customCells.length - 1;
    });
  }
  void _syncStateLists(int targetCount) {
    // Ensure all property lists have at least [targetCount] elements.
    // We never shrink these lists to preserve image data if the user reduces grid size
    // and then increases it back (as requested: "changing the rows and column should not remove all the imported images").
    
    while (_images.length < targetCount) _images.add(null);
    while (_controllers.length < targetCount) _controllers.add(TransformationController());
    while (_saturations.length < targetCount) _saturations.add(1.0);
    while (_brightnesses.length < targetCount) _brightnesses.add(0.0);
    while (_blurs.length < targetCount) _blurs.add(0.0);
    while (_cellCornerRadii.length < targetCount) _cellCornerRadii.add(_cornerRadius);
    while (_cellFlippedH.length < targetCount) _cellFlippedH.add(false);
    while (_cellFlippedV.length < targetCount) _cellFlippedV.add(false);
    while (_imageAspectRatios.length < targetCount) _imageAspectRatios.add(null);
  }

  void _removeCell(int index, {int? targetNeighborIndex}) {
    if (_customCells.length <= 1) return;
    _saveSnapshot();
    setState(() {
      if (_isTiledMode && _customCells.length > 1) {
        // Find a neighbor to expand into this space
        final r = _customCells[index];
        final double epsilon = 0.01;

        for (int i = 0; i < _customCells.length; i++) {
          if (i == index) continue;
          if (targetNeighborIndex != null && i != targetNeighborIndex) continue;
          
          final other = _customCells[i];
          if ((other.top - r.top).abs() < epsilon && (other.bottom - r.bottom).abs() < epsilon) {
            if ((other.right - r.left).abs() < epsilon) {
              _customCells[i] = Rect.fromLTWH(other.left, other.top, other.width + r.width, other.height);
              break;
            } else if ((other.left - r.right).abs() < epsilon) {
              _customCells[i] = Rect.fromLTWH(other.left - r.width, other.top, other.width + r.width, other.height);
              break;
            }
          }
          if ((other.left - r.left).abs() < epsilon && (other.right - r.right).abs() < epsilon) {
             if ((other.bottom - r.top).abs() < epsilon) {
               _customCells[i] = Rect.fromLTWH(other.left, other.top, other.width, other.height + r.height);
               break;
             } else if ((other.top - r.bottom).abs() < epsilon) {
               _customCells[i] = Rect.fromLTWH(other.left, other.top - r.height, other.width, other.height + r.height);
               break;
             }
          }
        }
      }

      _customCells.removeAt(index);
      if (index < _images.length) _images.removeAt(index);
      if (index < _controllers.length) _controllers.removeAt(index);
      if (index < _saturations.length) _saturations.removeAt(index);
      if (index < _brightnesses.length) _brightnesses.removeAt(index);
      if (index < _blurs.length) _blurs.removeAt(index);
      if (index < _cellCornerRadii.length) _cellCornerRadii.removeAt(index);
      if (index < _cellFlippedH.length) _cellFlippedH.removeAt(index);
      if (index < _cellFlippedV.length) _cellFlippedV.removeAt(index);
      
      _selectedCellIndex = null;
    });
  }

  /// Resolve overlaps: shrink any cell that the active cell now overlaps with.
  Rect _applyTilingConstraints(int index, Rect oldRect, Rect newRect) {
    if (!_isTiledMode) return newRect;

    final double canvasWidth = _lastConstraints?.maxWidth ?? 400.0;
    final double minSize = (_spacing * 2 / canvasWidth).clamp(0.05, 0.25);
    const double eps = 0.001;

    double l = newRect.left, r = newRect.right, t = newRect.top, b = newRect.bottom;

    for (int i = 0; i < _customCells.length; i++) {
      if (i == index) continue;
      final o = _customCells[i];

      // Check if there is a real 2D overlap
      if (r <= o.left + eps || l >= o.right - eps || b <= o.top + eps || t >= o.bottom - eps) continue;

      // There IS an overlap — resolve it by shrinking the OTHER cell's nearest edge
      double overlapL = r - o.left;   // how much we overlap from the left side of 'o'
      double overlapR = o.right - l;  // how much we overlap from the right side of 'o'
      double overlapT = b - o.top;    // from top of 'o'
      double overlapB = o.bottom - t; // from bottom of 'o'

      double minOverlap = [overlapL, overlapR, overlapT, overlapB].reduce((a, b) => a < b ? a : b);

      if (minOverlap == overlapL && overlapL > eps) {
        // Push o's left edge to our right
        double newOLeft = r;
        if (newOLeft > o.right - minSize) { newOLeft = o.right - minSize; r = newOLeft; }
        _customCells[i] = Rect.fromLTRB(newOLeft, o.top, o.right, o.bottom);
      } else if (minOverlap == overlapR && overlapR > eps) {
        // Push o's right edge to our left
        double newORight = l;
        if (newORight < o.left + minSize) { newORight = o.left + minSize; l = newORight; }
        _customCells[i] = Rect.fromLTRB(o.left, o.top, newORight, o.bottom);
      } else if (minOverlap == overlapT && overlapT > eps) {
        // Push o's top edge to our bottom
        double newOTop = b;
        if (newOTop > o.bottom - minSize) { newOTop = o.bottom - minSize; b = newOTop; }
        _customCells[i] = Rect.fromLTRB(o.left, newOTop, o.right, o.bottom);
      } else if (minOverlap == overlapB && overlapB > eps) {
        // Push o's bottom edge to our top
        double newOBottom = t;
        if (newOBottom < o.top + minSize) { newOBottom = o.top + minSize; t = newOBottom; }
        _customCells[i] = Rect.fromLTRB(o.left, o.top, o.right, newOBottom);
      }
    }

    // After resolving overlaps, settle the grid
    final result = Rect.fromLTRB(l, t, r, b);
    // We'll call _settleAllCells() from the caller after setting this
    return result;
  }

  /// Greedy expansion: each cell expands its edges outward until hitting
  /// another cell or the canvas boundary (0.0 / 1.0).
  void _settleAllCells() {
    const double eps = 0.001;
    final double canvasWidth = _lastConstraints?.maxWidth ?? 400.0;
    final double minSize = (_spacing * 2 / canvasWidth).clamp(0.05, 0.25);

    // Run a few passes so expansions propagate
    for (int pass = 0; pass < 3; pass++) {
      bool anyChange = false;
      for (int i = 0; i < _customCells.length; i++) {
        final c = _customCells[i];

        // Try to expand LEFT edge toward 0.0
        double bestLeft = 0.0;
        for (int j = 0; j < _customCells.length; j++) {
          if (j == i) continue;
          final o = _customCells[j];
          // o is to our left and overlaps vertically
          if (o.right <= c.left + eps && o.bottom > c.top + eps && o.top < c.bottom - eps) {
            if (o.right > bestLeft) bestLeft = o.right;
          }
        }
        
        // Try to expand RIGHT edge toward 1.0
        double bestRight = 1.0;
        for (int j = 0; j < _customCells.length; j++) {
          if (j == i) continue;
          final o = _customCells[j];
          if (o.left >= c.right - eps && o.bottom > c.top + eps && o.top < c.bottom - eps) {
            if (o.left < bestRight) bestRight = o.left;
          }
        }

        // Try to expand TOP edge toward 0.0
        double bestTop = 0.0;
        for (int j = 0; j < _customCells.length; j++) {
          if (j == i) continue;
          final o = _customCells[j];
          if (o.bottom <= c.top + eps && o.right > c.left + eps && o.left < c.right - eps) {
            if (o.bottom > bestTop) bestTop = o.bottom;
          }
        }

        // Try to expand BOTTOM edge toward 1.0
        double bestBottom = 1.0;
        for (int j = 0; j < _customCells.length; j++) {
          if (j == i) continue;
          final o = _customCells[j];
          if (o.top >= c.bottom - eps && o.right > c.left + eps && o.left < c.right - eps) {
            if (o.top < bestBottom) bestBottom = o.top;
          }
        }

        final newRect = Rect.fromLTRB(bestLeft, bestTop, bestRight, bestBottom);
        if ((newRect.left - c.left).abs() > eps || (newRect.right - c.right).abs() > eps ||
            (newRect.top - c.top).abs() > eps || (newRect.bottom - c.bottom).abs() > eps) {
          _customCells[i] = newRect;
          anyChange = true;
        }
      }
      if (!anyChange) break;
    }
  }

  Widget _buildCustomEditorSubTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSubTabItem(0, 'Fine-Tune', Icons.tune_rounded),
          if (!_isTiledMode) _buildSubTabItem(1, 'Order', Icons.layers_rounded),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(int index, String label, IconData icon) {
    bool isActive = _customEditorSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _customEditorSubTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                size: 16, 
                color: isActive ? const Color(0xFF6C63FF) : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF6C63FF) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTab() {
    return Column(
      children: [
        const Text('Layers (Top to Bottom)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6C63FF))),
        const SizedBox(height: 8),
        Column(
          children: List.generate(_customCells.length, (index) {
            // Reversed index so topmost (highest index) is at the top of the list
            final actualIndex = _customCells.length - 1 - index;
            final isSelected = _selectedCellIndex == actualIndex;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCellIndex = actualIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _images[actualIndex] != null ? Colors.grey[200] : _getEmptySlotColor(actualIndex),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _images[actualIndex] != null 
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(_images[actualIndex]!, fit: BoxFit.cover),
                            )
                          : Icon(Icons.layers_outlined, size: 20, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 12),
                      // Label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slot ${actualIndex + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[800],
                              ),
                            ),
                            Text(
                              actualIndex == _customCells.length - 1 ? 'Top Layer' : (actualIndex == 0 ? 'Bottom Layer' : 'Middle Layer'),
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                            onPressed: actualIndex < _customCells.length - 1 
                              ? () => _swapCellsZ(actualIndex, actualIndex + 1) : null,
                            color: const Color(0xFF6C63FF),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                            onPressed: actualIndex > 0 
                              ? () => _swapCellsZ(actualIndex, actualIndex - 1) : null,
                            color: const Color(0xFF6C63FF),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<int>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                            onSelected: (val) {
                              if (val == 0) _moveCellInZOrder(actualIndex, _customCells.length - 1);
                              if (val == 1) _moveCellInZOrder(actualIndex, 0);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 0, child: Text('Bring to Front', style: TextStyle(fontSize: 12))),
                              const PopupMenuItem(value: 1, child: Text('Send to Back', style: TextStyle(fontSize: 12))),
                            ],
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOrderButton(String label, IconData icon, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: const Color(0xFF6C63FF)),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  void _swapCellsZ(int i, int j) {
    if (i < 0 || i >= _customCells.length || j < 0 || j >= _customCells.length) return;
    
    setState(() {
      final rect = _customCells[i];
      _customCells[i] = _customCells[j];
      _customCells[j] = rect;

      final img = _images[i];
      _images[i] = _images[j];
      _images[j] = img;

      final ctrl = _controllers[i];
      _controllers[i] = _controllers[j];
      _controllers[j] = ctrl;

      final sat = _saturations[i];
      _saturations[i] = _saturations[j];
      _saturations[j] = sat;

      final brt = _brightnesses[i];
      _brightnesses[i] = _brightnesses[j];
      _brightnesses[j] = brt;

      final blr = _blurs[i];
      _blurs[i] = _blurs[j];
      _blurs[j] = blr;

      final rad = _cellCornerRadii[i];
      _cellCornerRadii[i] = _cellCornerRadii[j];
      _cellCornerRadii[j] = rad;

      final flipH = _cellFlippedH[i];
      _cellFlippedH[i] = _cellFlippedH[j];
      _cellFlippedH[j] = flipH;

      final flipV = _cellFlippedV[i];
      _cellFlippedV[i] = _cellFlippedV[j];
      _cellFlippedV[j] = flipV;

      if (_selectedCellIndex == i) _selectedCellIndex = j;
      else if (_selectedCellIndex == j) _selectedCellIndex = i;
    });
  }

  void _moveCellInZOrder(int from, int to) {
    if (from < 0 || from >= _customCells.length || to < 0 || to >= _customCells.length) return;
    if (from == to) return;

    setState(() {
      final rect = _customCells.removeAt(from);
      _customCells.insert(to, rect);

      final img = _images.removeAt(from);
      _images.insert(to, img);

      final ctrl = _controllers.removeAt(from);
      _controllers.insert(to, ctrl);

      final sat = _saturations.removeAt(from);
      _saturations.insert(to, sat);

      final brt = _brightnesses.removeAt(from);
      _brightnesses.insert(to, brt);

      final blr = _blurs.removeAt(from);
      _blurs.insert(to, blr);

      final rad = _cellCornerRadii.removeAt(from);
      _cellCornerRadii.insert(to, rad);

      final flipH = _cellFlippedH.removeAt(from);
      _cellFlippedH.insert(to, flipH);

      final flipV = _cellFlippedV.removeAt(from);
      _cellFlippedV.insert(to, flipV);

      _selectedCellIndex = to;
    });
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_presetsKey);
      if (raw == null) return;

      final List<dynamic> outerList = jsonDecode(raw);
      final List<List<Rect>> loaded = [];

      for (final layoutData in outerList) {
        final List<Rect> cells = (layoutData as List).map((rectMap) {
          return Rect.fromLTRB(
            (rectMap['l'] as num).toDouble(),
            (rectMap['t'] as num).toDouble(),
            (rectMap['r'] as num).toDouble(),
            (rectMap['b'] as num).toDouble(),
          );
        }).toList();
        loaded.add(cells);
      }

      setState(() => _customPresets = loaded);
    } catch (e) {
      debugPrint('Error loading presets: $e');
    }
  }

  Future<void> _savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<List<Map<String, double>>> data = _customPresets.map((layout) {
        return layout.map((rect) => {
          'l': rect.left,
          't': rect.top,
          'r': rect.right,
          'b': rect.bottom,
        }).toList();
      }).toList();

      await prefs.setString(_presetsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving presets: $e');
    }
  }

  Color _getEmptySlotColor(int index) {
    const colors = [
      Color(0xFFE3F2FD), // Light Blue
      Color(0xFFF3E5F5), // Light Purple
      Color(0xFFE8F5E9), // Light Green
      Color(0xFFFFF3E0), // Light Orange
      Color(0xFFFFEBEE), // Light Red
      Color(0xFFE0F2F1), // Light Teal
      Color(0xFFFFF8E1), // Light Amber
      Color(0xFFE8EAF6), // Light Indigo
    ];
    return colors[index % colors.length];
  }

  Widget _buildCustomActionButton({
    required String label,
    required IconData icon,
    required bool isActive,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Column(
            children: [
              Icon(icon, color: isActive ? Colors.white : (label.contains('Delete') ? Colors.redAccent : Colors.black87), size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : (label.contains('Delete') ? Colors.redAccent : Colors.black87),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isTabContentExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SingleChildScrollView(
                  child: _buildActiveTabContent(),
                ),
              ),
            ),
          _buildTabButtons(),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    final tabs = [
      {'icon': Icons.grid_view_rounded, 'label': 'Layout'},
      {'icon': Icons.photo_library_outlined, 'label': 'Images'},
      {'icon': Icons.style_outlined, 'label': 'Style'},
      {'icon': Icons.tune_rounded, 'label': 'Adjust'},
      {'icon': Icons.settings_outlined, 'label': 'Config'},
      {'icon': Icons.check_circle_rounded, 'label': 'Save'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            return GestureDetector(
              onTap: () {
                if (index == 5) {
                  _exportWithOpenGL();
                  return;
                }
                setState(() {
                  if (_selectedTabIndex == index) {
                    _isTabContentExpanded = !_isTabContentExpanded;
                  } else {
                    _selectedTabIndex = index;
                    _isTabContentExpanded = true;
                    // Unselect cell when switching to a non-Adjust tab manually
                    if (index != 3) {
                      _selectedCellIndex = null;
                    }
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _exportWithOpenGL() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final double exportWidth = 2000;
      final double exportHeight = exportWidth / _currentAspectRatio;
      
      final tempDir = await getTemporaryDirectory();
      final String outputPath = '${tempDir.path}/opengl_collage_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final double canvasWidth = _lastConstraints!.maxWidth;
      // Proportional scale factor for high-res export
      final double exportScaleFactor = exportWidth / canvasWidth;
      final items = <Map<String, dynamic>>[];

      if (_selectedLayoutSubTab == 2) {
        for (int i = 0; i < _customCells.length; i++) {
          if (_images[i] == null) continue;
          final rect = _customCells[i];
          final totalW = _lastConstraints!.maxWidth;
          final totalH = _lastConstraints!.maxHeight;
          
          final double left = rect.left * totalW;
          final double top = rect.top * totalH;
          final double width = rect.width * totalW;
          final double height = rect.height * totalH;

          items.add({
            'path': _images[i]!.path,
            'x': left,
            'y': top,
            'width': width,
            'height': height,
            'matrix': _controllers[i].value.storage.toList(),
            'saturation': _saturations[i],
            'brightness': _brightnesses[i],
            'blur': _blurs[i] * exportScaleFactor,
            'radius': _cellCornerRadii[i] * exportScaleFactor,
            'flippedH': _cellFlippedH[i],
            'flippedV': _cellFlippedV[i],
            'gap': _spacing,
          });
        }
      } else if (_layouts[_selectedLayoutIndex].name == 'Dynamic Grid') {
        final activeImages = _images.asMap().entries.where((e) => e.value != null).toList();
        
        for (int i = 0; i < activeImages.length; i++) {
          final originalIndex = activeImages[i].key;
          final Size cellSize = _getCellSize(i, _lastConstraints!);
          
          final row = i ~/ _columns;
          final col = i % _columns;
          
          final double cellW = _lastConstraints!.maxWidth / _columns;
          final double cellH = _autoHeight ? cellW : _lastConstraints!.maxHeight / _rows;
          final double x = col * cellW;
          final double y = row * cellH;

          items.add({
            'path': activeImages[i].value!.path,
            'x': x,
            'y': y,
            'width': cellW,
            'height': cellH,
            'matrix': _controllers[originalIndex].value.storage.toList(),
            'saturation': _saturations[originalIndex],
            'brightness': _brightnesses[originalIndex],
            'blur': _blurs[originalIndex] * exportScaleFactor,
            'radius': _cellCornerRadii[originalIndex] * exportScaleFactor,
            'flippedH': _cellFlippedH[originalIndex],
            'flippedV': _cellFlippedV[originalIndex],
            'gap': _spacing,
          });
        }
      } else {
        final layout = _layouts[_selectedLayoutIndex];
        
        for (int i = 0; i < layout.cells.length; i++) {
          if (_images[i] == null) continue;
          final Size cellSize = _getCellSize(i, _lastConstraints!);
          
          final rect = layout.cells[i].rect;
          final totalW = _lastConstraints!.maxWidth;
          final totalH = _lastConstraints!.maxHeight;
          
          final double left = rect.left * totalW;
          final double top = rect.top * totalH;
          final double width = rect.width * totalW;
          final double height = rect.height * totalH;
 
          items.add({
            'path': _images[i]!.path,
            'x': left,
            'y': top,
            'width': width,
            'height': height,
            'matrix': _controllers[i].value.storage.toList(),
            'saturation': _saturations[i],
            'brightness': _brightnesses[i],
            'blur': _blurs[i] * exportScaleFactor,
            'radius': _cellCornerRadii[i] * exportScaleFactor,
            'flippedH': _cellFlippedH[i],
            'flippedV': _cellFlippedV[i],
            'gap': _spacing,
          });
        }
      }

      final String? resultPath = await _collageChannel.invokeMethod('renderCollage', {
        'items': items,
        'outWidth': exportWidth.toInt(),
        'outHeight': exportHeight.toInt(),
        'canvasWidth': canvasWidth,
        'canvasHeight': _lastConstraints!.maxHeight,
        'bgColor': _bgColor.value,
        'showEdgeSpacing': _showEdgeSpacing,
        'outputPath': outputPath,
      });

      if (resultPath != null) {
        // Use the existing image generator to save to actual gallery
        final bytes = await File(resultPath).readAsBytes();
        final savedPath = await ImageGenerator.saveImageBytesToGallery(bytes);

        if (mounted) {
          _showSuccessDialog(savedPath);
          AppReviewService().incrementExportCount();
          AppReviewService().checkAndRequestReview();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPU Export failed: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showSuccessDialog(String? path) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Saved Successfully!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Your high-res collage has been saved to the gallery.', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          if (path != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                OpenFile.open(path);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Open', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildLayoutTab();
      case 1: return _buildImagesTab();
      case 2: return _buildStyleTab();
      case 3: return _buildAdjustTab();
      case 4: return _buildConfigTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildLayoutTab() {
    // Filter logic: Categorize by name
    final filteredIndices = List.generate(_layouts.length, (i) => i).where((i) {
      final name = _layouts[i].name;
      final isBento = name.contains('Bento') || name.contains('Golden') || name.contains('Focus') || name.contains('Slits');
      return _selectedLayoutSubTab == 0 ? !isBento : (_selectedLayoutSubTab == 1 ? isBento : false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSubTabButton('Basics', 0),
            const SizedBox(width: 8),
            _buildSubTabButton('Bento & Pro', 1),
            const SizedBox(width: 8),
            _buildSubTabButton('Custom', 2),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedLayoutSubTab == 2) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Custom Layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6C63FF))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20),
                onPressed: _undoStack.isEmpty ? null : _undo,
                color: const Color(0xFF6C63FF),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tooltip: 'Undo',
              ),
              IconButton(
                icon: const Icon(Icons.redo_rounded, size: 20),
                onPressed: _redoStack.isEmpty ? null : _redo,
                color: const Color(0xFF6C63FF),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tooltip: 'Redo',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Your Saved Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          if (_customPresets.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Center(
                child: Text('No presets saved yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _customPresets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _customCells = List.from(_customPresets[index]);
                        _selectedCellIndex = null;
                      });
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.dashboard_customize_rounded, color: const Color(0xFF6C63FF).withOpacity(0.5), size: 28),
                                  const SizedBox(height: 4),
                                  Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _customPresets.removeAt(index);
                                    _savePresets();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.delete_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCustomActionButton(
                      label: _isLayoutEditingMode ? 'Exit Editor' : 'Edit Layout',
                      icon: _isLayoutEditingMode ? Icons.check_circle_rounded : Icons.dashboard_customize_rounded,
                      isActive: _isLayoutEditingMode,
                      onTap: () {
                        setState(() {
                          _isLayoutEditingMode = !_isLayoutEditingMode;
                          if (_isLayoutEditingMode) {
                            _selectedTabIndex = 0;
                            _isTabContentExpanded = true;
                          }
                        });
                      },
                    ),
                  ),
                  if (!_isTiledMode) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCustomActionButton(
                        label: 'Add Slot',
                        icon: Icons.add_box_rounded,
                        isActive: false,
                        onTap: () {
                          setState(() {
                            _customCells = List.from(_customCells)..add(const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5));
                            _images = List.from(_images)..add(null);
                            _controllers = List.from(_controllers)..add(TransformationController());
                            _saturations = List.from(_saturations)..add(1.0);
                            _brightnesses = List.from(_brightnesses)..add(0.0);
                            _blurs = List.from(_blurs)..add(0.0);
                            _cellCornerRadii = List.from(_cellCornerRadii)..add(0.0);
                            _cellFlippedH = List.from(_cellFlippedH)..add(false);
                            _cellFlippedV = List.from(_cellFlippedV)..add(false);
                            _selectedCellIndex = _customCells.length - 1;
                          });
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCustomActionButton(
                        label: 'Split H',
                        icon: Icons.splitscreen_rounded,
                        isActive: false,
                        isEnabled: _selectedCellIndex != null,
                        onTap: () => _splitCell(_selectedCellIndex!, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCustomActionButton(
                        label: 'Split V',
                        icon: Icons.view_stream_rounded,
                        isActive: false,
                        isEnabled: _selectedCellIndex != null,
                        onTap: () => _splitCell(_selectedCellIndex!, false),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCustomActionButton(
                      label: 'Save Preset',
                      icon: Icons.save_rounded,
                      isActive: false,
                      onTap: () {
                        setState(() {
                          _customPresets.add(List.from(_customCells));
                          _savePresets();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCustomActionButton(
                      label: _isTiledMode ? (_mergingSlotIndex != null ? 'Cancel Merge' : 'Merge Slot') : 'Delete Slot',
                      icon: _isTiledMode ? (_mergingSlotIndex != null ? Icons.close_rounded : Icons.layers_clear_rounded) : Icons.delete_forever_rounded,
                      isActive: _mergingSlotIndex != null,
                      isEnabled: _selectedCellIndex != null && _selectedCellIndex! < _customCells.length,
                      onTap: () {
                        if (_selectedCellIndex != null) {
                          if (_isTiledMode) {
                            setState(() {
                              if (_mergingSlotIndex == _selectedCellIndex) {
                                _mergingSlotIndex = null;
                              } else {
                                _mergingSlotIndex = _selectedCellIndex;
                              }
                            });
                          } else {
                            _removeCell(_selectedCellIndex!);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_isLayoutEditingMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isTiledMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isTiledMode ? const Color(0xFF6C63FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Freeform',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isTiledMode ? Colors.white : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isTiledMode = true;
                              _customEditorSubTab = 0; // Reset to Fine-tune as Order is hidden
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isTiledMode ? const Color(0xFF6C63FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Tiling',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isTiledMode ? Colors.white : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isLayoutEditingMode && _isTiledMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputBox(
                        label: 'Columns',
                        controller: _customColsController,
                        onChanged: (v) {
                          setState(() {
                            _customGridCols = int.tryParse(v)?.clamp(1, 10) ?? 1;
                            _generateTiledGrid(_customGridRows, _customGridCols);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputBox(
                        label: 'Rows',
                        controller: _customRowsController,
                        onChanged: (v) {
                          setState(() {
                            _customGridRows = int.tryParse(v)?.clamp(1, 10) ?? 1;
                            _generateTiledGrid(_customGridRows, _customGridCols);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCustomActionButton(
                  label: 'Generate',
                  icon: Icons.grid_on_rounded,
                  isActive: false,
                  onTap: () => _generateTiledGrid(_customGridRows, _customGridCols),
                ),
              ],
              if (_isLayoutEditingMode && _customCells.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF6C63FF), size: 18),
                      onPressed: () {
                        setState(() {
                          if (_customCells.isEmpty) return;
                          if (_selectedCellIndex == null) {
                            _selectedCellIndex = _customCells.length - 1;
                          } else {
                            _selectedCellIndex = (_selectedCellIndex! - 1 + _customCells.length) % _customCells.length;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCellIndex == null ? 'Select a Slot' : 'Slot ${_selectedCellIndex! + 1} of ${_customCells.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF6C63FF)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6C63FF), size: 18),
                      onPressed: () {
                        setState(() {
                          if (_customCells.isEmpty) return;
                          if (_selectedCellIndex == null) {
                            _selectedCellIndex = 0;
                          } else {
                            _selectedCellIndex = (_selectedCellIndex! + 1) % _customCells.length;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
              if (_isLayoutEditingMode && _selectedCellIndex != null && _selectedCellIndex! < _customCells.length) ...[
                const SizedBox(height: 16),
                _buildCustomEditorSubTabBar(),
                const Divider(),
                const SizedBox(height: 8),
                if (_customEditorSubTab == 0) ...[
                  Row(
                    children: [
                      const Text('Fine-Tune Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6C63FF))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFineTuneSliderRow(
                    label: 'Pos X',
                    icon: Icons.open_with_rounded,
                    value: _customCells[_selectedCellIndex!].left,
                    min: 0.0,
                    max: (1.0 - _customCells[_selectedCellIndex!].width).clamp(0.0, 1.0),
                    onChanged: (v) {
                      setState(() {
                        final oldRect = _customCells[_selectedCellIndex!];
                        final newRect = Rect.fromLTWH(v, oldRect.top, oldRect.width, oldRect.height);
                        _customCells[_selectedCellIndex!] = newRect;
                         if (_isTiledMode) {
                           _customCells[_selectedCellIndex!] = _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
                         }
                      });
                    },
                  ),
                  _buildFineTuneSliderRow(
                    label: 'Pos Y',
                    icon: Icons.swap_vert_rounded,
                    value: _customCells[_selectedCellIndex!].top,
                    min: 0.0,
                    max: (1.0 - _customCells[_selectedCellIndex!].height).clamp(0.0, 1.0),
                    onChanged: (v) {
                      setState(() {
                        final oldRect = _customCells[_selectedCellIndex!];
                        final newRect = Rect.fromLTWH(oldRect.left, v, oldRect.width, oldRect.height);
                        _customCells[_selectedCellIndex!] = newRect;
                         if (_isTiledMode) {
                           _customCells[_selectedCellIndex!] = _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
                         }
                      });
                    },
                  ),
                  _buildFineTuneSliderRow(
                    label: 'Width',
                    icon: Icons.unfold_more_rounded,
                    value: _customCells[_selectedCellIndex!].width,
                    min: 0.05,
                    max: (1.0 - _customCells[_selectedCellIndex!].left).clamp(0.05, 1.0),
                    onChanged: (v) {
                      setState(() {
                        final oldRect = _customCells[_selectedCellIndex!];
                        final newRect = Rect.fromLTWH(oldRect.left, oldRect.top, v, oldRect.height);
                        _customCells[_selectedCellIndex!] = newRect;
                         if (_isTiledMode) {
                           _customCells[_selectedCellIndex!] = _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
                         }
                      });
                    },
                  ),
                  _buildFineTuneSliderRow(
                    label: 'Height',
                    icon: Icons.unfold_less_rounded,
                    value: _customCells[_selectedCellIndex!].height,
                    min: 0.05,
                    max: (1.0 - _customCells[_selectedCellIndex!].top).clamp(0.05, 1.0),
                    onChanged: (v) {
                      setState(() {
                        final oldRect = _customCells[_selectedCellIndex!];
                        final newRect = Rect.fromLTWH(oldRect.left, oldRect.top, oldRect.width, v);
                        _customCells[_selectedCellIndex!] = newRect;
                        if (_isTiledMode) _applyTilingConstraints(_selectedCellIndex!, oldRect, newRect);
                      });
                    },
                  ),
                  _buildFineTuneSliderRow(
                    label: 'Radius',
                    icon: Icons.rounded_corner_rounded,
                    value: _cellCornerRadii[_selectedCellIndex!],
                    min: 0.0,
                    max: 100.0,
                    onChanged: (v) {
                      setState(() {
                        _cellCornerRadii[_selectedCellIndex!] = v;
                      });
                    },
                  ),
                ] else ...[
                  _buildOrderTab(),
                ],
              ],
            ],
          ),
        ] else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...filteredIndices.map((index) {
                final layout = _layouts[index];
                final isSelected = _selectedLayoutIndex == index;
                return GestureDetector(
                  onTap: () {
                    _saveSnapshot();
                    setState(() {
                      _selectedLayoutIndex = index;
                      _selectedCellIndex = null;
                      // Ensure all state lists have enough capacity for the new layout
                      _syncStateLists(_layouts[index].cells.length);
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(layout.icon, size: 32, color: isSelected ? const Color(0xFF6C63FF) : Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        layout.name, 
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          if (_selectedLayoutSubTab == 0 && _layouts[_selectedLayoutIndex].name == 'Dynamic Grid') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInputBox(
                      label: 'Columns',
                      controller: _colsController,
                      onChanged: (v) {
                        setState(() {
                          _columns = int.tryParse(v)?.clamp(1, 10) ?? 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputBox(
                      label: 'Rows',
                      controller: _rowsController,
                      onChanged: (v) {
                        setState(() {
                          _rows = int.tryParse(v)?.clamp(1, 100) ?? 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSubTabButton(String label, int index) {
    final bool isSelected = _selectedLayoutSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedLayoutSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({required String label, required TextEditingController controller, required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    int val = (int.tryParse(controller.text) ?? 0) + 1;
                    controller.text = val.toString();
                    onChanged(val.toString());
                  },
                  child: const Icon(Icons.arrow_drop_up, size: 18),
                ),
                GestureDetector(
                  onTap: () {
                    int val = (int.tryParse(controller.text) ?? 1) - 1;
                    if (val < 1) val = 1;
                    controller.text = val.toString();
                    onChanged(val.toString());
                  },
                  child: const Icon(Icons.arrow_drop_down, size: 18),
                ),
              ],
            ),
          ),
          onChanged: (v) {
            _saveSnapshot();
            onChanged(v);
          },
          onTap: () => _saveSnapshot(),
        ),
      ],
    );
  }

  Widget _buildImagesTab() {
    return Column(
      children: [
        Row(
          children: [
            if (_selectedCellIndex != null) ...[
              _buildAdjustActionButton(
                label: 'Replace',
                icon: Icons.add_photo_alternate_rounded,
                isActive: false,
                onTap: () => _pickImages(startIndex: _selectedCellIndex),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: const Text('Pick Extra', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => _images.fillRange(0, _maxPossibleImages, null)),
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: 'Clear All',
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_images.length, (index) {
              if (_images[index] == null) return const SizedBox.shrink();
              
              final bool isCurrentlyInSelectedCell = _selectedCellIndex != null && 
                  _images[_selectedCellIndex!]?.path == _images[index]!.path;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    if (_selectedCellIndex != null) {
                      setState(() {
                        _images[_selectedCellIndex!] = _images[index];
                        _controllers[_selectedCellIndex!].value = Matrix4.identity();
                        _loadImageDimensions(_selectedCellIndex!);
                      });
                    } else {
                        // If no cell selected, maybe select the first empty one? 
                        // For now just do nothing or show a hint later.
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrentlyInSelectedCell ? const Color(0xFF6C63FF) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_images[index]!, width: 60, height: 60, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images[index] = null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        left: 2,
                        right: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          ),
                          child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTab() {
    return Column(
      children: [
        _buildSliderRow(
          label: 'Spacing',
          icon: Icons.grid_view_rounded,
          value: _spacing,
          min: 0,
          max: 20,
          onChanged: (v) => setState(() => _spacing = v),
        ),
        _buildSliderRow(
          label: 'Corners',
          icon: Icons.rounded_corner_rounded,
          value: _cornerRadius,
          min: 0,
          max: 50,
          onChanged: (v) {
            setState(() {
              _cornerRadius = v;
              // Update all cells to match global radius
              for (int i = 0; i < _cellCornerRadii.length; i++) {
                _cellCornerRadii[i] = v;
              }
            });
          },
        ),
        _buildToggleRow(
          label: 'Edge Spacing',
          icon: Icons.space_bar_rounded,
          value: _showEdgeSpacing,
          onChanged: (v) => setState(() => _showEdgeSpacing = v),
        ),
        const Divider(),
        _buildColorRow(),
      ],
    );
  }

  Widget _buildConfigTab() {
    final options = [
      {'label': 'Portrait 4:5', 'index': 0},
      {'label': 'Square 1:1', 'index': 1},
      {'label': 'Story 9:16', 'index': 2},
      {'label': 'Wide 16:9', 'index': 3},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aspect Ratio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final idx = opt['index'] as int;
            final isSelected = _selectedAspectIndex == idx;
            return GestureDetector(
              onTap: () => setState(() => _selectedAspectIndex = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                  ),
                ),
                child: Text(opt['label'] as String, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF6C63FF) : Colors.black87)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Infinite Height', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('Grid grows based on images', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            Switch(
              value: _autoHeight,
              onChanged: (v) => setState(() => _autoHeight = v),
              activeColor: const Color(0xFF6C63FF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSliderRow({required String label, required IconData icon, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: const Color(0xFF6C63FF),
            onChanged: onChanged,
          ),
        ),
        Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFineTuneSliderRow({required String label, required IconData icon, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(width: 45, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: const Color(0xFF6C63FF),
              onChanged: onChanged,
              onChangeStart: (_) => _saveSnapshot(),
            ),
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
        ),
      ],
    );
  }

  Widget _buildColorRow() {
    final colors = [
      Colors.white,
      Colors.black,
      const Color(0xFFF5F5F7), // Soft grey
      const Color(0xFFE8F1FF), // Soft blue
      const Color(0xFFFFEEEE), // Soft red
      const Color(0xFFF0FFF4), // Soft green
    ];

    return Row(
      children: [
        const Text('Background', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Bg Color'),
                        content: SingleChildScrollView(
                          child: AdvancedColorPicker(
                            initialColor: _bgColor,
                            onColorChanged: (c) => setState(() => _bgColor = c),
                          ),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), shape: BoxShape.circle),
                    child: const Icon(Icons.colorize, size: 16, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                ...colors.map((c) {
                  final bool isSelected = _bgColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _bgColor = c),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!, width: isSelected ? 2 : 1),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustTab() {
    final layout = _layouts[_selectedLayoutIndex];
    if (_selectedCellIndex == null || 
        _selectedCellIndex! < 0 || 
        _selectedCellIndex! >= _images.length || 
        _images[_selectedCellIndex!] == null ||
        (layout.name != 'Dynamic Grid' && _selectedCellIndex! >= layout.cells.length)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, color: Colors.grey, size: 32),
            SizedBox(height: 8),
            Text('Select an image cell to adjust', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    if (_imageAspectRatios[_selectedCellIndex!] == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(height: 12),
            Text('Loading image dimensions...', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      );
    }

    final controller = _controllers[_selectedCellIndex!];
    final matrix = controller.value;
    final Size cellSize = _getCellSize(_selectedCellIndex!, _lastConstraints!);
    final double cW = cellSize.width;
    final double cH = cellSize.height;

    final double matrixScale = matrix.getMaxScaleOnAxis();
    final double tx = matrix.storage[12];
    final double ty = matrix.storage[13];

    // Calculate boundary limits for the sliders
    final double imgAspect = _imageAspectRatios[_selectedCellIndex!]!;
    final double cellAspect = cW / (cH > 0 ? cH : 1);
    
    double drawW, drawH;
    if (imgAspect > cellAspect) {
      drawH = cH;
      drawW = cH * imgAspect;
    } else {
      drawW = cW;
      drawH = cW / imgAspect;
    }

    final double dx = (cW - drawW) / 2;
    final double dy = (cH - drawH) / 2;

    double txMax = -dx;
    double txMin = cW - dx - drawW * matrixScale;
    double tyMax = -dy;
    double tyMin = cH - dy - drawH * matrixScale;

    // Safety: Ensure min <= max for Sliders and clamp
    if (txMin.compareTo(txMax) > 0) {
      final tmp = txMin;
      txMin = txMax;
      txMax = tmp;
    }
    if (tyMin.compareTo(tyMax) > 0) {
      final tmp = tyMin;
      tyMin = tyMax;
      tyMax = tmp;
    }

    // Ensure finite values
    if (!txMin.isFinite) txMin = -1000;
    if (!txMax.isFinite) txMax = 1000;
    if (!tyMin.isFinite) tyMin = -1000;
    if (!tyMax.isFinite) tyMax = 1000;

    // Small buffer if min == max to avoid Slider errors
    if (txMin == txMax) { txMin -= 0.1; txMax += 0.1; }
    if (tyMin == tyMax) { tyMin -= 0.1; tyMax += 0.1; }

    final double currentX = tx.clamp(txMin, txMax);
    final double currentY = ty.clamp(tyMin, tyMax);

    // Calculate cell dimensions for center-scaling
    double cellW = 300, cellH = 300; 
    if (_lastConstraints != null) {
      if (_layouts[_selectedLayoutIndex].name == 'Dynamic Grid') {
        cellW = (_lastConstraints!.maxWidth - (_columns - 1) * _spacing) / _columns;
        cellH = _autoHeight ? cellW : (_lastConstraints!.maxHeight - (_rows - 1) * _spacing) / _rows;
      } else {
        final cell = _layouts[_selectedLayoutIndex].cells[_selectedCellIndex!];
        cellW = cell.rect.width * _lastConstraints!.maxWidth;
        cellH = cell.rect.height * _lastConstraints!.maxHeight;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 12),
                _buildAdjustActionButton(
                  label: 'Replace',
                  icon: Icons.add_photo_alternate_rounded,
                  isActive: false,
                  onTap: () => _pickImages(startIndex: _selectedCellIndex),
                ),
                const SizedBox(width: 6),
                _buildAdjustActionButton(
                  label: 'Flip H',
                  icon: Icons.flip_rounded,
                  isActive: _cellFlippedH[_selectedCellIndex!],
                  onTap: () => setState(() => _cellFlippedH[_selectedCellIndex!] = !_cellFlippedH[_selectedCellIndex!]),
                ),
                const SizedBox(width: 6),
                _buildAdjustActionButton(
                  label: 'Flip V',
                  icon: Icons.flip_rounded,
                  isActive: _cellFlippedV[_selectedCellIndex!],
                  onTap: () => setState(() => _cellFlippedV[_selectedCellIndex!] = !_cellFlippedV[_selectedCellIndex!]),
                ),
                const SizedBox(width: 6),
                _buildAdjustActionButton(
                  label: 'Swap',
                  icon: Icons.swap_horiz_rounded,
                  isActive: _isSwapMode,
                  onTap: () => setState(() => _isSwapMode = !_isSwapMode),
                ),
                const SizedBox(width: 6),
                _buildAdjustActionButton(
                  label: 'Multi',
                  icon: Icons.layers_rounded,
                  isActive: _isMultiSelectMode,
                  onTap: () {
                    setState(() {
                      _isMultiSelectMode = !_isMultiSelectMode;
                      if (_isMultiSelectMode) {
                        if (_selectedCellIndex != null) _selectedIndices.add(_selectedCellIndex!);
                      } else {
                        _selectedIndices.clear();
                        if (_selectedCellIndex != null) _selectedIndices.add(_selectedCellIndex!);
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildAdjustActionButton(
                  label: 'Reset All',
                  icon: Icons.refresh_rounded,
                  isActive: false,
                  onTap: () {
                    setState(() {
                      final Iterable<int> targets = _selectedIndices.isEmpty 
                          ? (_selectedCellIndex != null ? [_selectedCellIndex!] : <int>[]) 
                          : _selectedIndices;
                      for (final idx in targets) {
                        _controllers[idx].value = Matrix4.identity();
                        _saturations[idx] = 1.0;
                        _brightnesses[idx] = 0.0;
                        _blurs[idx] = 0.0;
                        _cellFlippedH[idx] = false;
                        _cellFlippedV[idx] = false;
                      }
                    });
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        if (_isSwapMode)
          _buildInfoBanner('Tap another cell to swap positions', Colors.orange, () => setState(() => _isSwapMode = false))
        else if (_isMultiSelectMode)
          _buildInfoBanner('Tap cells to group them for bulk adjustment', const Color(0xFF6C63FF), () => setState(() {
            _isMultiSelectMode = false;
            _selectedIndices.clear();
          })),
        _buildInteractiveSliderRow(
          label: 'Scale',
          icon: Icons.zoom_in_rounded,
          value: matrixScale,
          min: 0.1,
          max: 10.0,
          onChanged: (v) {
            setState(() {
              final targets = _isMultiSelectMode ? _selectedIndices : [_selectedCellIndex!];
              for (final idx in targets) {
                final ctrl = _controllers[idx];
                final m = ctrl.value;
                final s = m.getMaxScaleOnAxis();
                final tX = m.storage[12];
                final tY = m.storage[13];

                final Size cellSize = _getCellSize(idx, _lastConstraints!);
                final double cW = cellSize.width;
                final double cH = cellSize.height;

                final double anchorX = cW / 2;
                final double anchorY = cH / 2;
                final double ratio = v / s;
                
                final double newTx = anchorX - (anchorX - tX) * ratio;
                final double newTy = anchorY - (anchorY - tY) * ratio;

                ctrl.value = Matrix4.identity()
                  ..translate(newTx, newTy)
                  ..scale(v);
              }
            });
          },
          onReset: () {
            setState(() {
              final targets = _isMultiSelectMode ? _selectedIndices : [_selectedCellIndex!];
              for (final idx in targets) {
                _controllers[idx].value = Matrix4.identity();
              }
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Position X',
          icon: Icons.unfold_more_rounded,
          value: currentX,
          min: txMin < txMax ? txMin : txMax - 0.001,
          max: txMax,
          onChanged: (v) {
            setState(() {
              final m = _controllers[_selectedCellIndex!].value.clone();
              m.storage[12] = v;
              _controllers[_selectedCellIndex!].value = m;
            });
          },
          onReset: () {
            setState(() {
              final m = _controllers[_selectedCellIndex!].value.clone();
              m.storage[12] = -dx; // Reset to center
              _controllers[_selectedCellIndex!].value = m;
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Position Y',
          icon: Icons.unfold_more_rounded,
          value: currentY,
          min: tyMin < tyMax ? tyMin : tyMax - 0.001,
          max: tyMax,
          onChanged: (v) {
            setState(() {
              final m = _controllers[_selectedCellIndex!].value.clone();
              m.storage[13] = v;
              _controllers[_selectedCellIndex!].value = m;
            });
          },
          onReset: () {
            setState(() {
              final m = _controllers[_selectedCellIndex!].value.clone();
              m.storage[13] = -dy; // Reset to center
              _controllers[_selectedCellIndex!].value = m;
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Saturation',
          icon: Icons.palette_outlined,
          value: _saturations[_selectedCellIndex!],
          min: 0.0,
          max: 2.0,
          onChanged: (v) {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _saturations[idx] = v;
                }
              } else {
                _saturations[_selectedCellIndex!] = v;
              }
            });
          },
          onReset: () {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _saturations[idx] = 1.0;
                }
              } else {
                _saturations[_selectedCellIndex!] = 1.0;
              }
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Brightness',
          icon: Icons.brightness_6_rounded,
          value: _brightnesses[_selectedCellIndex!],
          min: -1.0,
          max: 1.0,
          onChanged: (v) {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _brightnesses[idx] = v;
                }
              } else {
                _brightnesses[_selectedCellIndex!] = v;
              }
            });
          },
          onReset: () {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _brightnesses[idx] = 0.0;
                }
              } else {
                _brightnesses[_selectedCellIndex!] = 0.0;
              }
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Blur',
          icon: Icons.blur_on_rounded,
          value: _blurs[_selectedCellIndex!],
          min: 0.0,
          max: 20.0,
          onChanged: (v) {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _blurs[idx] = v;
                }
              } else {
                _blurs[_selectedCellIndex!] = v;
              }
            });
          },
          onReset: () {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _blurs[idx] = 0.0;
                }
              } else {
                _blurs[_selectedCellIndex!] = 0.0;
              }
            });
          },
        ),
        _buildInteractiveSliderRow(
          label: 'Corner Radius',
          icon: Icons.rounded_corner_rounded,
          value: _cellCornerRadii[_selectedCellIndex!],
          min: 0,
          max: 50,
          onChanged: (v) {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _cellCornerRadii[idx] = v;
                }
              } else {
                _cellCornerRadii[_selectedCellIndex!] = v;
              }
            });
          },
          onReset: () {
            setState(() {
              if (_isMultiSelectMode) {
                for (final idx in _selectedIndices) {
                  _cellCornerRadii[idx] = 0;
                }
              } else {
                _cellCornerRadii[_selectedCellIndex!] = 0;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveSliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    final TextEditingController textController = TextEditingController(
      text: (label == 'Saturation' || label == 'Brightness') ? value.toStringAsFixed(2) : (label == 'Scale' || label == 'Blur' ? value.toStringAsFixed(1) : value.toInt().toString()),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const Spacer(),
              Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!, width: 0.5),
                ),
                child: TextField(
                  controller: textController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (val) {
                    final double? d = double.tryParse(val);
                    if (d != null) onChanged(d.clamp(min, max));
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: Colors.grey[500],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Reset',
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              trackShape: (label == 'Pos X' || label == 'Pos Y') ? CenteredSliderTrackShape() : const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFF6C63FF),
              showValueIndicator: ShowValueIndicator.always,
              tickMarkShape: min < 0 && max > 0 ? const RoundSliderTickMarkShape(tickMarkRadius: 2) : null,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustActionButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [
            BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text, Color color, VoidCallback onCancel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({required String label, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }
}
