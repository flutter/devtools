import 'ui/fake_flutter/fake_flutter.dart';

abstract class LineSegment {
  LineSegment(this.start, this.end, this.name);

  final Point start;
  final Point end;

  // Name is for debugging purposes.
  final String name;

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
    final intersectsY = (start.y >= rect.top && start.y <= rect.bottom) ||
        (end.y >= rect.top && end.y <= rect.bottom) ||
        (start.y < rect.top && end.y > rect.bottom);
    final intersectsX = (start.x >= rect.left && start.x <= rect.right) ||
        (end.x >= rect.left && end.x <= rect.right) ||
        (start.x < rect.left && end.x > rect.right);
    return intersectsX && intersectsY;
  }

  @override
  String toString() => '$name $start --> $end';
}

class HorizontalLineSegment extends LineSegment {
  HorizontalLineSegment(Point start, Point end, String name)
      : assert(start.y == end.y),
        super(start, end, name);

  double get y => start.y;

  @override
  bool crossAxisIntersects(Rect rect) => y >= rect.top && y <= rect.bottom;
}

class VerticalLineSegment extends LineSegment {
  VerticalLineSegment(Point start, Point end, String name)
      : assert(start.x == end.x),
        super(start, end, name);

  double get x => start.x;

  @override
  bool crossAxisIntersects(Rect rect) => x >= rect.left && x <= rect.right;
}

class Point {
  Point(this.x, this.y) : assert(x != null && y != null);
  final double x;
  final double y;

  @override
  String toString() => '($x, $y)';
}
