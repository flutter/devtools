import '../table_data.dart';
import '../url_utils.dart';
import '../utils.dart';
import 'cpu_profile_model.dart';

const _timeColumnWidthPx = 180.0;

class SelfTimeColumn extends ColumnData<CpuStackFrame> {
  SelfTimeColumn({String titleTooltip})
      : super(
          'Self Time',
          titleTooltip: titleTooltip,
          fixedWidthPx: _timeColumnWidthPx,
        );

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  dynamic getValue(CpuStackFrame dataObject) =>
      dataObject.selfTime.inMicroseconds;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.selfTime, fractionDigits: 2)} '
        '(${percent2(dataObject.selfTimeRatio)})';
  }
}

class TotalTimeColumn extends ColumnData<CpuStackFrame> {
  TotalTimeColumn({String titleTooltip})
      : super(
          'Total Time',
          titleTooltip: titleTooltip,
          fixedWidthPx: _timeColumnWidthPx,
        );

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  dynamic getValue(CpuStackFrame dataObject) =>
      dataObject.totalTime.inMicroseconds;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.totalTime, fractionDigits: 2)} '
        '(${percent2(dataObject.totalTimeRatio)})';
  }
}

class MethodNameColumn extends TreeColumnData<CpuStackFrame> {
  MethodNameColumn() : super('Method');

  static const maxMethodNameLength = 75;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.name;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    if (dataObject.name.length > maxMethodNameLength) {
      return dataObject.name.substring(0, maxMethodNameLength) + '...';
    }
    return dataObject.name;
  }

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.name;
}

// TODO(kenz): make these urls clickable once we can jump to source.
class SourceColumn extends ColumnData<CpuStackFrame> {
  SourceColumn() : super.wide('Source', alignment: ColumnAlignment.right);

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.url;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return getSimplePackageUrl(dataObject.url);
  }

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.url;

  @override
  bool get supportsSorting => true;
}
