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

      // Set debug to true to debug results.
      const debug = false;

      void outputResult(int num, EditingParts parts) {
        if (debug) {
          print('$num. left=${parts.leftSide}, active=${parts.activeWord}');
        }
      }

      // Test for various types of auto-complete (tracking) used for expression evaluator.
      EditingParts editingParts = testEdit('baseO');
      outputResult(0, editingParts);
      expect(editingParts.activeWord, 'baseO');
      expect(editingParts.leftSide.isEmpty, isTrue);
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject');
      outputResult(1, editingParts);
      expect(editingParts.activeWord, 'baseObject');
      expect(editingParts.leftSide.isEmpty, isTrue);
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.');
      outputResult(2, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit('baseObject.cl');
      outputResult(3, editingParts);
      expect(editingParts.activeWord, 'cl');
      expect(editingParts.leftSide, 'baseObject.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit('baseObject.close+');
      outputResult(4, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close+');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close+1000+');
      outputResult(5, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close+1000+');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close+1000+char');
      outputResult(6, editingParts);
      expect(editingParts.activeWord, 'char');
      expect(editingParts.leftSide, 'baseObject.close+1000+');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close + 1000');
      outputResult(7, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close + 1000/2000 + cha');
      outputResult(8, editingParts);
      expect(editingParts.activeWord, 'cha');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close + 1000/2000 + chart');
      outputResult(9, editingParts);
      expect(editingParts.activeWord, 'chart');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + ');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit('baseObject.close + 1000 / 2000 + chart.');
      outputResult(10, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000 / 2000 + chart.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit('baseObject.close + 1000/2000 + chart.tr');
      outputResult(11, editingParts);
      expect(editingParts.activeWord, 'tr');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit('baseObject.close+1000/2000+chart.traces');
      outputResult(12, editingParts);
      expect(editingParts.activeWord, 'traces');
      expect(editingParts.leftSide, 'baseObject.close+1000/2000+chart.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit('baseObject.close + 1000/2000 + chart.traces[10');
      outputResult(13, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10');
      expect(editingParts.isField, isFalse);

      editingParts =
          testEdit('baseObject.close + 1000/2000 + chart.traces[10]');
      outputResult(14, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10]');
      expect(editingParts.isField, isFalse);

      editingParts =
          testEdit('baseObject.close + 1000/2000 + chart.traces[10].yNa');
      outputResult(15, editingParts);
      expect(editingParts.activeWord, 'yNa');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].');
      expect(editingParts.isField, isTrue);

      editingParts =
          testEdit('baseObject.close + 1000/2000 + chart.traces[addO');
      outputResult(16, editingParts);
      expect(editingParts.activeWord, 'addO');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[');
      expect(editingParts.isField, isFalse);

      editingParts =
          testEdit('baseObject.close + 1000/2000 + chart.traces[addOne,addT');
      outputResult(17, editingParts);
      expect(editingParts.activeWord, 'addT');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[addOne,');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]');
      outputResult(18, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo]');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].xNam');
      outputResult(19, editingParts);
      expect(editingParts.activeWord, 'xNam');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[addOne,addTwo].');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute');
      outputResult(20, editingParts);
      expect(editingParts.activeWord, 'compute');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + ');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()');
      outputResult(21, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute()');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo');
      outputResult(22, editingParts);
      expect(editingParts.activeWord, 'foo');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar');
      outputResult(23, editingParts);
      expect(editingParts.activeWord, 'bar');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)');
      outputResult(24, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute(foo,bar)');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foo');
      outputResult(25, editingParts);
      expect(editingParts.activeWord, 'foo');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + ');
      expect(editingParts.isField, isFalse);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.');
      outputResult(26, editingParts);
      expect(editingParts.activeWord.isEmpty, isTrue);
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.');
      expect(editingParts.isField, isTrue);

      editingParts = testEdit(
          'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.length');
      outputResult(27, editingParts);
      expect(editingParts.activeWord, 'length');
      expect(editingParts.leftSide, 'baseObject.close + 1000/2000 + chart.traces[10].yName + compute() + foobar.');
      expect(editingParts.isField, isTrue);
    });
  });
}
