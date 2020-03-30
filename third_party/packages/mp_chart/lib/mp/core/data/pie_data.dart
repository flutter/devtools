import 'package:mp_chart/mp/core/data/chart_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/utils/dart_adapter_utils.dart';

class PieData extends ChartData<IPieDataSet> {
  PieData(IPieDataSet dataSet) : super.fromList(List()..add(dataSet));

  /// Sets the PieDataSet this data object should represent.
  ///
  /// @param dataSet
  void setDataSet(IPieDataSet dataSet) {
    dataSets.clear();
    dataSets.add(dataSet);
    notifyDataChanged();
  }

  /// Returns the DataSet this PieData object represents. A PieData object can
  /// only contain one DataSet.
  ///
  /// @return
  IPieDataSet getDataSet() {
    return dataSets[0];
  }

  /// The PieData object can only have one DataSet. Use getDataSet() method instead.
  ///
  /// @param index
  /// @return
  @override
  IPieDataSet getDataSetByIndex(int index) {
    return index == 0 ? getDataSet() : null;
  }

  @override
  IPieDataSet getDataSetByLabel(String label, bool ignorecase) {
    return ignorecase
        ? DartAdapterUtils.equalsIgnoreCase(label, dataSets[0].getLabel())
            ? dataSets[0]
            : null
        : (label == dataSets[0].getLabel()) ? dataSets[0] : null;
  }

  @override
  Entry getEntryForHighlight(Highlight highlight) {
    return getDataSet().getEntryForIndex(highlight.x.toInt());
  }

  /// Returns the sum of all values in this PieData object.
  ///
  /// @return
  double getYValueSum() {
    double sum = 0;
    for (int i = 0; i < getDataSet().getEntryCount(); i++)
      sum += getDataSet().getEntryForIndex(i).getValue();
    return sum;
  }
}
