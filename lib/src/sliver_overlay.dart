import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:boxy/utils.dart';

class SliverOverlay extends StatelessWidget {
  final Widget sliver;
  final Widget foreground;
  final Widget background;
  final double bufferExtent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final ShapeBorderClipper clipper;
  final Clip clipBehavior;
  final bool clipSliverOnly;

  SliverOverlay({
    Key key,
    @required this.sliver,
    this.foreground,
    this.background,
    this.bufferExtent = 0.0,
    this.padding,
    this.margin,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    this.clipSliverOnly = false,
  }) : super(key: key);

  build(context) {
    var current = sliver;
    if (padding != null) {
      current = SliverPadding(
        sliver: current,
        padding: padding,
      );
    }
    current = _SliverOverlay(
      sliver: current,
      foreground: foreground,
      background: background,
      bufferExtent: bufferExtent,
      clipper: clipper,
      clipBehavior: clipBehavior,
    );
    if (margin != null) {
      current = SliverPadding(
        sliver: current,
        padding: margin,
      );
    }
    return current;
  }
}

class _SliverOverlay extends RenderObjectWidget {
  final Widget sliver;
  final Widget foreground;
  final Widget background;
  final double bufferExtent;
  final ShapeBorderClipper clipper;
  final Clip clipBehavior;
  final bool clipSliverOnly;

  const _SliverOverlay({
    Key key,
    @required this.sliver,
    this.foreground,
    this.background,
    this.bufferExtent = 0.0,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    this.clipSliverOnly = false,
  }) :
    assert(sliver != null),
    assert(bufferExtent != null),
    assert(clipBehavior != null),
    super(key: key);

  createElement() => _SliverOverlayElement(this);

  createRenderObject(context) =>
    RenderSliverOverlay(
      bufferExtent: bufferExtent,
      clipper: clipper,
      clipBehavior: clipBehavior,
      clipSliverOnly: clipSliverOnly,
    );

  updateRenderObject(BuildContext context, RenderSliverOverlay renderObject) {
    renderObject.bufferExtent = bufferExtent;
    renderObject.clipper = clipper;
    renderObject.clipBehavior = clipBehavior;
    renderObject.clipSliverOnly = clipSliverOnly;
  }
}

class RenderSliverOverlay extends RenderSliver with RenderSliverHelpers {
  RenderSliverOverlay({
    this.foreground,
    this.sliver,
    this.background,
    bufferExtent = 0.0,
    Clip clipBehavior,
    ShapeBorderClipper clipper,
    bool clipSliverOnly,
  }) :
    assert(bufferExtent != null),
    _clipBehavior = clipBehavior,
    _clipper = clipper,
    _bufferExtent = bufferExtent,
    _clipSliverOnly = clipSliverOnly {
    if (foreground != null) adoptChild(foreground);
    if (sliver != null) adoptChild(sliver);
    if (background != null) adoptChild(background);
  }

  CustomClipper<Path> get clipper => _clipper;
  CustomClipper<Path> _clipper;
  set clipper(CustomClipper<Path> newClipper) {
    if (_clipper == newClipper) return;
    var oldClipper = _clipper;
    _clipper = newClipper;

    assert(newClipper != null || oldClipper != null);
    if (newClipper == null || oldClipper == null ||
      newClipper.runtimeType != oldClipper.runtimeType ||
      newClipper.shouldReclip(oldClipper)) _markNeedsClip();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (foreground != null) foreground.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    if (foreground != null) foreground.detach();
    if (sliver != null) sliver.detach();
    if (background != null) background.detach();
  }

  @override
  void redepthChildren() {
    if (foreground != null) redepthChild(foreground);
    if (sliver != null) redepthChild(sliver);
    if (background != null) redepthChild(background);
  }

  void updateChild(RenderObject oldChild, RenderObject newChild) {
    if (oldChild != null) dropChild(oldChild);
    if (newChild != null) adoptChild(newChild);
  }

