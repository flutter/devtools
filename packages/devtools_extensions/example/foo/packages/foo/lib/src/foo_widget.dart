// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../foo.dart';

/// This is an example widget that will be used from `app_that_uses_foo`.
class FooWidget extends StatelessWidget {
  const FooWidget({super.key, required this.fooController});

  final FooController fooController;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    return ValueListenableBuilder(
      valueListenable: fooController.things,
      builder: (context, things, _) {
        return ValueListenableBuilder(
          valueListenable: fooController.favoriteThing,
          builder: (context, favorite, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: fooController.addThing,
                      child: Text('Add thing', style: textStyle),
                    ),
                    ElevatedButton(
                      onPressed: fooController.removeThing,
                      child: Text('Remove thing', style: textStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: fooController.selectRandomFavorite,
                  child: Text('Select random favorite', style: textStyle),
                ),
                const SizedBox(height: 32.0),
                Text('Total things: ${things.length}', style: textStyle),
                const SizedBox(height: 8.0),
                Text('Favorite thing: $favorite', style: textStyle),
              ],
            );
          },
        );
      },
    );
  }
}
