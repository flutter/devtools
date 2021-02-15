import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../inspector/inspector_service.dart';
import 'eval.dart';
import 'result.dart';

part 'provider_state_controller.freezed.dart';

@immutable
class InstancePath {
  const InstancePath._({
    @required this.providerId,
    @required this.instanceId,
    @required this.pathToProperty,
  });

  const InstancePath.fromProvider(
    this.providerId, {
    this.pathToProperty = const [],
  }) : instanceId = null;

  const InstancePath.fromInstanceId(
    this.instanceId, {
    this.pathToProperty = const [],
  }) : providerId = null;

  final String providerId;
  final String instanceId;
  final List<String> pathToProperty;

  InstancePath get parent {
    return InstancePath._(
      providerId: providerId,
      instanceId: instanceId,
      pathToProperty: [
        for (var i = 0; i + 1 < pathToProperty.length; i++) pathToProperty[i],
      ],
    );
  }

  InstancePath pathForChild(String property) {
    return InstancePath._(
      providerId: providerId,
      instanceId: instanceId,
      pathToProperty: [...pathToProperty, property],
    );
  }

  @override
  String toString() {
    return 'InstancePath('
        'providerId: "$providerId", '
        'instanceId: "$instanceId", '
        'pathToProperty: $pathToProperty)';
  }

  @override
  bool operator ==(Object other) {
    return other is InstancePath &&
        other.providerId == providerId &&
        other.instanceId == instanceId &&
        const ListEquality<Object>()
            .equals(pathToProperty, other.pathToProperty);
  }

  @override
  int get hashCode =>
      providerId.hashCode ^
      instanceId.hashCode ^
      const ListEquality<Object>().hash(pathToProperty);
}

@immutable
class ProviderNode {
  const ProviderNode({
    @required this.id,
    @required this.type,
  });

  ProviderNode.fromJson(Map<String, dynamic> json)
      : this(
          id: json['id'],
          type: json['type'],
        );

  final String id;
  final String type;
}

final _providerListChanged = AutoDisposeStreamProvider<void>((ref) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'provider:providers_list_changed';
  });
});

final providerIdsProvider =
    AutoDisposeStreamProvider<List<String>>((ref) async* {
  // cause the list of providers to be re-evaluated when notified of a change
  ref.watch(_providerListChanged);

  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final eval = ref.watch(evalProvider);

  final providerIdRefs = await eval.evalInstance(
    'ProviderBinding.debugInstance.providerDetails.keys.toList()',
    isAlive: isAlive,
  );

  final providerIdInstances = await Future.wait([
    for (final idRef in providerIdRefs.elements.cast<InstanceRef>())
      eval.getInstance(idRef, isAlive)
  ]);

  yield [
    for (final idInstance in providerIdInstances) idInstance.valueAsString,
  ];
});

final providerNodeProvider =
    AutoDisposeStreamProviderFamily<ProviderNode, String>((ref, id) async* {
  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final eval = ref.watch(evalProvider);

  final providerNodeInstance = await eval.evalInstance(
    "ProviderBinding.debugInstance.providerDetails['$id']",
    isAlive: isAlive,
  );

  Future<Instance> getFieldWithName(String name) {
    return eval.getInstance(
      providerNodeInstance.fields.firstWhere((e) => e.decl.name == name).value
          as InstanceRef,
      isAlive,
    );
  }

  final type = await getFieldWithName('type');

  yield ProviderNode(
    id: id,
    type: type.valueAsString,
  );
});

typedef Setter = Future<void> Function(String);

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
    List<String> fieldsName, {
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
    return map(
      nill: (_) => false,
      boolean: (_) => false,
      number: (_) => false,
      string: (_) => false,
      map: (instance) => instance.keys.isNotEmpty,
      list: (instance) => instance.length > 0,
      object: (instance) => instance.fieldsName.isNotEmpty,
      enumeration: (_) => false,
    );
  }
}