  Path _clipPath;
  void _markNeedsClip() {
    _clipPath = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _updateClip() {
    if (_clipper == null || _clipPath != null) return;
    _clipPath = _clipper?.getClip(_bufferRect.size);
  }

  double _bufferExtent;
  double get bufferExtent => _bufferExtent;
  set bufferExtent(double value) {
    if (value == _bufferExtent) return;
    markNeedsLayout();
    _bufferExtent = value;
  }

  Clip _clipBehavior;
  Clip get clipBehavior => _clipBehavior;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
    }
  }

  bool _clipSliverOnly;
  bool get clipSliverOnly => _clipSliverOnly;
  set clipSliverOnly(bool value) {
    if (value != clipSliverOnly) {
      _clipSliverOnly = value;
      markNeedsPaint();
    }
  }

  RenderBox foreground;
  RenderSliver sliver;
  RenderBox background;

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (foreground != null) visitor(foreground);
    if (sliver != null) visitor(sliver);
    if (background != null) visitor(background);
  }

  Offset _getBufferOffset(double mainAxisPosition, double mainAxisSize) {
    var delta = mainAxisPosition;
    assert(constraints.axis != null);
    switch (constraints.axis) {
      case Axis.horizontal:
        if (!_rightWayUp)
          delta = geometry.paintExtent - mainAxisSize - delta;
        return Offset(delta, 0);
      case Axis.vertical:
        if (!_rightWayUp)
          delta = geometry.paintExtent - mainAxisSize - delta;
        return Offset(0, delta);
        break;
    }
    assert(false, 'Unreachable');
    return null;
  }

  Rect _bufferRect;
  bool _rightWayUp;
  double _bufferMainSize;

  @override
  void performLayout() {
    assert(sliver != null);
    sliver.layout(constraints, parentUsesSize: true);
    var geometry = this.geometry = sliver.geometry;

    var maxBufferExtent = min(
      bufferExtent,
      geometry.maxPaintExtent / 2,
    );

    var start = -min(constraints.scrollOffset, maxBufferExtent);
    var end = min(
      geometry.maxPaintExtent - constraints.scrollOffset,
      geometry.paintExtent + maxBufferExtent
    );

    if (constraints.scrollOffset > 0) {
      start = min(start, end - maxBufferExtent * 2);
    } else {
      end = max(end, start + maxBufferExtent * 2);
    }

    assert(constraints.axisDirection != null);
    switch (constraints.axisDirection) {
      case AxisDirection.up:
      case AxisDirection.left:
        _rightWayUp = false;
        break;
      case AxisDirection.down:
      case AxisDirection.right:
        _rightWayUp = true;
        break;
    }
    assert(constraints.growthDirection != null);
    switch (constraints.growthDirection) {
      case GrowthDirection.reverse:
        _rightWayUp = !_rightWayUp;
        break;
      default:
        break;
    }

    _bufferMainSize = end - start;
    final boxConstraints = BoxConstraintsAxisUtil.tightFor(
      constraints.axis,
      cross: constraints.crossAxisExtent,
      main: _bufferMainSize,
    );

    var newRect = _getBufferOffset(start, _bufferMainSize) & boxConstraints.biggest;
    if (_bufferRect == null || newRect.size != _bufferRect.size) _markNeedsClip();
    _bufferRect = newRect;

    if (foreground != null)
      foreground.layout(boxConstraints, parentUsesSize: false);

    if (background != null)
      background.layout(boxConstraints, parentUsesSize: false);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child != null);
    if (identical(child, sliver)) return;
    transform.translate(_bufferRect.left, _bufferRect.top);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _updateClip();
    if (_clipPath != null) {
      if (clipSliverOnly && background != null) context.paintChild(background, offset + _bufferRect.topLeft);

      var transform = Matrix4.translationValues(_bufferRect.left, _bufferRect.top, 0);
      context.pushTransform(needsCompositing, Offset.zero, transform, (context, newOffset) {
        context.pushClipPath(
          needsCompositing, offset, Offset.zero & _bufferRect.size, _clipPath,
          (context, offset) {
            offset -= _bufferRect.topLeft;
            if (!clipSliverOnly && background != null) context.paintChild(background, offset + _bufferRect.topLeft);
            if (sliver != null) context.paintChild(sliver, offset);
            if (!clipSliverOnly && foreground != null) context.paintChild(foreground, offset + _bufferRect.topLeft);
          },
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipPathLayer,
        );
      });

      if (clipSliverOnly && foreground != null) context.paintChild(foreground, offset + _bufferRect.topLeft);
    } else {
      if (background != null) context.paintChild(background, offset + _bufferRect.topLeft);
      if (sliver != null) context.paintChild(sliver, offset);
      if (foreground != null) context.paintChild(foreground, offset + _bufferRect.topLeft);
    }
  }

  bool _hitTestBoxChild(BoxHitTestResult result, RenderBox child, {
    double mainAxisPosition, double crossAxisPosition,
  }) {
    var transformedPosition = OffsetAxisUtil.create(constraints.axis, crossAxisPosition, mainAxisPosition);
    return result.addWithPaintOffset(
      offset: _bufferRect.topLeft,
      position: transformedPosition,
      hitTest: (BoxHitTestResult result, Offset position) => child.hitTest(result, position: position),
    );
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {
    double mainAxisPosition, double crossAxisPosition,
  }) {
    return (foreground != null && _hitTestBoxChild(
      BoxHitTestResult.wrap(result),
      foreground,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    )) || (sliver != null && sliver.geometry.hitTestExtent > 0 && sliver.hitTest(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    )) || (background != null && _hitTestBoxChild(
      BoxHitTestResult.wrap(result),
      background,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    ));
  }

  @override
  double childMainAxisPosition(RenderObject child) {
    return identical(child, sliver) ? 0 : _bufferMainSize;
  }
}

