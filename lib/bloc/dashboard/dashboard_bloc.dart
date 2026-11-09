import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiva_mobile_final/repositories/dashboard/dashboard_repository.dart';
import 'package:kiva_mobile_final/services/errors.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
export 'dashboard_event.dart';
export 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this.repository) : super(const DashboardState()) {
    on<DashboardRequested>((event, emit) async {
      emit(DashboardState(loading: true, data: state.data));
      try {
        final data = event.workspace
            ? await repository.workspace(event.account)
            : await repository.personal();
        emit(DashboardState(data: data));
      } catch (error) {
        emit(DashboardState(data: state.data, error: friendlyError(error)));
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final DashboardRepository repository;
  Future<void> refresh(DashboardRequested event) async {
    if (isClosed || state.loading) return;
    final completed = stream.firstWhere((state) => !state.loading);
    add(event);
    await completed;
  }
}
