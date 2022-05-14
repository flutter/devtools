// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const testAllocationData = r'''
{"allocations": {"version": 1, "dartDevToolsScreen": "memory", "data": [
  {"class": {"fixedId": true, "id": "classes/1", "name": "AClass"}, "bytesCurrent": 10000, "bytesDelta": 100, "instancesCurrent": 10, "instancesDelta": 10, "isStackedTraced": true},
  {"class": {"fixedId": true, "id": "classes/2", "name": "BClass"}, "bytesCurrent": 20000, "bytesDelta": 200, "instancesCurrent": 20, "instancesDelta": 20, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/3", "name": "CClass"}, "bytesCurrent": 30000, "bytesDelta": 300, "instancesCurrent": 30, "instancesDelta": 30, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/4", "name": "DClass"}, "bytesCurrent": 40000, "bytesDelta": 400, "instancesCurrent": 40, "instancesDelta": 40, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/5", "name": "EClass"}, "bytesCurrent": 50000, "bytesDelta": 500, "instancesCurrent": 50, "instancesDelta": 50, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/6", "name": "FClass"}, "bytesCurrent": 60000, "bytesDelta": 600, "instancesCurrent": 60, "instancesDelta": 60, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/7", "name": "GClass"}, "bytesCurrent": 70000, "bytesDelta": 700, "instancesCurrent": 70, "instancesDelta": 70, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/8", "name": "HClass"}, "bytesCurrent": 80000, "bytesDelta": 800, "instancesCurrent": 80, "instancesDelta": 80, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/9", "name": "IClass"}, "bytesCurrent": 90000, "bytesDelta": 900, "instancesCurrent": 90, "instancesDelta": 90, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/10", "name": "JClass"}, "bytesCurrent": 100000, "bytesDelta": 1000, "instancesCurrent": 5, "instancesDelta": 2, "isStackedTraced": true},
  {"class": {"fixedId": true, "id": "classes/11", "name": "KClass"}, "bytesCurrent": 1111, "bytesDelta": 11, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/12", "name": "LClass"}, "bytesCurrent": 2222, "bytesDelta": 22, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/13", "name": "MClass"}, "bytesCurrent": 3333, "bytesDelta": 33, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/14", "name": "NClass"}, "bytesCurrent": 4444, "bytesDelta": 44, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/15", "name": "OClass"}, "bytesCurrent": 5555, "bytesDelta": 55, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/16", "name": "PClass"}, "bytesCurrent": 6666, "bytesDelta": 66, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/17", "name": "QClass"}, "bytesCurrent": 7777, "bytesDelta": 77, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/18", "name": "RClass"}, "bytesCurrent": 8888, "bytesDelta": 99, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/19", "name": "SClass"}, "bytesCurrent": 9999, "bytesDelta": 99, "instancesCurrent": 50, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/20", "name": "TClass"}, "bytesCurrent": 10, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 1, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/21", "name": "UClass"}, "bytesCurrent": 20, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 2, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/22", "name": "VClass"}, "bytesCurrent": 30, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 3, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/23", "name": "WClass"}, "bytesCurrent": 40, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 5, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/24", "name": "XClass"}, "bytesCurrent": 50, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 1, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/24", "name": "YClass"}, "bytesCurrent": 60, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 2, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/24", "name": "ZClass"}, "bytesCurrent": 70, "bytesDelta": 0, "instancesCurrent": 5, "instancesDelta": 3, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/27", "name": "AnotherClass"}, "bytesCurrent": 88, "bytesDelta": 0, "instancesCurrent": 55, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/28", "name": "OneMoreClass"}, "bytesCurrent": 91, "bytesDelta": 0, "instancesCurrent": 55, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/28", "name": "SecondClass"}, "bytesCurrent": 99, "bytesDelta": 0, "instancesCurrent": 55, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/29", "name": "OneClass"}, "bytesCurrent": 111, "bytesDelta": 0, "instancesCurrent": 55, "instancesDelta": 0, "isStackedTraced": false},
  {"class": {"fixedId": true, "id": "classes/30", "name": "LastClass"}, "bytesCurrent": 222, "bytesDelta": 0, "instancesCurrent": 55, "instancesDelta": 0, "isStackedTraced": false}
]
}}
''';
