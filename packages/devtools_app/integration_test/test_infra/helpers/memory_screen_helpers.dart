// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Prepares the UI of the memory screen so that the eval-related elements are
/// visible on the screen for testing.
// Future<void> prepareMemoryUI() async {
//   // Open memory screen.
//   await switchToScreen(
//     tester,
//     tabIcon: ScreenMetaData.memory.icon!,
//     screenId: ScreenMetaData.memory.id,
//   );

//   // Close warning and chart to get screen space.
//   await tapAndPump(
//     find.descendant(
//       of: find.byType(BannerWarning),
//       matching: find.byIcon(Icons.close),
//     ),
//   );
//   await tapAndPump(find.text(PrimaryControls.memoryChartText));

//   // Make console wider.
//   // The distance is big enough to see more items in console,
//   // but not too big to make classes in snapshot hidden.
//   const dragDistance = -320.0;
//   await tester.drag(
//     find.byType(ConsolePaneHeader),
//     const Offset(0, dragDistance),
//   );
//   await tester.pumpAndSettle();
// }
