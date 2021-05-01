import 'package:devtools_app/src/ui/search.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  group('AutoComplete', () {
    setUp(() {
      // TODO: add code to run before each test
    });

    test('activeEditing', () {
      EditingParts testEdit(
        String editing, [
        bool subExpression = true,
      ]) {
        final length = editing.length;
        return AutoCompleteSearchControllerMixin.activeEdtingParts(
          editing,
          TextSelection(baseOffset: length, extentOffset: length),
          handleFields: true,
          computeSubExpression: subExpression,
        );
      }

      // Set debug to true displays editing parts.
      const debug = false;

      void outputResult(int num, EditingParts editingParts) {
        if (debug) {
          print('$num. left=${editingParts.leftSide}, '
              'active=${editingParts.activeWord}');
        }
      }

      // Test for various types of auto-complete (tracking) used for expression evaluator.
      EditingParts parts = testEdit('baseO');
      outputResult(0, parts);
      expect(parts.activeWord, 'baseO');
      expect(parts.leftSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject');
      outputResult(1, parts);
      expect(parts.activeWord, 'baseObject');
      expect(parts.leftSide.isEmpty, isTrue);
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.');
      outputResult(2, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.');
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.cl');
      outputResult(3, parts);
      expect(parts.activeWord, 'cl');
      expect(parts.leftSide, 'baseObject.');
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close+');
      outputResult(4, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close+');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close+1000+');
      outputResult(5, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close+1000+');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close+1000+char');
      outputResult(6, parts);
      expect(parts.activeWord, 'char');
      expect(parts.leftSide, 'baseObject.close+1000+');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000');
      outputResult(7, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + cha');
      outputResult(8, parts);
      expect(parts.activeWord, 'cha');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart');
      outputResult(9, parts);
      expect(parts.activeWord, 'chart');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000 / 2000 + chart.');
      outputResult(10, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000 / 2000 + chart.');
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.tr');
      outputResult(11, parts);
      expect(parts.activeWord, 'tr');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.');
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close+1000/2000+chart.traces');
      outputResult(12, parts);
      expect(parts.activeWord, 'traces');
      expect(parts.leftSide, 'baseObject.close+1000/2000+chart.');
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10');
      outputResult(13, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10]');
      outputResult(14, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10]');
      expect(parts.isField, isFalse);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[10].yNa');
      outputResult(15, parts);
      expect(parts.activeWord, 'yNa');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].',
      );
      expect(parts.isField, isTrue);

      parts = testEdit('baseObject.close + 1000/2000 + chart.traces[addO');
      outputResult(16, parts);
      expect(parts.activeWord, 'addO');
      expect(parts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[');
      expect(parts.isField, isFalse);

      parts =
          testEdit('baseObject.close + 1000/2000 + chart.traces[addOne,addT');
      outputResult(17, parts);
      expect(parts.activeWord, 'addT');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]');
      outputResult(18, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].xNam');
      outputResult(19, parts);
      expect(parts.activeWord, 'xNam');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].',
      );
      expect(parts.isField, isTrue);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute');
      outputResult(20, parts);
      expect(parts.activeWord, 'compute');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + ',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()');
      outputResult(21, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()',
      );
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
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar');
      outputResult(23, parts);
      expect(parts.activeWord, 'bar');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)');
      outputResult(24, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foo');
      outputResult(25, parts);
      expect(parts.activeWord, 'foo');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + ',
      );
      expect(parts.isField, isFalse);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.');
      outputResult(26, parts);
      expect(parts.activeWord.isEmpty, isTrue);
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.',
      );
      expect(parts.isField, isTrue);

      parts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.length');
      outputResult(27, parts);
      expect(parts.activeWord, 'length');
      expect(
        parts.leftSide,
        'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.',
      );
      expect(parts.isField, isTrue);
    });
  });
}
