// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const nonGcableInstancesColumnTooltip = 'Number of instances of the class,\n'
    'that are reachable, i.e. have a retaining path from the root\n'
    "and therefore can't be garbage collected.";

/// When to have verbose Dropdown based on media width.
const memoryControlsMinVerboseWidth = 240.0;

enum SizeType {
  shallow(
    displayName: 'Shallow',
    description: 'The total shallow size of all of the instances.\n'
        'The shallow size of an object is the size of the object\n'
        'plus the references it holds to other Dart objects\n'
        "in its fields (this doesn't include the size of\n"
        'the fields - just the size of the references).',
  ),
  retained(
    displayName: 'Retained',
    description:
        'Total shallow Dart size of objects plus shallow Dart size of objects they retain,\n'
        'taking into account only the shortest retaining path for the referenced objects.',
  ),
  ;

  const SizeType({required this.displayName, required this.description});

  final String displayName;
  final String description;
}
