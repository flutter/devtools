// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' as developer;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(
        title: 'Flutter Memory Case Study #1',
      ),
      // showPerformanceOverlay: true,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.title = ""});

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

int globalObjectId = 0;

class ObjectWithUniqueId {
  ObjectWithUniqueId()
      : now = DateTime.now(),
        uniqueId = globalObjectId++;

  DateTime now = DateTime.now();
  int uniqueId = globalObjectId++;

  @override
  String toString() => 'Collected @ $now, id=$uniqueId';
}

class MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List tabs = ['1', '2', '3'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  final objects = <ObjectWithUniqueId>[];

  void devToolsPostEvent(String eventName, Map<String, Object> eventData) {
    developer.postEvent('DevTools.Event_$eventName', eventData);

    objects.add(ObjectWithUniqueId());
  }

  Widget recordLoadedImage(ImageChunkEvent imageChunkEvent, String imageUrl) {
    devToolsPostEvent('MyFirstApp', {
      'method': 'recordLoadedImage',
      'param': imageUrl,
    });

    // if (imageChunkEvent == null) return null;

    final recordLoading = loadedImages.putIfAbsent(imageUrl, () {
      developer.log(
        'Start loading total: ${imageChunkEvent.expectedTotalBytes},'
        ' chunk: ${imageChunkEvent.cumulativeBytesLoaded}'
        ' image: $imageUrl',
      );
      return imageChunkEvent;
    });

    final expectedTotalBytes = recordLoading.expectedTotalBytes;
    final cumulativeBytes = recordLoading.cumulativeBytesLoaded;

    final loadingState = cumulativeBytes == expectedTotalBytes
        ? 'Loaded.'
        : 'Still Loading, $cumulativeBytes of $expectedTotalBytes bytes.';

    developer.log('$loadingState, $imageUrl');

    // Progress spinner.
    return Center(
      child: CircularProgressIndicator(
        value: expectedTotalBytes != null
            ? cumulativeBytes / expectedTotalBytes
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The build method reruns every time setState is called.
    //
    // The Flutter framework has been optimized to efficiently run the build.
    // So that only what needs updating rather than having to individually
    // change instances of widgets.
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Image Viewer'),
        actions: <Widget>[
          IconButton(
            // action button
            icon: const Icon(Icons.add),
            onPressed: () {
              _jumpNewPage();
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: listView(),
    );

    return scaffold;
  }

  Widget listView() => ListView.builder(
        itemCount: allImages.length,
        itemBuilder: (
          BuildContext context,
          int idx,
        ) {
          final imgUrl = allImages[idx];

          developer.log('Start Network Load: [$idx] $imgUrl');

          final image = Image.network(
            imgUrl,
            width: 750.0,
            height: 500,
            fit: BoxFit.fitWidth,
            loadingBuilder: (
              BuildContext context,
              Widget child,
              ImageChunkEvent? loadingProgress,
            ) {
              if (loadingProgress == null) return child;
              return recordLoadedImage(loadingProgress, imgUrl);
            },
          );

          return image;
        },
      );

  void _jumpNewPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecondScreen()),
    );
  }
}

class SecondScreen extends MyHomePage {
  const SecondScreen({super.key});
}

// Loaded images. key is ImageUrl and value is the ImageChunkEvent (total and cumulative bytes loaded).
final loadedImages = <String, ImageChunkEvent>{};

List<String> allImages = [
  'https://www.nasa.gov/sites/default/files/images/757100main_iss036e011593_full.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e010102.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e012660.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss059e072286.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e010136.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e010586.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e010616.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e010583.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e009965.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e009535.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e006714.jpg',
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/iss063e006674.jpg',
  'https://images-assets.nasa.gov/image/jsc2020e016257/jsc2020e016257~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA23872/PIA23872~orig.jpg',
  'https://images-assets.nasa.gov/image/S67-50903/S67-50903~orig.jpg',
  'https://images-assets.nasa.gov/image/as17-152-23392/as17-152-23392~orig.jpg',
  'https://images-assets.nasa.gov/image/6900556/6900556~orig.jpg',
  'https://images-assets.nasa.gov/image/as10-34-5026/as10-34-5026~orig.jpg',
  'https://images-assets.nasa.gov/image/0201587/0201587~orig.jpg',
  'https://images-assets.nasa.gov/image/9802675/9802675~orig.jpg',
  'https://images-assets.nasa.gov/image/NM21-396-024/NM21-396-024~orig.jpg',
  'https://images-assets.nasa.gov/image/sts119-s-005/sts119-s-005~orig.jpg',
  'https://images-assets.nasa.gov/image/9258803/9258803~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA03343/PIA03343~orig.jpg',
  'https://images-assets.nasa.gov/image/41G-121-099/41G-121-099~orig.jpg',
  'https://images-assets.nasa.gov/image/sts066-63-006/sts066-63-006~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA02708/PIA02708~orig.jpg',
  'https://images-assets.nasa.gov/image/9261132/9261132~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA09113/PIA09113~orig.jpg',
  'https://images-assets.nasa.gov/image/S65-63189/S65-63189~orig.jpg',
  'https://images-assets.nasa.gov/image/S65-34635/S65-34635~orig.jpg',

  // Hubble:
  'https://www.nasa.gov/sites/default/files/styles/full_width_feature/public/thumbnails/image/redspot.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/s109e5101.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/sts103_731_051.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/s82e5718.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/s103e5031.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/sa2.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/solarpanels_unfold.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/s82e5147.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/hubble_orbit_large.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/ann0813.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1809a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0613a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0612d.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo1535a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0720a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo1207a.jpg',

  // Space Telescope
  'https://cdn.spacetelescope.org/archives/images/wallpaper2/heic1815a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo0220a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1708a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1814b.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1814a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo0124a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1613a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1914b.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic2008b.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1904a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo0745a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo9818a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1715a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0515a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1501a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0503a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1310a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic1518a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/potw1020a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo9607a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/potw1720a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/sts103s006.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/hst_launch_hi.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/heic0506a.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/opo0510b.jpg',
  'https://cdn.spacetelescope.org/archives/images/screen/main_mirror.jpg',

  // Big images:
  'https://images-assets.nasa.gov/image/KSC-20200515-PH-KLS01_0122/KSC-20200515-PH-KLS01_0122~orig.jpg',
  'https://images-assets.nasa.gov/image/iss063e010159/iss063e010159~orig.jpg',
  'https://images-assets.nasa.gov/image/S69-27915/S69-27915~orig.jpg',
  'https://images-assets.nasa.gov/image/7995383/7995383~orig.jpg',
  'https://images-assets.nasa.gov/image/as14-67-09369/as14-67-09369~orig.jpg',
  'https://images-assets.nasa.gov/image/as09-24-3657/as09-24-3657~orig.jpg',
  'https://images-assets.nasa.gov/image/as09-24-3657/as09-24-3657~orig.jpg',
  'https://images-assets.nasa.gov/image/9312448/9312448~orig.jpg',
  'https://images-assets.nasa.gov/image/as12-48-7034/as12-48-7034~orig.jpg',
  'https://images-assets.nasa.gov/image/0600896/0600896~orig.jpg',
  'https://images-assets.nasa.gov/image/S69-31741/S69-31741~orig.jpg',
  'https://images-assets.nasa.gov/image/as09-24-3641/as09-24-3641~orig.jpg',
  'https://images-assets.nasa.gov/image/6901208/6901208~orig.jpg',
  'https://images-assets.nasa.gov/image/6862616/6862616~orig.jpg',
  'https://images-assets.nasa.gov/image/9407054/9407054~orig.jpg',
  'https://images-assets.nasa.gov/image/8909250/8909250~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA03388/PIA03388~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA03377/PIA03377~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA03393/PIA03393~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA03395/PIA03395~orig.jpg',
  'https://images-assets.nasa.gov/image/ECN-24314/ECN-24314~orig.jpg',
  'https://images-assets.nasa.gov/image/ARC-1981-AC81-0083-2/ARC-1981-AC81-0083-2~orig.jpg',
  'https://images-assets.nasa.gov/image/8898508/8898508~orig.jpg',
  'https://images-assets.nasa.gov/image/PIA06667/PIA06667~orig.jpg',
  'https://images-assets.nasa.gov/image/9515816/9515816~orig.jpg',
  'https://www.nasa.gov/sites/default/files/thumbnails/image/stsci-h-p2016a-m-2000x1374.png',
];
