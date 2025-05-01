// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/colors.dart';

class HowToUseMessage extends StatelessWidget {
  const HowToUseMessage({super.key});

  static const _lightHighlighterColor = Colors.yellow;
  static const _darkHighlighterColor = Color.fromARGB(168, 191, 17, 196);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fixedFontStyle = theme.fixedFontStyle;
    TextSpan colorA(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.declarationsSyntaxColor,
    );
    TextSpan colorB(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.modifierSyntaxColor,
    );
    TextSpan colorC(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.variableSyntaxColor,
    );
    TextSpan colorD(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.controlFlowSyntaxColor,
    );
    TextSpan colorE(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.stringSyntaxColor,
    );
    TextSpan colorF(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.functionSyntaxColor,
    );
    TextSpan colorG(String text) => _coloredSpan(
      text,
      style: fixedFontStyle,
      color: colorScheme.numericConstantSyntaxColor,
    );
    TextSpan highlight(TextSpan original) => _highlight(
      original,
      highlighterColor: theme.isDarkTheme
          ? _darkHighlighterColor
          : _lightHighlighterColor,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '\nPlease move your cursor anywhere inside a '),
          TextSpan(
            text: 'Flutter widget constructor invocation',
            style: theme.boldTextStyle,
          ),
          const TextSpan(text: ' to view and edit its properties.\n\n'),
          const TextSpan(
            text:
                'For example, the highlighted code below is a constructor invocation of a ',
          ),
          TextSpan(
            text: 'Text',
            style: Theme.of(
              context,
            ).fixedFontStyle.copyWith(color: colorScheme.primary),
          ),
          const TextSpan(text: ' widget:\n\n'),
          colorA('@override\n'),
          colorB('Widget '),
          colorG('build'),
          colorC('('),
          colorB('BuildContext '),
          colorA('context'),
          colorC(') '),
          colorC('{\n'),
          colorD(' return '),
          highlight(colorB('Text')),
          highlight(colorC('(\n')),
          highlight(colorE('  "Hello World!"')),
          highlight(colorF(',\n')),
          highlight(colorA('  overflow')),
          highlight(colorF(': ')),
          highlight(colorB('TextOveflow')),
          highlight(colorF('.')),
          highlight(colorG('clip')),
          highlight(colorF(',\n')),
          highlight(colorC('  )')),
          highlight(colorF(';\n')),
          colorC('}'),
        ],
      ),
    );
  }

  TextSpan _coloredSpan(
    String text, {
    required TextStyle style,
    required Color color,
  }) => TextSpan(
    text: text,
    style: style.copyWith(color: color),
  );

  TextSpan _highlight(TextSpan original, {required Color highlighterColor}) =>
      TextSpan(
        text: original.text,
        style: original.style!.copyWith(backgroundColor: highlighterColor),
      );
}

class NoDartCodeMessage extends StatelessWidget {
  const NoDartCodeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'No Dart code found at the current cursor location.',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class NoMatchingPropertiesMessage extends StatelessWidget {
  const NoMatchingPropertiesMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('No properties matching the current filter.');
  }
}

class NoWidgetAtLocationMessage extends StatelessWidget {
  const NoWidgetAtLocationMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'No Flutter widget found at the current cursor location.',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '👋 Welcome to the Flutter Property Editor!',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