Future<InstanceRef> _resolveInstanceRefForPath(
  InstancePath path, {
  @required AutoDisposeProviderReference ref,
  @required IsAlive isAlive,
  @required InstanceDetails parent,
}) async {
  final eval = ref.watch(evalProvider);

  if (path.pathToProperty.isEmpty) {
    // root of the provider tree

    if (path.providerId != null) {
      return eval.safeEval(
        'ProviderBinding.debugInstance.providerDetails["${path.providerId}"].value',
        isAlive: isAlive,
      );
    } else {
      if (path.instanceId == null) return null;

      return eval.safeEval(
        'value',
        isAlive: isAlive,
        scope: {'value': path.instanceId},
      );
    }
  }

  return parent.maybeMap(
    // TODO: support sets
    // TODO: iterables should use iterators / next() for iterable to navigate, to avoid recomputing the content

    map: (parent) {
      final key = path.pathToProperty.last == null ? 'null' : 'key';

      return eval.safeEval(
        'parent[$key]',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
          if (path.pathToProperty.last != null) 'key': path.pathToProperty.last,
        },
      );
    },
    list: (parent) {
      return eval.safeEval(
        'parent[${path.pathToProperty.last}]',
        isAlive: isAlive,
        scope: {'parent': parent.instanceRefId},
      );
    },
    object: (parent) async {
      final instance = await eval.getInstanceById(
        parent.instanceRefId,
        isAlive,
      );

      final propertyBoundField = instance.fields.firstWhere((e) {
        return e.decl.name == path.pathToProperty.last;
      });

      return propertyBoundField.value as InstanceRef;
    },
    orElse: () => throw StateError('Cannot mutate $path'),
  );
}

Future<void> _mutate(
  String newValueExpression, {
  @required InstancePath path,
  @required AutoDisposeProviderReference ref,
  @required IsAlive isAlive,
  @required InstanceDetails parent,
}) async {
  final eval = ref.watch(evalProvider);

  await parent.maybeMap(
    list: (parent) => eval.safeEval(
      'parent[${path.pathToProperty.last}] = $newValueExpression',
      isAlive: isAlive,
      scope: {
        'parent': parent.instanceRefId,
      },
    ),
    map: (parent) {
      final key = path.pathToProperty.last == null ? 'null' : 'key';

      return eval.safeEval(
        'parent[$key] = $newValueExpression',
        isAlive: isAlive,
        scope: {
          'parent': parent.instanceRefId,
          if (path.pathToProperty.last != null) 'key': path.pathToProperty.last,
        },
      );
    },
    object: (parent) =>
        // TODO test that we can eval private properties
        parent.evalForInstance.safeEval(
      'parent.${path.pathToProperty.last} = $newValueExpression',
      isAlive: isAlive,
      scope: {
        'parent': parent.instanceRefId,
      },
    ),
    orElse: () => throw StateError('Can only mutate lists/maps/objects'),
  );

  // Since the same object can be used in multiple locations at once, we need
  // to refresh the entire tree instead of just the node that was modified.
  unawaited(ref.container.refresh(instanceProvider(path)));

  // Forces the UI to rebuild after the state change
  await serviceManager.performHotReload();
}

Future<InstanceDetails> _resolveParent(
  AutoDisposeProviderReference ref,
  InstancePath path,
) async {
  return path.pathToProperty.isNotEmpty
      ? await ref.watch(instanceProvider(path.parent).future)
      : null;
}

/// Public properties first, then sort alphabetically
int _sortFieldsByName(String a, String b) {
  final isAPrivate = a.startsWith('_');
  final isBPrivate = b.startsWith('_');

  if (isAPrivate && !isBPrivate) {
    return 1;
  }
  if (!isAPrivate && isBPrivate) {
    return -1;
  }

  return a.compareTo(b);
}

Future<EnumInstance> _tryParseEnum(
  Instance instance, {
  @required EvalOnDartLibrary eval,
  @required IsAlive isAlive,
  @required String instanceRefId,
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
    setter: null,
    instanceRefId: instanceRefId,
  );
}

