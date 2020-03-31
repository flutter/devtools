mixin OnTouchEventListener {
  TouchValueType valueType();
  void onTapDown(double x, double y);
  void onSingleTapUp(double x, double y);
  void onDoubleTapUp(double x, double y);
  void onMoveStart(double x, double y);
  void onMoveUpdate(double x, double y);
  void onMoveEnd(double x, double y);
  void onScaleStart(double x, double y);
  void onScaleUpdate(double x, double y);
  void onScaleEnd(double x, double y);
  void onDragStart(double x, double y);
  void onDragUpdate(double x, double y);
  void onDragEnd(double x, double y);
}

enum TouchValueType{
  SCREEN,LOCAL,CHART
}