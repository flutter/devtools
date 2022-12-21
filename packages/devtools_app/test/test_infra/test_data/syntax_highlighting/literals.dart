// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const a = 'aaaaa';

const list1 = [];
const list2 = <String>[];
const list3 = ['', '$a'];
const list4 = <String>['', '$a'];

const set1 = {};
const set2 = <String>{};
const set3 = {'', '$a'};
const set4 = <String>{'', '$a'};

const map1 = <String, String>{};
const map2 = {'': '$a'};
const map3 = <String, String>{'': '$a'};
