// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print, avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

/// A tool to fetch and format comprehensive details for GitHub issues in `flutter/devtools`.
///
/// Usage:
///   # Fetch specific issues:
///   dart fetch_issues.dart 4152 4072 4071
///
///   # Fetch a specific page of open issues (default 25 per page, sort:updated-desc):
///   dart fetch_issues.dart --page 31
///
///   # Fetch with custom query or limit:
///   dart fetch_issues.dart --page 31 --query "is:issue state:open sort:updated-desc"
///   dart fetch_issues.dart --query "label:bug is:open sort:created-asc" --limit 20
void main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }

  String repo = 'flutter/devtools';
  String? query;
  int? page;
  int perPage = 25;
  int? limit;
  final issueNumbers = <int>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--repo' && i + 1 < args.length) {
      repo = args[++i];
    } else if (arg == '--query' && i + 1 < args.length) {
      query = args[++i];
    } else if (arg == '--page' && i + 1 < args.length) {
      page = int.tryParse(args[++i]);
    } else if (arg == '--per-page' && i + 1 < args.length) {
      perPage = int.tryParse(args[++i]) ?? 25;
    } else if (arg == '--limit' && i + 1 < args.length) {
      limit = int.tryParse(args[++i]);
    } else if (arg.startsWith('#')) {
      final num = int.tryParse(arg.substring(1));
      if (num != null) issueNumbers.add(num);
    } else {
      final num = int.tryParse(arg);
      if (num != null) {
        issueNumbers.add(num);
      } else {
        stderr.writeln('Unrecognized argument: $arg');
        _printUsage();
        exitCode = 1;
        return;
      }
    }
  }

  if (issueNumbers.isEmpty) {
    if (page != null) {
      final defaultQuery = query ?? 'is:issue is:open sort:updated-desc';
      issueNumbers.addAll(
        await _fetchIssueNumbersForPage(
          repo: repo,
          query: defaultQuery,
          page: page,
          perPage: perPage,
        ),
      );
    } else if (query != null || limit != null) {
      final effectiveQuery = query ?? 'is:issue is:open sort:created-asc';
      final effectiveLimit = limit ?? 25;
      issueNumbers.addAll(
        await _fetchIssueNumbersForQuery(
          repo: repo,
          query: effectiveQuery,
          limit: effectiveLimit,
        ),
      );
    }
  }

  if (issueNumbers.isEmpty) {
    print('No issues found matching criteria.');
    return;
  }

  print(
    'Fetching details for ${issueNumbers.length} issues: ${issueNumbers.join(', ')}...\n',
  );

  // Fetch issue details with bounded concurrency (5 concurrent requests).
  final results = await _fetchAllIssueDetails(repo, issueNumbers);

  results.forEach(_printFormattedIssue);
}

void _printUsage() {
  print('''
Usage:
  dart fetch_issues.dart <issue_number> [<issue_number> ...]
  dart fetch_issues.dart --page <page_number> [--per-page <count>] [--query <search_query>]
  dart fetch_issues.dart --query "<search_query>" [--limit <count>]

Options:
  --repo <owner/repo>   GitHub repository (default: flutter/devtools)
  --page <number>       Page number from search results
  --per-page <number>   Number of results per page (default: 25)
  --query <string>      Search query string
  --limit <number>      Total number of issues to fetch
  -h, --help            Show this help message
''');
}

Future<List<int>> _fetchIssueNumbersForPage({
  required String repo,
  required String query,
  required int page,
  required int perPage,
}) async {
  final encodedQuery = 'repo:$repo $query';
  final result = await Process.run('gh', [
    'api',
    'search/issues?q=${Uri.encodeQueryComponent(encodedQuery)}&per_page=$perPage&page=$page',
    '--jq',
    '.items[].number',
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Error fetching issues: ${result.stderr}');
    return [];
  }

  final lines = (result.stdout as String).trim().split('\n');
  return lines.map((l) => int.tryParse(l.trim())).whereType<int>().toList();
}

Future<List<int>> _fetchIssueNumbersForQuery({
  required String repo,
  required String query,
  required int limit,
}) async {
  final result = await Process.run('gh', [
    'issue',
    'list',
    '--repo',
    repo,
    '--search',
    query,
    '--limit',
    limit.toString(),
    '--json',
    'number',
    '--jq',
    '.[].number',
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Error fetching issues: ${result.stderr}');
    return [];
  }

  final lines = (result.stdout as String).trim().split('\n');
  return lines.map((l) => int.tryParse(l.trim())).whereType<int>().toList();
}

Future<List<Map<String, dynamic>>> _fetchAllIssueDetails(
  String repo,
  List<int> numbers, {
  int concurrency = 5,
}) async {
  final results = <Map<String, dynamic>?>[];
  results.length = numbers.length;

  var index = 0;
  Future<void> worker() async {
    while (true) {
      if (index >= numbers.length) return;
      final currentIdx = index++;
      final num = numbers[currentIdx];
      results[currentIdx] = await _fetchSingleIssueDetails(repo, num);
    }
  }

  final workers = List.generate(concurrency, (_) => worker());
  await Future.wait(workers);

  return results.whereType<Map<String, dynamic>>().toList();
}

Future<Map<String, dynamic>?> _fetchSingleIssueDetails(
  String repo,
  int number,
) async {
  final result = await Process.run('gh', [
    'issue',
    'view',
    number.toString(),
    '--repo',
    repo,
    '--json',
    'number,title,author,createdAt,updatedAt,labels,body,comments,state,url',
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Error fetching issue #$number: ${result.stderr}');
    return null;
  }

  try {
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Error parsing JSON for issue #$number: $e');
    return null;
  }
}

void _printFormattedIssue(Map<String, dynamic> data) {
  final number = data['number'];
  final title = data['title'] ?? '';
  final author = data['author']?['login'] ?? 'unknown';
  final createdAt = data['createdAt'] ?? '';
  final state = data['state'] ?? '';
  final url =
      data['url'] ?? 'https://github.com/flutter/devtools/issues/$number';
  final labels = (data['labels'] as List? ?? [])
      .map((l) => l['name'] as String)
      .toList();
  final body = (data['body'] as String? ?? '').trim();
  final comments = data['comments'] as List? ?? [];

  print('=' * 70);
  print('ISSUE #$number: $title');
  print('URL: $url');
  print('Author: $author | Created: $createdAt | State: $state');
  print('Labels: $labels');
  print('\n--- BODY ---');
  if (body.isEmpty) {
    print('(No description provided)');
  } else if (body.length > 1000) {
    print('${body.substring(0, 1000)}\n... (truncated)');
  } else {
    print(body);
  }

  print('\n--- COMMENTS (${comments.length}) ---');
  if (comments.isEmpty) {
    print('(No comments)');
  } else {
    for (final c in comments) {
      final cAuthor = c['author']?['login'] ?? 'unknown';
      final cDate = c['createdAt'] ?? '';
      final cBody = (c['body'] as String? ?? '')
          .replaceAll('\r\n', '\n')
          .trim();
      final preview = cBody.length > 300
          ? '${cBody.substring(0, 300)}...'
          : cBody;
      final formattedPreview = preview.replaceAll('\n', '\n    ');
      print('  [$cAuthor at $cDate]:\n    $formattedPreview');
    }
  }
  print('');
}
