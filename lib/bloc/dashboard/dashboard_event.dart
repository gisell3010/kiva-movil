import 'package:kiva_mobile_final/models/account.dart';

sealed class DashboardEvent {
  const DashboardEvent();
}

final class DashboardRequested extends DashboardEvent {
  const DashboardRequested({required this.account, required this.workspace});
  final Account account;
  final bool workspace;
}
