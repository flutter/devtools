// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

void main(List<String> args) {
  if (args.length < 3) {
    print('Usage: dart add_note.dart <section> <note> <pr_number>');
    exit(1);
  }

  final section = args[0].trim();
  final note = args[1].trim();
  final pr = args[2].trim();

  final prLink = pr == 'TODO' 
      ? '[TODO](https://github.com/flutter/devtools/pull/TODO)'
      : '[#$pr](https://github.com/flutter/devtools/pull/$pr)';

  final filePath = 'packages/devtools_app/release_notes/NEXT_RELEASE_NOTES.md';
  final file = File(filePath);

  if (!file.existsSync()) {
    print('Error: $filePath not found.');
    exit(1);
  }

  var content = file.readAsStringSync();

  if (!content.contains('## $section')) {
    print("Error: Section '$section' not found.");
    exit(1);
  }

  final noteWithPeriod = note.endsWith('.') ? note : '$note.';
  final newEntry = '- $noteWithPeriod $prLink\n';

  // Check for TODO placeholder.
  const todoText = 'TODO: Remove this section if there are not any updates.';
  final todoPattern = RegExp(
    '## ${RegExp.escape(section)}\\s*\\n\\s*${RegExp.escape(todoText)}\\s*\\n*',
  );

  if (todoPattern.hasMatch(content)) {
    content = content.replaceFirst(todoPattern, '## $section\n\n$newEntry\n');
  } else {
    // Append to existing list in the section.
    final sectionHeader = '## $section';
    final sectionStart = content.indexOf(sectionHeader);

    // Find the next section start or the end of the file.
    var nextSectionStart = content.indexOf('\n## ', sectionStart + 1);
    if (nextSectionStart == -1) {
      nextSectionStart =
          content.indexOf('\n# Full commit history', sectionStart + 1);
    }
    if (nextSectionStart == -1) {
      nextSectionStart = content.length;
    }

    var sectionContent =
        content.substring(sectionStart, nextSectionStart).trimRight();
    sectionContent += '\n$newEntry';

    content =
        '${content.substring(0, sectionStart)}$sectionContent\n${content.substring(nextSectionStart).trimLeft()}';
  }

  file.writeAsStringSync(content);
  print('Successfully added note to $section.');
}
