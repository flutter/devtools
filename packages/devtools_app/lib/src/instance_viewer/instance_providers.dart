// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' hide SentinelException;

import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../result.dart';
import 'eval.dart';

part 'instance_providers.freezed.dart';

@freezed
abstract class ProviderId with _$ProviderId {
  const factory ProviderId({
    @required String containerId,
    @required String providerId,
  }) = _ProviderId;
}

// TODO make sure that expansion state is preserved between state update (refs could change, breaking it)

@freezed
abstract class PathToProperty with _$PathToProperty {
  const factory PathToProperty.listIndex(int index) = _ListIndexPath;

  // TODO test that mutating a Map does not collapse previously expanded keys
  const factory PathToProperty.mapKey({
    @required @nullable String ref,
  }) = _MapKeyPath;

  /// Must not depend on [InstanceRef] and its ID, as they may change across
  /// re-evaluations of the object.
  /// Depending on those would lead to the UI collapsing previously expanded objects
  /// because the new path to a property would be different.
  ///
  /// We can't just rely on the property name either, because in some cases
  /// an object can have multiple properties with the same name (private properties
  /// defined in different libraries)
  const factory PathToProperty.objectProperty({
    @required String name,

    /// Path to the class/mixin that defined this property
    @required String ownerUri,

    /// Name of the class/mixin that defined this property
    @required String ownerName,
  }) = _PropertyPath;

  factory PathToProperty.fromObjectField(ObjectField field) {
    return PathToProperty.objectProperty(
      name: field.name,
      ownerUri: field.ownerUri,
      ownerName: field.ownerName,
    );
  }
}

/// The path to visit child elements of an [Instance] or providers from `provider`/`riverpod`.
@freezed
abstract class InstancePath with _$InstancePath {
  const InstancePath._();

  const factory InstancePath.fromInstanceId(
    @nullable String instanceId, {
    @Default([]) List<PathToProperty> pathToProperty,
  }) = _InstancePathFromInstanceId;

  const factory InstancePath.fromProviderId(
    String providerId, {
    @Default([]) List<PathToProperty> pathToProperty,
  }) = _InstancePathFromProviderId;

  const factory InstancePath.fromRiverpodId(
    ProviderId riverpodId, {
    @Default([]) List<PathToProperty> pathToProperty,
  }) = _InstancePathFromRiverpodId;

  InstancePath get root => copyWith(pathToProperty: []);

  InstancePath get parent {
    if (pathToProperty.isEmpty) return null;

    return copyWith(
      pathToProperty: [
        for (var i = 0; i + 1 < pathToProperty.length; i++) pathToProperty[i],
      ],
    );
  }

  InstancePath pathForChild(PathToProperty property) {
    return copyWith(
      pathToProperty: [...pathToProperty, property],
    );
  }
}

typedef Setter = Future<void> Function(String);

@freezed
abstract class ObjectField with _$ObjectField {
  factory ObjectField({
    @required String name,
    @required bool isFinal,
    @required String ownerName,
    @required String ownerUri,
    @required @nullable Result<InstanceRef> ref,

    /// An [EvalOnDartLibrary] that can access this field from the owner object
    @required EvalOnDartLibrary eval,

    /// Whether this field was defined by the inspected app or by one of its dependencies
    ///
    /// This is used by the UI to hide variables that are not useful for the user.
    @required bool isDefinedByDependency,
  }) = _ObjectField;

  ObjectField._();

  bool get isPrivate => name.startsWith('_');
}

@freezed
abstract class InstanceDetails with _$InstanceDetails {
  InstanceDetails._();

  @Assert('instanceRefId == null')
  factory InstanceDetails.nill({
    String instanceRefId,
    @required @nullable Setter setter,
  }) = NullInstance;

  factory InstanceDetails.boolean(
    String displayString, {
    @required String instanceRefId,
    @required @nullable Setter setter,
  }) = BoolInstance;

  factory InstanceDetails.number(
    String displayString, {
    @required String instanceRefId,
    @required @nullable Setter setter,
  }) = NumInstance;

