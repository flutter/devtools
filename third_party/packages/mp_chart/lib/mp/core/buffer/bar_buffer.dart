import 'package:mp_chart/mp/core/buffer/abstract_buffer.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';

class BarBuffer extends AbstractBuffer<IBarDataSet> {
  int _dataSetIndex = 0;
  int _dataSetCount = 1;
  bool _containsStacks = false;
  bool _inverted = false;

  /// width of the bar on the x-axis, in values (not pixels)
  double _barWidth = 1.0;

  BarBuffer(int size, int dataSetCount, bool containsStacks) : super(size) {
    this._dataSetCount = dataSetCount;
    this._containsStacks = containsStacks;
  }

  // ignore: unnecessary_getters_setters
  int get dataSetIndex => _dataSetIndex;

  // ignore: unnecessary_getters_setters
  set dataSetIndex(int value) {
    _dataSetIndex = value;
  }

  void addBar(double left, double top, double right, double bottom) {
    buffer[index] = left;
    index += 1;
    buffer[index] = top;
    index += 1;
    buffer[index] = right;
    index += 1;
    buffer[index] = bottom;
    index += 1;
  }

  @override
  void feed(IBarDataSet data) {
    double size = data.getEntryCount() * phaseX;
    double barWidthHalf = _barWidth / 2.0;

    for (int i = 0; i < size; i++) {
      BarEntry e = data.getEntryForIndex(i);

      if (e == null) continue;

      double x = e.x;
      double y = e.y;
      List<double> vals = e.yVals;

      if (!_containsStacks || vals == null) {
        double left = x - barWidthHalf;
        double right = x + barWidthHalf;
        double bottom, top;

        if (_inverted) {
          bottom = y >= 0 ? y : 0;
          top = y <= 0 ? y : 0;
        } else {
          top = y >= 0 ? y : 0;
          bottom = y <= 0 ? y : 0;
        }

        // multiply the height of the rect with the phase
        if (top > 0)
          top *= phaseY;
        else
          bottom *= phaseY;

        addBar(left, top, right, bottom);
      } else {
        double posY = 0.0;
        double negY = -e.negativeSum;
        double yStart = 0.0;

        // fill the stack
        for (int k = 0; k < vals.length; k++) {
          double value = vals[k];

          if (value == 0.0 && (posY == 0.0 || negY == 0.0)) {
            // Take care of the situation of a 0.0 value, which overlaps a non-zero bar
            y = value;
            yStart = y;
          } else if (value >= 0.0) {
            y = posY;
            yStart = posY + value;
            posY = yStart;
          } else {
            y = negY;
            yStart = negY + value.abs();
            negY += value.abs();
          }

          double left = x - barWidthHalf;
          double right = x + barWidthHalf;
          double bottom, top;

          if (_inverted) {
            bottom = y >= yStart ? y : yStart;
            top = y <= yStart ? y : yStart;
          } else {
            top = y >= yStart ? y : yStart;
            bottom = y <= yStart ? y : yStart;
          }

          // multiply the height of the rect with the phase
          top *= phaseY;
          bottom *= phaseY;

          addBar(left, top, right, bottom);
        }
      }
    }
    reset();
  }

  // ignore: unnecessary_getters_setters
  int get dataSetCount => _dataSetCount;

  // ignore: unnecessary_getters_setters
  set dataSetCount(int value) {
    _dataSetCount = value;
  }

  // ignore: unnecessary_getters_setters
  bool get containsStacks => _containsStacks;

  // ignore: unnecessary_getters_setters
  set containsStacks(bool value) {
    _containsStacks = value;
  }

  // ignore: unnecessary_getters_setters
  bool get inverted => _inverted;

  // ignore: unnecessary_getters_setters
  set inverted(bool value) {
    _inverted = value;
  }

  // ignore: unnecessary_getters_setters
  double get barWidth => _barWidth;

  // ignore: unnecessary_getters_setters
  set barWidth(double value) {
    _barWidth = value;
  }
}
