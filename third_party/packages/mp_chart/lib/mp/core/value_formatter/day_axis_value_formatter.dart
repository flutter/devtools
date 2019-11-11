import 'dart:math';

import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class DayAxisValueFormatter extends ValueFormatter {
  final List<String> _months = List()
    ..add("Jan")
    ..add("Feb")
    ..add("Mar")
    ..add("Apr")
    ..add("May")
    ..add("Jun")
    ..add("Jul")
    ..add("Aug")
    ..add("Sep")
    ..add("Oct")
    ..add("Nov")
    ..add("Dec");

  BarLineScatterCandleBubbleController _controller;

  DayAxisValueFormatter(BarLineScatterCandleBubbleController controller) {
    this._controller = controller;
  }

  @override
  String getFormattedValue1(double value) {
    int days = value.toInt();

    int year = determineYear(days);

    int month = determineMonth(days);
    String monthName = _months[month % _months.length];
    String yearName = year.toString();

    if (_controller.painter.getVisibleXRange() > 30 * 6) {
      return monthName + " " + yearName;
    } else {
      int dayOfMonth = determineDayOfMonth(days, month + 12 * (year - 2016));

      String appendix = "th";

      switch (dayOfMonth) {
        case 1:
          appendix = "st";
          break;
        case 2:
          appendix = "nd";
          break;
        case 3:
          appendix = "rd";
          break;
        case 21:
          appendix = "st";
          break;
        case 22:
          appendix = "nd";
          break;
        case 23:
          appendix = "rd";
          break;
        case 31:
          appendix = "st";
          break;
      }

      return dayOfMonth == 0 ? "" : "$dayOfMonth$appendix $monthName";
    }
  }

  int getDaysForMonth(int month, int year) {
    // month is 0-based

    if (month == 1) {
      bool is29Feb = false;

      if (year < 1582)
        is29Feb = (year < 1 ? year + 1 : year) % 4 == 0;
      else if (year > 1582)
        is29Feb = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

      return is29Feb ? 29 : 28;
    }

    if (month == 3 || month == 5 || month == 8 || month == 10)
      return 30;
    else
      return 31;
  }

  int determineMonth(int dayOfYear) {
    int month = -1;
    int days = 0;

    while (days < dayOfYear) {
      month = month + 1;

      if (month >= 12) month = 0;

      int year = determineYear(days);
      days += getDaysForMonth(month, year);
    }

    return max(month, 0);
  }

  int determineDayOfMonth(int days, int month) {
    int count = 0;
    int daysForMonths = 0;

    while (count < month) {
      int year = determineYear(daysForMonths);
      daysForMonths += getDaysForMonth(count % 12, year);
      count++;
    }

    return days - daysForMonths;
  }

  int determineYear(int days) {
    if (days <= 366)
      return 2016;
    else if (days <= 730)
      return 2017;
    else if (days <= 1094)
      return 2018;
    else if (days <= 1458)
      return 2019;
    else
      return 2020;
  }
}
