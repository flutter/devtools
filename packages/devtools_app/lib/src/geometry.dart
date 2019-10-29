import 'ui/fake_flutter/fake_flutter.dart';

abstract class LineSegment {
  LineSegment(this.start, this.end);

  final Offset start;
  final Offset end;

  /// Whether [this] line segment intersects [rect] along the cross axis.
  ///
  /// For [HorizontalLineSegment]s, this will return true if [this] line segment
  /// fits withing the y bounds of the [rect]. For [VerticalLineSegment]s, this
  /// will return true if [this] line segment fits within the x bounds of the
  /// [rect].
  bool crossAxisIntersects(Rect rect);

  /// Whether [this] line segment intersects [rect], bound by both its x and y
  /// constraints.
  bool intersects(Rect rect) {
    final intersectRect = Rect.fromPoints(start, end).intersect(rect);
    return intersectRect.width >= 0 && intersectRect.height >= 0;
  }

  @override
  String toString() => '$start --> $end';
}

class HorizontalLineSegment extends LineSegment {
  HorizontalLineSegment(Offset start, Offset end)
      : assert(start.dy == end.dy),
        super(start, end);

  double get y => start.dy;

  @override
  bool crossAxisIntersects(Rect rect) => y >= rect.top && y <= rect.bottom;
}

class VerticalLineSegment extends LineSegment {
  VerticalLineSegment(Offset start, Offset end)
      : assert(start.dx == end.dx),
        super(start, end);

  double get x => start.dx;

  @override
  bool crossAxisIntersects(Rect rect) => x >= rect.left && x <= rect.right;
}
