// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print, avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

/// A script to search for PRs in `flutter/devtools`.
///
/// Usage:
///   `dart search_prs.dart <query> [--limit <count>] [--state <open|closed|merged|all>]`
void main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    print('''
Usage:
  dart search_prs.dart <query> [--limit <count>] [--state <open|closed|merged|all>]

Options:
  --limit <number>    Maximum number of PRs to return (default: 20)
  --state <state>     Filter by state: open, closed, merged, all (default: all)
  --repo <owner/repo> GitHub repository (default: flutter/devtools)
  -h, --help          Show this help message
''');
    return;
  }

  String repo = 'flutter/devtools';
  int limit = 20;
  String? state;
  final queryTerms = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--limit' && i + 1 < args.length) {
      limit = int.tryParse(args[++i]) ?? 20;
    } else if (arg == '--state' && i + 1 < args.length) {
      state = args[++i];
    } else if (arg == '--repo' && i + 1 < args.length) {
      repo = args[++i];
    } else {
      queryTerms.add(arg);
    }
  }

  var query = queryTerms.join(' ');
  if (state != null) {
    query += ' state:$state';
  }

  print('--- SEARCHING PRs IN $repo FOR: $query ---\n');

  final result = await Process.run('gh', [
    'search',
    'prs',
    query,
    '--repo',
    repo,
    '--limit',
    limit.toString(),
    '--json',
    'number,title,state,url,createdAt,closedAt',
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Error searching PRs: ${result.stderr}');
    exitCode = 1;
    return;
  }

  final prs = (jsonDecode(result.stdout as String) as List)
      .cast<Map<String, dynamic>>();

  if (prs.isEmpty) {
    print('No PRs found matching query.');
    return;
  }

  for (final pr in prs) {
    final number = pr['number'];
    final title = pr['title'] ?? '';
    final prState = pr['state'] ?? '';
    final url = pr['url'] ?? '';
    final createdAt = pr['createdAt'] ?? '';
    print('#$number $title ($prState)');
    print('Url: $url');
    print('Created: $createdAt');
    print('-' * 60);
  }
}
