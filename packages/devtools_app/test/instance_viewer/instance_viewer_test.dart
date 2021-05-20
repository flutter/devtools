// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/provider/instance_viewer/instance_details.dart';
import 'package:devtools_app/src/provider/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/provider/instance_viewer/instance_viewer.dart';
import 'package:devtools_app/src/provider/instance_viewer/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/utils.dart';

final alwaysExpandedOverride =
    isExpandedProvider.overrideWithProvider((ref, param) => true);

final neverExpandedOverride =
    isExpandedProvider.overrideWithProvider((ref, param) => false);

final emptyObjectInstance = AsyncValue.data(
  InstanceDetails.object(
    const [],
    hash: 0,
    instanceRefId: 'map0',
    setter: null,
    evalForInstance: FakeEvalOnDartLibrary(),
    type: 'MyClass',
  ),
);

final object2Instance = AsyncValue.data(
  ObjectInstance(
    [
      ObjectField(
        name: 'first',
        isFinal: true,
        ownerName: '',
        ownerUri: '',
        eval: FakeEvalOnDartLibrary(),
        ref: Result.error(Error()),
        isDefinedByDependency: false,
      ),
      ObjectField(
        name: 'second',
        isFinal: true,
        ownerName: '',
        ownerUri: '',
        eval: FakeEvalOnDartLibrary(),
        ref: Result.error(Error()),
        isDefinedByDependency: false,
      ),
    ],
    hash: 0,
    instanceRefId: 'object',
    setter: null,
    evalForInstance: FakeEvalOnDartLibrary(),
    type: 'MyClass',
  ),
);

final emptyMapInstance = AsyncValue.data(
  InstanceDetails.map(const [], hash: 0, instanceRefId: 'map0', setter: null),
);

final map2Instance = AsyncValue.data(
  InstanceDetails.map([
    stringInstance.data.value,
    list2Instance.data.value,
  ], hash: 0, instanceRefId: '0', setter: null),
);

final emptyListInstance = AsyncValue.data(
  InstanceDetails.list(
    length: 0,
    hash: 0,
    instanceRefId: 'list0',
    setter: null,
  ),
);

final list2Instance = AsyncValue.data(
  InstanceDetails.list(
    length: 2,
    hash: 0,
    instanceRefId: 'list2',
    setter: null,
  ),
);

final stringInstance = AsyncValue.data(
  InstanceDetails.string('string', instanceRefId: 'string', setter: null),
);

final nullInstance = AsyncValue.data(InstanceDetails.nill(setter: null));

final trueInstance = AsyncValue.data(
  InstanceDetails.boolean('true', instanceRefId: 'true', setter: null),
);

final int42Instance = AsyncValue.data(
  NumInstance('42', instanceRefId: '42', setter: null),
);

final enumValueInstance = AsyncValue.data(
  InstanceDetails.enumeration(
    type: 'Enum',
    value: 'value',
    setter: null,
    instanceRefId: 'Enum.value',
  ),
);

