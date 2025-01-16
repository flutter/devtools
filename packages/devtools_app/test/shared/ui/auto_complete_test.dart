// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'package:devtools_app/src/shared/ui/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Set debug to true displays editing parts.
bool debug = false;

void main() {
  group('AutoComplete', () {
    setUp(() {
      // TODO: add code to run before each test
    });

    // [caretPosition] if null (default) TextSelection is set to EOL.
    EditingParts testEdit(String editing, [int? caretPosition]) {
      final position = caretPosition ?? editing.length;
      return AutoCompleteSearchControllerMixin.activeEditingParts(
        editing,
        TextSelection(baseOffset: position, extentOffset: position),
        handleFields: true,
      );
    }

    void outputResult(int num, EditingParts editingParts) {
      if (debug) {
        print(
          '$num. left=${editingParts.leftSide}, '
          'active=${editingParts.activeWord}',
        );
      }
    }

    test('activeEditing parsing caret EOL', () {
      // Test for various types of auto-complete (tracking) used for expression evaluator
      // with caret (insertion point) at EOL.
      EditingParts parts = testEdit('baseO');
      outputResult(0, parts);
      expect(parts.activeWord, 'baseO');
      expect(parts.leftSide.isEmpty, isTrue);
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject');
      outputResult(1, parts);
      expect(parts.activeWord, 'baseObject');
      expect(parts.leftSide.isEmpty, isTrue);
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.');
      outputResult(2, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.cl');
      outputResult(3, parts);
      expect(parts.activeWord, 'cl');
      expect(parts.leftSide, 'baseObject.');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close+');
      outputResult(4, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close+');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close+1000+');
      outputResult(5, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close+1000+');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close+1000+char');
      outputResult(6, parts);
      expect(parts.activeWord, 'char');
      expect(parts.leftSide, 'baseObject.close+1000+');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000');
      outputResult(7, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + cha');
      outputResult(8, parts);
      expect(parts.activeWord, 'cha');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart');
      outputResult(9, parts);
      expect(parts.activeWord, 'chart');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000 / 2000 + chart.');
      outputResult(10, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000 / 2000 + chart.');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.tr');
      outputResult(11, parts);
      expect(parts.activeWord, 'tr');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close+1000/2000+chart.traces');
      outputResult(12, parts);
      expect(parts.activeWord, 'traces');
      expect(parts.leftSide, 'baseObject.close+1000/2000+chart.');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10');
      outputResult(13, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10]');
      outputResult(14, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10]');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10].yNa');
      outputResult(15, parts);
      expect(parts.activeWord, 'yNa');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[addO');
      outputResult(16, parts);
      expect(parts.activeWord, 'addO');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[');
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[addOne,addT',
      );
      outputResult(17, parts);
      expect(parts.activeWord, 'addT');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]',
      );
      outputResult(18, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].xNam',
      );
      outputResult(19, parts);
      expect(parts.activeWord, 'xNam');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute',
      );
      outputResult(20, parts);
      expect(parts.activeWord, 'compute');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + ',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()',
      );
      outputResult(21, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo',
      );
      outputResult(22, parts);
      expect(parts.activeWord, 'foo');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar',
      );
      outputResult(23, parts);
      expect(parts.activeWord, 'bar');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)',
      );
      outputResult(24, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foo',
      );
      outputResult(25, parts);
      expect(parts.activeWord, 'foo');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + ',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.',
      );
      outputResult(26, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);

      parts = testEdit(
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.length',
      );
      outputResult(27, parts);
      expect(parts.activeWord, 'length');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.',
      );
      expect(parts.rightSide.isEmpty, isTrue);
      expect(parts.isField, isTrue);
    });

    test('activeEditing parsing caret inside', () {
      EditingParts parts;
      // Test for various types of auto-complete (tracking) used for expression evaluator
      // with caret (insertion point) within the text (not at EOL).

      // Expression 1 test.
      const expression1 = 'myApplication.name + ch + controller.clear()';
      int caret1 = expression1.indexOf('ch + ');
      expect(caret1 >= 0, isTrue);
      caret1 += 2; // Caret after ch

      parts = testEdit(expression1, caret1);
      outputResult(1, parts);
      expect(parts.activeWord, 'ch');
      expect(parts.leftSide, 'myApplication.name + ');
      expect(parts.rightSide, ' + controller.clear()');
      expect(parts.isField, isFalse);

      // Expression 2 test.
      const expression2 = 'myApplication.name + chart.tra + controller.clear()';
      int caret2 = expression2.indexOf('tra + ');
      expect(caret2 >= 0, isTrue);
      caret2 += 3; // Caret after tra

      parts = testEdit(expression2, caret2);
      outputResult(2, parts);
      expect(parts.activeWord, 'tra');
      expect(parts.leftSide, 'myApplication.name + chart.');
      expect(parts.rightSide, ' + controller.clear()');
      expect(parts.isField, isTrue);
    });
  });
}
