import 'dart:developer';

import '_config.dart';
import 'model.dart';

LeakSummary? _previous;

void reportLeaksSummary(LeakSummary leakSummary) {
  postEvent('memory_leaks_summary', leakSummary.toJson());
  if (leakSummary.equals(_previous)) return;
  _previous = leakSummary;

  // TODO(polina-c): add deep link for DevTools here.
  appLogger.info(leakSummary.toMessage());
}

void reportLeaks(Leaks leaks) {
  postEvent('memory_leaks_details', leaks.toJson());
}
