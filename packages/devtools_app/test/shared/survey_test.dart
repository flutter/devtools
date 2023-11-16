// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/survey.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurveyService', () {
    test('can fetch survey metadata', () async {
      final survey = await SurveyService().fetchSurveyContent();
      expect(survey, isNotNull);
    });
  });

  group('DevToolsSurvey', () {
    test('parse constructor succeeds', () {
      final survey = DevToolsSurvey.parse({
        '_comments': [
          'uniqueId must be updated with each new survey so DevTools knows to re-prompt users.',
          'title should not exceed 45 characters.',
          'startDate and endDate should follow ISO 8601 standard with a timezone offset.',
        ],
        'uniqueId': '2020Q4',
        'title': 'Help improve DevTools! Take our Q4 survey.',
        'url': 'https://google.qualtrics.com/jfe/form/SV_9XDmbo8lhv0VaUl',
        'startDate': '2020-10-30T09:00:00-07:00',
        'endDate': '2020-11-30T09:00:00-07:00',
        'minDevToolsVersion': '2.29.0',
        'environments': ['VSCode'],
      });
      expect(survey.id, equals('2020Q4'));
      expect(survey.startDate, equals(DateTime.utc(2020, 10, 30, 16)));
      expect(survey.endDate, equals(DateTime.utc(2020, 11, 30, 16)));
      expect(
        survey.title,
        equals('Help improve DevTools! Take our Q4 survey.'),
      );
      expect(
        survey.url,
        'https://google.qualtrics.com/jfe/form/SV_9XDmbo8lhv0VaUl',
      );
      expect(survey.minDevToolsVersion.toString(), '2.29.0');
      expect(survey.environments, ['VSCode']);

      final emptySurvey = DevToolsSurvey.parse({});
      expect(emptySurvey.id, isNull);
      expect(emptySurvey.startDate, isNull);
      expect(emptySurvey.endDate, isNull);
      expect(emptySurvey.title, isNull);
      expect(emptySurvey.url, isNull);
      expect(emptySurvey.minDevToolsVersion, isNull);
      expect(emptySurvey.environments, isNull);
    });

    group('should show', () {
      test('empty survey', () {
        final emptySurvey = DevToolsSurvey.parse({});

        withClock(Clock.fixed(DateTime(2023, 11, 7)), () {
          expect(emptySurvey.meetsDateRequirement, isFalse);
        });
        withClock(Clock.fixed(DateTime(2023, 11, 15)), () {
          expect(emptySurvey.meetsDateRequirement, isFalse);
        });
        expect(emptySurvey.meetsMinVersionRequirement, isTrue);
        expect(emptySurvey.meetsEnvironmentRequirement, isTrue);
        expect(emptySurvey.shouldShow, isFalse);
      });

      test('real survey', () {
        final survey = DevToolsSurvey.parse({
          '_comments': [
            'uniqueId must be updated with each new survey so DevTools knows to re-prompt users.',
            'title should not exceed 45 characters.',
            'startDate and endDate should follow ISO 8601 standard with a timezone offset.',
          ],
          'uniqueId': '2020Q4',
          'title': 'Help improve DevTools! Take our Q4 survey.',
          'url': 'https://google.qualtrics.com/jfe/form/SV_9XDmbo8lhv0VaUl',
          'startDate': '2023-10-30T09:00:00-07:00',
          'endDate': '2023-11-14T09:00:00-07:00',
          'minDevToolsVersion': '2.29.0',
          'environments': ['VSCode'],
        });

        ideLaunched = 'VSCode';
        withClock(Clock.fixed(DateTime(2023, 11, 7)), () {
          expect(survey.shouldShow, isTrue);
        });
      });

      test('meetsDateRequirement', () {
        final survey = DevToolsSurvey.parse({
          'startDate': '2023-10-30T09:00:00-07:00',
          'endDate': '2023-11-14T09:00:00-07:00',
        });

        withClock(Clock.fixed(DateTime(2023, 11, 7)), () {
          expect(survey.meetsDateRequirement, isTrue);
        });
        withClock(Clock.fixed(DateTime(2023, 11, 15)), () {
          expect(survey.meetsDateRequirement, isFalse);
        });
      });

      test('meetsMinVersionRequirement', () {
        var survey = DevToolsSurvey.parse({'minDevToolsVersion': '2.25.0'});
        expect(survey.meetsMinVersionRequirement, isTrue);

        survey = DevToolsSurvey.parse({'minDevToolsVersion': '5.25.0'});
        expect(survey.meetsMinVersionRequirement, isFalse);
      });

      test('meetsEnvironmentRequirement', () {
        final vsCodeOnlySurvey = DevToolsSurvey.parse({
          'environments': ['VSCode'],
        });
        final intelliJSurvey = DevToolsSurvey.parse({
          'environments': ['Android-Studio', 'IntelliJ-IDEA'],
        });

        ideLaunched = 'Android-Studio';
        expect(vsCodeOnlySurvey.meetsEnvironmentRequirement, isFalse);
        expect(intelliJSurvey.meetsEnvironmentRequirement, isTrue);

        ideLaunched = 'IntelliJ-IDEA';
        expect(vsCodeOnlySurvey.meetsEnvironmentRequirement, isFalse);
        expect(intelliJSurvey.meetsEnvironmentRequirement, isTrue);

        ideLaunched = 'VSCode';
        expect(vsCodeOnlySurvey.meetsEnvironmentRequirement, isTrue);
        expect(intelliJSurvey.meetsEnvironmentRequirement, isFalse);
      });
    });
  });
}
