// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../shared/globals.dart';

const preCompileShadersDocsUrl = 'https://docs.flutter.dev/perf/shader';

const impellerDocsUrl = 'https://flutter.dev/to/impeller';

const flutterPerformanceDocsUrl = 'https://docs.flutter.dev/perf';

void pushNoTimelineEventsAvailableWarning() {
  notificationService.push(
    'No timeline events available for the selected frame. Timeline '
    'events occurred too long ago before DevTools could access them. '
    'To avoid this, open the DevTools Performance page earlier.',
  );
}
