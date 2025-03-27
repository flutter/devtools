// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/ui/colors.dart';

class HowToUseMessage extends StatelessWidget {
  const HowToUseMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    TextSpan colorA(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.declarationsSyntaxColor,
    );
    TextSpan colorB(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.modifierSyntaxColor,
    );
    TextSpan colorC(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.variableSyntaxColor,
    );
    TextSpan colorD(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.controlFlowSyntaxColor,
    );
    TextSpan colorE(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.stringSyntaxColor,
    );
    TextSpan colorF(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.functionSyntaxColor,
    );
    TextSpan colorG(String text) => _coloredSpan(
      text,
      context: context,
      color: colorScheme.numericConstantSyntaxColor,
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
          _highlight(colorB('Text')),
          _highlight(colorC('(\n')),
          _highlight(colorE('  "Hello World!"')),
          _highlight(colorF(',\n')),
          _highlight(colorA('  overflow')),
          _highlight(colorF(': ')),
          _highlight(colorB('TextOveflow')),
          _highlight(colorF('.')),
          _highlight(colorG('clip')),
          _highlight(colorF(',\n')),
          _highlight(colorC('  )')),
          _highlight(colorF(';\n')),
          colorC('}'),
        ],
      ),
    );
  }

  TextSpan _coloredSpan(
    String text, {
    required BuildContext context,
    required Color color,
  }) {
    final fixedFontStyle = Theme.of(context).fixedFontStyle;
    return TextSpan(text: text, style: fixedFontStyle.copyWith(color: color));
  }

  TextSpan _highlight(TextSpan original) {
    return TextSpan(
      text: original.text,
      style: original.style!.copyWith(backgroundColor: Colors.yellow),
    );
  }
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
