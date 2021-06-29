part of 'bloc_list_bloc.dart';

abstract class BlocListState extends Equatable {
  const BlocListState();

  @override
  List<Object> get props => [];
}

class BlocListInitial extends BlocListState {}

class BlocListLoadInProgress extends BlocListState {}

class BlocListLoadSuccess extends BlocListState {
  const BlocListLoadSuccess(this.blocs, this.selectedBlocId)
      : assert(blocs != null);

  final List<BlocObject> blocs;
  final String selectedBlocId;

  @override
  List<Object> get props => [blocs, selectedBlocId];
}

class BlocListLoadFailure extends BlocListState {}
