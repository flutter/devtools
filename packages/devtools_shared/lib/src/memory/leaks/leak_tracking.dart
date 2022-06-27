import 'dart:async';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:memory_tools/src/_utils.dart';

import 'model.dart';
import 'src/_config.dart' as config;
import 'src/_object_registry.dart';
import 'src/_reporter.dart' as reporter;
import 'dart:developer' as developer;

import 'src/_reporter.dart';

Timer? _timer;

void init({
  required String Function(Object object) objectLocationGetter,
  Duration tick = const Duration(seconds: 1),
}) {
  config.objectLocationGetter = objectLocationGetter;

  _timer ??= Timer.periodic(
    tick,
    (_) {
      reporter.reportLeaksSummary(objectRegistry.collectLeaksSummary());
    },
  );

  // We need the extension to receive GC events.
  developer.registerExtension('ext.memory-leak-tracking',
      (method, parameters) async {
    objectRegistry.registerGCEvent(
      oldSpace: parameters.containsKey('old'),
      newSpace: parameters.containsKey('new'),
    );
    return developer.ServiceExtensionResponse.result('ok');
  });

  if (configureLogging) {
    Logger.root.level = logLevel; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      final DateFormat _formatter = DateFormat.Hms();
      print(
          '${record.level.name}: ${_formatter.format(record.time)}: ${record.message}');
    });
  }

  config.leakTrackingEnabled = true;
  config.logger.info('Leak detector initialized.');
}

// Initiated by DevTools with 'eval'.
void sendLeaks() {
  print('!!!!!!! reporting leaks...');
  reportLeaks(objectRegistry.collectLeaks());
  print('!!!!!!! reported leaks.');
}

// Initiated by DevTools with 'eval'.
void triggerFullGC() async {
  print('!!!!!!! triggering GC...');
  Iterable.generate(3).forEach((_) async => await forceGC());
  print('!!!!!!! triggered GC.');
}
