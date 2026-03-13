// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../framework/scaffold/bottom_pane.dart';
import '../../ui/tab.dart';
import '../../utils/utils.dart';
import '../ai_controller.dart';
import '../ai_message_types.dart';

class AiAssistantPane extends StatefulWidget implements TabbedPane {
  const AiAssistantPane({super.key});

  @override
  DevToolsTab get tab => DevToolsTab.create(
    tabName: AiAssistantPane._tabName,
    gaPrefix: AiAssistantPane._gaPrefix,
  );

  static const _tabName = 'AI Assistant';
  static const _gaPrefix = 'aiAssistant';

  @override
  State<AiAssistantPane> createState() => _AiAssistantPaneState();
}

class _AiAssistantPaneState extends State<AiAssistantPane> {
  static const _baseOverscrollPadding = 125.0;
  static const _spinnerHeight = 50.0;
  static const _scrollDuration = Duration(milliseconds: 250);

  final _textController = TextEditingController();
  final _messages = <ChatMessage>[];
  final _scrollController = ScrollController();
  final _aiController = AiController();
  late final FocusNode _focusNode;

  bool _isThinking = false;
  double _overscrollPadding = _baseOverscrollPadding;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleEnterKey);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  KeyEventResult _handleEnterKey(FocusNode node, KeyEvent event) {
    final isEnterKey =
        event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter;

    if (isEnterKey && !HardwareKeyboard.instance.isShiftPressed) {
      if (!_isThinking) {
        safeUnawaited(_sendMessage());
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _sendMessage() async {
    final messageText = _textController.text;
    if (messageText.isEmpty) return;
    _textController.clear();

    final userMessage = ChatMessage(text: messageText, isUser: true);
    setState(() {
      _overscrollPadding = _calculateOverscrollPadding(userMessage);
      _isThinking = true;
      _messages.add(userMessage);
    });
    _scrollToBottom();

    final aiResponse = await _aiController.sendMessage(userMessage);
    setState(() {
      _isThinking = false;
      _overscrollPadding = _calculateOverscrollPadding(aiResponse);
      _messages.add(aiResponse);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        safeUnawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: _scrollDuration,
            curve: Curves.ease,
          ),
        );
      }
    });
  }

  double _calculateOverscrollPadding(ChatMessage message) {
    final messageHeight =
        message.text.split('\n').length * (defaultFontSize + densePadding);
    final overscrollPadding = _baseOverscrollPadding + messageHeight;
    return message.isUser
        ? overscrollPadding + _spinnerHeight
        : overscrollPadding;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                  bottom: math.max(
                    0,
                    constraints.maxHeight - _overscrollPadding,
                  ),
                ),
                controller: _scrollController,
                itemCount: _isThinking
                    ? _messages.length + 1
                    : _messages.length,
                itemBuilder: (context, index) {
                  if (_isThinking && index == _messages.length) {
                    return const _ThinkingSpinner();
                  }
                  return _ChatMessageBubble(message: _messages[index]);
                },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(denseSpacing),
                child: RoundedOutlinedBorder(
                  child: Padding(
                    // ignore: prefer-correct-edge-insets-constructor, false positive.
                    padding: const EdgeInsets.fromLTRB(
                      defaultSpacing,
                      noPadding,
                      defaultSpacing,
                      densePadding,
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.center,
                      minLines: 1,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _isThinking ? null : _sendMessage,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: message.isUser
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          borderRadius: defaultBorderRadius,
        ),
        padding: const EdgeInsets.all(defaultSpacing),
        margin: const EdgeInsets.all(denseSpacing),
        child: Text(message.text),
      ),
    );
  }
}

class _ThinkingSpinner extends StatelessWidget {
  const _ThinkingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: denseSpacing,
          horizontal: extraLargeSpacing,
        ),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