  factory InstanceDetails.string(
    String displayString, {
    @required String instanceRefId,
    @required @nullable Setter setter,
  }) = StringInstance;

  factory InstanceDetails.map(
    List<InstanceDetails> keys, {
    @required String hash,
    @required String instanceRefId,
    @required @nullable Setter setter,
  }) = MapInstance;

  factory InstanceDetails.list({
    @required @nullable int length,
    @required String hash,
    @required String instanceRefId,
    @required @nullable Setter setter,
  }) = ListInstance;

  factory InstanceDetails.object(
    List<ObjectField> fields, {
    @required String type,
    @required String hash,
    @required String instanceRefId,
    @required @nullable Setter setter,

    /// An [EvalOnDartLibrary] associated with the library of this object
    ///
    /// This allows to edit private properties.
    @required EvalOnDartLibrary evalForInstance,
  }) = ObjectInstance;

  factory InstanceDetails.enumeration({
    @required String type,
    @required String value,
    @required @nullable Setter setter,
    @required String instanceRefId,
  }) = EnumInstance;

  bool get isExpandable {
    bool falsy(Object obj) => false;

    return map(
      nill: falsy,
      boolean: falsy,
      number: falsy,
      string: falsy,
      enumeration: falsy,
      map: (instance) => instance.keys.isNotEmpty,
      list: (instance) => instance.length > 0,
      object: (instance) => instance.fields.isNotEmpty,
    );
  }
}

Future<InstanceRef> _resolveInstanceRefForPath(
  InstancePath path, {
  @required AutoDisposeProviderReference ref,
  @required IsAlive isAlive,
  @required InstanceDetails parent,
}) async {
  if (path.pathToProperty.isEmpty) {
    // root of the provider tree

    return path.map(
      fromRiverpodId: (path) async {
        // cause the instances to be re-evaluated when the devtool is notified
        // that a provider changed
        ref.watch(_riverpodChanged(path.riverpodId));

        final eval = ref.watch(riverpodEvalProvider);

        return eval.safeEval(
          'RiverpodBinding.debugInstance.containers["${path.riverpodId.containerId}"]'
          '!.debugProviderElements.firstWhere((p) => p.provider.debugId == "${path.riverpodId.providerId}")'
          '.getExposedValue()',
          isAlive: isAlive,
        );
      },
      fromProviderId: (path) {
        final eval = ref.watch(providerEvalProvider);
        // cause the instances to be re-evaluated when the devtool is notified
        // that a provider changed
        ref.watch(_providerChanged(path.providerId));

        return eval.safeEval(
          'ProviderBinding.debugInstance.providerDetails["${path.providerId}"]!.value',
          isAlive: isAlive,
        );
      },
      fromInstanceId: (path) {
        if (path.instanceId == null) return null;

        final eval = ref.watch(evalProvider);
        return eval.safeEval(
          'value',
          isAlive: isAlive,
          scope: {'value': path.instanceId},
        );
      },
    );
  }

  final eval = ref.watch(evalProvider);

  return parent.maybeMap(
    // TODO: support sets
    // TODO: iterables should use iterators / next() for iterable to navigate, to avoid recomputing the content

    map: (parent) {
      final keyPath = path.pathToProperty.last as _MapKeyPath;
      final key = keyPath.ref == null ? 'null' : 'key';

      return eval.safeEval(
        'parent[$key]',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
          if (keyPath.ref != null) 'key': keyPath.ref
        },
      );
    },
    list: (parent) {
      final indexPath = path.pathToProperty.last as _ListIndexPath;

      return eval.safeEval(
        'parent[${indexPath.index}]',
        isAlive: isAlive,
        scope: {'parent': parent.instanceRefId},
      );
    },
    object: (parent) async {
      final propertyPath = path.pathToProperty.last as _PropertyPath;

      // compare by both name and ref ID because an object may have multiple
      // fields with the same name
      final field = parent.fields.firstWhere((element) =>
          element.name == propertyPath.name &&
          element.ownerName == propertyPath.ownerName &&
          element.ownerUri == propertyPath.ownerUri);

      final ref = field.ref.dataOrThrow;
      if (ref == null) return null;

      // we cannot do `eval('parent.propertyName')` because it is possible for
      // objects to have multiple properties with the same name
      return eval.getInstance(ref, isAlive);
    },
    orElse: () => throw StateError('Cannot mutate $path'),
  );
}

