void main() {
  if (true) {
    group(
      'ext.flutter.inspector.addPubRootDirectories',
      () {
        late final String pubRootTest;

        setUpAll(() async {
          pubRootTest = generateTestPubRootDirectory(service);
        });

        setUp(() async {
          service.resetPubRootDirectories(<String>[]);
        });

        testWidgets(
          'has createdByLocalProject when the widget is in the pubRootDirectory',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': pubRootTest},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject if the prefix of the pubRootDirectory is different',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': '/invalid/$pubRootTest'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject if the pubRootDirectory is prefixed with file://',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': 'file://$pubRootTest'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject if the pubRootDirectory has a different suffix',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': '$pubRootTest/different'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject if at least one of the pubRootDirectories matches',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': '/unrelated/$pubRootTest',
              'arg1': 'file://$pubRootTest',
            });

            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject even if pubRootDirectories were previously added',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': 'file://$pubRootTest',
            });
            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': '/unrelated/$pubRootTest',
            });

            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'widget is part of core framework and is the child of a widget in the package pubRootDirectories',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );
            final Element elementA = find.text('a').evaluate().first;

            // The RichText child of the Text widget is created by the core framework
            // not the current package.
            final Element richText = find
                .descendant(
                  of: find.text('a'),
                  matching: find.byType(RichText),
                )
                .evaluate()
                .first;
            service.setSelection(richText, 'my-group');
            service.addPubRootDirectories(<String>[pubRootTest]);
            final Map<String, Object?> jsonObject =
                json.decode(service.getSelectedWidget(null, 'my-group'))
                    as Map<String, Object?>;
            expect(jsonObject, isNot(contains('createdByLocalProject')));
            final Map<String, Object?> creationLocation =
                jsonObject['creationLocation']! as Map<String, Object?>;
            expect(creationLocation, isNotNull);
            // This RichText widget is created by the build method of the Text widget
            // thus the creation location is in text.dart not basic.dart
            final List<String> pathSegmentsFramework =
                Uri.parse(creationLocation['file']! as String).pathSegments;
            expect(
              pathSegmentsFramework.join('/'),
              endsWith('/flutter/lib/src/widgets/text.dart'),
            );

            // Strip off /src/widgets/text.dart.
            final String pubRootFramework =
                '/${pathSegmentsFramework.take(pathSegmentsFramework.length - 3).join('/')}';
            service.resetPubRootDirectories(<String>[]);
            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': pubRootFramework},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
            service.setSelection(elementA, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );

            service.resetPubRootDirectories(<String>[]);
            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': pubRootFramework, 'arg1': pubRootTest},
            );
            service.setSelection(elementA, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
            service.setSelection(richText, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );
      },
      skip: !WidgetInspectorService.instance
          .isWidgetCreationTracked(), // [intended] Test requires --track-widget-creation flag.
    );

    group(
      'ext.flutter.inspector.removePubRootDirectories',
      () {
        late final String pubRootTest;

        setUpAll(() async {
          pubRootTest = generateTestPubRootDirectory(service);
        });

        setUp(() async {
          service.resetPubRootDirectories(<String>[]);
        });

        testWidgets(
          'does not have createdByLocalProject when no pubRootDirectories set and an unknown directory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'removePubRootDirectories',
              <String, String>{'arg0': 'an/unknown/directory'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when the pubRootDirectory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(<String>[pubRootTest]);
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
              'removePubRootDirectories',
              <String, String>{'arg0': pubRootTest},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when all matching pubRootDirectories are removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(
              <String>[pubRootTest, 'file://$pubRootTest'],
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
                'removePubRootDirectories', <String, String>{
              'arg0': pubRootTest,
              'arg1': 'file://$pubRootTest'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject when a different pubRootDirectory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(
              <String>[pubRootTest, '$pubRootTest/invalid'],
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
              'removePubRootDirectories',
              <String, String>{'arg0': '$pubRootTest/invalid'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );
      },
      skip: !WidgetInspectorService.instance
          .isWidgetCreationTracked(), // [intended] Test requires --track-widget-creation flag.
    );

    group(
      'ext.flutter.inspector.addPubRootDirectories',
      () {
        late final String pubRootTest;

        setUpAll(() async {
          pubRootTest = generateTestPubRootDirectory(service);
        });

        setUp(() async {
          service.resetPubRootDirectories(<String>[]);
        });

        testWidgets(
          'has createdByLocalProject when the widget is in the pubRootDirectory',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': pubRootTest, 'isolateId': '34'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when widget package directory is a suffix of a pubRootDirectory',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
                'addPubRootDirectories', <String, String>{
              'arg0': '/invalid/$pubRootTest',
              'isolateId': '34'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject when the pubRootDirectory is prefixed with file://',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{
                'arg0': 'file://$pubRootTest',
                'isolateId': '34'
              },
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when thePubRootDirectoy has a different suffix',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
                'addPubRootDirectories', <String, String>{
              'arg0': '$pubRootTest/different',
              'isolateId': '34'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject even if another pubRootDirectory does not match',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': '/unrelated/$pubRootTest',
              'arg1': 'file://$pubRootTest',
              'isolateId': '34',
            });

            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );
        testWidgets(
            'has createdByLocalProject if multiple pubRootDirectories match',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: const <Widget>[
                  Text('a'),
                  Text('b', textDirection: TextDirection.ltr),
                  Text('c', textDirection: TextDirection.ltr),
                ],
              ),
            ),
          );

          final Element elementA = find.text('a').evaluate().first;
          service.setSelection(elementA, 'my-group');

          await service.testExtension('addPubRootDirectories', <String, String>{
            'arg0': pubRootTest,
            'arg1': 'file://$pubRootTest',
            'isolateId': '34',
          });

          expect(
            await service.testExtension(
              'getSelectedWidget',
              <String, String>{'objectGroup': 'my-group'},
            ),
            contains('createdByLocalProject'),
          );
        });

        testWidgets(
          'has createdByLocalProject even if pubRootDirectories were previously added',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': 'file://$pubRootTest',
              'isolateId': '34',
            });
            await service
                .testExtension('addPubRootDirectories', <String, String>{
              'arg0': '/unrelated/$pubRootTest',
              'isolateId': '34',
            });

            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );

        testWidgets(
          'widget is part of core framework and is the child of a widget in the package pubRootDirectories',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );
            final Element elementA = find.text('a').evaluate().first;

            // The RichText child of the Text widget is created by the core framework
            // not the current package.
            final Element richText = find
                .descendant(
                  of: find.text('a'),
                  matching: find.byType(RichText),
                )
                .evaluate()
                .first;
            service.setSelection(richText, 'my-group');
            service.addPubRootDirectories(<String>[pubRootTest]);
            final Map<String, Object?> jsonObject =
                json.decode(service.getSelectedWidget(null, 'my-group'))
                    as Map<String, Object?>;
            expect(jsonObject, isNot(contains('createdByLocalProject')));
            final Map<String, Object?> creationLocation =
                jsonObject['creationLocation']! as Map<String, Object?>;
            expect(creationLocation, isNotNull);
            // This RichText widget is created by the build method of the Text widget
            // thus the creation location is in text.dart not basic.dart
            final List<String> pathSegmentsFramework =
                Uri.parse(creationLocation['file']! as String).pathSegments;
            expect(
              pathSegmentsFramework.join('/'),
              endsWith('/flutter/lib/src/widgets/text.dart'),
            );

            // Strip off /src/widgets/text.dart.
            final String pubRootFramework =
                '/${pathSegmentsFramework.take(pathSegmentsFramework.length - 3).join('/')}';
            service.resetPubRootDirectories(<String>[]);
            await service.testExtension(
              'addPubRootDirectories',
              <String, String>{'arg0': pubRootFramework, 'isolateId': '34'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
            service.setSelection(elementA, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );

            service.resetPubRootDirectories(<String>[]);
            await service.testExtension(
                'addPubRootDirectories', <String, String>{
              'arg0': pubRootFramework,
              'arg1': pubRootTest,
              'isolateId': '34'
            });
            service.setSelection(elementA, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
            service.setSelection(richText, 'my-group');
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );
      },
      skip: !WidgetInspectorService.instance
          .isWidgetCreationTracked(), // [intended] Test requires --track-widget-creation flag.
    );

    group(
      'ext.flutter.inspector.removePubRootDirectories',
      () {
        late final String pubRootTest;

        setUpAll(() async {
          pubRootTest = generateTestPubRootDirectory(service);
        });

        setUp(() async {
          service.resetPubRootDirectories(<String>[]);
        });

        testWidgets(
          'does not have createdByLocalProject when no pubRootDirectories set and an unknown directory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            await service.testExtension(
                'removePubRootDirectories', <String, String>{
              'arg0': 'an/unknown/directory',
              'isolateId': '34'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when the pubRootDirectory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(<String>[pubRootTest]);
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
              'removePubRootDirectories',
              <String, String>{'arg0': pubRootTest, 'isolateId': '34'},
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'does not have createdByLocalProject when all matching pubRootDirectories are removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(
              <String>[pubRootTest, 'file://$pubRootTest'],
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
                'removePubRootDirectories', <String, String>{
              'arg0': pubRootTest,
              'arg1': 'file://$pubRootTest',
              'isolateId': '34'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              isNot(contains('createdByLocalProject')),
            );
          },
        );

        testWidgets(
          'has createdByLocalProject when a different pubRootDirectory is removed',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  children: const <Widget>[
                    Text('a'),
                    Text('b', textDirection: TextDirection.ltr),
                    Text('c', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
            );

            final Element elementA = find.text('a').evaluate().first;
            service.setSelection(elementA, 'my-group');

            service.addPubRootDirectories(
              <String>[pubRootTest, '$pubRootTest/invalid'],
            );
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );

            await service.testExtension(
                'removePubRootDirectories', <String, String>{
              'arg0': '$pubRootTest/invalid',
              'isolateId': '34'
            });
            expect(
              await service.testExtension(
                'getSelectedWidget',
                <String, String>{'objectGroup': 'my-group'},
              ),
              contains('createdByLocalProject'),
            );
          },
        );
      },
      skip: !WidgetInspectorService.instance
          .isWidgetCreationTracked(), // [intended] Test requires --track-widget-creation flag.
    );
  }
}

void testWidgets(String s, Future<Null> Function(dynamic tester) param1) {}

String generateTestPubRootDirectory(service) {}

void setUpAll(Null Function() param0) {}

void group(String s, Null Function() param1) {}
