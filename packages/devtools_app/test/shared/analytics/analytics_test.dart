// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_app/src/shared/analytics/analytics_common.dart';
import 'package:devtools_test/helpers.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:test/test.dart';

void main() {
  group('createStackTraceForAnalytics for stack trace', () {
    final fileUriBase =
        Platform.isWindows ? 'file:///c:/b/s/w' : 'file:///b/s/w';
    test(
      'with DevTools stack frames near the top',
      () {
        final stackTrace = stack_trace.Trace.parse(
          '''$fileUriBase/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/vm_service.dart 95:18          28240
$fileUriBase/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/dart_io_extensions.dart 63:12  28301
$fileUriBase/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/dart_io_extensions.dart 61:25  28300
$fileUriBase/ir/x/w/devtools/packages/devtools_app/lib/src/screens/network/network_service.dart 104:34     28297
$fileUriBase/ir/x/w/devtools/packages/devtools_app_shared/lib/src/service/service_utils.dart 82:25         9696
org-dartlang-sdk:///dart-sdk/lib/_internal/wasm/lib/async_patch.dart 103:30                                 2140''',
        );
        final stackTraceChunks = createStackTraceForAnalytics(stackTrace);
        expect(
          stackTraceChunks.display,
          '''/b/s/w/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/vm_service.dart 95:18 |  28240
/b/s/w/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/dart_io_extensions.dart 63:12 |  28301
/b/s/w/ir/x/w/rc/tmp6qd7qvz0/hosted/pub.dev/vm_service-14.3.0/lib/src/dart_io_extensions.dart 61:25 |  28300
/b/s/w/ir/x/w/devtools/packages/devtools_app/lib/src/screens/network/network_service.dart 104:34 |  28297
/b/s/w/ir/x/w/devtools/packages/devtools_app_shared/lib/src/service/service_utils.dart 82:25 |  9696
org-dartlang-sdk:///dart-sdk/lib/_internal/wasm/lib/async_patch.dart 103:30 |  2140''',
        );
      },
      // TODO(https://github.com/flutter/devtools/issues/8761): unskip.
      tags: skipForCustomerTestsTag,
    );

    test(
      'with DevTools stack frames near the bottom',
      () {
        final stackTrace = stack_trace.Trace.parse(
          '''$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/box.dart 2212:22         size
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 298:21    performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/shifted_box.dart 239:12  performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 117:21    performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 117:21    performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 117:21    performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 117:21    performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7       layout
$fileUriBase/ir/x/w/devtools/packages/devtools_app/lib/src/screens/performance/panes/timeline_events/timeline_events_controller.dart 210:29  24070
$fileUriBase/ir/x/w/devtools/packages/devtools_app/lib/src/shared/analytics/_analytics_web.dart 557:25                                       24080
$fileUriBase/ir/x/w/devtools/packages/devtools_app/lib/src/shared/analytics/_analytics_web.dart 549:14                                       24079
$fileUriBase/ir/x/w/devtools/packages/devtools_app/lib/src/screens/performance/panes/timeline_events/timeline_events_controller.dart 207:20  24074''',
        );
        final stackTraceChunks = createStackTraceForAnalytics(stackTrace);
        expect(
          stackTraceChunks.display,
          '''/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/box.dart 2212:22 | size
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 298:21 | performLayout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7 | layout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/shifted_box.dart 239:12 | performLayout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7 | layout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 117:21 | performLayout
<modified to include DevTools frames>
/b/s/w/ir/x/w/devtools/packages/devtools_app/lib/src/screens/performance/panes/timeline_events/timeline_events_controller.dart 210:29 |  24070
/b/s/w/ir/x/w/devtools/packages/devtools_app/lib/src/shared/analytics/_analytics_web.dart 557:25 |  24080
/b/s/w/ir/x/w/devtools/packages/devtools_app/lib/src/shared/analytics/_analytics_web.dart 549:14 |  24079''', // nullnullnull expected since the last 3 chunks do not exist
        );
      },
      // TODO(https://github.com/flutter/devtools/issues/8761): unskip.
      tags: skipForCustomerTestsTag,
    );

    test(
      'without DevTools stack frames',
      () {
        final stackTrace = stack_trace.Trace.parse(
          '''
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/box.dart 2212:22          size
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 298:21     performLayout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7        layout
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/layout_helper.dart 61:11  layoutChild
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/stack.dart 601:43         _computeSize
$fileUriBase/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/stack.dart 628:12         performLayout''',
        );
        final stackTraceChunks = createStackTraceForAnalytics(stackTrace);
        expect(
          stackTraceChunks.display,
          '''/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/box.dart 2212:22 | size
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/proxy_box.dart 298:21 | performLayout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/object.dart 2627:7 | layout
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/layout_helper.dart 61:11 | layoutChild
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/stack.dart 601:43 | _computeSize
/b/s/w/ir/x/w/rc/flutter/packages/flutter/lib/src/rendering/stack.dart 628:12 | performLayout''',
        );
      },
      // TODO(https://github.com/flutter/devtools/issues/8761): unskip.
      tags: skipForCustomerTestsTag,
    );
  });
}

extension on Map<String, String?> {
  String get display => values.whereType<String>().join();
}