/// Update a variable using the `=` operator.
///
/// In rare cases, it is possible for this function to mutate the wrong property.
/// This can happen when an object contains multiple fields with the same name
/// (such as private properties or overriden properties), where the conflicting
/// fields are both defined in the same library.
Future<void> _mutate(
  String newValueExpression, {
  @required InstancePath path,
  @required AutoDisposeProviderReference ref,
  @required IsAlive isAlive,
  @required InstanceDetails parent,
}) async {
  await parent.maybeMap(
    list: (parent) {
      final eval = ref.watch(evalProvider);
      final indexPath = path.pathToProperty.last as _ListIndexPath;
      return eval.safeEval(
        'parent[${indexPath.index}] = $newValueExpression',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
        },
      );
    },
    map: (parent) {
      final eval = ref.watch(evalProvider);
      final keyPath = path.pathToProperty.last as _MapKeyPath;
      final keyRefVar = keyPath.ref == null ? 'null' : 'key';

      return eval.safeEval(
        'parent[$keyRefVar] = $newValueExpression',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
          if (keyPath.ref != null) 'key': keyPath.ref,
        },
      );
    },
    // TODO test can mutate properties of a mixin placed in a different library that the class that uses it
    object: (parent) {
      final propertyPath = path.pathToProperty.last as _PropertyPath;

      final field =
          parent.fields.firstWhere((f) => f.name == propertyPath.name);

      return field.eval.safeEval(
        'parent.${propertyPath.name} = $newValueExpression',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
        },
      );
    },
    orElse: () => throw StateError('Can only mutate lists/maps/objects'),
  );

  await path.map(
    fromInstanceId: (_) async {},
    fromProviderId: (_) async {},
    fromRiverpodId: (path) async {
      final eval = ref.watch(riverpodEvalProvider);
      await eval.safeEval(
        'RiverpodBinding.debugInstance.containers["${path.riverpodId.containerId}"]'
        '!.debugProviderElements.firstWhere((p) => p.provider.debugId == "${path.riverpodId.providerId}")'
        '.markDidChange()',
        isAlive: isAlive,
      );
    },
  );

  // Since the same object can be used in multiple locations at once, we need
  // to refresh the entire tree instead of just the node that was modified.
  unawaited(ref.container.refresh(rawInstanceProvider(path.root)));

  // Forces the UI to rebuild after the state change
  await serviceManager.performHotReload();
}

Future<InstanceDetails> _resolveParent(
  AutoDisposeProviderReference ref,
  InstancePath path,
) async {
  return path.pathToProperty.isNotEmpty
      ? await ref.watch(rawInstanceProvider(path.parent).future)
      : null;
}

/// Public properties first, then sort alphabetically
int _sortFieldsByName(ObjectField a, ObjectField b) {
  final isAPrivate = a.name.startsWith('_');
  final isBPrivate = b.name.startsWith('_');

  if (isAPrivate && !isBPrivate) {
    return 1;
  }
  if (!isAPrivate && isBPrivate) {
    return -1;
  }

  return a.name.compareTo(b.name);
}

