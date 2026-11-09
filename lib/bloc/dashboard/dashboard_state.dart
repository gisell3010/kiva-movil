import 'package:kiva_mobile_final/services/api_client.dart';

class DashboardState {
  const DashboardState({this.loading = false, this.data, this.error});
  final bool loading;
  final Json? data;
  final String? error;
}
