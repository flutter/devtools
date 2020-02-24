import 'dart:math' as math;

import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_line_scatter_candle_bubble_data_provider.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/rounding.dart';

class XBounds {
  /// minimum visible entry index
  int _min;

  /// maximum visible entry index
  int _max;

  /// range of visible entry indices
  int _range;

  Animator _animator;

  XBounds(this._animator);

  // ignore: unnecessary_getters_setters
  int get range => _range;

  // ignore: unnecessary_getters_setters
  set range(int value) {
    _range = value;
  }

  // ignore: unnecessary_getters_setters
  int get max => _max;

  // ignore: unnecessary_getters_setters
  set max(int value) {
    _max = value;
  }

  // ignore: unnecessary_getters_setters
  int get min => _min;

  // ignore: unnecessary_getters_setters
  set min(int value) {
    _min = value;
  }

  /// Calculates the minimum and maximum x values as well as the range between them.
  ///
  /// @param chart
  /// @param dataSet
  void set(BarLineScatterCandleBubbleDataProvider chart,
      IBarLineScatterCandleBubbleDataSet dataSet) {
    double phaseX = math.max(0.0, math.min(1.0, _animator.getPhaseX()));

    double low = chart.getLowestVisibleX();
    double high = chart.getHighestVisibleX();
    Entry entryFrom =
        dataSet.getEntryForXValue1(low, double.nan, Rounding.DOWN);
    Entry entryTo = dataSet.getEntryForXValue1(high, double.nan, Rounding.UP);

    _min = entryFrom == null ? 0 : dataSet.getEntryIndex2(entryFrom);
    _max = entryTo == null ? 0 : dataSet.getEntryIndex2(entryTo);

    if (_min > _max) {
      var t = _min;
      _min = _max;
      _max = t;
    }

    _range = ((_max - _min) * phaseX).toInt();
  }
}
