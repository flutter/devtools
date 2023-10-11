// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class FooBarBaz extends StatelessWidget {
  const FooBarBaz({super.key, this.onFoo, this.onBar, this.onBaz});

  final VoidCallback? onFoo;
  final VoidCallback? onBar;
  final VoidCallback? onBaz;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton(
            onPressed: onFoo,
            child: const Text('Foo'),
          ),
          TextButton(
            onPressed: onBar,
            child: const Text('Bar'),
          ),
          TextButton(
            onPressed: onBaz,
            child: const Text('Baz'),
          ),
        ],
      ),
    );
  }
}