void main() {
  setUpAll(() => loadFonts());

  group('InstanceViewer', () {
    testWidgets(
        'showInternalProperties: false hides private properties from dependencies',
        (tester) async {
      const objPath = InstancePath.fromInstanceId('obj');

      InstancePath pathForProperty(String name) {
        return objPath.pathForChild(
          PathToProperty.objectProperty(
            name: name,
            ownerUri: '',
            ownerName: '',
          ),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rawInstanceProvider(objPath).overrideWithValue(
              AsyncValue.data(
                ObjectInstance(
                  [
                    ObjectField(
                      name: 'first',
                      isFinal: false,
                      ownerName: '',
                      ownerUri: '',
                      eval: FakeEvalOnDartLibrary(),
                      ref: Result.error(Error()),
                      isDefinedByDependency: true,
                    ),
                    ObjectField(
                      name: '_second',
                      isFinal: false,
                      ownerName: '',
                      ownerUri: '',
                      eval: FakeEvalOnDartLibrary(),
                      ref: Result.error(Error()),
                      isDefinedByDependency: true,
                    ),
                    ObjectField(
                      name: 'third',
                      isFinal: false,
                      ownerName: '',
                      ownerUri: '',
                      eval: FakeEvalOnDartLibrary(),
                      ref: Result.error(Error()),
                      isDefinedByDependency: false,
                    ),
                    ObjectField(
                      name: '_forth',
                      isFinal: false,
                      ownerName: '',
                      ownerUri: '',
                      eval: FakeEvalOnDartLibrary(),
                      ref: Result.error(Error()),
                      isDefinedByDependency: false,
                    ),
                  ],
                  hash: 0,
                  instanceRefId: 'object',
                  setter: null,
                  evalForInstance: FakeEvalOnDartLibrary(),
                  type: 'MyClass',
                ),
              ),
            ),
            rawInstanceProvider(pathForProperty('first'))
                .overrideWithValue(int42Instance),
            rawInstanceProvider(pathForProperty('_second'))
                .overrideWithValue(int42Instance),
            rawInstanceProvider(pathForProperty('third'))
                .overrideWithValue(int42Instance),
            rawInstanceProvider(pathForProperty('_forth'))
                .overrideWithValue(int42Instance),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: false,
                rootPath: objPath,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('show_internal_properties.png'),
      );
    });

    testWidgets('field editing flow', (tester) async {
      const objPath = InstancePath.fromInstanceId('obj');
      final propertyPath = objPath.pathForChild(
        const PathToProperty.objectProperty(
          name: 'first',
          ownerUri: '',
          ownerName: '',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rawInstanceProvider(objPath).overrideWithValue(
              AsyncValue.data(
                ObjectInstance(
                  [
                    ObjectField(
                      name: 'first',
                      isFinal: false,
                      ownerName: '',
                      ownerUri: '',
                      eval: FakeEvalOnDartLibrary(),
                      ref: Result.error(Error()),
                      isDefinedByDependency: false,
                    ),
                  ],
                  hash: 0,
                  instanceRefId: 'object',
                  setter: null,
                  evalForInstance: FakeEvalOnDartLibrary(),
                  type: 'MyClass',
                ),
              ),
            ),
            rawInstanceProvider(propertyPath).overrideWithValue(
              AsyncValue.data(
                InstanceDetails.number(
                  '0',
                  instanceRefId: '0',
                  setter: (value) async {},
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: objPath,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey(propertyPath)));

      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/edit.png'),
      );

      // can press esc to unfocus active node
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/edit_esc.png'),
      );
    });

    testWidgets('renders <loading> while an instance is fetched',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rawInstanceProvider(const InstancePath.fromInstanceId('0'))
                .overrideWithValue(const AsyncValue.loading())
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('0'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/loading.png'),
      );
    });

    testWidgets(
        'once valid data was fetched, going back to loading shows the previous value for 1 second',
        (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('0'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/null.png'),
      );

      container.updateOverrides([
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(const AsyncValue.loading()),
      ]);

      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/null.png'),
      );

      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/loading.png'),
      );
    });

    // TODO(rrousselGit) find a way to test "data then loading then wait then loading then wait shows "loading" after a total of one second"
    // This is tricky because tester.pump(duration) completes the Timer even if the duration is < 1 second

    testWidgets(
        'once valid data was fetched, going back to loading and emiting an error immediately updates the UI',
        (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('0'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      container.updateOverrides([
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(const AsyncValue.loading()),
      ]);

      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/null.png'),
      );

      container.updateOverrides([
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(AsyncValue.error(StateError('test error'))),
      ]);

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/error.png'),
      );
    });

    testWidgets(
        'once valid data was fetched, going back to loading and emiting a new value immediately updates the UI',
        (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('0'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      container.updateOverrides([
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(const AsyncValue.loading()),
      ]);

      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/null.png'),
      );

      container.updateOverrides([
        rawInstanceProvider(const InstancePath.fromInstanceId('0'))
            .overrideWithValue(int42Instance),
      ]);

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/num.png'),
      );
    });

    testWidgets('renders enums', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('enum'))
            .overrideWithValue(enumValueInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('enum'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/enum.png'),
      );
    });

    testWidgets('renders null', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('null'))
            .overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('null'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/null.png'),
      );
    });

    testWidgets('renders bools', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('bool'))
            .overrideWithValue(trueInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('bool'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/bool.png'),
      );
    });

    testWidgets('renders strings', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('string'))
            .overrideWithValue(stringInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('string'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/string.png'),
      );
    });

    testWidgets('renders numbers', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('num'))
            .overrideWithValue(int42Instance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('num'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/num.png'),
      );
    });

    testWidgets('renders maps', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('map'))
            .overrideWithValue(map2Instance),
        // {'string': 42, [...]: ['string', null]}
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'map',
          pathToProperty: [PathToProperty.mapKey(ref: 'string')],
        )).overrideWithValue(int42Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'map',
          pathToProperty: [PathToProperty.mapKey(ref: 'list2')],
        )).overrideWithValue(list2Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'map',
          pathToProperty: [
            PathToProperty.mapKey(ref: 'list2'),
            PathToProperty.listIndex(0),
          ],
        )).overrideWithValue(stringInstance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'map',
          pathToProperty: [
            PathToProperty.mapKey(ref: 'list2'),
            PathToProperty.listIndex(1),
          ],
        )).overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('map'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/collasped_map.png'),
      );

      container
          .read(isExpandedProvider(const InstancePath.fromInstanceId(
            'map',
            pathToProperty: [PathToProperty.mapKey(ref: 'list2')],
          )))
          .state = true;

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/expanded_map.png'),
      );
    });

    testWidgets('renders objects', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('object'))
            .overrideWithValue(object2Instance),
        // MyClass(first: 42, second: ['string', null])
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'object',
          pathToProperty: [
            PathToProperty.objectProperty(
              name: 'first',
              ownerUri: '',
              ownerName: '',
            ),
          ],
        )).overrideWithValue(int42Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'object',
          pathToProperty: [
            PathToProperty.objectProperty(
              name: 'second',
              ownerUri: '',
              ownerName: '',
            ),
          ],
        )).overrideWithValue(list2Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'object',
          pathToProperty: [
            PathToProperty.objectProperty(
              name: 'second',
              ownerUri: '',
              ownerName: '',
            ),
            PathToProperty.listIndex(0),
          ],
        )).overrideWithValue(stringInstance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'object',
          pathToProperty: [
            PathToProperty.objectProperty(
              name: 'second',
              ownerUri: '',
              ownerName: '',
            ),
            PathToProperty.listIndex(1),
          ],
        )).overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('object'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/collasped_object.png'),
      );

      container
          .read(isExpandedProvider(const InstancePath.fromInstanceId(
            'object',
            pathToProperty: [
              PathToProperty.objectProperty(
                name: 'second',
                ownerUri: '',
                ownerName: '',
              ),
            ],
          )))
          .state = true;

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/expanded_object.png'),
      );
    });

    testWidgets('renders lists', (tester) async {
      final container = ProviderContainer(overrides: [
        rawInstanceProvider(const InstancePath.fromInstanceId('list'))
            .overrideWithValue(list2Instance),
        // [true, {'string': 42, [...]: null}]
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'list',
          pathToProperty: [
            PathToProperty.listIndex(0),
          ],
        )).overrideWithValue(trueInstance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'list',
          pathToProperty: [
            PathToProperty.listIndex(1),
          ],
        )).overrideWithValue(map2Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'list',
          pathToProperty: [
            PathToProperty.listIndex(1),
            PathToProperty.mapKey(ref: 'string'),
          ],
        )).overrideWithValue(int42Instance),
        rawInstanceProvider(const InstancePath.fromInstanceId(
          'list',
          pathToProperty: [
            PathToProperty.listIndex(1),
            PathToProperty.mapKey(ref: 'list2'),
          ],
        )).overrideWithValue(nullInstance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('list'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/collasped_list.png'),
      );

      container
          .read(isExpandedProvider(const InstancePath.fromInstanceId(
            'list',
            pathToProperty: [PathToProperty.listIndex(1)],
          )))
          .state = true;

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/instance_viewer/expanded_list.png'),
      );
    });

    testWidgets('does not listen to unexpanded nodes', (tester) async {
      final container = ProviderContainer(overrides: [
        neverExpandedOverride,
        rawInstanceProvider(const InstancePath.fromInstanceId('list2'))
            .overrideWithValue(list2Instance),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InstanceViewer(
                showInternalProperties: true,
                rootPath: InstancePath.fromInstanceId('list2'),
              ),
            ),
          ),
        ),
      );

      expect(
        container
            .readProviderElement(
              rawInstanceProvider(const InstancePath.fromInstanceId('list2')),
            )
            .hasListeners,
        isTrue,
      );
      expect(
        container
            .readProviderElement(rawInstanceProvider(
              const InstancePath.fromInstanceId(
                'list2',
                pathToProperty: [PathToProperty.listIndex(0)],
              ),
            ))
            .hasListeners,
        isFalse,
      );
      expect(
        container
            .readProviderElement(rawInstanceProvider(
              const InstancePath.fromInstanceId(
                'list2',
                pathToProperty: [PathToProperty.listIndex(1)],
              ),
            ))
            .hasListeners,
        isFalse,
      );
    });
  });

  group('estimatedChildCountProvider', () {
    group('primitives', () {
      test('count for one line when not expanded', () {
        final container = ProviderContainer(overrides: [
          neverExpandedOverride,
          rawInstanceProvider(const InstancePath.fromInstanceId('string'))
              .overrideWithValue(stringInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('null'))
              .overrideWithValue(nullInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('bool'))
              .overrideWithValue(trueInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('num'))
              .overrideWithValue(int42Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId('enum'))
              .overrideWithValue(enumValueInstance),
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('string'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('null'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('bool'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('num'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('enum'),
          )),
          1,
        );
      });

      test('count for one line when expanded', () {
        final container = ProviderContainer(overrides: [
          // force expanded status
          alwaysExpandedOverride,
          rawInstanceProvider(const InstancePath.fromInstanceId('string'))
              .overrideWithValue(stringInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('null'))
              .overrideWithValue(nullInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('bool'))
              .overrideWithValue(trueInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('num'))
              .overrideWithValue(int42Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId('enum'))
              .overrideWithValue(enumValueInstance),
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('string'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('null'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('bool'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('num'),
          )),
          1,
        );
        expect(
          container.read(estimatedChildCountProvider(
            const InstancePath.fromInstanceId('enum'),
          )),
          1,
        );
      });
    });

    group('lists', () {
      test('count for one line when not expanded regarless of the list length',
          () {
        final container = ProviderContainer(overrides: [
          neverExpandedOverride,
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyListInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('list-2'))
              .overrideWithValue(emptyListInstance)
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('list-2')),
          ),
          1,
        );
      });

      test('when expanded, recursively traverse the list content', () {
        final container = ProviderContainer(overrides: [
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyListInstance),
          // ['string', [42, true]]
          rawInstanceProvider(const InstancePath.fromInstanceId('list-2'))
              .overrideWithValue(list2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'list-2',
            pathToProperty: [PathToProperty.listIndex(0)],
          )).overrideWithValue(stringInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'list-2',
            pathToProperty: [PathToProperty.listIndex(1)],
          )).overrideWithValue(list2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'list-2',
            pathToProperty: [
              PathToProperty.listIndex(1),
              PathToProperty.listIndex(0),
            ],
          )).overrideWithValue(int42Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'list-2',
            pathToProperty: [
              PathToProperty.listIndex(1),
              PathToProperty.listIndex(1),
            ],
          )).overrideWithValue(trueInstance),
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );

        expect(
          container.read(
            estimatedChildCountProvider(
              const InstancePath.fromInstanceId('list-2'),
            ),
          ),
          // header + 2 items
          3,
        );

        // expand the nested list
        container
            .read(
              isExpandedProvider(const InstancePath.fromInstanceId(
                'list-2',
                pathToProperty: [PathToProperty.listIndex(1)],
              )),
            )
            .state = true;

        // now the estimatedChildCount traverse the nested list too
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('list-2')),
          ),
          // header + string + sub-list header + sub-list 2 items
          5,
        );
      });
    });

    group('maps', () {
      test('count for one line when not expanded regarless of the map length',
          () {
        final container = ProviderContainer(overrides: [
          neverExpandedOverride,
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyMapInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('map-2'))
              .overrideWithValue(map2Instance)
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('map-2')),
          ),
          1,
        );
      });

      test('when expanded, recursively traverse the map content', () {
        final container = ProviderContainer(overrides: [
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyMapInstance),
          // {'string': 'string', [...]: [42, true]]
          rawInstanceProvider(const InstancePath.fromInstanceId('map-2'))
              .overrideWithValue(map2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'map-2',
            pathToProperty: [PathToProperty.mapKey(ref: 'string')],
          )).overrideWithValue(stringInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'map-2',
            pathToProperty: [PathToProperty.mapKey(ref: 'list2')],
          )).overrideWithValue(list2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'map-2',
            pathToProperty: [
              PathToProperty.mapKey(ref: 'list2'),
              PathToProperty.listIndex(0),
            ],
          )).overrideWithValue(int42Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'map-2',
            pathToProperty: [
              PathToProperty.mapKey(ref: 'list2'),
              PathToProperty.listIndex(1),
            ],
          )).overrideWithValue(trueInstance),
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );

        expect(
          container.read(
            estimatedChildCountProvider(
              const InstancePath.fromInstanceId('map-2'),
            ),
          ),
          // header + 2 items
          3,
        );

        // expand the nested list
        container
            .read(
              isExpandedProvider(const InstancePath.fromInstanceId(
                'map-2',
                pathToProperty: [PathToProperty.mapKey(ref: 'list2')],
              )),
            )
            .state = true;

        // now the estimatedChildCount traverse the nested list too
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('map-2')),
          ),
          // header + string + sub-list header + sub-list 2 items
          5,
        );
      });
    });

    group('objects', () {
      test(
          'count for one line when not expanded regarless of the number of fields',
          () {
        final container = ProviderContainer(overrides: [
          neverExpandedOverride,
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyObjectInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId('object-2'))
              .overrideWithValue(object2Instance)
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('object-2')),
          ),
          1,
        );
      });

      test('when expanded, recursively traverse the object content', () {
        final container = ProviderContainer(overrides: [
          rawInstanceProvider(const InstancePath.fromInstanceId('empty'))
              .overrideWithValue(emptyObjectInstance),
          // Class(first: 'string', second: [42, true])
          rawInstanceProvider(const InstancePath.fromInstanceId('object-2'))
              .overrideWithValue(object2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'object-2',
            pathToProperty: [
              PathToProperty.objectProperty(
                name: 'first',
                ownerUri: '',
                ownerName: '',
              )
            ],
          )).overrideWithValue(stringInstance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'object-2',
            pathToProperty: [
              PathToProperty.objectProperty(
                name: 'second',
                ownerUri: '',
                ownerName: '',
              )
            ],
          )).overrideWithValue(list2Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'object-2',
            pathToProperty: [
              PathToProperty.objectProperty(
                name: 'second',
                ownerUri: '',
                ownerName: '',
              ),
              PathToProperty.listIndex(0),
            ],
          )).overrideWithValue(int42Instance),
          rawInstanceProvider(const InstancePath.fromInstanceId(
            'object-2',
            pathToProperty: [
              PathToProperty.objectProperty(
                name: 'second',
                ownerUri: '',
                ownerName: '',
              ),
              PathToProperty.listIndex(1),
            ],
          )).overrideWithValue(trueInstance),
        ]);
        addTearDown(container.dispose);

        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('empty')),
          ),
          1,
        );

        expect(
          container.read(
            estimatedChildCountProvider(
              const InstancePath.fromInstanceId('object-2'),
            ),
          ),
          // header + 2 items
          3,
        );

        // expand the nested list
        container
            .read(
              isExpandedProvider(const InstancePath.fromInstanceId(
                'object-2',
                pathToProperty: [
                  PathToProperty.objectProperty(
                    name: 'second',
                    ownerUri: '',
                    ownerName: '',
                  ),
                ],
              )),
            )
            .state = true;

        // now the estimatedChildCount traverse the nested list too
        expect(
          container.read(
            estimatedChildCountProvider(
                const InstancePath.fromInstanceId('object-2')),
          ),
          // header + string + sub-list header + sub-list 2 items
          5,
        );
      });
    });
  });

  group('isExpandedProvider', () {
    test('the graph root starts as expanded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container
            .read(isExpandedProvider(const InstancePath.fromProviderId('0')))
            .state,
        isTrue,
      );

      expect(
        container
            .read(isExpandedProvider(const InstancePath.fromInstanceId('0')))
            .state,
        isTrue,
      );
    });

    test('children nodes are not expanded by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container
            .read(isExpandedProvider(
              const InstancePath.fromProviderId(
                '0',
                pathToProperty: [PathToProperty.listIndex(0)],
              ),
            ))
            .state,
        isFalse,
      );

      expect(
        container
            .read(
              isExpandedProvider(const InstancePath.fromInstanceId(
                '0',
                pathToProperty: [PathToProperty.listIndex(0)],
              )),
            )
            .state,
        isFalse,
      );
    });
  });
}

class FakeEvalOnDartLibrary extends Fake implements EvalOnDartLibrary {}
