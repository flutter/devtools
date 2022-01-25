// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/analytics_common.dart';
import 'package:devtools_app/src/shared/survey.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevToolsSurvey', () {
    test('parse constructor succeeds', () {
      final survey = DevToolsSurvey.parse({
        '_comments': [
          'uniqueId must be updated with each new survey so DevTools knows to re-prompt users.',
          'title should not exceed 45 characters.',
          'startDate and endDate should follow ISO 8601 standard with a timezone offset.'
        ],
        'uniqueId': '2020Q4',
        'title': 'Help improve DevTools! Take our Q4 survey.',
        'url': 'https://google.qualtrics.com/jfe/form/SV_9XDmbo8lhv0VaUl',
        'startDate': '2020-10-30T09:00:00-07:00',
        'endDate': '2020-11-30T09:00:00-07:00',
      });
      expect(survey.id, equals('2020Q4'));
      expect(survey.startDate, equals(DateTime.utc(2020, 10, 30, 16)));
      expect(survey.endDate, equals(DateTime.utc(2020, 11, 30, 16)));
      expect(
          survey.title, equals('Help improve DevTools! Take our Q4 survey.'));
      expect(survey.url,
          'https://google.qualtrics.com/jfe/form/SV_9XDmbo8lhv0VaUl');

      final emptySurvey = DevToolsSurvey.parse({});
      expect(emptySurvey.id, isNull);
      expect(emptySurvey.startDate, isNull);
      expect(emptySurvey.endDate, isNull);
      expect(emptySurvey.title, isNull);
      expect(emptySurvey.url, isNull);
    });

    group('parses the current page', () {
      test('from the path', () {
        final page =
            extractCurrentPageFromUrl('http://localhost:9000/inspector?uri=x');
        expect(page, 'inspector');
      });

      test('from the query string', () {
        final page = extractCurrentPageFromUrl(
            'http://localhost:9000/?uri=x&page=inspector&theme=dark');
        expect(page, 'inspector');
      });

      test('from the path even if query string is populated', () {
        final page = extractCurrentPageFromUrl(
            'http://localhost:9000/memory?uri=x&page=inspector&theme=dark');
        expect(page, 'memory');
      });
    });
  });
}