Future<EnumInstance> _tryParseEnum(
  Instance instance, {
  @required EvalOnDartLibrary eval,
  @required IsAlive isAlive,
  @required String instanceRefId,
  @required Setter setter,
}) async {
  if (instance.kind != InstanceKind.kPlainInstance ||
      instance.fields.length != 2) return null;

  InstanceRef findPropertyWithName(String name) {
    return instance.fields
        .firstWhereOrNull((element) => element.decl.name == name)
        ?.value;
  }

  final _nameRef = findPropertyWithName('_name');
  final indexRef = findPropertyWithName('index');

  if (_nameRef == null || indexRef == null) return null;

  final nameInstanceFuture = eval.getInstance(_nameRef, isAlive);
  final indexInstanceFuture = eval.getInstance(indexRef, isAlive);

  final index = await indexInstanceFuture;

  if (index.kind != InstanceKind.kInt) return null;

  final name = await nameInstanceFuture;
  if (name.kind != InstanceKind.kString) return null;

  final nameSplit = name.valueAsString.split('.');

  if (nameSplit.length > 2) return null;

  return EnumInstance(
    type: nameSplit.first,
    value: nameSplit[1],
    instanceRefId: instanceRefId,
    setter: setter,
  );
}

Setter _parseSetter({
  @required InstancePath path,
  @required ProviderReference ref,
  @required IsAlive isAlive,
  @required InstanceDetails parent,
}) {
  if (parent == null) return null;

  Future<void> mutate(String expression) {
    return _mutate(
      expression,
      path: path,
      ref: ref,
      isAlive: isAlive,
      parent: parent,
    );
  }

  return parent.maybeMap(
    // TODO const collections should have no setter
    map: (parent) => mutate,
    list: (parent) => mutate,
    object: (parent) {
      final keyPath = path.pathToProperty.last as _PropertyPath;

      // Mutate properties by name as we can't mutate them from a reference.
      // This may edit the wrong property when an object has two properties with
      // with the same name.
      // TODO use ownerUri
      final field =
          parent.fields.firstWhere((field) => field.name == keyPath.name);

      if (field.isFinal) return null;
      return mutate;
    },
    orElse: () => throw FallThroughError(),
  );
}

/// Fetches informations related to an instance/provider at a given path
///
/// The UI should not be used directly. Instead, use [instanceProvider].
final AutoDisposeFutureProviderFamily<InstanceDetails, InstancePath>
    rawInstanceProvider =
    AutoDisposeFutureProviderFamily<InstanceDetails, InstancePath>(
        (ref, path) async {
  final eval = ref.watch(evalProvider);

  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final parent = await _resolveParent(ref, path);

  InstanceRef instanceRef;

  instanceRef = await _resolveInstanceRefForPath(
    path,
    ref: ref,
    parent: parent,
    isAlive: isAlive,
  );

  final setter = _parseSetter(
    path: path,
    isAlive: isAlive,
    ref: ref,
    parent: parent,
  );

  if (instanceRef == null) {
    return InstanceDetails.nill(setter: setter);
  }

  final instance = await eval.getInstance(instanceRef, isAlive);

  switch (instance.kind) {
    case InstanceKind.kBool:
      return InstanceDetails.boolean(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: setter,
      );
    case InstanceKind.kInt:
    case InstanceKind.kDouble:
      return InstanceDetails.number(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: setter,
      );
    case InstanceKind.kString:
      return InstanceDetails.string(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: setter,
      );

    case InstanceKind.kMap:
      final hashCodeFuture =
          eval.getInstanceHashCode(instanceRef, isAlive: isAlive);

      // voluntarily throw if a key failed to load
      final keysRef = instance.associations.map((e) => e.key as InstanceRef);

      final keysFuture = Future.wait<InstanceDetails>([
        for (final keyRef in keysRef)
          ref.watch(
            rawInstanceProvider(InstancePath.fromInstanceId(keyRef?.id)).future,
          )
      ]);

      return InstanceDetails.map(
        await keysFuture,
        hash: await hashCodeFuture,
        instanceRefId: instanceRef.id,
        setter: setter,
      );

    // TODO(rrousselGit): support sets
    // TODO(rrousselGit): support custom lists
    // TODO(rrousselGit): support Type
    case InstanceKind.kList:
      return InstanceDetails.list(
        length: instance.length,
        hash: await eval.getInstanceHashCode(instanceRef, isAlive: isAlive),
        instanceRefId: instanceRef.id,
        setter: setter,
      );

    case InstanceKind.kPlainInstance:
    default:
      final enumDetails = await _tryParseEnum(
        instance,
        eval: eval,
        isAlive: isAlive,
        instanceRefId: instanceRef.id,
        setter: setter,
      );

      if (enumDetails != null) return enumDetails;

      final hashCodeFuture =
          eval.getInstanceHashCode(instanceRef, isAlive: isAlive);

      final classInstance = await eval.getClass(instance.classRef, isAlive);
      final evalForInstance =
          ref.watch(libraryEvalProvider(classInstance.library.uri));

      final appName = tryParsePackageName(eval.isolate.rootLib.uri);

      final fields = await _parseFields(
        ref,
        eval,
        instance,
        classInstance,
        isAlive: isAlive,
        appName: appName,
      );

      return InstanceDetails.object(
        fields.sorted(_sortFieldsByName),
        hash: await hashCodeFuture,
        type: instance.classRef.name,
        instanceRefId: instanceRef.id,
        evalForInstance: evalForInstance,
        setter: setter,
      );
  }
});

