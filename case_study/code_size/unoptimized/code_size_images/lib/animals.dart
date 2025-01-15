// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'package:flutter/material.dart';

class Animals extends StatelessWidget {
  const Animals({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      itemExtent: 75.0,
      children: _buildListItems(),
    );
  }

  List<Widget> _buildListItems() {
    final items = <Widget>[];
    for (int i = 1; i <= 1000; i++) {
      final asset = _assets[i % (_assets.length - 1)];
      items.add(_buildListItem(asset));
    }
    return items;
  }

  Widget _buildListItem(String assetName) {
    final title = assetName.split('.').first.split('/').last;
    return ListTile(
      leading: Image.asset(
        assetName,
        height: 48.0,
        width: 48.0,
        fit: BoxFit.fill,
      ),
      title: Text(title),
      subtitle: Text('This is a $title. It is neat.'),
    );
  }
}

final _assets = [
  'assets/buck.jpeg',
  'assets/dog.jpeg',
  'assets/flamingo.jpeg',
  'assets/fox.jpeg',
  'assets/gorilla.jpeg',
  'assets/horse.jpeg',
  'assets/husky.jpeg',
  'assets/kangaroo.jpeg',
  'assets/lion.jpeg',
  'assets/parrot.jpeg',
  'assets/puppy.jpeg',
  'assets/rooster.jpeg',
  'assets/white_tiger.jpeg',
  'assets/yak.jpeg',
  'assets/zebra.jpeg',
];
