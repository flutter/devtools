import 'package:mp_chart/mp/core/bounds.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/render/data_renderer.dart';
import 'package:mp_chart/mp/core/view_port.dart';

abstract class BarLineScatterCandleBubbleRenderer extends DataRenderer {
  /// buffer for storing the current minimum and maximum visible x
  XBounds _xBounds;

  BarLineScatterCandleBubbleRenderer(
      Animator animator, ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _xBounds = XBounds(this.animator);
  }

  // ignore: unnecessary_getters_setters
  XBounds get xBounds => _xBounds;

  // ignore: unnecessary_getters_setters
  set xBounds(XBounds value) {
    _xBounds = value;
  }

  /// Returns true if the DataSet values should be drawn, false if not.
  ///
  /// @param set
  /// @return
  bool shouldDrawValues(IDataSet set) {
    return set.isVisible() &&
        (set.isDrawValuesEnabled() || set.isDrawIconsEnabled());
  }

  /// Checks if the provided entry object is in bounds for drawing considering the current animation phase.
  ///
  /// @param e
  /// @param set
  /// @return
  bool isInBoundsX(Entry e, IBarLineScatterCandleBubbleDataSet set) {
    if (e == null) return false;

    double entryIndex = set.getEntryIndex2(e).toDouble();

    if (e == null || entryIndex >= set.getEntryCount() * animator.getPhaseX()) {
      return false;
    } else {
      return true;
    }
  }
}
