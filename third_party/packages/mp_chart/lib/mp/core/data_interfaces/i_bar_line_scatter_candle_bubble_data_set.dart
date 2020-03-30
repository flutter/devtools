import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';

mixin IBarLineScatterCandleBubbleDataSet<T extends Entry>
    implements IDataSet<T> {
  /// Returns the color that is used for drawing the highlight indicators.
  ///
  /// @return
  Color getHighLightColor();
}