final _instanceCacheProvider = AutoDisposeStateNotifierProviderFamily<
    StateController<AsyncValue<InstanceDetails>>, InstancePath>((ref, path) {
  final controller = StateController<AsyncValue<InstanceDetails>>(
    // It is safe to use `read` here because the provider is immediately listened after
    ref.read(rawInstanceProvider(path)),
  );

  Timer timer;
  ref.onDispose(() => timer?.cancel());

  // TODO(rrousselGit): refactor to use `ref.listen` when available
  final sub = ref.container.listen<AsyncValue<InstanceDetails>>(
    rawInstanceProvider(path),
    mayHaveChanged: (sub) => Future(sub.flush),
    didChange: (sub) {
      timer?.cancel();

      sub.read().map(
            data: (instance) => controller.state = instance,
            error: (instance) => controller.state = instance,
            loading: (instance) {
              timer = Timer(const Duration(seconds: 1), () {
                controller.state = instance;
              });
            },
          );
    },
  );

  ref.onDispose(sub.close);

  return controller;
});

/// [rawInstanceProvider] but the loading state is debounced for one second.
///
/// This avoids flickers when a state is refreshed
final instanceProvider =
    AutoDisposeProviderFamily<AsyncValue<InstanceDetails>, InstancePath>(
        (ref, path) {
  // Hide the StateController as it is an implementation detail
  return ref.watch(_instanceCacheProvider(path).state);
});

final _packageNameExp = RegExp(
  r'package:(.+?)/',
);

String tryParsePackageName(String uri) {
  return _packageNameExp.firstMatch(uri)?.group(1);
}

Future<List<ObjectField>> _parseFields(
  AutoDisposeProviderReference ref,
  EvalOnDartLibrary eval,
  Instance instance,
  Class classInstance, {
  @required IsAlive isAlive,
  @required String appName,
}) async {
  final fields = instance.fields.map((field) async {
    final owner = await eval.getClass(field.decl.owner, isAlive);

    final ownerPackageName = tryParsePackageName(owner.library.uri);

    return ObjectField(
      name: field.decl.name,
      isFinal: field.decl.isFinal,
      ref: parseSentinel<InstanceRef>(field.value),
      ownerName: owner.name,
      ownerUri: owner.library.uri,
      eval: ref.watch(libraryEvalProvider(owner.library.uri)),
      isDefinedByDependency: ownerPackageName == appName,
    );
  }).toList();

  return Future.wait(fields);
}

final _providerChanged =
    AutoDisposeStreamProviderFamily<void, String>((ref, id) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'provider:provider_changed' &&
        event.extensionData.data['id'] == id;
  });
});

final _riverpodChanged =
    AutoDisposeStreamProviderFamily<void, ProviderId>((ref, id) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'riverpod:provider_changed' &&
        event.extensionData.data['provider_id'] == id.providerId &&
        event.extensionData.data['container_id'] == id.containerId;
  });
});

class IsAlive implements Disposable {
  @override
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}
