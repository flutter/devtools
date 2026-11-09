// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/managers/survey.dart';
import 'package:devtools_app/src/shared/primitives/query_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    fakeClockTimeForSurvey = null;
  });

  group('SurveyService', () {
    test('can fetch survey metadata', () async {
      final survey = await SurveyService().fetchSurveyContent();
      expect(survey, isNotNull);
    });
  });

  group('DevToolsSurvey', () {
    test('parse constructor succeeds', () {
      final survey = DevToolsSurvey.fromJson({
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
        'devEnvironments': ['VSCode'],
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
      expect(survey.devEnvironments, ['VSCode']);

      final emptySurvey = DevToolsSurvey.fromJson({});
      expect(emptySurvey.id, isNull);
      expect(emptySurvey.startDate, isNull);
      expect(emptySurvey.endDate, isNull);
      expect(emptySurvey.title, isNull);
      expect(emptySurvey.url, isNull);
      expect(emptySurvey.minDevToolsVersion, isNull);
      expect(emptySurvey.devEnvironments, isNull);
    });

    group('should show', () {
      test('empty survey', () {
        final emptySurvey = DevToolsSurvey.fromJson({});

        fakeClockTimeForSurvey = DateTime(2023, 11, 7);
        expect(emptySurvey.meetsDateRequirement, isFalse);

        fakeClockTimeForSurvey = DateTime(2023, 11, 15);
        expect(emptySurvey.meetsDateRequirement, isFalse);

        expect(emptySurvey.meetsMinVersionRequirement, isTrue);
        expect(emptySurvey.meetsEnvironmentRequirement, isTrue);
        expect(emptySurvey.shouldShow, isFalse);
      });

      test('real survey', () {
        final survey = DevToolsSurvey.fromJson({
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
          'devEnvironments': ['VSCode'],
        });

        ideLaunched = 'VSCode';
        fakeClockTimeForSurvey = DateTime(2023, 11, 7);
        expect(survey.shouldShow, isTrue);
      });

      test('meetsDateRequirement', () {
        final survey = DevToolsSurvey.fromJson({
          'startDate': '2023-10-30T09:00:00-07:00',
          'endDate': '2023-11-14T09:00:00-07:00',
        });

        fakeClockTimeForSurvey = DateTime(2023, 11, 7);
        expect(survey.meetsDateRequirement, isTrue);

        fakeClockTimeForSurvey = DateTime(2023, 11, 15);
        expect(survey.meetsDateRequirement, isFalse);
      });

      test('meetsMinVersionRequirement', () {
        var survey = DevToolsSurvey.fromJson({'minDevToolsVersion': '2.25.0'});
        expect(survey.meetsMinVersionRequirement, isTrue);

        survey = DevToolsSurvey.fromJson({'minDevToolsVersion': '5.25.0'});
        expect(survey.meetsMinVersionRequirement, isFalse);
      });

      test('meetsEnvironmentRequirement', () {
        final vsCodeOnlySurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['VSCode'],
        });
        final intelliJSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['Android-Studio', 'IntelliJ-IDEA'],
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

      group('meetsEnvironmentRequirementFor', () {
        final vsCodeSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['VSCode'],
        });
        final intelliJSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['Android-Studio', 'IntelliJ-IDEA'],
        });
        final vsCodeDashToolSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['vscode-plugins'],
        });
        final intelliJDashToolSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['intellij-plugins'],
        });
        final cliSurvey = DevToolsSurvey.fromJson({
          'devEnvironments': ['CLI'],
        });

        bool meetsRequirement(
          DevToolsSurvey survey, {
          required String ideLaunched,
          Map<String, String?> queryParams = const {},
        }) => survey.meetsEnvironmentRequirementFor(
          ideLaunched: ideLaunched,
          queryParams: DevToolsQueryParams(queryParams),
        );

        test('matches the legacy ide value', () {
          // IDE integrations that predate the dashTool parameter.
          const vsCodeParams = {DevToolsQueryParams.ideKey: 'VSCode'};
          expect(
            meetsRequirement(
              vsCodeSurvey,
              ideLaunched: 'VSCode',
              queryParams: vsCodeParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              intelliJSurvey,
              ideLaunched: 'VSCode',
              queryParams: vsCodeParams,
            ),
            isFalse,
          );

          const androidStudioParams = {
            DevToolsQueryParams.ideKey: 'Android-Studio',
          };
          expect(
            meetsRequirement(
              intelliJSurvey,
              ideLaunched: 'Android-Studio',
              queryParams: androidStudioParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              vsCodeSurvey,
              ideLaunched: 'Android-Studio',
              queryParams: androidStudioParams,
            ),
            isFalse,
          );
        });

        test('matches the dashTool', () {
          const vsCodeParams = {
            DevToolsQueryParams.ideKey: 'VSCode',
            DevToolsQueryParams.dashToolKey: 'vscode-plugins',
            DevToolsQueryParams.dashIdeNameKey: 'Visual Studio Code',
          };
          expect(
            meetsRequirement(
              vsCodeDashToolSurvey,
              ideLaunched: 'VSCode',
              queryParams: vsCodeParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              intelliJDashToolSurvey,
              ideLaunched: 'VSCode',
              queryParams: vsCodeParams,
            ),
            isFalse,
          );

          // Android Studio and IntelliJ share the same dashTool.
          const androidStudioParams = {
            DevToolsQueryParams.ideKey: 'Android-Studio',
            DevToolsQueryParams.dashToolKey: 'intellij-plugins',
            DevToolsQueryParams.dashIdeNameKey: 'Android Studio',
          };
          expect(
            meetsRequirement(
              intelliJDashToolSurvey,
              ideLaunched: 'Android-Studio',
              queryParams: androidStudioParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              vsCodeDashToolSurvey,
              ideLaunched: 'Android-Studio',
              queryParams: androidStudioParams,
            ),
            isFalse,
          );
        });

        test(
          'matches dashTool environments when only the legacy ide value is passed',
          () {
            const vsCodeParams = {DevToolsQueryParams.ideKey: 'VSCode'};
            expect(
              meetsRequirement(
                vsCodeDashToolSurvey,
                ideLaunched: 'VSCode',
                queryParams: vsCodeParams,
              ),
              isTrue,
            );
            expect(
              meetsRequirement(
                intelliJDashToolSurvey,
                ideLaunched: 'VSCode',
                queryParams: vsCodeParams,
              ),
              isFalse,
            );

            for (final ide in ['Android-Studio', 'IntelliJ-IDEA']) {
              final params = {DevToolsQueryParams.ideKey: ide};
              expect(
                meetsRequirement(
                  intelliJDashToolSurvey,
                  ideLaunched: ide,
                  queryParams: params,
                ),
                isTrue,
                reason: ide,
              );
              expect(
                meetsRequirement(
                  vsCodeDashToolSurvey,
                  ideLaunched: ide,
                  queryParams: params,
                ),
                isFalse,
                reason: ide,
              );
            }
          },
        );

        test('matches VS Code forks for the legacy VSCode environment', () {
          // A fork does not have to pass 'VSCode' as its legacy ide value.
          const cursorParams = {
            DevToolsQueryParams.ideKey: 'Cursor',
            DevToolsQueryParams.dashToolKey: 'vscode-plugins',
            DevToolsQueryParams.dashIdeNameKey: 'Cursor',
          };
          expect(
            meetsRequirement(
              vsCodeSurvey,
              ideLaunched: 'Cursor',
              queryParams: cursorParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              intelliJSurvey,
              ideLaunched: 'Cursor',
              queryParams: cursorParams,
            ),
            isFalse,
          );

          // Once IDE integrations stop passing the legacy ide parameter, the
          // launch environment defaults to 'CLI'.
          const dashToolOnlyParams = {
            DevToolsQueryParams.dashToolKey: 'vscode-plugins',
          };
          expect(
            meetsRequirement(
              vsCodeSurvey,
              ideLaunched: 'CLI',
              queryParams: dashToolOnlyParams,
            ),
            isTrue,
          );
          expect(
            meetsRequirement(
              intelliJSurvey,
              ideLaunched: 'CLI',
              queryParams: dashToolOnlyParams,
            ),
            isFalse,
          );
          expect(
            meetsRequirement(
              cliSurvey,
              ideLaunched: 'CLI',
              queryParams: dashToolOnlyParams,
            ),
            isFalse,
          );

          for (final dashTool in [
            'intellij-plugins',
            'android-studio-plugins',
          ]) {
            final intelliJDashToolOnlyParams = {
              DevToolsQueryParams.dashToolKey: dashTool,
            };
            expect(
              meetsRequirement(
                intelliJSurvey,
                ideLaunched: 'CLI',
                queryParams: intelliJDashToolOnlyParams,
              ),
              isTrue,
              reason: dashTool,
            );
            expect(
              meetsRequirement(
                vsCodeSurvey,
                ideLaunched: 'CLI',
                queryParams: intelliJDashToolOnlyParams,
              ),
              isFalse,
              reason: dashTool,
            );
            expect(
              meetsRequirement(
                cliSurvey,
                ideLaunched: 'CLI',
                queryParams: intelliJDashToolOnlyParams,
              ),
              isFalse,
              reason: dashTool,
            );
          }
        });

        test('does not match other environments', () {
          for (final survey in [
            vsCodeSurvey,
            intelliJSurvey,
            vsCodeDashToolSurvey,
            intelliJDashToolSurvey,
          ]) {
            expect(meetsRequirement(survey, ideLaunched: 'CLI'), isFalse);
          }
          expect(meetsRequirement(cliSurvey, ideLaunched: 'CLI'), isTrue);
          expect(
            meetsRequirement(
              cliSurvey,
              ideLaunched: 'CLI',
              queryParams: {DevToolsQueryParams.dashToolKey: 'flutter-tool'},
            ),
            isTrue,
          );
        });

        test('matches any environment when none is specified or known', () {
          final anyEnvironmentSurvey = DevToolsSurvey.fromJson({});
          expect(
            meetsRequirement(anyEnvironmentSurvey, ideLaunched: 'CLI'),
            isTrue,
          );

          // The launch environment is not known until the analytics
          // dimensions are computed.
          for (final survey in [vsCodeSurvey, vsCodeDashToolSurvey]) {
            expect(meetsRequirement(survey, ideLaunched: ''), isTrue);
          }
        });
      });
    });
  });
}
