// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const String shallowSizeColumnTooltip =
    'Total shallow size of all of the instances.\n'
    'Shallow size of an object is the size of this object\n'
    'plus the references it holds to other Dart objects\n'
    "in its fields (this doesn't include the size of\n"
    'the fields - just the size of the references).';

const String retainedSizeColumnTooltip =
    'Total shallow Dart size of objects plus shallow Dart size of objects they retain,\n'
    'taking into account only the shortest retaining path for the referenced objects.';

const String nonGcableInstancesColumnTooltip =
    'Number of instances of the class\n'
    'that have a retaining path from the root\n'
    'and therefore can’t be garbage collected.';