enum _SliverOverlaySlot {
  foreground,
  sliver,
  background,
}

class _SliverOverlayElement extends RenderObjectElement {
  _SliverOverlayElement(_SliverOverlay widget) : super(widget);

  Element foreground;
  Element sliver;
  Element background;

  _SliverOverlay get widget => super.widget as _SliverOverlay;
  RenderSliverOverlay get renderObject => super.renderObject as RenderSliverOverlay;

  visitChildren(ElementVisitor visitor) {
    if (foreground != null) visitor(foreground);
    if (sliver != null) visitor(sliver);
    if (background != null) visitor(background);
  }

  @override
  void forgetChild(Element child) {
    if (identical(foreground, child)) {
      foreground = null;
    } else if (identical(sliver, child)) {
      sliver = null;
    } else if (identical(background, child)) {
      background = null;
    }
    super.forgetChild(child);
  }

  void _updateChildren() {
    foreground = updateChild(foreground, widget.foreground, _SliverOverlaySlot.foreground);
    sliver = updateChild(sliver, widget.sliver, _SliverOverlaySlot.sliver);
    background = updateChild(background, widget.background, _SliverOverlaySlot.background);
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _updateChildren();
  }

  @override
  void update(_SliverOverlay newWidget) {
    super.update(newWidget);
    _updateChildren();
  }

  void _updateRenderObject(RenderObject child, _SliverOverlaySlot slot) {
    switch (slot) {
      case _SliverOverlaySlot.foreground:
        renderObject.updateChild(renderObject.foreground, child);
        renderObject.foreground = child;
        break;
      case _SliverOverlaySlot.sliver:
        renderObject.updateChild(renderObject.sliver, child);
        renderObject.sliver = child;
        break;
      case _SliverOverlaySlot.background:
        renderObject.updateChild(renderObject.background, child);
        renderObject.background = child;
        break;
    }
  }

  @override
  void insertChildRenderObject(RenderObject child, dynamic slotValue) {
    _updateRenderObject(child, slotValue as _SliverOverlaySlot);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    _updateRenderObject(null, renderObject.parentData as _SliverOverlaySlot);
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slotValue) {
    assert(false, 'Unreachable');
  }
}