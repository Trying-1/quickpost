import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AlphaMask extends MultiChildRenderObjectWidget {
  AlphaMask({Key? key, required Widget mask, required Widget child})
      : super(key: key, children: [child, mask]); // Note: child is first, mask is second!

  @override
  RenderAlphaMask createRenderObject(BuildContext context) {
    return RenderAlphaMask();
  }
}

class AlphaMaskParentData extends ContainerBoxParentData<RenderBox> {}

class RenderAlphaMask extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, AlphaMaskParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, AlphaMaskParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! AlphaMaskParentData) {
      child.parentData = AlphaMaskParentData();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(constraints, parentUsesSize: false);
      final AlphaMaskParentData childParentData = child.parentData! as AlphaMaskParentData;
      childParentData.offset = Offset.zero;
      child = childParentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = firstChild;
    if (child == null) return;
    
    final AlphaMaskParentData childParentData = child.parentData! as AlphaMaskParentData;
    final RenderBox? mask = childParentData.nextSibling;
    if (mask == null) return;

    // Draw the child (text stroke)
    context.canvas.saveLayer(offset & size, Paint());
    context.paintChild(child, offset + childParentData.offset);

    // Draw the mask (foreground image) using dstIn
    // dstIn keeps the destination (child) where the source (mask) is opaque.
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.dstIn,
    );
    context.paintChild(mask, offset + (mask.parentData as AlphaMaskParentData).offset);

    context.canvas.restore();
    context.canvas.restore();
  }
}
