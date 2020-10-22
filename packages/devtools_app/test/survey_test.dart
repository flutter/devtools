// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/survey.dart';
import 'package:test/test.dart';

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
  });
}
