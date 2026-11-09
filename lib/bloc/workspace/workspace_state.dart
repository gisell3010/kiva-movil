import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';

enum WorkspaceStatus { initial, loading, ready, saving, failure }

class WorkspaceState {
  const WorkspaceState({
    this.status = WorkspaceStatus.initial,
    this.items = const <KivaMap>[],
    this.trips = const <KivaMap>[],
    this.summary,
    this.tripId,
    this.error,
  });

  final WorkspaceStatus status;
  final List<KivaMap> items;
  final List<KivaMap> trips;
  final KivaMap? summary;
  final int? tripId;
  final Object? error;

  WorkspaceState copyWith({
    WorkspaceStatus? status,
    List<KivaMap>? items,
    List<KivaMap>? trips,
    KivaMap? summary,
    int? tripId,
    Object? error,
  }) => WorkspaceState(
    status: status ?? this.status,
    items: items ?? this.items,
    trips: trips ?? this.trips,
    summary: summary ?? this.summary,
    tripId: tripId ?? this.tripId,
    error: error,
  );
}
