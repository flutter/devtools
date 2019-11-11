import 'package:mp_chart/mp/core/buffer/bar_buffer.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';

class HorizontalBarBuffer extends BarBuffer {
  HorizontalBarBuffer(int size, int dataSetCount, bool containsStacks)
      : super(size, dataSetCount, containsStacks);

  @override
  void feed(IBarDataSet data) {
    double size = data.getEntryCount() * phaseX;
    double barWidthHalf = barWidth / 2;

    for (int i = 0; i < size; i++) {
      BarEntry e = data.getEntryForIndex(i);

      if (e == null) continue;

      double x = e.x;
      double y = e.y;
      List<double> vals = e.yVals;

      if (!containsStacks || vals == null) {
        double bottom = x - barWidthHalf;
        double top = x + barWidthHalf;
        double left, right;
        if (inverted) {
          left = y >= 0 ? y : 0;
          right = y <= 0 ? y : 0;
        } else {
          right = y >= 0 ? y : 0;
          left = y <= 0 ? y : 0;
        }

        // multiply the height of the rect with the phase
        if (right > 0)
          right *= phaseY;
        else
          left *= phaseY;

        addBar(left, top, right, bottom);
      } else {
        double posY = 0;
        double negY = -e.negativeSum;
        double yStart = 0;

        // fill the stack
        for (int k = 0; k < vals.length; k++) {
          double value = vals[k];

          if (value >= 0) {
            y = posY;
            yStart = posY + value;
            posY = yStart;
          } else {
            y = negY;
            yStart = negY + value.abs();
            negY += value.abs();
          }

          double bottom = x - barWidthHalf;
          double top = x + barWidthHalf;
          double left, right;
          if (inverted) {
            left = y >= yStart ? y : yStart;
            right = y <= yStart ? y : yStart;
          } else {
            right = y >= yStart ? y : yStart;
            left = y <= yStart ? y : yStart;
          }

          // multiply the height of the rect with the phase
          right *= phaseY;
          left *= phaseY;

          addBar(left, top, right, bottom);
        }
      }
    }

    reset();
  }
}
