import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/eval_on_dart_library.dart';
import '../provider/instance_viewer/eval.dart';
import 'nodes/riverpod_node.dart';

final _riverpodEvalProvider =
    libraryEvalProvider('package:riverpod/src/provider.dart');

final riverpodEvalFunctionProvider = FutureProvider.autoDispose(
  (ref) async {
    final isAlive = Disposable();
    ref.onDispose(isAlive.dispose);

    final eval = await ref.watch(_riverpodEvalProvider.future);

    return (String query) => eval.evalInstance(
          'RiverpodBinding.debugInstance.$query',
          isAlive: isAlive,
        );
  },
  name: 'riverpodEvalFunctionProvider',
);

final evalFieldFunctionProvider = FutureProvider.autoDispose(
  (ref) async {
    final isAlive = Disposable();
    ref.onDispose(isAlive.dispose);

    final eval = await ref.watch(_riverpodEvalProvider.future);

    return (String name, Instance instance) => eval.safeGetInstance(
          instance.fields!.firstWhere((e) => e.decl?.name == name).value
              as InstanceRef,
          isAlive,
        );
  },
  name: 'evalFieldFunctionProvider',
);

final evalRiverpodNodeProvider = FutureProvider.autoDispose.family(
  (ref, Instance instance) async {
    final evalField = await ref.watch(evalFieldFunctionProvider.future);

    Future<MapEntry<String, Instance>> mapEntryForKey(String key) async {
      return MapEntry(key, await evalField(key, instance));
    }

    final fieldsMap = Map.fromEntries(
      await Future.wait([
        for (final field in instance.fields!) mapEntryForKey(field.decl!.name!)
      ]),
    );

    return RiverpodNode(
      id: fieldsMap['id']!.valueAsString!,
      containerId: fieldsMap['containerId']!.valueAsString!,
      name: fieldsMap['name']!.kind == InstanceKind.kNull
          ? null
          : fieldsMap['name']!.valueAsString,
      type: fieldsMap['type']!.valueAsString!,
      stateId: fieldsMap['state']!.id!,
      mightBeOutdated: fieldsMap['mightBeOutdated']!.valueAsString == 'true',
    );
  },
  name: 'evalRiverpodNodeProvider',
);

final evalInstanceFunctionProvider = FutureProvider.autoDispose(
  (ref) async {
    final isAlive = Disposable();
    ref.onDispose(isAlive.dispose);
    final eval = await ref.watch(_riverpodEvalProvider.future);

    return (InstanceRef instanceRef) => eval.safeGetInstance(
          instanceRef,
          isAlive,
        );
  },
  name: 'evalInstanceFunctionProvider',
);
