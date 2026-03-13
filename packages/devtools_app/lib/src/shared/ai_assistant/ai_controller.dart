// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';

import 'ai_message_types.dart';

class AiController extends DisposableController
    with AutoDisposeControllerMixin {
  AiController();

  Future<ChatMessage> sendMessage(ChatMessage _) async {
    await Future.delayed(const Duration(seconds: 3));
    return const ChatMessage(text: _loremIpsum, isUser: false);
  }
}

const _loremIpsum = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.
''';