final AutoDisposeFutureProviderFamily<InstanceDetails, InstancePath>
    instanceProvider =
    AutoDisposeFutureProviderFamily<InstanceDetails, InstancePath>(
        (ref, path) async {
  final eval = ref.watch(evalProvider);

  // cause the instances to be re-evaluated when the devtool is notified
  // that a provider changed
  ref.watch(_providerChanged(path.providerId));

  final isAlive = IsAlive();
  ref.onDispose(isAlive.dispose);

  final parent = await _resolveParent(ref, path);

  final instanceRef = await _resolveInstanceRefForPath(
    path,
    ref: ref,
    parent: parent,
    isAlive: isAlive,
  );

  if (instanceRef == null) {
    return InstanceDetails.nill(
      setter: (value) => _mutate(
        value,
        path: path,
        ref: ref,
        isAlive: isAlive,
        parent: parent,
      ),
    );
  }

  final instance = await eval.getInstance(instanceRef, isAlive);

  switch (instance.kind) {
    case InstanceKind.kBool:
      return InstanceDetails.boolean(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: (value) => _mutate(
          value,
          path: path,
          ref: ref,
          isAlive: isAlive,
          parent: parent,
        ),
      );
    case InstanceKind.kInt:
    case InstanceKind.kDouble:
      return InstanceDetails.number(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: (value) => _mutate(
          value,
          path: path,
          ref: ref,
          isAlive: isAlive,
          parent: parent,
        ),
      );
    case InstanceKind.kString:
      return InstanceDetails.string(
        instance.valueAsString,
        instanceRefId: instanceRef.id,
        setter: (value) => _mutate(
          value,
          path: path,
          ref: ref,
          isAlive: isAlive,
          parent: parent,
        ),
      );

    case InstanceKind.kMap:
      final hashCodeFuture =
          eval.getInstanceHashCode(instance, isAlive: isAlive);

      // voluntarily throw if a key failed to load
      final keysRef = instance.associations.map((e) => e.key as InstanceRef);

      final keysFuture = Future.wait<InstanceDetails>([
        for (final keyRef in keysRef)
          ref.watch(
            instanceProvider(InstancePath.fromInstanceId(keyRef?.id)).future,
          )
      ]);

      return InstanceDetails.map(
        await keysFuture,
        hash: await hashCodeFuture,
        instanceRefId: instanceRef.id,
        setter: null,
      );

    // TODO(rrousselGit): support sets
    // TODO(rrousselGit): support custom lists
    // TODO(rrousselGit): support Type
    case InstanceKind.kList:
      return InstanceDetails.list(
        length: instance.length,
        hash: await eval.getInstanceHashCode(instance, isAlive: isAlive),
        instanceRefId: instanceRef.id,
        setter: null,
      );

    case InstanceKind.kPlainInstance:
    default:
      final enumDetails = await _tryParseEnum(
        instance,
        eval: eval,
        isAlive: isAlive,
        instanceRefId: instanceRef.id,
      );

      if (enumDetails != null) return enumDetails;

      final hashCodeFuture =
          eval.getInstanceHashCode(instance, isAlive: isAlive);

      final classInstance = await eval.getClass(instance.classRef, isAlive);
      final evalForInstance =
          ref.watch(libraryEvalProvider(classInstance.library.uri));

      return InstanceDetails.object(
        instance.fields
            .map((field) => field.decl.name)
            .sorted(_sortFieldsByName),
        hash: await hashCodeFuture,
        type: instance.classRef.name,
        instanceRefId: instanceRef.id,
        setter: null,
        evalForInstance: evalForInstance,
      );
  }
});

final _providerChanged =
    AutoDisposeStreamProviderFamily<void, String>((ref, id) {
  return serviceManager.service.onExtensionEvent.where((event) {
    return event.extensionKind == 'provider:provider_changed' &&
        event.extensionData.data['id'] == id;
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
