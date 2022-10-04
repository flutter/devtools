// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/utils.dart';

/// When to have verbose Dropdown based on media width.
const verboseDropDownMinimumWidth = 950;

const legendXOffset = 20;
const legendYOffset = 7.0;
double get legendWidth => scaleByFontFactor(200.0);
double get legendTextWidth => scaleByFontFactor(55.0);
double get legendHeight1Chart => scaleByFontFactor(200.0);
double get legendHeight2Charts => scaleByFontFactor(323.0);

const memorySourceMenuItemPrefix = 'Source: ';
final legendKey = GlobalKey(debugLabel: 'Legend Button');
const sourcesDropdownKey = Key('Sources Dropdown');
const sourcesKey = Key('Sources');

/// Padding for each title in the legend.
const legendTitlePadding = EdgeInsets.fromLTRB(5, 0, 0, 4);
