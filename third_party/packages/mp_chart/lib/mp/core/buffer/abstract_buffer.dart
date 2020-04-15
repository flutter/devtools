abstract class AbstractBuffer<T> {
  /// index in the buffer
  int _index = 0;

  /// double-buffer that holds the data points to draw, order: x,y,x,y,...
  List<double> _buffer;

  /// animation phase x-axis
  double _phaseX = 1.0;

  /// animation phase y-axis
  double _phaseY = 1.0;

  /// indicates from which x-index the visible data begins
  // ignore: unused_field
  int _mFrom = 0;

  /// indicates to which x-index the visible data ranges
  // ignore: unused_field
  int _mTo = 0;

  /// Initialization with buffer-size.
  ///
  /// @param size
  AbstractBuffer(int size) {
    _index = 0;
    _buffer = List(size);
  }

  /// limits the drawing on the x-axis
  void limitFrom(int from) {
    if (from < 0) from = 0;
    _mFrom = from;
  }

  /// limits the drawing on the x-axis
  void limitTo(int to) {
    if (to < 0) to = 0;
    _mTo = to;
  }

  /// Resets the buffer index to 0 and makes the buffer reusable.
  void reset() {
    _index = 0;
  }

  /// Returns the size (length) of the buffer array.
  ///
  /// @return
  int size() {
    return _buffer.length;
  }

  /// Set the phases used for animations.
  ///
  /// @param phaseX
  /// @param phaseY
  void setPhases(double phaseX, double phaseY) {
    this._phaseX = phaseX;
    this._phaseY = phaseY;
  }

  /// Builds up the buffer with the provided data and resets the buffer-index
  /// after feed-completion. This needs to run FAST.
  ///
  /// @param data
  void feed(T data);

  List<double> get buffer => _buffer;

  // ignore: unnecessary_getters_setters
  int get index => _index;

  // ignore: unnecessary_getters_setters
  set index(int value) {
    _index = value;
  }

  double get phaseX => _phaseX;

  double get phaseY => _phaseY;
}
