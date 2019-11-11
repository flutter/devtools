import 'package:mp_chart/mp/core/data_interfaces/i_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_set/bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/entry/bubble_entry.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class BubbleDataSet extends BarLineScatterCandleBubbleDataSet<BubbleEntry>
    implements IBubbleDataSet {
  double _maxSize = 0.0;
  bool _normalizeSize = true;

  double _highlightCircleWidth = 2.5;

  BubbleDataSet(List<BubbleEntry> yVals, String label) : super(yVals, label);

  @override
  void setHighlightCircleWidth(double width) {
    _highlightCircleWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getHighlightCircleWidth() {
    return _highlightCircleWidth;
  }

  @override
  void calcMinMax1(BubbleEntry e) {
    super.calcMinMax1(e);

    final double size = e.size;

    if (size > _maxSize) {
      _maxSize = size;
    }
  }

  @override
  DataSet<BubbleEntry> copy1() {
    List<BubbleEntry> entries = List<BubbleEntry>();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    BubbleDataSet copied = BubbleDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BubbleDataSet) {
      var bubbleDataSet = baseDataSet;
      bubbleDataSet._highlightCircleWidth = _highlightCircleWidth;
      bubbleDataSet._normalizeSize = _normalizeSize;
    }
  }

  @override
  double getMaxSize() {
    return _maxSize;
  }

  @override
  bool isNormalizeSizeEnabled() {
    return _normalizeSize;
  }

  void setNormalizeSizeEnabled(bool normalizeSize) {
    _normalizeSize = normalizeSize;
  }
}
