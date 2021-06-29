import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vm_service/vm_service.dart';

import '../../eval_on_dart_library.dart';
import '../../globals.dart';
import '../models/bloc_object.dart';

part 'bloc_list_event.dart';
part 'bloc_list_state.dart';

class BlocListBloc extends Bloc<BlocListEvent, BlocListState> {
  BlocListBloc(this._evalOnDartLibrary) : super(BlocListLoadInProgress()) {
    _postEventSubscription =
        serviceManager.service.onExtensionEvent.where((event) {
      return event.extensionKind == 'bloc:bloc_map_changed';
    }).listen((_) {
      add(BlocListRequested());
    });
    add(BlocListRequested());
  }

  final EvalOnDartLibrary _evalOnDartLibrary;
  StreamSubscription<void> _postEventSubscription;

  @override
  Future<void> close() {
    _postEventSubscription.cancel();
    return super.close();
  }

  @override
  Stream<BlocListState> mapEventToState(
    BlocListEvent event,
  ) async* {
    if (event is BlocListRequested) {
      yield* _mapBlocListRequestedToState(event);
    } else if (event is BlocSelected) {
      yield* _mapBlocSelectedToState(event);
    }
  }

  Stream<BlocListState> _mapBlocListRequestedToState(
      BlocListRequested event) async* {
    yield BlocListLoadInProgress();
    try {
      final List<BlocObject> blocList = await _getBlocList();
      yield BlocListLoadSuccess(blocList, null);
    } catch (_) {
      yield BlocListLoadFailure();
    }
  }

  Stream<BlocListState> _mapBlocSelectedToState(BlocSelected event) async* {
    try {
      final List<BlocObject> blocList = await _getBlocList();
      final String selectedBlocId = event.blocIdSelected;
      yield BlocListLoadSuccess(blocList, selectedBlocId);
    } catch (_) {
      yield BlocListLoadFailure();
    }
  }

  Future<List<BlocObject>> _getBlocList() async {
    final observerRef = await _evalOnDartLibrary
        .safeEval('Bloc.observer.blocMap', isAlive: null);
    final observers = await _evalOnDartLibrary.getInstance(observerRef, null);
    final List<BlocObject> blocs = [];
    for (var element in observers.associations) {
      final keyResult = element.key;
      final valueResult = element.value;
      if (keyResult is! Sentinel && valueResult is! Sentinel) {
        final elementId = element.key.valueAsString;
        final elementType = element.value.classRef.name;
        final BlocObject next = BlocObject(elementId, elementType);
        blocs.add(next);
      }
    }
    return blocs;
  }
}
