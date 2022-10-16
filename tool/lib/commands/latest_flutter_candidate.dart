import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:http/http.dart' as http;

const githubToken = 'githubToken';

/// Outputs the latest flutter candidate branch name.
///
/// The latest candidate branch will be the branch that matches the Flutter SDK
/// inside g3.
///
/// Sample usage:
/// ```shell
///   $dart tool/bin/repo_tool.dart latest-flutter-candidate
/// ```
class LatestFlutterCandidateCommand extends Command {
  LatestFlutterCandidateCommand() {
    argParser.addOption(
      githubToken,
      help: 'Specify the github auth token to be used for API requests.'
          ' If unspecified, this may lead to rate limit errors from the'
          ' GitHub API.',
      defaultsTo: '',
    );
  }

  @override
  String get name => 'latest-flutter-candidate';

  @override
  String get description =>
      'Outputs the most recent flutter release candidate banch';

  @override
  Future run() async {
    final authToken = (argResults?[githubToken] ?? '') as String;

    SemanticVersion latest = SemanticVersion();
    String? latestBranchName;

    final allBranchNames = <String>[];

    // TODO(kenz): consider traversing pages properly instead of using a while
    // loop.
    // See https://docs.github.com/en/rest/guides/traversing-with-pagination
    const maxPerPage = 100;
    var requestPage = 0;
    bool lastPageReceived = false;
    while (!lastPageReceived) {
      final uri = Uri.https(
        'api.github.com',
        '/repos/flutter/flutter/branches',
        {
          'per_page': '$maxPerPage',
          'page': '$requestPage',
        },
      );

      final response = await http.get(
        uri,
        headers:
            authToken.isEmpty ? null : {'authorization': 'Bearer $authToken'},
      );

      if (response.statusCode != HttpStatus.ok) {
        print('HttpStatus ${response.statusCode}: ${response.reasonPhrase}');
        return;
      }

      final List<Map<String, dynamic>> branches =
          (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();

      final branchNames =
          branches.map((branch) => branch['name']).cast<String>();
      allBranchNames.addAll(branchNames);

      final candidateBranchesNames =
          branchNames.where((name) => name.contains('candidate'));

      for (final branchName in candidateBranchesNames) {
        final semVer = semVerFromCandidateBranch(branchName);
        if (semVer != null && semVer > latest) {
          latest = semVer;
          latestBranchName = branchName;
        }
      }

      requestPage++;
      if (branches.length < maxPerPage) {
        lastPageReceived = true;
      }
    }

    if (latestBranchName == null) {
      throw Exception(
          'Something went wrong. Could not find the latest candidate branch:'
          '${allBranchNames.join('\n')}');
    } else {
      print(latestBranchName);
    }
  }
}

SemanticVersion? semVerFromCandidateBranch(String branch) {
  final candidateBranchPattern =
      RegExp(r'^flutter-([0-9]+).([0-9]+)-candidate.([0-9]+)$');

  final match = candidateBranchPattern.firstMatch(branch);
  if (match == null) {
    return null;
  }

  final x = int.parse(match.group(1)!);
  final y = int.parse(match.group(2)!);
  final z = int.parse(match.group(3)!);

  return SemanticVersion(major: x, minor: y, patch: z);
}
