// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/src/shared/primitives/flutter_widgets/linked_scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// This file was originally forked from package:flutter_widgets. Note that the
// source may diverge over time.

/// This test sets up two linked, side-by-side [ListView]s, one with letter
/// captions and one with number captions, and verifies that they stay in sync
/// while scrolling.
void main() {
  group(LinkedScrollControllerGroup, () {
    testWidgets('letters drive numbers - fling', (tester) async {
      await tester.pumpWidget(const Test());
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.fling(
        find.text('Hello A'),
        const Offset(0.0, -50.0),
        10000.0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsNothing);
      expect(find.text('Hello 1'), findsNothing);
      expect(find.text('Hello E'), findsOneWidget);
      expect(find.text('Hello 5'), findsOneWidget);
      await tester.fling(
        find.text('Hello E'),
        const Offset(0.0, 50.0),
        10000.0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
    });

    testWidgets('letters drive numbers - drag', (tester) async {
      await tester.pumpWidget(const Test());
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsNothing);
      expect(find.text('Hello 4'), findsNothing);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.drag(find.text('Hello B'), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsNothing);
      expect(find.text('Hello 1'), findsNothing);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsOneWidget);
      expect(find.text('Hello 4'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.drag(find.text('Hello B'), const Offset(0.0, 300.0));
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsNothing);
      expect(find.text('Hello 4'), findsNothing);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
    });

    testWidgets('numbers drive letters - fling', (tester) async {
      await tester.pumpWidget(const Test());
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.fling(
        find.text('Hello 1'),
        const Offset(0.0, -50.0),
        10000.0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsNothing);
      expect(find.text('Hello 1'), findsNothing);
      expect(find.text('Hello E'), findsOneWidget);
      expect(find.text('Hello 5'), findsOneWidget);
      await tester.fling(
        find.text('Hello 5'),
        const Offset(0.0, 50.0),
        10000.0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
    });

    testWidgets('numbers drive letters - drag', (tester) async {
      await tester.pumpWidget(const Test());
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsNothing);
      expect(find.text('Hello 4'), findsNothing);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.drag(find.text('Hello 2'), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsNothing);
      expect(find.text('Hello 1'), findsNothing);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsOneWidget);
      expect(find.text('Hello 4'), findsOneWidget);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
      await tester.drag(find.text('Hello 2'), const Offset(0.0, 300.0));
      await tester.pumpAndSettle();
      expect(find.text('Hello A'), findsOneWidget);
      expect(find.text('Hello 1'), findsOneWidget);
      expect(find.text('Hello B'), findsOneWidget);
      expect(find.text('Hello 2'), findsOneWidget);
      expect(find.text('Hello C'), findsOneWidget);
      expect(find.text('Hello 3'), findsOneWidget);
      expect(find.text('Hello D'), findsNothing);
      expect(find.text('Hello 4'), findsNothing);
      expect(find.text('Hello E'), findsNothing);
      expect(find.text('Hello 5'), findsNothing);
    });

    testWidgets('offset throws for empty group', (tester) async {
      await tester.pumpWidget(const TestEmptyGroup());

      final state = tester.state<TestEmptyGroupState>(
        find.byType(TestEmptyGroup),
      );
      expect(() {
        state._controllers.offset;
      }, throwsAssertionError);
    });

    testWidgets('offset returns current position', (tester) async {
      await tester.pumpWidget(const Test());

      final state = tester.state<TestState>(find.byType(Test));
      expect(state._controllers.offset, equals(0.0));

      await tester.drag(find.text('Hello 2'), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(300.0));
      expect(state._controllers.offset, equals(state._letters.offset));

      await tester.drag(find.text('Hello 2'), const Offset(0.0, 300.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(0.0));
      expect(state._controllers.offset, equals(state._letters.offset));
    });

    testWidgets('onOffsetChanged fires on scroll', (tester) async {
      await tester.pumpWidget(const Test());
      final state = tester.state<TestState>(find.byType(Test));

      var onOffsetChangedCount = 0;
      void listener() {
        onOffsetChangedCount++;
      }

      state._controllers.addOffsetChangedListener(listener);

      expect(state._controllers.offset, equals(0.0));
      expect(onOffsetChangedCount, equals(0));

      await tester.drag(find.text('Hello 2'), const Offset(0.0, -1.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(1.0));
      // The count should be incremented since the scroll offset changed.
      expect(onOffsetChangedCount, equals(1));

      await tester.drag(find.text('Hello 2'), const Offset(0.0, 0.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(1.0));
      // The count should be unchanged since the scroll offset is unchanged.
      expect(onOffsetChangedCount, equals(1));

      await tester.drag(find.text('Hello 2'), const Offset(0.0, -1.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(2.0));
      // The count should be incremented since the scroll offset changed.
      expect(onOffsetChangedCount, equals(2));

      state._controllers.removeOffsetChangedListener(listener);

      await tester.drag(find.text('Hello 2'), const Offset(0.0, -1.0));
      await tester.pumpAndSettle();
      expect(state._controllers.offset, equals(3.0));
      // The count should be unchanged since we removed the listener.
      expect(onOffsetChangedCount, equals(2));
    });

    testWidgets('jumpTo jumps group to offset', (tester) async {
      await tester.pumpWidget(const Test());

      final state = tester.state<TestState>(find.byType(Test));
      expect(state._controllers.offset, equals(0.0));
      expect(state._letters.position.pixels, equals(0.0));
      expect(state._numbers.position.pixels, equals(0.0));

      state._controllers.jumpTo(50.0);

      expect(state._controllers.offset, equals(50.0));
      expect(state._letters.position.pixels, equals(50.0));
      expect(state._numbers.position.pixels, equals(50.0));
    });

    testWidgets('animateTo animates group to offset', (tester) async {
      await tester.pumpWidget(const Test());

      final state = tester.state<TestState>(find.byType(Test));
      expect(state._controllers.offset, equals(0.0));
      expect(state._letters.position.pixels, equals(0.0));
      expect(state._numbers.position.pixels, equals(0.0));

      // The call to `animateTo` needs to be unawaited because the animation is
      // handled by a [DrivenScrollActivity], which only completes when the
      // scroll activity is disposed.
      unawaited(
        state._controllers.animateTo(
          50.0,
          curve: Curves.easeInOutCubic,
          duration: const Duration(milliseconds: 200),
        ),
      );
      await tester.pumpAndSettle();

      expect(state._controllers.offset, equals(50.0));
      expect(state._letters.position.pixels, equals(50.0));
      expect(state._numbers.position.pixels, equals(50.0));
    });

    testWidgets('resetScroll moves scroll back to 0', (tester) async {
      await tester.pumpWidget(const Test());

      await tester.drag(find.text('Hello 2'), const Offset(0.0, -300.0));
      await tester.pumpAndSettle();

      final state = tester.state<TestState>(find.byType(Test));
      state._controllers.resetScroll();

      expect(state._letters.position.pixels, 0.0);
      expect(state._numbers.position.pixels, 0.0);
    });

    testWidgets('jumpTo is synced', (tester) async {
      await tester.pumpWidget(const Test());
      final state = tester.state<TestState>(find.byType(Test));

      expect(state._letters.position.pixels, 0.0);
      expect(state._numbers.position.pixels, 0.0);

      state._letters.jumpTo(100.0);

      await tester.pumpAndSettle();

      expect(state._letters.position.pixels, 100.0);
      expect(state._numbers.position.pixels, 100.0);
    });

    testWidgets('tap on another scrollable during fling stops scrolling', (
      tester,
    ) async {
      await tester.pumpWidget(const Test());
      final state = tester.state<TestState>(find.byType(Test));

      await tester.fling(find.text('Hello A'), const Offset(0.0, -50.0), 500.0);
      await tester.tap(find.text('Hello 1'));

      await tester.pumpAndSettle();

      // Position would be about 100 if the scroll were not stopped by the tap.
      expect(state._letters.position.pixels, 50.0);
      expect(state._numbers.position.pixels, 50.0);
    });
  });
}

class TestEmptyGroup extends StatefulWidget {
  const TestEmptyGroup({super.key});

  @override
  TestEmptyGroupState createState() => TestEmptyGroupState();
}

class TestEmptyGroupState extends State<TestEmptyGroup> {
  late LinkedScrollControllerGroup _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  TestState createState() => TestState();
}

class TestState extends State<Test> {
  late LinkedScrollControllerGroup _controllers;
  late ScrollController _letters;
  late ScrollController _numbers;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _letters = _controllers.addAndGet();
    _numbers = _controllers.addAndGet();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: _letters,
              children: const <Widget>[
                Tile('Hello A'),
                Tile('Hello B'),
                Tile('Hello C'),
                Tile('Hello D'),
                Tile('Hello E'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _numbers,
              children: const <Widget>[
                Tile('Hello 1'),
                Tile('Hello 2'),
                Tile('Hello 3'),
                Tile('Hello 4'),
                Tile('Hello 5'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile(this.caption, {super.key});

  final String caption;

  @override
  Widget build(BuildContext _) => Container(
    margin: const EdgeInsets.all(8.0),
    padding: const EdgeInsets.all(8.0),
    height: 250.0,
    child: Center(child: Text(caption)),
  );
}
