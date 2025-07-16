// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:custom_widgets/custom_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    const CustomApp(
      home: HomeScreen(),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomContainer(
      color: Colors.cyanAccent,
      child: CustomCenter(
        child: CustomButton(
          onPressed: () {},
          child: const CustomText(
            'Click Me!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}