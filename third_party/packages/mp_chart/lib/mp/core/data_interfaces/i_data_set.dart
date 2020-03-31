import 'dart:ui' as ui;

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/color/gradient_color.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/enums/legend_form.dart';
import 'package:mp_chart/mp/core/enums/rounding.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

mixin IDataSet<T extends Entry> {
  double getYMin();

  double getYMax();

  double getXMin();

  double getXMax();

  int getEntryCount();

  void calcMinMax();

  void calcMinMaxY(double fromX, double toX);

  T getEntryForXValue1(double xValue, double closestToY, Rounding rounding);

  T getEntryForXValue2(double xValue, double closestToY);

  List<T> getEntriesForXValue(double xValue);

  T getEntryForIndex(int index);

  int getEntryIndex1(double xValue, double closestToY, Rounding rounding);

  int getEntryIndex2(T e);

  int getIndexInEntries(int xIndex);

  bool addEntry(T e);

  void addEntryOrdered(T e);

  bool removeFirst();

  bool removeLast();

  bool removeEntry1(T e);

  bool removeEntryByXValue(double xValue);

  bool removeEntry2(int index);

  bool contains(T entry);

  void clear();

  String getLabel();

  void setLabel(String label);

  AxisDependency getAxisDependency();

  void setAxisDependency(AxisDependency dependency);

  List<ui.Color> getColors();

  ui.Color getColor1();

  GradientColor getGradientColor1();

  List<GradientColor> getGradientColors();

  GradientColor getGradientColor2(int index);

  ui.Color getColor2(int index);

  bool isHighlightEnabled();

  void setHighlightEnabled(bool enabled);

  void setValueFormatter(ValueFormatter f);

  ValueFormatter getValueFormatter();

  bool needsFormatter();

  void setValueTextColor(ui.Color color);

  void setValueTextColors(List<ui.Color> colors);

  void setValueTypeface(TypeFace ts);

  void setValueTextSize(double size);

  ui.Color getValueTextColor1();

  ui.Color getValueTextColor2(int index);

  TypeFace getValueTypeface();

  double getValueTextSize();

  LegendForm getForm();

  double getFormSize();

  double getFormLineWidth();

  DashPathEffect getFormLineDashEffect();

  void setDrawValues(bool enabled);

  bool isDrawValuesEnabled();

  void setDrawIcons(bool enabled);

  bool isDrawIconsEnabled();

  void setIconsOffset(MPPointF offset);

  MPPointF getIconsOffset();

  void setVisible(bool visible);

  bool isVisible();
}
