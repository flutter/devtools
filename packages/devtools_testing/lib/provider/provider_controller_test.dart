// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member, non_constant_identifier_names

import 'package:devtools_app/src/provider/provider_state_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/provider/eval.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devtools_app/src/globals.dart';

import '../support/flutter_test_environment.dart';

Future<void> runProviderControllerTests(FlutterTestEnvironment env) async {
  EvalOnDartLibrary evalOnDartLibrary;
  IsAlive isAlive;

  setUp(() async {
    await env.setupEnvironment();
    await serviceManager.service.allFuturesCompleted;

    isAlive = IsAlive();
    evalOnDartLibrary = EvalOnDartLibrary(
      [
        'package:provider_app/main.dart',
        'package:provider_app/tester.dart',
      ],
      env.service,
    );
  });

  tearDown(() async {
    isAlive.dispose();
    evalOnDartLibrary.dispose();
    await env.tearDownEnvironment(force: true);
  });

  group('Provider controllers', () {
    test('providerIdsProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(providerIdsProvider.last);

      await expectLater(
        sub.read(),
        completion(['0']),
      );

      await evalOnDartLibrary.awaitEval(
        'tester.tap(find.byKey(Key("add"))).then((_) => tester.pump())',
        isAlive: isAlive,
      );

      await expectLater(
        sub.read(),
        completion(['0', '1']),
      );

      await evalOnDartLibrary.awaitEval(
        'tester.tap(find.byKey(Key("remove"))).then((_) => tester.pump())',
        isAlive: isAlive,
      );

      await expectLater(
        sub.read(),
        completion(['0']),
      );
    });

    test('providerNodeProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub0 = container.listen(providerNodeProvider('0').last);

      await evalOnDartLibrary.awaitEval(
        'tester.tap(find.byKey(Key("add"))).then((_) => tester.pump())',
        isAlive: isAlive,
      );

      await expectLater(
        sub0.read(),
        completion(
          isA<ProviderNode>()
              .having((e) => e.id, 'id', '0')
              .having((e) => e.type, 'type', 'ChangeNotifierProvider<Counter>'),
        ),
      );

      final sub1 = container.listen(providerNodeProvider('1').last);

      await expectLater(
        sub1.read(),
        completion(
          isA<ProviderNode>()
              .having((e) => e.id, 'id', '1')
              .having((e) => e.type, 'type', 'Provider<int>'),
        ),
      );
    });

    group('instanceProvider', () {
      // TODO(rrousselGit) test `late final property = value`
      test('deeply parse complex objects', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final counterFuture = container
            .listen(
              instanceProvider(const InstancePath.fromProvider('0')).future,
            )
            .read();

        final complexFuture = await container
            .listen(
              instanceProvider(
                const InstancePath.fromProvider(
                  '0',
                  pathToProperty: ['complex'],
                ),
              ).future,
            )
            .read();

        final complexProperties = Future.wait([
          for (final fieldName in (complexFuture as ObjectInstance).fieldsName)
            container
                .listen(
                  instanceProvider(
                    InstancePath.fromProvider(
                      '0',
                      pathToProperty: ['complex', fieldName],
                    ),
                  ).future,
                )
                .read()
        ]);

        final listItems = Future.wait([
          for (var i = 0; i < 6; i++)
            container
                .listen(
                  instanceProvider(
                    InstancePath.fromProvider('0',
                        pathToProperty: ['complex', 'list', '$i']),
                  ).future,
                )
                .read()
        ]);

        // Counter.complex.list[4].value
        final list4valueFuture = container
            .listen(
              instanceProvider(
                const InstancePath.fromProvider(
                  '0',
                  pathToProperty: ['complex', 'list', '4', 'value'],
                ),
              ).future,
            )
            .read();

        // Counter.complex.plainInstance.value
        final plainInstanceValueFuture = container
            .listen(
              instanceProvider(
                const InstancePath.fromProvider(
                  '0',
                  pathToProperty: ['complex', 'plainInstance', 'value'],
                ),
              ).future,
            )
            .read();

        await expectLater(
          counterFuture,
          completion(
            isA<ObjectInstance>()
                .having((e) => e.type, 'type', 'Counter')
                .having((e) => e.hash, 'hash', '0002a')
                .having((e) => e.fieldsName, 'fields',
                    ['complex', '_count', '_listeners']),
          ),
        );

        await expectLater(
          complexFuture,
          isA<ObjectInstance>()
              .having((e) => e.type, 'type', 'ComplexObject')
              .having((e) => e.hash, 'hash', '00015')
              .having((e) => e.fieldsName, 'fields', [
            'boolean',
            'enumeration',
            'float',
            'integer',
            'list',
            'map',
            'nill',
            'plainInstance',
            'string',
            'type',
          ]),
        );

        await expectLater(
          complexProperties,
          completion([
            isA<BoolInstance>()
                .having((e) => e.displayString, 'displayString', 'false'),
            isA<EnumInstance>()
                .having((e) => e.type, 'displayString', 'Enum')
                .having((e) => e.value, 'displayString', 'a'),
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '0.42'),
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '0'),
            isA<ListInstance>()
                .having((e) => e.hash, 'hash', isNotEmpty)
                .having((e) => e.length, 'length', 6),
            isA<MapInstance>()
                .having((e) => e.hash, 'hash', isNotEmpty)
                .having((e) => e.keys.length, 'keys.length', 8),
            isA<NullInstance>(),
            isA<ObjectInstance>()
                .having((e) => e.type, 'type', '_SubObject')
                .having((e) => e.fieldsName, 'fields', ['value']),
            isA<StringInstance>()
                .having((e) => e.displayString, 'displayString', 'hello world'),
            // TODO(rrousselGit) figure out why `type` resolves with a SentinelKind.collected
            anything,
          ]),
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
                .having((e) => e.fieldsName, 'fields', ['value']),
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

        // TODO(rrousselGit) test map rendering
      });

      test('listens to updates from the application side', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Counter._count
        final counter_countSub = container.listen(
          instanceProvider(
            const InstancePath.fromProvider(
              '0',
              pathToProperty: ['_count'],
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

        await evalOnDartLibrary.awaitEval(
          'tester.tap(find.byKey(Key("increment"))).then((_) => tester.pump())',
          isAlive: isAlive,
        );

        await expectLater(
          counter_countSub.read(),
          completion(
            isA<NumInstance>()
                .having((e) => e.displayString, 'displayString', '1'),
          ),
        );
      });
    });
  });
}
