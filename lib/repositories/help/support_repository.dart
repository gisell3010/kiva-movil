import 'package:kiva_mobile_final/services/api_client.dart';

class SupportRepository {
  SupportRepository(this.client);
  final ApiClient client;
  Future<Json> _map(
    String method,
    String path, {
    Json? data,
    Json? query,
    bool public = false,
  }) async => Map<String, dynamic>.from(
    await client.request(method, path, data: data, query: query, auth: !public)
        as Map,
  );
  Future<List<Json>> _pages(
    String path, {
    String method = 'GET',
    Json? data,
    bool public = false,
  }) async {
    final result = <Json>[];
    for (var page = 1; ; page++) {
      final response = await _map(
        method,
        path,
        data: data,
        query: {'page': page, 'page_size': 100},
        public: public,
      );
      final items = (response['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      result.addAll(items);
      if (items.isEmpty || result.length >= (response['total'] as num)) {
        return result;
      }
    }
  }

  Future<Json> create(Json data, {bool public = false}) => _map(
    'POST',
    public ? '/support-reports/public' : '/support-reports',
    data: data,
    public: public,
  );
  Future<List<Json>> reports() => _pages('/support-reports');
  Future<List<Json>> trips() => _pages('/trips');
  Future<Json> detail(int id, {String? token, bool staff = false}) =>
      token != null
      ? _map(
          'POST',
          '/support-reports/public/lookup',
          data: {'report_id': id, 'tracking_token': token},
          public: true,
        )
      : _map('GET', staff ? '/support/reports/$id' : '/support-reports/$id');
  Future<List<Json>> messages(int id, {String? token, bool staff = false}) =>
      token != null
      ? _pages(
          '/support-reports/public/messages',
          method: 'POST',
          data: {'report_id': id, 'tracking_token': token},
          public: true,
        )
      : _pages(
          staff
              ? '/support/reports/$id/messages'
              : '/support-reports/$id/messages',
        );
  Future<Json> reply(
    int id,
    String body, {
    String? token,
    bool staff = false,
    bool internal = false,
  }) => token != null
      ? _map(
          'POST',
          '/support-reports/public/reply',
          data: {'report_id': id, 'tracking_token': token, 'body': body.trim()},
          public: true,
        )
      : _map(
          'POST',
          staff
              ? '/support/reports/$id/messages'
              : '/support-reports/$id/messages',
          data: {'body': body.trim(), 'is_internal': staff && internal},
        );
}
