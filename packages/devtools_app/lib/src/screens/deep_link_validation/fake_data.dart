// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'deep_links_model.dart';

/// Fake data for demo usage. Will replece this file with real deep link data.
const paths = <String>[
  '/shoes/..*',
  '/Clothes/..*',
  '/Toys/..*',
  '/Jewelry/..*',
  '/Watches/..* ',
  '/Glasses/..*',
];

final allLinkDatas = <LinkData>[
  for (var path in paths)
    LinkData(
      os: [PlatformOS.android, PlatformOS.ios],
      domain: 'm.shopping.com',
      path: path,
      domainError: true,
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: [PlatformOS.ios],
      domain: 'm.french.shopping.com',
      path: path,
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: [PlatformOS.android],
      domain: 'm.chinese.shopping.com',
      path: path,
      pathError: path.contains('shoe'),
    ),
];
