// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/banner_messages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/utils.dart';

void main() {
  group('BannerMessagesController', () {
    BannerMessagesController controller;
    setUp(() {
      controller = BannerMessagesController();
    });

    test('refreshMessages fires stream subscriptions', () async {
      int refreshCount = 0;
      controller.onRefreshMessages.listen((_) {
        refreshCount++;
      });

      controller.refreshMessages();
      await delay();
      expect(refreshCount, equals(1));

      controller.refreshMessages();
      await delay();
      expect(refreshCount, equals(2));
    });

    test('isMessageDismissed returns proper values', () {
      const id = 'test message';
      expect(controller.isMessageDismissed(id), isFalse);
      controller.dismissMessage(id);
      expect(controller.isMessageDismissed(id), isTrue);

      const id2 = 'test message 2';
      expect(controller.isMessageDismissed(id2), isFalse);
      controller.dismissMessage(id2);
      expect(controller.isMessageDismissed(id2), isTrue);
    });

    test('dismissMessage dismisses message and refreshes', () async {
      int refreshCount = 0;
      controller.onRefreshMessages.listen((_) {
        refreshCount++;
      });

      const id = 'test message';
      expect(controller.isMessageDismissed(id), isFalse);
      controller.dismissMessage(id);

      await delay();
      expect(controller.isMessageDismissed(id), isTrue);
      expect(refreshCount, equals(1));
    });

    test('dismissMessage throws error for already dismissed message', () {
      const id = 'test message';
      expect(controller.isMessageDismissed(id), isFalse);
      controller.dismissMessage(id);
      expect(controller.isMessageDismissed(id), isTrue);

      // Attempting to dismiss the same message should throw an error.
      expect(() => controller.dismissMessage(id), throwsAssertionError);
    });
  });
}
