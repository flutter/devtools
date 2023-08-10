// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Contains all data relevant to a deep link.
class LinkData {
  LinkData({
    required this.os,
    required this.domain,
    required this.paths,
    this.scheme = 'Http://, Https://',
    this.domainError = false,
    this.pathError = false,
  });

  final String os;
  final List<String> paths;
  final String domain;
  final String scheme;
  final bool domainError;
  final bool pathError;

  String get searchLabel => (os + paths.join() + domain + scheme).toLowerCase();

  LinkData mergeByDomain(LinkData? linkData) {
    if (linkData == null) {
      return this;
    }

    return LinkData(
      os: os,
      domain: domain,
      paths: [...paths, ...linkData.paths],
      domainError: domainError || linkData.domainError,
    );
  }
}
