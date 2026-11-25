import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/shape_mask_model.dart';
import 'services/shape_mask_service.dart';
import 'widgets/shape_mask_canvas_view.dart';

/// Custom Drag Handle mode for Select & Move tool.
enum _DragHandleMode { none, moveBody, resizeBottomRight, moveLineP1, moveLineP2 }

/// Shape Mask & Cutout Frame Studio:
/// - Always-accessible Quick Tool Rail (Mask Tap, Box, Circle, Line, Polygon, Move, Pan Photo)
/// - Rotation-aware vector shapes, 1-tap geometric stamps, & watertight BFS closed-region masking
/// - 8 Mask Backdrop FX (B&W Color Pop, Frosted Blur, Focus Dim, Gradient, Transparent PNG, etc.)
/// - Watermark-style horizontal control tabs & 1080p+ MediaStore PNG export
class ShapeMaskMakerScreen extends StatefulWidget {
  const ShapeMaskMakerScreen({super.key});

  @override
  State<ShapeMaskMakerScreen> createState() => _ShapeMaskMakerScreenState();
}

class _ShapeMaskMakerScreenState extends State<ShapeMaskMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  static const List<Color> _borderPalette = [
    Colors.white,
    Color(0xFF0F172A),
    Color(0xFF00796B),
    Color(0xFFFACC15),
    Color(0xFF00E5FF),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFFF97316),
    Color(0xFFA855F7),
  ];

  ui.Image? _photoImage;
  SolvedMaskData? _solvedMask;
  ShapeMaskConfig _config = ShapeMaskConfig.initialDefault;
  ShapeMaskTool _activeTool = ShapeMaskTool.rectangle;
  Set<String> _selectedElementIds = {};
  bool _multiSelectMode = false;

  // Undo / Redo Stacks
  final List<ShapeMaskConfig> _undoStack = [];
  final List<ShapeMaskConfig> _redoStack = [];

  // UI state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = false;
  bool _isSolving = false;
  int _solveGeneration = 0;
  bool _isSaving = false;
  bool _hideEditorOverlays = false;
  bool _isPeekingOriginal = false;
  String? _lastSavedPath;

  // Live drawing drafts
  Offset? _dragStartNorm;
  Offset? _dragPrevNorm;
  Rect? _draftRect;
  Offset? _draftLineStart;
  Offset? _draftLineEnd;
  List<Offset> _draftPolygonPoints = [];
  _DragHandleMode _dragHandleMode = _DragHandleMode.none;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Shape Mask Studio');
  }

  @override
  void dispose() {
    _photoImage?.dispose();
    _solvedMask?.maskAlphaImage.dispose();
    super.dispose();
  }

  double _currentAspectRatio() {
    if (_config.aspectRatio.ratio != null) return _config.aspectRatio.ratio!;
    if (_photoImage != null && _photoImage!.height > 0) {
      return (_photoImage!.width / _photoImage!.height).clamp(0.45, 2.2);
    }
    return 4.0 / 5.0;
  }

  void _commitConfig(ShapeMaskConfig nextConfig, {bool recordUndo = true, bool reSolve = true}) {
    if (recordUndo) {
      _undoStack.add(_config);
      if (_undoStack.length > 35) _undoStack.removeAt(0);
      _redoStack.clear();
    }
    setState(() => _config = nextConfig);
    if (reSolve && _photoImage != null) {
      _solveMaskRegions();
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_config);
    final prev = _undoStack.removeLast();
    setState(() {
      _config = prev;
      _selectedElementIds = _selectedElementIds
          .where((id) => prev.elements.any((e) => e.id == id))
          .toSet();
    });
    _solveMaskRegions();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_config);
    final next = _redoStack.removeLast();
    setState(() => _config = next);
    _solveMaskRegions();
  }

  Future<void> _pickImage() async {
    final file = await ShapeMaskService().pickImage();
    if (file == null) return;
    setState(() => _isSolving = true);
    final decoded = await ShapeMaskService().decodeFileToUiImage(file);
    if (decoded != null && mounted) {
      setState(() {
        _photoImage?.dispose();
        _photoImage = decoded;
      });
      await _solveMaskRegions();
    } else if (mounted) {
      setState(() => _isSolving = false);
    }
  }

  Future<void> _loadDemoScene() async {
    setState(() => _isSolving = true);
    final demo = await ShapeMaskService().generateSamplePhoto();
    if (mounted) {
      setState(() {
        _photoImage?.dispose();
        _photoImage = demo;
        _config = ShapeMaskConfig.starterPresets.first.config;
        _activeTool = ShapeMaskTool.maskToggle;
        _undoStack.clear();
        _redoStack.clear();
      });
      await _solveMaskRegions();
    }
  }

  Future<void> _solveMaskRegions() async {
    if (_photoImage == null) return;
    final int gen = ++_solveGeneration;
    final solved = await ShapeMaskService().solveRegionsAndMask(
      config: _config,
      canvasAspect: _currentAspectRatio(),
    );
    if (!mounted || gen != _solveGeneration) {
      solved.maskAlphaImage.dispose();
      return;
    }
    setState(() {
      _solvedMask?.maskAlphaImage.dispose();
      _solvedMask = solved;
      _isSolving = false;
    });
  }

  String _newId() => 'el_${DateTime.now().microsecondsSinceEpoch}';

  List<MaskElement> _getSelectedElements() {
    if (_selectedElementIds.isEmpty) return const [];
    return _config.elements.where((e) => _selectedElementIds.contains(e.id)).toList();
  }

  MaskElement? _getPrimarySelectedElement() {
    final sel = _getSelectedElements();
    return sel.isNotEmpty ? sel.first : null;
  }

  Set<String> _expandGroupMembers(String id) {
    final idx = _config.elements.indexWhere((e) => e.id == id);
    if (idx < 0) return {id};
    final grp = _config.elements[idx].groupId;
    if (grp == null) return {id};
    return _config.elements.where((e) => e.groupId == grp).map((e) => e.id).toSet();
  }

  bool get _hasGroupedSelection {
    return _getSelectedElements().any((e) => e.groupId != null);
  }

  bool get _canMergeSelection {
    final closedCount = _getSelectedElements().where((e) => e.type != MaskElementType.line).length;
    return closedCount >= 2;
  }

  Offset _inverseRotateAround(Offset pt, Offset center, double deg) {
    if (deg.abs() < 0.05) return pt;
    final aspect = _currentAspectRatio();
    final rad = -deg * math.pi / 180.0;
    final dx = pt.dx - center.dx;
    final dy = (pt.dy - center.dy) / aspect;
    final rx = dx * math.cos(rad) - dy * math.sin(rad);
    final ry = (dx * math.sin(rad) + dy * math.cos(rad)) * aspect;
    return Offset(center.dx + rx, center.dy + ry);
  }

  // ─── Interactive Canvas Gesture Handlers ───

  void _handleTapCanvas(Offset normPos) {
    if (_activeTool == ShapeMaskTool.maskToggle) {
      _toggleClosedAreaAt(normPos);
    } else if (_activeTool == ShapeMaskTool.selectMove) {
      final hit = ShapeMaskService().hitTestElement(
        _config.elements,
        normPos,
        canvasAspect: _currentAspectRatio(),
      );
      if (hit == null) {
        if (!_multiSelectMode) {
          setState(() => _selectedElementIds = {});
        }
        return;
      }
      final groupMembers = _expandGroupMembers(hit.id);
      setState(() {
        if (_multiSelectMode) {
          if (_selectedElementIds.contains(hit.id)) {
            _selectedElementIds = Set<String>.from(_selectedElementIds)..removeAll(groupMembers);
          } else {
            _selectedElementIds = Set<String>.from(_selectedElementIds)..addAll(groupMembers);
          }
        } else {
          _selectedElementIds = groupMembers;
        }
      });
    } else if (_activeTool == ShapeMaskTool.polygon) {
      if (_draftPolygonPoints.length >= 3 && (normPos - _draftPolygonPoints.first).distance < 0.06) {
        _finishPolygon();
      } else {
        setState(() => _draftPolygonPoints = [..._draftPolygonPoints, normPos]);
      }
    }
  }

  void _toggleClosedAreaAt(Offset normPos) {
    if (_solvedMask == null) return;
    final int rid = _solvedMask!.regionIdAt(normPos);
    if (rid <= 0) return;

    final bool currentlyVisible =
        rid < _solvedMask!.regionVisible.length ? _solvedMask!.regionVisible[rid] : false;
    final bool nextVisible = !currentlyVisible;

    final updatedSeeds = _config.regionSeeds.where((s) {
      return _solvedMask!.regionIdAt(s.normPos) != rid;
    }).toList();

    updatedSeeds.add(RegionToggleSeed(normPos: normPos, showImage: nextVisible));
    _commitConfig(_config.copyWith(regionSeeds: updatedSeeds));
  }

  void _finishPolygon() {
    if (_draftPolygonPoints.length < 3) {
      setState(() => _draftPolygonPoints = []);
      return;
    }
    final newPoly = MaskElement(
      id: _newId(),
      type: MaskElementType.polygon,
      points: List.of(_draftPolygonPoints),
      borderColor: _config.activeBorderColor,
      borderWidth: _config.activeBorderWidth,
      strokePattern: _config.activeStrokePattern,
      dashLength: _config.activeDashLength,
      dashGap: _config.activeDashGap,
    );
    final newSeeds = List<RegionToggleSeed>.from(_config.regionSeeds)
      ..add(RegionToggleSeed(
        normPos: newPoly.normalizedCenter,
        showImage: true,
        linkedElementId: newPoly.id,
      ));

    setState(() {
      _draftPolygonPoints = [];
      _selectedElementIds = {newPoly.id};
    });
    _commitConfig(_config.copyWith(
      elements: [..._config.elements, newPoly],
      regionSeeds: newSeeds,
    ));
  }

  void _handleDragStart(Offset normPos) {
    _dragStartNorm = normPos;
    _dragPrevNorm = normPos;

    if (_activeTool == ShapeMaskTool.panPhoto) {
      _undoStack.add(_config);
      _redoStack.clear();
      return;
    }

    if (_activeTool == ShapeMaskTool.rectangle) {
      setState(() => _draftRect = Rect.fromPoints(normPos, normPos));
    } else if (_activeTool == ShapeMaskTool.circle || _activeTool == ShapeMaskTool.arc) {
      final bool forcePerfect = _activeTool == ShapeMaskTool.arc || _config.lockPerfectCircle;
      setState(() {
        _draftRect = forcePerfect
            ? Rect.fromCenter(center: normPos, width: 0.01, height: 0.01)
            : Rect.fromPoints(normPos, normPos);
      });
    } else if (_activeTool == ShapeMaskTool.lineCut) {
      setState(() {
        _draftLineStart = normPos;
        _draftLineEnd = normPos;
      });
    } else if (_activeTool == ShapeMaskTool.selectMove) {
      // Single-element resize / endpoint handle check
      if (_selectedElementIds.length == 1) {
        final target = _getPrimarySelectedElement();
        if (target != null && target.rect != null) {
          final localPt = _inverseRotateAround(normPos, target.normalizedCenter, target.rotationDeg);
          if ((localPt - target.rect!.bottomRight).distance < 0.075) {
            _dragHandleMode = _DragHandleMode.resizeBottomRight;
            _undoStack.add(_config);
            _redoStack.clear();
            return;
          }
        }
        if (target != null && target.p1 != null && (normPos - target.p1!).distance < 0.065) {
          _dragHandleMode = _DragHandleMode.moveLineP1;
          _undoStack.add(_config);
          _redoStack.clear();
          return;
        }
        if (target != null && target.p2 != null && (normPos - target.p2!).distance < 0.065) {
          _dragHandleMode = _DragHandleMode.moveLineP2;
          _undoStack.add(_config);
          _redoStack.clear();
          return;
        }
      }

      final hit = ShapeMaskService().hitTestElement(
        _config.elements,
        normPos,
        canvasAspect: _currentAspectRatio(),
      );
      if (hit != null) {
        if (!_selectedElementIds.contains(hit.id)) {
          final groupMembers = _expandGroupMembers(hit.id);
          setState(() {
            _selectedElementIds = _multiSelectMode
                ? (Set<String>.from(_selectedElementIds)..addAll(groupMembers))
                : groupMembers;
          });
        }
        _dragHandleMode = _DragHandleMode.moveBody;
        _undoStack.add(_config);
        _redoStack.clear();
      } else {
        if (!_multiSelectMode) {
          setState(() => _selectedElementIds = {});
        }
        _dragHandleMode = _DragHandleMode.none;
      }
    }
  }

  void _handleDragUpdate(Offset normPos) {
    if (_dragStartNorm == null || _dragPrevNorm == null) return;

    if (_activeTool == ShapeMaskTool.panPhoto) {
      final delta = normPos - _dragPrevNorm!;
      _dragPrevNorm = normPos;
      setState(() {
        _config = _config.copyWith(
          imageOffset: Offset(
            (_config.imageOffset.dx + delta.dx).clamp(-0.7, 0.7),
            (_config.imageOffset.dy + delta.dy).clamp(-0.7, 0.7),
          ),
        );
      });
      return;
    }

    if (_activeTool == ShapeMaskTool.rectangle) {
      setState(() => _draftRect = Rect.fromPoints(_dragStartNorm!, normPos));
    } else if (_activeTool == ShapeMaskTool.circle || _activeTool == ShapeMaskTool.arc) {
      final bool forcePerfect = _activeTool == ShapeMaskTool.arc || _config.lockPerfectCircle;
      setState(() {
        _draftRect = forcePerfect
            ? ShapeMaskService().buildPerfectCircleRect(_dragStartNorm!, normPos, _currentAspectRatio())
            : Rect.fromPoints(_dragStartNorm!, normPos);
      });
    } else if (_activeTool == ShapeMaskTool.lineCut) {
      Offset endPt = _config.angleSnapLines
          ? ShapeMaskService().snapLineAngle(_dragStartNorm!, normPos)
          : normPos;

      if (_config.extendLinesToEdge && (endPt - _dragStartNorm!).distance > 0.03) {
        final ext = ShapeMaskService().extendLineToCanvasEdges(_dragStartNorm!, endPt);
        setState(() {
          _draftLineStart = ext.p1;
          _draftLineEnd = ext.p2;
        });
      } else {
        setState(() {
          _draftLineStart = _dragStartNorm;
          _draftLineEnd = endPt;
        });
      }
    } else if (_activeTool == ShapeMaskTool.selectMove &&
        _selectedElementIds.isNotEmpty &&
        _dragHandleMode != _DragHandleMode.none) {
      final delta = normPos - _dragPrevNorm!;
      _dragPrevNorm = normPos;

      final List<MaskElement> updatedEls = _config.elements.map((el) {
        if (!_selectedElementIds.contains(el.id)) return el;

        if (_dragHandleMode == _DragHandleMode.moveBody) {
          return el.translated(delta);
        } else if (_dragHandleMode == _DragHandleMode.resizeBottomRight && el.rect != null) {
          final localPt = _inverseRotateAround(normPos, el.normalizedCenter, el.rotationDeg);
          if ((el.type == MaskElementType.circle && _config.lockPerfectCircle) ||
              el.type == MaskElementType.arc) {
            return el.copyWith(
              rect: ShapeMaskService().buildPerfectCircleRect(
                el.normalizedCenter,
                normPos,
                _currentAspectRatio(),
              ),
            );
          }
          final double newRight = math.max(el.rect!.left + 0.05, localPt.dx).clamp(0.05, 1.0);
          final double newBottom = math.max(el.rect!.top + 0.05, localPt.dy).clamp(0.05, 1.0);
          return el.copyWith(rect: Rect.fromLTRB(el.rect!.left, el.rect!.top, newRight, newBottom));
        } else if (_dragHandleMode == _DragHandleMode.moveLineP1 && el.p2 != null) {
          final snapped = _config.angleSnapLines
              ? ShapeMaskService().snapLineAngle(el.p2!, normPos)
              : normPos;
          return el.copyWith(p1: snapped);
        } else if (_dragHandleMode == _DragHandleMode.moveLineP2 && el.p1 != null) {
          final snapped = _config.angleSnapLines
              ? ShapeMaskService().snapLineAngle(el.p1!, normPos)
              : normPos;
          return el.copyWith(p2: snapped);
        }
        return el;
      }).toList();

      List<RegionToggleSeed> updatedSeeds = _config.regionSeeds;
      if (_dragHandleMode == _DragHandleMode.moveBody) {
        updatedSeeds = _config.regionSeeds.map((seed) {
          if (seed.linkedElementId != null && _selectedElementIds.contains(seed.linkedElementId)) {
            return seed.copyWith(
              normPos: Offset(
                (seed.normPos.dx + delta.dx).clamp(0.01, 0.99),
                (seed.normPos.dy + delta.dy).clamp(0.01, 0.99),
              ),
            );
          }
          return seed;
        }).toList();
      } else if (_dragHandleMode == _DragHandleMode.resizeBottomRight && _selectedElementIds.length == 1) {
        final singleId = _selectedElementIds.first;
        final resizedIdx = updatedEls.indexWhere((e) => e.id == singleId);
        if (resizedIdx >= 0) {
          final newCenter = updatedEls[resizedIdx].normalizedCenter;
          updatedSeeds = _config.regionSeeds.map((seed) {
            if (seed.linkedElementId == singleId) {
              return seed.copyWith(normPos: newCenter);
            }
            return seed;
          }).toList();
        }
      }

      setState(() {
        _config = _config.copyWith(elements: updatedEls, regionSeeds: updatedSeeds);
      });
    }
  }

  void _handleDragEnd() {
    if ((_activeTool == ShapeMaskTool.rectangle ||
            _activeTool == ShapeMaskTool.circle ||
            _activeTool == ShapeMaskTool.arc) &&
        _draftRect != null) {
      final Rect finalRect = _draftRect!;
      setState(() => _draftRect = null);

      if (finalRect.width > 0.04 && finalRect.height > 0.04) {
        final MaskElementType elType = _activeTool == ShapeMaskTool.circle
            ? MaskElementType.circle
            : _activeTool == ShapeMaskTool.arc
                ? MaskElementType.arc
                : MaskElementType.rectangle;
        final el = MaskElement(
          id: _newId(),
          type: elType,
          rect: finalRect,
          borderColor: _config.activeBorderColor,
          borderWidth: _config.activeBorderWidth,
          cornerRadius: _config.activeCornerRadius,
          strokePattern: _config.activeStrokePattern,
          dashLength: _config.activeDashLength,
          dashGap: _config.activeDashGap,
          arcCount: _config.activeArcCount,
          arcSweepRatio: _config.activeArcSweepRatio,
          arcCloseMaskRegion: _config.activeArcCloseMask,
        );
        final updatedSeeds = List<RegionToggleSeed>.from(_config.regionSeeds);
        if (elType != MaskElementType.arc || el.arcCloseMaskRegion) {
          updatedSeeds.add(RegionToggleSeed(
            normPos: el.normalizedCenter,
            showImage: true,
            linkedElementId: el.id,
          ));
        }
        setState(() => _selectedElementIds = {el.id});
        _commitConfig(_config.copyWith(
          elements: [..._config.elements, el],
          regionSeeds: updatedSeeds,
        ));
      }
    } else if (_activeTool == ShapeMaskTool.lineCut &&
        _draftLineStart != null &&
        _draftLineEnd != null) {
      final a = _draftLineStart!;
      final b = _draftLineEnd!;
      setState(() {
        _draftLineStart = null;
        _draftLineEnd = null;
      });

      if ((b - a).distance > 0.04) {
        final line = MaskElement(
          id: _newId(),
          type: MaskElementType.line,
          p1: a,
          p2: b,
          borderColor: _config.activeBorderColor,
          borderWidth: _config.activeBorderWidth,
          strokePattern: _config.activeStrokePattern,
          dashLength: _config.activeDashLength,
          dashGap: _config.activeDashGap,
        );
        setState(() => _selectedElementIds = {line.id});
        _commitConfig(_config.copyWith(elements: [..._config.elements, line]));
      }
    } else if (_activeTool == ShapeMaskTool.selectMove && _dragHandleMode != _DragHandleMode.none) {
      _dragHandleMode = _DragHandleMode.none;
      _solveMaskRegions();
    }

    _dragStartNorm = null;
    _dragPrevNorm = null;
  }

  /// Inserts a 1-tap geometric shape stamp (Diamond, Triangle, Hexagon, Star, Pill).
  void _insertQuickStamp(QuickStampShape shape) {
    final id = _newId();
    final el = ShapeMaskService().buildQuickStamp(
      id: id,
      shape: shape,
      config: _config,
      canvasAspect: _currentAspectRatio(),
    );
    final updatedSeeds = List<RegionToggleSeed>.from(_config.regionSeeds)
      ..add(RegionToggleSeed(normPos: el.normalizedCenter, showImage: true, linkedElementId: id));

    setState(() {
      _selectedElementIds = {id};
      _activeTool = ShapeMaskTool.selectMove;
    });
    _commitConfig(_config.copyWith(
      elements: [..._config.elements, el],
      regionSeeds: updatedSeeds,
    ));
  }

  /// Inserts a crisp 2x2 grid split cleanly across the canvas.
  void _insert2x2SplitGrid() {
    final t = DateTime.now().microsecondsSinceEpoch;
    final l1 = MaskElement(
      id: 'split_v_$t',
      type: MaskElementType.line,
      p1: const Offset(0.5, 0.0),
      p2: const Offset(0.5, 1.0),
      borderColor: _config.activeBorderColor,
      borderWidth: _config.activeBorderWidth,
      strokePattern: _config.activeStrokePattern,
      dashLength: _config.activeDashLength,
      dashGap: _config.activeDashGap,
    );
    final l2 = MaskElement(
      id: 'split_h_$t',
      type: MaskElementType.line,
      p1: const Offset(0.0, 0.5),
      p2: const Offset(1.0, 0.5),
      borderColor: _config.activeBorderColor,
      borderWidth: _config.activeBorderWidth,
      strokePattern: _config.activeStrokePattern,
      dashLength: _config.activeDashLength,
      dashGap: _config.activeDashGap,
    );
    setState(() {
      _activeTool = ShapeMaskTool.maskToggle;
      _selectedElementIds = {};
    });
    _commitConfig(_config.copyWith(
      elements: [..._config.elements, l1, l2],
      regionSeeds: [
        ..._config.regionSeeds,
        const RegionToggleSeed(normPos: Offset(0.25, 0.25), showImage: true),
        const RegionToggleSeed(normPos: Offset(0.75, 0.75), showImage: true),
      ],
    ));
  }

  void _applyElementStyleUpdate({
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
    double? circularRadiusNorm,
    double? rotationDeg,
    MaskStrokePattern? strokePattern,
    double? dashLength,
    double? dashGap,
    int? arcCount,
    double? arcSweepRatio,
    bool? arcCloseMaskRegion,
    bool recordUndo = true,
    bool reSolve = false,
  }) {
    final bool applyToAllWhenNoneSelected = _selectedElementIds.isEmpty && _config.elements.isNotEmpty;
    final double aspect = _currentAspectRatio();
    final List<MaskElement> updated = _config.elements.map((el) {
      final bool isTarget = applyToAllWhenNoneSelected || _selectedElementIds.contains(el.id);
      if (!isTarget) return el;

      final bool isRect = el.type == MaskElementType.rectangle;
      final bool isArc = el.type == MaskElementType.arc;
      final bool isCircular = isArc || el.type == MaskElementType.circle;
      final bool isClosedOrArc = el.type != MaskElementType.line;

      Rect? nextRect;
      if (circularRadiusNorm != null && isCircular && el.rect != null) {
        final Offset center = el.normalizedCenter;
        final double rx = circularRadiusNorm.clamp(0.05, 0.58);
        final double ry = (isArc || _config.lockPerfectCircle)
            ? rx * aspect
            : rx * (el.rect!.height / math.max(0.01, el.rect!.width));
        nextRect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
      }

      return el.copyWith(
        rect: nextRect,
        borderColor: borderColor,
        borderWidth: borderWidth,
        cornerRadius: isRect ? cornerRadius : null,
        rotationDeg: isClosedOrArc ? rotationDeg : null,
        strokePattern: strokePattern,
        dashLength: dashLength,
        dashGap: dashGap,
        arcCount: isArc ? arcCount : null,
        arcSweepRatio: isArc ? arcSweepRatio : null,
        arcCloseMaskRegion: isArc ? arcCloseMaskRegion : null,
      );
    }).toList();

    _commitConfig(
      _config.copyWith(
        elements: updated,
        activeBorderColor: borderColor,
        activeBorderWidth: borderWidth,
        activeCornerRadius: cornerRadius,
        activeStrokePattern: strokePattern,
        activeDashLength: dashLength,
        activeDashGap: dashGap,
        activeArcCount: arcCount,
        activeArcSweepRatio: arcSweepRatio,
        activeArcCloseMask: arcCloseMaskRegion,
      ),
      recordUndo: recordUndo,
      reSolve: reSolve,
    );
  }

  void _groupSelectedElements() {
    if (_selectedElementIds.length < 2) return;
    final grpId = 'grp_${DateTime.now().microsecondsSinceEpoch}';
    final updated = _config.elements.map((el) {
      if (_selectedElementIds.contains(el.id)) {
        return el.copyWith(groupId: grpId);
      }
      return el;
    }).toList();
    _commitConfig(_config.copyWith(elements: updated), reSolve: false);
  }

  void _ungroupSelectedElements() {
    if (!_hasGroupedSelection) return;
    final updated = _config.elements.map((el) {
      if (_selectedElementIds.contains(el.id)) {
        return el.copyWith(clearGroupId: true);
      }
      return el;
    }).toList();
    _commitConfig(_config.copyWith(elements: updated), reSolve: false);
  }

  void _mergeSelectedShapes() {
    final selectedClosed = _getSelectedElements()
        .where((e) => e.type != MaskElementType.line)
        .toList();
    if (selectedClosed.length < 2) return;

    final merged = ShapeMaskService().mergeElements(
      selectedClosed,
      canvasAspect: _currentAspectRatio(),
      newId: _newId(),
    );
    if (merged == null) return;

    final mergedIds = selectedClosed.map((e) => e.id).toSet();
    final remainingElements = _config.elements.where((e) => !mergedIds.contains(e.id)).toList()
      ..add(merged);

    final updatedSeeds = _config.regionSeeds
        .where((s) => s.linkedElementId == null || !mergedIds.contains(s.linkedElementId))
        .toList()
      ..add(RegionToggleSeed(
        normPos: merged.normalizedCenter,
        showImage: true,
        linkedElementId: merged.id,
      ));

    setState(() => _selectedElementIds = {merged.id});
    _commitConfig(_config.copyWith(
      elements: remainingElements,
      regionSeeds: updatedSeeds,
    ));
  }

  void _duplicateSelectedElements() {
    final selected = _getSelectedElements();
    if (selected.isEmpty) return;

    final String? newGroupId =
        selected.length > 1 ? 'grp_${DateTime.now().microsecondsSinceEpoch}' : null;
    final List<MaskElement> copies = [];
    final Set<String> newIds = {};
    final List<RegionToggleSeed> updatedSeeds = List.from(_config.regionSeeds);

    int seq = 0;
    for (final sel in selected) {
      final copyId = '${_newId()}_${seq++}';
      final translated = sel.translated(const Offset(0.06, 0.06));
      final dup = MaskElement(
        id: copyId,
        groupId: newGroupId,
        type: translated.type,
        rect: translated.rect,
        p1: translated.p1,
        p2: translated.p2,
        points: translated.points,
        extraPolygons: translated.extraPolygons,
        borderColor: sel.borderColor,
        borderWidth: sel.borderWidth,
        cornerRadius: sel.cornerRadius,
        rotationDeg: sel.rotationDeg,
        strokePattern: sel.strokePattern,
        dashLength: sel.dashLength,
        dashGap: sel.dashGap,
        arcCount: sel.arcCount,
        arcSweepRatio: sel.arcSweepRatio,
        arcCloseMaskRegion: sel.arcCloseMaskRegion,
      );
      copies.add(dup);
      newIds.add(copyId);
      if (dup.type != MaskElementType.line &&
          (dup.type != MaskElementType.arc || dup.arcCloseMaskRegion)) {
        updatedSeeds.add(RegionToggleSeed(
          normPos: dup.normalizedCenter,
          showImage: true,
          linkedElementId: copyId,
        ));
      }
    }

    setState(() => _selectedElementIds = newIds);
    _commitConfig(_config.copyWith(
      elements: [..._config.elements, ...copies],
      regionSeeds: updatedSeeds,
    ));
  }

  void _rotateSelectedElements(double deltaDeg) {
    final bool applyToAll = _selectedElementIds.isEmpty && _config.elements.isNotEmpty;
    final updated = _config.elements.map((el) {
      final bool isTarget = applyToAll || _selectedElementIds.contains(el.id);
      if (!isTarget || el.type == MaskElementType.line) return el;
      final next = (el.rotationDeg + deltaDeg) % 360;
      return el.copyWith(rotationDeg: next > 180 ? next - 360 : next);
    }).toList();
    _commitConfig(_config.copyWith(elements: updated), reSolve: true);
  }

  void _invertAllMask() {
    final flippedSeeds = _config.regionSeeds
        .map((s) => s.copyWith(showImage: !s.showImage))
        .toList();
    _commitConfig(_config.copyWith(
      defaultRevealImage: !_config.defaultRevealImage,
      regionSeeds: flippedSeeds,
    ));
  }

  void _deleteSelectedElements() {
    if (_selectedElementIds.isEmpty) return;
    final ids = Set<String>.from(_selectedElementIds);
    final updatedEls = _config.elements.where((e) => !ids.contains(e.id)).toList();
    final updatedSeeds = _config.regionSeeds
        .where((s) => s.linkedElementId == null || !ids.contains(s.linkedElementId))
        .toList();
    setState(() => _selectedElementIds = {});
    _commitConfig(_config.copyWith(elements: updatedEls, regionSeeds: updatedSeeds));
  }

  void _deleteElement(String id) {
    final updatedEls = _config.elements.where((e) => e.id != id).toList();
    final updatedSeeds = _config.regionSeeds.where((s) => s.linkedElementId != id).toList();
    setState(() => _selectedElementIds = Set<String>.from(_selectedElementIds)..remove(id));
    _commitConfig(_config.copyWith(elements: updatedEls, regionSeeds: updatedSeeds));
  }

  Future<void> _exportShapeMask() async {
    if (_photoImage == null) return;
    setState(() {
      _isSaving = true;
      _hideEditorOverlays = true;
    });

    await Future.delayed(const Duration(milliseconds: 60));

    try {
      final Uint8List? pngBytes = await ShapeMaskService().captureBoundary(_boundaryKey);
      if (mounted) setState(() => _hideEditorOverlays = false);

      if (pngBytes == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final String? path = await ShapeMaskService().saveShapeMaskToGallery(
        pngBytes,
        _config.backdropStyle.label,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _lastSavedPath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primarySurface, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shape Mask saved to Gallery! (Pictures/Quick Post Shape Masks)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting shape mask: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hideEditorOverlays = false;
        });
      }
    }
  }

  Future<void> _shareShapeMask() async {
    if (_lastSavedPath == null) {
      setState(() => _hideEditorOverlays = true);
      await Future.delayed(const Duration(milliseconds: 60));
      final Uint8List? pngBytes = await ShapeMaskService().captureBoundary(_boundaryKey);
      if (mounted) setState(() => _hideEditorOverlays = false);

      if (pngBytes != null) {
        _lastSavedPath = await ShapeMaskService().saveShapeMaskToGallery(
          pngBytes,
          _config.backdropStyle.label,
        );
      }
    }

    if (_lastSavedPath != null) {
      await ShapeMaskService().shareShapeMask(_lastSavedPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shape Mask Studio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          if (_photoImage != null) ...[
            IconButton(
              tooltip: 'Undo',
              icon: Icon(
                Icons.undo_rounded,
                color: _undoStack.isNotEmpty ? AppColors.textPrimary : Colors.grey.shade300,
              ),
              onPressed: _undoStack.isNotEmpty ? _undo : null,
            ),
            IconButton(
              tooltip: 'Redo',
              icon: Icon(
                Icons.redo_rounded,
                color: _redoStack.isNotEmpty ? AppColors.textPrimary : Colors.grey.shade300,
              ),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
            ),
            IconButton(
              tooltip: 'Toggle Rule-of-Thirds Guides',
              icon: Icon(
                Icons.grid_3x3_rounded,
                color: _config.showAlignGuides ? AppColors.primary : AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() => _config = _config.copyWith(showAlignGuides: !_config.showAlignGuides));
              },
            ),
            PopupMenuButton<ShapeMaskConfig>(
              tooltip: 'Starter Templates',
              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (preset) {
                _selectedElementIds = {};
                _draftPolygonPoints = [];
                _commitConfig(preset.copyWith(aspectRatio: _config.aspectRatio));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'STARTER MASK TEMPLATES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...ShapeMaskConfig.starterPresets.map((preset) {
                  return PopupMenuItem(
                    value: preset.config,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          preset.subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
      body: _photoImage == null ? _buildEmptyState() : _buildEditorBody(),
    );
  }

  /// Welcome screen prompting gallery import or 1-tap demo scene.
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00796B).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 24),
            const Text(
              'Shape Mask Studio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import a photo, draw cutout boxes, stars, polygons & split lines with custom borders, then tap any closed compartment to reveal vivid color or mask it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 20),
                label: const Text(
                  'Import Photo from Gallery',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loadDemoScene,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Try B&W Color Pop Demo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Studio Workspace: sleek top tool rail, spacious canvas, and single consolidated bottom control panel.
  Widget _buildEditorBody() {
    final selectedList = _getSelectedElements();
    final bool hasClosedInSel = selectedList.any((e) => e.type != MaskElementType.line);

    return Column(
      children: [
        // ─── Sleek Top 1-Tap Quick Tool Rail (42px) ───
        _buildQuickToolRail(),

        // ─── Spacious Proportional Interactive Canvas ───
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: ShapeMaskCanvasView(
                      boundaryKey: _boundaryKey,
                      photoImage: _photoImage,
                      solvedMask: _solvedMask,
                      config: _config,
                      activeTool: _activeTool,
                      selectedElementIds: _selectedElementIds,
                      hideEditorOverlays: _hideEditorOverlays,
                      isPeekingOriginal: _isPeekingOriginal,
                      draftRect: _draftRect,
                      draftLineStart: _draftLineStart,
                      draftLineEnd: _draftLineEnd,
                      draftPolygonPoints: _draftPolygonPoints,
                      onTapCanvas: _handleTapCanvas,
                      onDragStartCanvas: _handleDragStart,
                      onDragUpdateCanvas: _handleDragUpdate,
                      onDragEndCanvas: _handleDragEnd,
                    ),
                  ),
                ),
                // Top-Left Context Actions (Polygon Done / Multi-Select, Group, Merge, Dup, Rot, Del)
                if ((_activeTool == ShapeMaskTool.polygon && _draftPolygonPoints.length >= 3) ||
                    _activeTool == ShapeMaskTool.selectMove)
                  Positioned(
                    top: 4,
                    left: 4,
                    right: 92,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeTool == ShapeMaskTool.polygon && _draftPolygonPoints.length >= 3)
                            GestureDetector(
                              onTap: _finishPolygon,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'Close Shape',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (_activeTool == ShapeMaskTool.selectMove) ...[
                            // Multi-select Toggle Pill
                            GestureDetector(
                              onTap: () {
                                setState(() => _multiSelectMode = !_multiSelectMode);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _multiSelectMode
                                      ? AppColors.primary
                                      : Colors.black.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.checklist_rounded, color: Colors.white, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      _selectedElementIds.length > 1
                                          ? 'Multi (${_selectedElementIds.length})'
                                          : 'Multi',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (selectedList.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              if (selectedList.length >= 2)
                                _buildMicroContextBtn(
                                  icon: Icons.group_work_rounded,
                                  tooltip: 'Group',
                                  color: const Color(0xFF7C3AED),
                                  onTap: _groupSelectedElements,
                                ),
                              if (_hasGroupedSelection) ...[
                                const SizedBox(width: 5),
                                _buildMicroContextBtn(
                                  icon: Icons.link_off_rounded,
                                  tooltip: 'Ungroup',
                                  color: const Color(0xFF475569),
                                  onTap: _ungroupSelectedElements,
                                ),
                              ],
                              if (_canMergeSelection) ...[
                                const SizedBox(width: 5),
                                _buildMicroContextBtn(
                                  icon: Icons.join_full_rounded,
                                  tooltip: 'Merge',
                                  color: const Color(0xFF0EA5E9),
                                  onTap: _mergeSelectedShapes,
                                ),
                              ],
                              const SizedBox(width: 5),
                              _buildMicroContextBtn(
                                icon: Icons.copy_rounded,
                                tooltip: 'Duplicate',
                                color: AppColors.primary,
                                onTap: _duplicateSelectedElements,
                              ),
                              if (hasClosedInSel) ...[
                                const SizedBox(width: 5),
                                _buildMicroContextBtn(
                                  icon: Icons.rotate_right_rounded,
                                  tooltip: 'Rotate +15°',
                                  color: const Color(0xFF0284C7),
                                  onTap: () => _rotateSelectedElements(15.0),
                                ),
                              ],
                              const SizedBox(width: 5),
                              _buildMicroContextBtn(
                                icon: Icons.delete_outline_rounded,
                                tooltip: 'Delete',
                                color: const Color(0xFFEF4444),
                                onTap: _deleteSelectedElements,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                // Top-Right Hold-to-Peek Original Photo Pill
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTapDown: (_) {
                      setState(() => _isPeekingOriginal = true);
                    },
                    onTapUp: (_) => setState(() => _isPeekingOriginal = false),
                    onTapCancel: () => setState(() => _isPeekingOriginal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isPeekingOriginal
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPeekingOriginal ? Icons.visibility_rounded : Icons.visibility_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isPeekingOriginal ? 'Original' : 'Hold Peek',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isSolving)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Updating Mask...',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ─── Collapsible Tab Drawer (when a control tab is expanded) ───
        if (_isTabContentExpanded) _buildActiveTabContent(),

        // ─── Single Consolidated Control & Action Panel (Tabs + Import + Invert + Share + Save) ───
        _buildConsolidatedControlPanel(),
      ],
    );
  }

  Widget _buildMicroContextBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }

  /// Compact 40px icon-only 1-tap drawing tool rail at top of canvas.
  Widget _buildQuickToolRail() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ShapeMaskTool.values.map((tool) {
          final bool isSelected = _activeTool == tool;
          return Tooltip(
            message: tool.label,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTool = tool;
                  _draftPolygonPoints = [];
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 36,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tool.icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Single unified bottom bar with Save leftmost followed by Control Tabs and Import/Invert/Share.
  Widget _buildConsolidatedControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              // Leftmost integrated Save tab tile (non-floating)
              GestureDetector(
                onTap: _isSaving ? null : _exportShapeMask,
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else
                        const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        _isSaving ? 'Saving' : 'Save',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                color: Colors.grey.shade200,
              ),
              _buildTabItem(0, Icons.dashboard_customize_rounded, 'Add', const Color(0xFF00796B)),
              _buildTabItem(1, Icons.border_color_rounded, 'Borders', const Color(0xFF8B5CF6)),
              _buildTabItem(2, Icons.blur_on_rounded, 'Mask FX', const Color(0xFF0284C7)),
              _buildTabItem(3, Icons.photo_size_select_large_rounded, 'Photo', const Color(0xFFEA580C)),
              _buildTabItem(4, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
              _buildTabItem(5, Icons.layers_rounded, 'Shapes', const Color(0xFFEC4899)),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                color: Colors.grey.shade200,
              ),
              _buildQuickActionTile(
                icon: Icons.photo_library_rounded,
                label: 'Import',
                color: AppColors.textPrimary,
                onTap: _pickImage,
              ),
              _buildQuickActionTile(
                icon: Icons.invert_colors_rounded,
                label: 'Invert',
                color: AppColors.textPrimary,
                onTap: _invertAllMask,
              ),
              _buildQuickActionTile(
                icon: Icons.share_rounded,
                label: 'Share',
                color: AppColors.textPrimary,
                onTap: _shareShapeMask,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedTabIndex == index) {
            _isTabContentExpanded = !_isTabContentExpanded;
          } else {
            _selectedTabIndex = index;
            _isTabContentExpanded = true;
          }
        });
      },
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slim drag/collapse bar for closing panel in 1 tap
          GestureDetector(
            onTap: () => setState(() => _isTabContentExpanded = false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _buildCurrentTabWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabWidget() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildQuickAddTab();
      case 1:
        return _buildBordersTab();
      case 2:
        return _buildMaskFxTab();
      case 3:
        return _buildPhotoTab();
      case 4:
        return _buildFormatTab();
      case 5:
        return _buildShapesListTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── TAB 0: 1-Tap Shape Stamps, Split Lines & Bulk Actions ───
  Widget _buildQuickAddTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1-Tap Cutout Stamps',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...QuickStampShape.values.map((stamp) {
              return ActionChip(
                avatar: Icon(stamp.icon, size: 15, color: AppColors.primary),
                label: Text(stamp.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                backgroundColor: Colors.grey.shade100,
                onPressed: () => _insertQuickStamp(stamp),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.grid_view_rounded, size: 15, color: AppColors.primary),
              label: const Text('2x2 Split', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              backgroundColor: AppColors.primarySurface.withValues(alpha: 0.65),
              onPressed: _insert2x2SplitGrid,
            ),
          ],
        ),
        const Divider(height: 16),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Perfect 1:1 Circle',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          subtitle: const Text(
            'Locks circle tool to geometric round (off allows ovals)',
            style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins'),
          ),
          value: _config.lockPerfectCircle,
          onChanged: (v) => setState(() => _config = _config.copyWith(lockPerfectCircle: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Extend Lines Edge-to-Edge',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          subtitle: const Text(
            'Off draws exact segment; On stretches across canvas',
            style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins'),
          ),
          value: _config.extendLinesToEdge,
          onChanged: (v) => setState(() => _config = _config.copyWith(extendLinesToEdge: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Snap Lines to 0° / 45° / 90°',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          value: _config.angleSnapLines,
          onChanged: (v) => setState(() => _config = _config.copyWith(angleSnapLines: v)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _invertAllMask,
                icon: const Icon(Icons.invert_colors_rounded, size: 16),
                label: const Text('Invert Mask', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  _commitConfig(_config.copyWith(defaultRevealImage: false, regionSeeds: []));
                },
                icon: const Icon(Icons.visibility_off_rounded, size: 16),
                label: const Text('Cover All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── TAB 1: Border Color, Width, Radius, Dash/Dot Controls, Arcs & Rotation ───
  Widget _buildBordersTab() {
    final selectedList = _getSelectedElements();
    final bool hasSelection = selectedList.isNotEmpty;
    final List<MaskElement> inspected =
        hasSelection ? selectedList : _config.elements;
    final selectedEl = inspected.isNotEmpty ? inspected.first : null;

    MaskElement? rectEl;
    MaskElement? circleEl;
    MaskElement? arcEl;
    MaskElement? rotEl;
    for (final el in inspected) {
      rectEl ??= el.type == MaskElementType.rectangle ? el : null;
      circleEl ??= el.type == MaskElementType.circle ? el : null;
      arcEl ??= el.type == MaskElementType.arc ? el : null;
      rotEl ??= el.type != MaskElementType.line ? el : null;
    }

    final int selCount = selectedList.length;
    final Color activeColor = selectedEl?.borderColor ?? _config.activeBorderColor;
    final double activeWidth = selectedEl?.borderWidth ?? _config.activeBorderWidth;
    final double activeRadius = rectEl?.cornerRadius ?? _config.activeCornerRadius;
    final MaskElement? ringEl = arcEl ?? circleEl;
    final double activeRingRadius = ringEl?.rect != null
        ? (ringEl!.rect!.width * 0.5).clamp(0.05, 0.58)
        : 0.28;
    final double activeRotation = rotEl?.rotationDeg ?? 0.0;
    final MaskStrokePattern activePattern =
        selectedEl?.strokePattern ?? _config.activeStrokePattern;
    final double activeDashLen = selectedEl?.dashLength ?? _config.activeDashLength;
    final double activeDashGap = selectedEl?.dashGap ?? _config.activeDashGap;
    final int activeArcCount = arcEl?.arcCount ?? _config.activeArcCount;
    final double activeArcSweep = arcEl?.arcSweepRatio ?? _config.activeArcSweepRatio;
    final bool activeArcClose = arcEl?.arcCloseMaskRegion ?? _config.activeArcCloseMask;

    final bool showBoxRadius = rectEl != null || _activeTool == ShapeMaskTool.rectangle;
    final bool showRingRadius = ringEl != null;
    final bool showArcControls = arcEl != null || _activeTool == ShapeMaskTool.arc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selCount > 1
                  ? 'Style ($selCount Selected)'
                  : (hasSelection
                      ? 'Selected Shape Style'
                      : (_config.elements.isNotEmpty ? 'All Shapes Style' : 'Default Border Style')),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            if (selectedEl != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selCount > 1
                      ? 'Batch Live Edit'
                      : (hasSelection ? 'Live Selected' : 'Live Canvas'),
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _borderPalette.map((color) {
              final bool isSelected = activeColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => _applyElementStyleUpdate(borderColor: color),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: isSelected ? 3 : 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        _buildCompactSlider(
          label: 'Width',
          valueText: '${activeWidth.toStringAsFixed(1)}px',
          value: activeWidth.clamp(0.0, 20.0),
          min: 0.0,
          max: 20.0,
          divisions: 40,
          onChanged: (v) => _applyElementStyleUpdate(borderWidth: v, recordUndo: false),
        ),
        if (showRingRadius)
          _buildCompactSlider(
            label: arcEl != null ? 'Arc Radius' : 'Circle Size',
            valueText: '${(activeRingRadius * 100).round()}%',
            value: activeRingRadius,
            min: 0.05,
            max: 0.58,
            divisions: 53,
            onChanged: (v) => _applyElementStyleUpdate(
              circularRadiusNorm: v,
              recordUndo: false,
              reSolve: false,
            ),
            onChangeEnd: (_) => _solveMaskRegions(),
          ),
        if (showBoxRadius)
          _buildCompactSlider(
            label: showRingRadius ? 'Box Corner' : 'Radius',
            valueText: '${activeRadius.round()}px',
            value: activeRadius.clamp(0.0, 140.0),
            min: 0.0,
            max: 140.0,
            divisions: 35,
            onChanged: (v) => _applyElementStyleUpdate(
              cornerRadius: v,
              recordUndo: false,
              reSolve: false,
            ),
            onChangeEnd: (_) => _solveMaskRegions(),
          ),
        if (rotEl != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildCompactSlider(
                  label: 'Rotate',
                  valueText: '${activeRotation.round()}°',
                  value: activeRotation.clamp(-180.0, 180.0),
                  min: -180.0,
                  max: 180.0,
                  divisions: 72,
                  onChanged: (v) => _applyElementStyleUpdate(
                    rotationDeg: v,
                    recordUndo: false,
                    reSolve: false,
                  ),
                  onChangeEnd: (_) => _solveMaskRegions(),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _rotateSelectedElements(15.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '+15°',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Stroke Pattern',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: MaskStrokePattern.values.map((pattern) {
            final bool isSelected = activePattern == pattern;
            return ChoiceChip(
              label: Text(pattern.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (_) => _applyElementStyleUpdate(strokePattern: pattern),
            );
          }).toList(),
        ),
        if (activePattern != MaskStrokePattern.solid) ...[
          const SizedBox(height: 4),
          if (activePattern != MaskStrokePattern.dotted)
            _buildCompactSlider(
              label: 'Dash Len',
              valueText: '${activeDashLen.round()}px',
              value: activeDashLen.clamp(3.0, 36.0),
              min: 3.0,
              max: 36.0,
              divisions: 33,
              onChanged: (v) => _applyElementStyleUpdate(dashLength: v, recordUndo: false),
            ),
          _buildCompactSlider(
            label: activePattern == MaskStrokePattern.dotted ? 'Dot Space' : 'Dash Gap',
            valueText: '${activeDashGap.round()}px',
            value: activeDashGap.clamp(3.0, 32.0),
            min: 3.0,
            max: 32.0,
            divisions: 29,
            onChanged: (v) => _applyElementStyleUpdate(dashGap: v, recordUndo: false),
          ),
        ],
        if (showArcControls) ...[
          const Divider(height: 14),
          const Text(
            'Segmented Arcs',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
          _buildCompactSlider(
            label: 'Arcs',
            valueText: '$activeArcCount',
            value: activeArcCount.toDouble().clamp(1.0, 12.0),
            min: 1.0,
            max: 12.0,
            divisions: 11,
            onChanged: (v) => _applyElementStyleUpdate(
              arcCount: v.round(),
              recordUndo: false,
            ),
          ),
          _buildCompactSlider(
            label: 'Arc Fill',
            valueText: '${(activeArcSweep * 100).round()}%',
            value: activeArcSweep.clamp(0.15, 0.95),
            min: 0.15,
            max: 0.95,
            divisions: 16,
            onChanged: (v) => _applyElementStyleUpdate(
              arcSweepRatio: v,
              recordUndo: false,
            ),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text(
              'Mask Inside Arcs',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
            ),
            subtitle: const Text(
              'Pop color inside ring or use as HUD frame overlay',
              style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins'),
            ),
            value: activeArcClose,
            onChanged: (v) => _applyElementStyleUpdate(
              arcCloseMaskRegion: v,
              reSolve: true,
            ),
          ),
        ],
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Cutout Window Depth Shadow',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          value: _config.enableWindowShadow,
          onChanged: (v) => setState(() => _config = _config.copyWith(enableWindowShadow: v)),
        ),
      ],
    );
  }

  Widget _buildCompactSlider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primary,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ─── TAB 2: Masked Area Backdrop FX & Outer Frame ───
  Widget _buildMaskFxTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unmasked Backdrop FX',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MaskBackdropStyle.values.map((style) {
            final bool isSelected = _config.backdropStyle == style;
            return ChoiceChip(
              avatar: Icon(style.icon, size: 15, color: isSelected ? AppColors.primary : Colors.grey.shade600),
              label: Text(style.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (_) {
                _commitConfig(_config.copyWith(backdropStyle: style), reSolve: false);
              },
            );
          }).toList(),
        ),
        if (_config.backdropStyle == MaskBackdropStyle.dimmedDark ||
            _config.backdropStyle == MaskBackdropStyle.frostedBlur ||
            _config.backdropStyle == MaskBackdropStyle.bwColorPop) ...[
          const SizedBox(height: 8),
          _buildCompactSlider(
            label: _config.backdropStyle == MaskBackdropStyle.frostedBlur
                ? 'Blur'
                : _config.backdropStyle == MaskBackdropStyle.bwColorPop
                    ? 'B&W Dim'
                    : 'Dim',
            valueText: '${(_config.backdropIntensity * 100).round()}%',
            value: _config.backdropIntensity.clamp(0.2, 0.95),
            min: 0.2,
            max: 0.95,
            onChanged: (v) => setState(() => _config = _config.copyWith(backdropIntensity: v)),
          ),
        ],
        if (_config.backdropStyle == MaskBackdropStyle.customColor) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _borderPalette.map((color) {
                final bool isSelected = _config.customBackdropColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => _commitConfig(_config.copyWith(customBackdropColor: color), reSolve: false),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const Divider(height: 14),
        _buildCompactSlider(
          label: 'Frame',
          valueText: _config.outerFrameWidth < 0.5 ? 'Off' : '${_config.outerFrameWidth.round()}px',
          value: _config.outerFrameWidth.clamp(0.0, 16.0),
          min: 0.0,
          max: 16.0,
          divisions: 16,
          onChanged: (v) => setState(() => _config = _config.copyWith(outerFrameWidth: v)),
        ),
      ],
    );
  }

  // ─── TAB 3: Underlying Photo Framing ───
  Widget _buildPhotoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Photo Zoom & Position',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _config = _config.copyWith(imageScale: 1.0, imageOffset: Offset.zero));
              },
              child: const Text('Reset', style: TextStyle(fontSize: 11.5, color: AppColors.primary)),
            ),
          ],
        ),
        _buildCompactSlider(
          label: 'Zoom',
          valueText: '${_config.imageScale.toStringAsFixed(1)}x',
          value: _config.imageScale.clamp(1.0, 2.8),
          min: 1.0,
          max: 2.8,
          onChanged: (v) => setState(() => _config = _config.copyWith(imageScale: v)),
        ),
        _buildCompactSlider(
          label: 'Pan X',
          valueText: '${(_config.imageOffset.dx * 100).round()}%',
          value: _config.imageOffset.dx.clamp(-0.7, 0.7),
          min: -0.7,
          max: 0.7,
          onChanged: (v) => setState(() =>
              _config = _config.copyWith(imageOffset: Offset(v, _config.imageOffset.dy))),
        ),
        _buildCompactSlider(
          label: 'Pan Y',
          valueText: '${(_config.imageOffset.dy * 100).round()}%',
          value: _config.imageOffset.dy.clamp(-0.7, 0.7),
          min: -0.7,
          max: 0.7,
          onChanged: (v) => setState(() =>
              _config = _config.copyWith(imageOffset: Offset(_config.imageOffset.dx, v))),
        ),
      ],
    );
  }

  // ─── TAB 4: Canvas Aspect Ratio ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Canvas Aspect Ratio',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        ...ShapeMaskAspectRatio.values.map((ratio) {
          final bool isSelected = _config.aspectRatio == ratio;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.aspect_ratio_rounded,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
              title: Text(
                ratio.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                  : null,
              onTap: () {
                _commitConfig(_config.copyWith(aspectRatio: ratio));
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── TAB 5: Drawn Shapes & Lines Layer Manager (with Multi-Select, Group & Merge) ───
  Widget _buildShapesListTab() {
    if (_config.elements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No shapes or lines drawn yet.\nUse the Quick Tool Rail above canvas or Add tab!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Layers (${_config.elements.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedElementIds.length == _config.elements.length) {
                        _selectedElementIds = {};
                      } else {
                        _selectedElementIds = _config.elements.map((e) => e.id).toSet();
                        _multiSelectMode = true;
                        _activeTool = ShapeMaskTool.selectMove;
                      }
                    });
                  },
                  child: Text(
                    _selectedElementIds.length == _config.elements.length ? 'Deselect' : 'Select All',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedElementIds = {});
                    _commitConfig(_config.copyWith(elements: [], regionSeeds: []));
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                ),
              ],
            ),
          ],
        ),
        if (_selectedElementIds.length >= 2 || _hasGroupedSelection) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_selectedElementIds.length >= 2)
                ActionChip(
                  avatar: const Icon(Icons.group_work_rounded, size: 14, color: Color(0xFF7C3AED)),
                  label: const Text('Group', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                  backgroundColor: Colors.grey.shade100,
                  onPressed: _groupSelectedElements,
                ),
              if (_hasGroupedSelection)
                ActionChip(
                  avatar: const Icon(Icons.link_off_rounded, size: 14, color: Color(0xFF475569)),
                  label: const Text('Ungroup', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                  backgroundColor: Colors.grey.shade100,
                  onPressed: _ungroupSelectedElements,
                ),
              if (_canMergeSelection)
                ActionChip(
                  avatar: const Icon(Icons.join_full_rounded, size: 14, color: Color(0xFF0EA5E9)),
                  label: const Text('Merge Shapes', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                  backgroundColor: Colors.grey.shade100,
                  onPressed: _mergeSelectedShapes,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ..._config.elements.asMap().entries.map((entry) {
          final idx = entry.key;
          final el = entry.value;
          final bool isSelected = _selectedElementIds.contains(el.id);

          final IconData icon = switch (el.type) {
            MaskElementType.rectangle => Icons.crop_square_rounded,
            MaskElementType.circle => Icons.circle_outlined,
            MaskElementType.arc => Icons.donut_large_rounded,
            MaskElementType.line => Icons.horizontal_rule_rounded,
            MaskElementType.polygon => Icons.polyline_rounded,
          };
          final String title = switch (el.type) {
            MaskElementType.rectangle => 'Rectangle #${idx + 1}',
            MaskElementType.circle => 'Circle #${idx + 1}',
            MaskElementType.arc => 'Arcs (${el.arcCount}x) #${idx + 1}',
            MaskElementType.line => 'Line Segment #${idx + 1}',
            MaskElementType.polygon => 'Polygon #${idx + 1}',
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.45) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                isSelected ? Icons.check_box_rounded : icon,
                size: 18,
                color: AppColors.primary,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  if (el.groupId != null)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GRP',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${el.borderWidth.toStringAsFixed(1)}px${el.rotationDeg.abs() > 0.5 ? ' • ${el.rotationDeg.round()}°' : ''}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontFamily: 'Poppins'),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: el.borderColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  if (el.type != MaskElementType.line)
                    IconButton(
                      tooltip: 'Toggle Window Visibility',
                      icon: const Icon(Icons.visibility_rounded, size: 17, color: AppColors.primary),
                      onPressed: () => _toggleClosedAreaAt(el.normalizedCenter),
                    ),
                  IconButton(
                    tooltip: 'Delete Element',
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                    onPressed: () => _deleteElement(el.id),
                  ),
                ],
              ),
              onTap: () {
                final members = _expandGroupMembers(el.id);
                setState(() {
                  _activeTool = ShapeMaskTool.selectMove;
                  if (_selectedElementIds.contains(el.id)) {
                    _selectedElementIds = Set<String>.from(_selectedElementIds)..removeAll(members);
                  } else {
                    _selectedElementIds = Set<String>.from(_selectedElementIds)..addAll(members);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

}
