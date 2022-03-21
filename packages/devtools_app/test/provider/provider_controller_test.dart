// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/screens/provider/instance_viewer/instance_details.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/screens/provider/provider_nodes.dart';
// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member, non_constant_identifier_names

import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' hide SentinelException;

import '../test_infra/flutter_test_driver.dart';
import '../test_infra/flutter_test_environment.dart';

Future<void> runProviderControllerTests(FlutterTestEnvironment env) async {
  late EvalOnDartLibrary evalOnDartLibrary;
  Disposable? isAlive;

  setUp(() async {
    await env.setupEnvironment(
      config: const FlutterRunConfiguration(withDebugger: true),
    );
    await serviceManager.service!.allFuturesCompleted;

    isAlive = Disposable();
    evalOnDartLibrary = EvalOnDartLibrary(
      'package:provider_app/main.dart',
      env.service!,
    );
  });

  tearDown(() async {
    isAlive!.dispose();
    evalOnDartLibrary.dispose();
    await env.tearDownEnvironment(force: true);
  });

  test('refreshes everything on hot-reload', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final providersSub =
        container.listen(rawSortedProviderNodesProvider.future);
    final countSub = container.listen(
      rawInstanceProvider(
        const InstancePath.fromProviderId('0').pathForChild(
          const PathToProperty.objectProperty(
            name: '_count',
            ownerUri: 'package:provider_app/main.dart',
            ownerName: 'Counter',
          ),
        )!,
      ).future,
    );

    await evalOnDartLibrary.asyncEval(
      'await tester.tap(find.byKey(Key("add"))).then((_) => tester.pump())',
      isAlive: isAlive,
    );
    await evalOnDartLibrary.asyncEval(
      'await tester.tap(find.byKey(Key("increment"))).then((_) => tester.pump())',
      isAlive: isAlive,
    );

    expect(
      await providersSub.read(),
      [
        isA<ProviderNode>()
            .having((e) => e.type, 'type', 'ChangeNotifierProvider<Counter>'),
        isA<ProviderNode>().having((e) => e.type, 'type', 'Provider<int>'),
      ],
    );
    expect(
      await countSub.read(),
      isA<NumInstance>().having((e) => e.displayString, 'displayString', '1'),
    );

    await env.flutter!.hotRestart();

    final evalOnDartLibrary2 = EvalOnDartLibrary(
      'package:provider_app/main.dart',
      env.service!,
    );
    addTearDown(evalOnDartLibrary2.dispose);

    expect(await providersSub.read(), [
      isA<ProviderNode>()
          .having((e) => e.type, 'type', 'ChangeNotifierProvider<Counter>'),
    ]);
    expect(
      await countSub.read(),
      isA<NumInstance>().having((e) => e.displayString, 'displayString', '0'),
    );
    // TODO(rrousselGit) unskip test once hot-restart works properly (https://github.com/flutter/devtools/issues/3007)
  }, timeout: const Timeout.factor(8), skip: true);

  group('Provider controllers', () {
    test('can mutate private properties from mixins', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(
        rawInstanceProvider(
          const InstancePath.fromProviderId('0').pathForChild(
            const PathToProperty.objectProperty(
              name: '_privateMixinProperty',
              ownerUri: 'package:provider_app/mixin.dart',
              ownerName: 'Mixin',
            ),
          )!,
        ).future,
      );

      var instance = await sub.read();

      expect(
        instance,
        isA<NumInstance>().having((e) => e.displayString, 'displayString', '0'),
      );

      await instance.setter!('42');

      // read the instance again since it should have changed
      instance = await sub.read();

      expect(
        instance,
        isA<NumInstance>()
            .having((e) => e.displayString, 'displayString', '42'),
      );
    });

    test('rawSortedProviderNodesProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(rawSortedProviderNodesProvider.future);

      await evalOnDartLibrary.asyncEval(
        'await tester.tap(find.byKey(Key("add"))).then((_) => tester.pump())',
        isAlive: isAlive,
      );

      await expectLater(
        sub.read(),
        completion([
          isA<ProviderNode>()
              .having((e) => e.id, 'id', '0')
              .having((e) => e.type, 'type', 'ChangeNotifierProvider<Counter>'),
          isA<ProviderNode>()
              .having((e) => e.id, 'id', '1')
              .having((e) => e.type, 'type', 'Provider<int>'),
        ]),
      );
    }, timeout: const Timeout.factor(8));

    group('rawInstanceProvider', () {
      test('deeply parse complex objects', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final counterFuture = container
            .listen(
              rawInstanceProvider(const InstancePath.fromProviderId('0'))
                  .future,
            )
            .read();

        const complexPath = InstancePath.fromProviderId(
          '0',
          pathToProperty: [
            PathToProperty.objectProperty(
              name: 'complex',
              ownerUri: 'package:provider_app/main.dart',
              ownerName: 'Counter',
            ),
          ],
        );

        final complexFuture = await container
            .listen(rawInstanceProvider(complexPath).future)
            .read();

        final complexPropertiesFuture = Future.wait<MapEntry<String, Object>>([
          for (final field in (complexFuture as ObjectInstance).fields)
            container
                .listen(
                  rawInstanceProvider(
                    complexPath.pathForChild(
                      PathToProperty.objectProperty(
                        name: field.name,
                        ownerUri: 'package:provider_app/main.dart',
                        ownerName: 'ComplexObject',
                      ),
                    )!,
                  ).future,
                )
                .read()
                .then(
                  (value) => MapEntry(field.name, value),
                  onError: (Object err) => MapEntry(field.name, err),
                )
        ]);

        final mapPath = complexPath.pathForChild(
          const PathToProperty.objectProperty(
            name: 'map',
            ownerUri: 'package:provider_app/main.dart',
            ownerName: 'ComplexObject',
          ),
        );

        final mapKeys = await container
            .listen(rawInstanceProvider(mapPath).future)
            .read()
            .then((value) => value as MapInstance);

        final mapItems = Future.wait([
          for (final key in mapKeys.keys)
            container
                .listen(
                  rawInstanceProvider(
                    mapPath.pathForChild(
                      PathToProperty.mapKey(ref: key.instanceRefId),
                    )!,
                  ).future,
                )
                .read()
        ]);

        final listPath = complexPath.pathForChild(
          const PathToProperty.objectProperty(
            name: 'list',
            ownerUri: 'package:provider_app/main.dart',
            ownerName: 'ComplexObject',
          ),
        )!;

        final listItems = Future.wait([
          for (var i = 0; i < 6; i++)
            container
                .listen(
                  rawInstanceProvider(
                    listPath.pathForChild(PathToProperty.listIndex(i))!,
                  ).future,
                )
                .read()
        ]);

        // Counter.complex.list[4].value
        final list4valueFuture = container
            .listen(
              rawInstanceProvider(
                listPath
                    .pathForChild(const PathToProperty.listIndex(4))!
                    .pathForChild(
                      const PathToProperty.objectProperty(
                        name: 'value',
                        ownerUri: 'package:provider_app/main.dart',
                        ownerName: '_SubObject',
                      ),
                    )!,
              ).future,
            )
            .read();

        // Counter.complex.plainInstance.value
        final plainInstanceValueFuture = container
            .listen(
              rawInstanceProvider(
                complexPath
                    .pathForChild(
                      const PathToProperty.objectProperty(
                        name: 'plainInstance',
                        ownerUri: 'package:provider_app/main.dart',
                        ownerName: 'ComplexObject',
                      ),
                    )!
                    .pathForChild(
                      const PathToProperty.objectProperty(
                        name: 'value',
                        ownerUri: 'package:provider_app/main.dart',
                        ownerName: '_SubObject',
                      ),
                    )!,
              ).future,
            )
            .read();

        await expectLater(
          counterFuture,
          completion(
            isA<ObjectInstance>()
                .having((e) => e.type, 'type', 'Counter')
                .having(
                  (e) => e.fields,
                  'fields',
                  containsAllInOrder([
                    isA<ObjectField>()
                        .having((e) => e.name, 'name', 'complex')
                        .having((e) => e.ownerName, 'ownerName', 'Counter')
                        .having((e) => e.isFinal, 'isFinal', true)
                        .having((e) => e.isPrivate, 'isPrivate', false)
                        .having((e) => e.isDefinedByDependency,
                            'isDefinedByDependency', false),
                    isA<ObjectField>()
                        .having((e) => e.ownerName, 'ownerName', 'Counter')
                        .having((e) => e.name, 'name', '_count')
                        .having((e) => e.ownerUri, 'ownerUri',
                            'package:provider_app/main.dart')
                        .having((e) => e.isFinal, 'isFinal', false)
                        .having((e) => e.isPrivate, 'isPrivate', true)
                        .having((e) => e.isDefinedByDependency,
                            'isDefinedByDependency', false),
                    isA<ObjectField>()
                        .having(
                            (e) => e.ownerName, 'ownerName', 'ChangeNotifier')
                        .having((e) => e.name, 'name', '_listeners')
                        .having((e) => e.ownerUri, 'ownerUri',
                            'package:flutter/src/foundation/change_notifier.dart')
                        .having((e) => e.isFinal, 'isFinal', false)
                        .having((e) => e.isPrivate, 'isPrivate', true)
                        .having((e) => e.isDefinedByDependency,
                            'isDefinedByDependency', true),
                    isA<ObjectField>()
                        .having((e) => e.ownerName, 'ownerName', 'Mixin')
                        .having((e) => e.name, 'name', '_privateMixinProperty')
                        .having((e) => e.ownerUri, 'ownerUri',
                            'package:provider_app/mixin.dart')
                        .having((e) => e.isFinal, 'isFinal', false)
                        .having((e) => e.isPrivate, 'isPrivate', true)
                        .having((e) => e.isDefinedByDependency,
                            'isDefinedByDependency', true),
                  ]),
                ),
          ),
        );

        await expectLater(
          complexFuture,
          isA<ObjectInstance>()
              .having((e) => e.type, 'type', 'ComplexObject')
              .having((e) => e.fields, 'fields', [
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'boolean')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'enumeration')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'finalVar')
                .having((e) => e.isFinal, 'isFinal', true)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'float')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'integer')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'lateWithInitializer')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'list')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'map')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'nill')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'plainInstance')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'string')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'uninitializedLate')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
            isA<ObjectField>()
                .having((e) => e.name, 'name', '_getterAndSetter')
                .having((e) => e.isFinal, 'isFinal', false)
                .having((e) => e.isPrivate, 'isPrivate', true)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false),
          ]),
        );

        final complexProperties =
            Map.fromEntries(await complexPropertiesFuture);

        expect(
          complexProperties['boolean'],
          isA<BoolInstance>()
              .having((e) => e.displayString, 'displayString', 'false')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['enumeration'],
          isA<EnumInstance>()
              .having((e) => e.type, 'displayString', 'Enum')
              .having((e) => e.value, 'displayString', 'a')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['finalVar'],
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '42')
              .having((e) => e.setter, 'setter', isNull),
        );

        expect(
          complexProperties['float'],
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '0.42')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['integer'],
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '0')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['lateWithInitializer'],
          isA<SentinelException>().having((e) => e.sentinel.kind,
              'sentinel.kind', SentinelKind.kNotInitialized),
        );

        expect(
          complexProperties['list'],
          isA<ListInstance>()
              .having((e) => e.hash, 'hash', isA<int>())
              .having((e) => e.length, 'length', 6)
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['map'],
          isA<MapInstance>()
              .having((e) => e.hash, 'hash', isA<int>())
              .having((e) => e.keys.length, 'keys.length', 8)
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['nill'],
          isA<NullInstance>(),
        );

        expect(
          complexProperties['plainInstance'],
          isA<ObjectInstance>()
              .having((e) => e.type, 'type', '_SubObject')
              .having((e) => e.fields, 'fields', [
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'value')
                .having((e) => e.isFinal, 'isFinal', true)
                .having((e) => e.isPrivate, 'isPrivate', false)
                .having((e) => e.isDefinedByDependency, 'isDefinedByDependency',
                    false)
          ]).having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['string'],
          isA<StringInstance>()
              .having((e) => e.displayString, 'displayString', 'hello world')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['_getterAndSetter'],
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '0')
              .having((e) => e.setter, 'setter', isNotNull),
        );

        expect(
          complexProperties['uninitializedLate'],
          isA<SentinelException>().having((e) => e.sentinel.kind,
              'sentinel.kind', SentinelKind.kNotInitialized),
        );

        await expectLater(
          listItems,
          completion([
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '42'),
            isA<StringInstance>()
                .having((e) => e.displayString, 'displayString', 'string'),
            isA<ListInstance>().having((e) => e.length, 'length', 0),
            isA<MapInstance>().having((e) => e.keys, 'value', isEmpty),
            isA<ObjectInstance>()
                .having((e) => e.type, 'type', '_SubObject')
                .having((e) => e.fields, 'fields', [
              isA<ObjectField>()
                  .having((e) => e.name, 'name', 'value')
                  .having((e) => e.isFinal, 'isFinal', true)
                  .having((e) => e.isPrivate, 'isPrivate', false)
                  .having((e) => e.isDefinedByDependency,
                      'isDefinedByDependency', false)
            ]),
            isA<NullInstance>()
          ]),
        );

        await expectLater(
          list4valueFuture,
          completion(
            isA<StringInstance>().having(
              (e) => e.displayString,
              'displayString',
              'complex-value',
            ),
          ),
        );

        await expectLater(
          plainInstanceValueFuture,
          completion(
            isA<StringInstance>().having(
              (e) => e.displayString,
              'displayString',
              'hello world',
            ),
          ),
        );

        await expectLater(mapKeys.keys, [
          isA<StringInstance>()
              .having((e) => e.displayString, 'displayString', 'list')
              .having((e) => e.setter, 'setter', null),
          isA<StringInstance>()
              .having((e) => e.displayString, 'displayString', 'string')
              .having((e) => e.setter, 'setter', null),
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '42')
              .having((e) => e.setter, 'setter', null),
          isA<BoolInstance>()
              .having((e) => e.displayString, 'displayString', 'true')
              .having((e) => e.setter, 'setter', null),
          isA<NullInstance>().having((e) => e.setter, 'setter', null),
          isA<ObjectInstance>()
              .having((e) => e.type, 'type', '_SubObject')
              .having((e) => e.setter, 'setter', null)
              .having((e) => e.fields, 'fields', [
            isA<ObjectField>()
                .having((e) => e.name, 'name', 'value')
                .having((e) => e.isFinal, 'isFinal', true)
          ]),
          isA<ObjectInstance>()
              .having((e) => e.type, 'type', 'Object')
              .having((e) => e.setter, 'setter', null),
          isA<StringInstance>()
              .having((e) => e.displayString, 'displayString', 'nested_map')
              .having((e) => e.setter, 'setter', null),
        ]);

        await expectLater(
          mapItems,
          completion([
            isA<ListInstance>()
                .having((e) => e.length, 'length', 1)
                .having((e) => e.setter, 'setter', isNotNull),
            isA<StringInstance>()
                .having((e) => e.displayString, 'displayString', 'string')
                .having((e) => e.setter, 'setter', isNotNull),
            isA<StringInstance>()
                .having((e) => e.displayString, 'displayString', 'number_key')
                .having((e) => e.setter, 'setter', isNotNull),
            isA<StringInstance>()
                .having((e) => e.displayString, 'displayString', 'bool_key')
                .having((e) => e.setter, 'setter', isNotNull),
            isA<NullInstance>().having((e) => e.setter, 'setter', isNotNull),
            isA<ObjectInstance>()
                .having((e) => e.type, 'type', '_SubObject')
                .having((e) => e.setter, 'setter', isNotNull)
                .having((e) => e.fields, 'fields', [
              isA<ObjectField>()
                  .having((e) => e.name, 'name', 'value')
                  .having((e) => e.isFinal, 'isFinal', true)
            ]),
            isA<StringInstance>()
                .having(
                    (e) => e.displayString, 'displayString', 'non-constant key')
                .having((e) => e.setter, 'setter', isNotNull),
            isA<MapInstance>()
                .having((e) => e.setter, 'setter', isNotNull)
                .having((e) => e.keys, 'keys', [
              isA<StringInstance>()
                  .having((e) => e.displayString, 'displayString', 'key')
                  .having((e) => e.setter, 'setter', null),
            ]),
          ]),
        );
      }, timeout: const Timeout.factor(8));

      test('listens to updates from the application side', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Counter._count
        final counter_countSub = container.listen(
          rawInstanceProvider(
            const InstancePath.fromProviderId(
              '0',
              pathToProperty: [
                PathToProperty.objectProperty(
                  name: '_count',
                  ownerUri: 'package:provider_app/main.dart',
                  ownerName: 'Counter',
                ),
              ],
            ),
          ).future,
        );

        await expectLater(
          counter_countSub.read(),
          completion(
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '0'),
          ),
        );

        await evalOnDartLibrary.asyncEval(
          'await tester.tap(find.byKey(Key("increment"))).then((_) => tester.pump())',
          isAlive: isAlive,
        );

        await expectLater(
          counter_countSub.read(),
          completion(
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '1'),
          ),
        );
      }, timeout: const Timeout.factor(8));
    });
  });

  const countPath = InstancePath.fromProviderId('0', pathToProperty: [
    PathToProperty.objectProperty(
      name: '_count',
      ownerUri: 'package:provider_app/main.dart',
      ownerName: 'Counter',
    )
  ]);

  testWidgets('supports edits', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // TODO(rrousselGit) alter the test so that it does not print in the console
    // (eval logs the errors in the console)
    await tester.runAsync(() async {
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('0').evaluate().first",
          isAlive: isAlive,
        ),
        completes,
      );
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('42').evaluate().first",
          isAlive: isAlive,
        ),
        throwsA(anything),
      );

      // wait for the list of providers to be obtained
      await container.listen(rawSortedProviderNodesProvider.future).read();

      final countSub = container.listen(rawInstanceProvider(countPath).future);

      final instance = await countSub.read();

      expect(
        instance,
        isA<NumInstance>()
            .having((e) => e.displayString, 'displayString', '0')
            .having((e) => e.setter, 'setter', isNotNull),
      );

      await instance.setter!('42');

      await expectLater(
        countSub.read(),
        completion(
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '42'),
        ),
      );

      // verify that the UI updated
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('0').evaluate().first",
          isAlive: isAlive,
        ),
        throwsA(anything),
      );
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('42').evaluate().first",
          isAlive: isAlive,
        ),
        completes,
      );
    });
  }, timeout: const Timeout.factor(8));
}
