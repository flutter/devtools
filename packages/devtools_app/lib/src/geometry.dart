import 'ui/fake_flutter/fake_flutter.dart';

// TODO(kenz): consolidate the logic between [VerticalLineSegment] and
// [HorizontalLineSegment] by using [LineSegment] and switching on the main axis
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

class HorizontalLineSegment extends LineSegment
    implements Comparable<HorizontalLineSegment> {
  HorizontalLineSegment(Offset start, Offset end)
      : assert(start.dy == end.dy),
        super(start, end);

  double get y => start.dy;

  @override
  bool crossAxisIntersects(Rect rect) => y >= rect.top && y <= rect.bottom;

  @override
  int compareTo(HorizontalLineSegment other) {
    final compare = y.compareTo(other.y);
    if (compare == 0) {
      return start.dx.compareTo(other.start.dx);
    }
    return compare;
  }
}

class VerticalLineSegment extends LineSegment
    implements Comparable<VerticalLineSegment> {
  VerticalLineSegment(Offset start, Offset end)
      : assert(start.dx == end.dx),
        super(start, end);

  double get x => start.dx;

  @override
  bool crossAxisIntersects(Rect rect) => x >= rect.left && x <= rect.right;

  @override
  int compareTo(VerticalLineSegment other) {
    final compare = x.compareTo(other.x);
    if (compare == 0) {
      return start.dy.compareTo(other.start.dy);
    }
    return compare;
  }
}
