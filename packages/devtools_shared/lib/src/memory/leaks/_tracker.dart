// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '_config.dart';
import '_gc_time.dart';
import 'model.dart';

final leakTracker = LeakTracker();

Object _getToken(Object object, Token? token) =>
    token ?? identityHashCode(object);

typedef FinalizerBuilder = Finalizer<Object> Function(
  Function(Token token) gcEventHandler,
);

/// Tracks objects for leaking.
@visibleForTesting
class LeakTracker {
  /// The parameters are injected for testing purposes.
  LeakTracker({
    FinalizerBuilder? finalizerBuilder,
    GCTimeLine? gcTimeLine,
  }) {
    finalizerBuilder ??= (handler) => Finalizer<Object>(handler);
    _finalizer = finalizerBuilder(_objectGarbageCollected);
    _gcTime = gcTimeLine ?? GCTimeLine();
  }

  late Finalizer<Object> _finalizer;
  late GCTimeLine _gcTime;

  // Objects migrate between collections below based on their state.
  // On registration, each object enters collections _notGCed,
  // _notGCedByCode, _notGCedFresh.
  // If the object stays not GCed after disposal too long,
  // it migrates from _notGCedFresh to _notGCedLate.
  //
  // If the object gets GCed, it is removed from all _notGCed... collections,
  // and, if it was GCed wrongly, added to one of _gced... collections.
  final _notGCed = <Token, TrackedObjectInfo>{};
  final _notGCedByCode = <IdentityHashCode, TrackedObjectInfo>{};
  final _notGCedFresh = <Token>{};
  final _notGCedLate = <Token>{};

  final _gcedLateLeaks = <TrackedObjectInfo>[];
  final _gcedNotDisposedLeaks = <TrackedObjectInfo>[];

  void _objectGarbageCollected(Token token) {
    final info = _notGCed[token];
    if (info == null) {
      throw '$token cannot be garbage collected twice.';
    }
    assert(_assertIntegrity(info));
    info.setGCed(_gcTime.now);

    if (info.isGCedLateLeak) {
      _gcedLateLeaks.add(info);
    } else if (info.isNotDisposedLeak) {
      _gcedNotDisposedLeaks.add(info);
    }
    _notGCed.remove(token);
    _notGCedByCode.remove(info.code);
    _notGCedFresh.remove(token);
    _notGCedLate.remove(token);

    assert(_assertIntegrity(info));
  }

  void startTracking(Object object, Token? token) {
    token = _getToken(object, token);
    assert(!_notGCed.containsKey(token));
    _finalizer.attach(object, token);

    final TrackedObjectInfo info = TrackedObjectInfo(
      token,
      objectLocationGetter(object),
      object,
    );

    _notGCed[token] = info;
    _notGCedByCode[identityHashCode(object)] = info;
    _notGCedFresh.add(token);
    assert(_assertIntegrity(info));
  }

  void registerDisposal(Object object, Token? token) {
    token = _getToken(object, token);
    final info = _notGCed[token]!;
    assert(_assertIntegrity(info));

    info.setDisposed(_gcTime.now);

    assert(_assertIntegrity(info));
  }

  bool _assertIntegrity(TrackedObjectInfo info) {
    if (_notGCed.containsKey(info.token)) {
      assert(_notGCed[info.token]!.token == info.token);
      assert(!info.isGCed);
    }

    assert(
      _gcedLateLeaks.contains(info) == info.isGCedLateLeak,
      '${_gcedLateLeaks.contains(info)}, ${info.isDisposed}, ${info.isGCed},',
    );

    assert(
      _gcedNotDisposedLeaks.contains(info) == (info.isGCed && !info.isDisposed),
      '${_gcedNotDisposedLeaks.contains(info)}, ${info.isGCed}, ${!info.isDisposed}',
    );

    return true;
  }

  LeakSummary collectLeaksSummary() {
    _checkForNewNotGCedLeaks();

    return LeakSummary({
      LeakType.notDisposed: _gcedNotDisposedLeaks.length,
      LeakType.notGCed: _notGCedLate.length,
      LeakType.gcedLate: _gcedLateLeaks.length,
    });
  }

  void _checkForNewNotGCedLeaks() {
    assert(_assertIntegrityForAll());
    for (var token in _notGCedFresh.toList(growable: false)) {
      final info = _notGCed[token]!;
      if (info.isNotGCedLeak(_gcTime.now)) {
        _notGCedFresh.remove(token);
        _notGCedLate.add(token);
      }
    }
    _assertIntegrityForAll();
  }

  Leaks collectLeaks() {
    _checkForNewNotGCedLeaks();

    return Leaks({
      LeakType.notDisposed:
          _gcedNotDisposedLeaks.map((i) => i.toLeakReport()).toList(),
      LeakType.notGCed:
          _notGCedLate.map((t) => _notGCed[t]!.toLeakReport()).toList(),
      LeakType.gcedLate: _gcedLateLeaks.map((i) => i.toLeakReport()).toList(),
    });
  }

  bool _assertIntegrityForAll() {
    _assertIntegrityForCollections();
    _notGCed.values.forEach(_assertIntegrity);
    _gcedLateLeaks.forEach(_assertIntegrity);
    _gcedNotDisposedLeaks.forEach(_assertIntegrity);
    return true;
  }

  bool _assertIntegrityForCollections() {
    assert(_notGCed.length == _notGCedFresh.length + _notGCedLate.length);
    return true;
  }

  void registerGCEvent({required bool oldSpace, required bool newSpace}) {
    _gcTime.registerGCEvent({
      if (oldSpace) GCEvent.oldGC,
      if (newSpace) GCEvent.newGC,
    });
  }
}
