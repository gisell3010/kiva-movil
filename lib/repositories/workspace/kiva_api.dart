import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:kiva_mobile_final/services/api_client.dart';

typedef KivaMap = Map<String, dynamic>;

/// Acceso a los recursos de la API pública de KIVA.
///
/// Las validaciones de autorización siguen estando en FastAPI. Esta capa solo
/// compone rutas permitidas y convierte las respuestas paginadas a colecciones
/// cómodas para las vistas móviles.
class KivaApi {
  KivaApi(this.client);

  final ApiClient client;

  KivaMap _query(Map<String, Object?> values) => <String, dynamic>{
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value,
  };

  Future<dynamic> _request(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    bool auth = true,
    ResponseType? responseType,
  }) => client.request(
    method,
    path,
    data: data,
    query: query == null ? null : _query(query),
    auth: auth,
    responseType: responseType,
  );

  Future<KivaMap> map(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    final value = await _request(
      method,
      path,
      data: data,
      query: query,
      auth: auth,
    );
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<List<KivaMap>> list(
    String path, {
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    final value = await _request(
      path.startsWith('/calendar') ? 'GET' : 'GET',
      path,
      query: query,
      auth: auth,
    );
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (value is Map && value['items'] is List) {
      return (value['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <KivaMap>[];
  }

  Future<KivaMap> page(
    String path, {
    int pageNumber = 1,
    int pageSize = 100,
    Map<String, Object?>? filters,
  }) async {
    final query = <String, Object?>{
      'page': pageNumber,
      'page_size': pageSize,
      ...?filters,
    };
    return map('GET', path, query: query);
  }

  Future<List<KivaMap>> all(
    String path, {
    Map<String, Object?>? filters,
    int pageSize = 100,
  }) async {
    final result = <KivaMap>[];
    var pageNumber = 1;
    var total = 0;
    do {
      final response = await page(
        path,
        pageNumber: pageNumber,
        pageSize: pageSize,
        filters: filters,
      );
      final items = response['items'];
      if (items is! List) break;
      result.addAll(
        items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      );
      total = int.tryParse(response['total'].toString()) ?? result.length;
      pageNumber += 1;
    } while (result.length < total && pageNumber <= 100);
    return result;
  }

  Future<void> empty(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    await _request(method, path, data: data, query: query, auth: auth);
  }

  Future<List<KivaMap>> groups({String? search}) =>
      all('/groups', filters: {'q': search});

  Future<KivaMap> group(int id) => map('GET', '/groups/$id');
  Future<KivaMap> createGroup(String name, String? description) => map(
    'POST',
    '/groups',
    data: <String, dynamic>{
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    },
  );
  Future<KivaMap> updateGroup(int id, Map<String, dynamic> data) =>
      map('PATCH', '/groups/$id', data: data);
  Future<void> deleteGroup(int id) => empty('DELETE', '/groups/$id');
  Future<List<KivaMap>> groupMembers(int id) => all('/groups/$id/members');
  Future<KivaMap> addGroupMember(int groupId, int userId) => map(
    'POST',
    '/groups/$groupId/members',
    data: <String, dynamic>{'user_id': userId},
  );
  Future<void> removeGroupMember(int groupId, int userId) =>
      empty('DELETE', '/groups/$groupId/members/$userId');
  Future<KivaMap> transferGroup(int groupId, int userId) => map(
    'POST',
    '/groups/$groupId/ownership',
    data: <String, dynamic>{'new_owner_user_id': userId},
  );

  Future<List<KivaMap>> trips({int? groupId, String? status}) async {
    return all('/trips', filters: {'group_id': groupId, 'status': status});
  }

  Future<KivaMap> trip(int id) => map('GET', '/trips/$id');
  Future<KivaMap> createTrip(Map<String, dynamic> data) =>
      map('POST', '/trips', data: data);
  Future<KivaMap> updateTrip(int id, Map<String, dynamic> data) =>
      map('PATCH', '/trips/$id', data: data);
  Future<void> deleteTrip(int id) => empty('DELETE', '/trips/$id');
  Future<List<KivaMap>> tripMembers(int id) async {
    return all('/trips/$id/members');
  }

  Future<KivaMap> addTripMember(int tripId, int userId, String role) => map(
    'POST',
    '/trips/$tripId/members',
    data: <String, dynamic>{'user_id': userId, 'role': role},
  );
  Future<KivaMap> updateTripMember(int tripId, int userId, String role) =>
      map('PATCH', '/trips/$tripId/members/$userId', data: {'role': role});
  Future<void> removeTripMember(int tripId, int userId) =>
      empty('DELETE', '/trips/$tripId/members/$userId');
  Future<KivaMap> transferTrip(int tripId, int userId) => map(
    'POST',
    '/trips/$tripId/ownership',
    data: <String, dynamic>{'new_owner_user_id': userId},
  );

  Future<List<KivaMap>> tripCollection(int tripId, String resource) =>
      all('/trips/$tripId/$resource');

  Future<KivaMap> tripItem(int tripId, String resource, int id) =>
      map('GET', '/trips/$tripId/$resource/$id');
  Future<KivaMap> createTripItem(
    int tripId,
    String resource,
    Map<String, dynamic> data,
  ) => map('POST', '/trips/$tripId/$resource', data: data);
  Future<KivaMap> updateTripItem(
    int tripId,
    String resource,
    int id,
    Map<String, dynamic> data,
  ) => map('PATCH', '/trips/$tripId/$resource/$id', data: data);
  Future<void> deleteTripItem(int tripId, String resource, int id) =>
      empty('DELETE', '/trips/$tripId/$resource/$id');

  Future<List<KivaMap>> expenseBalances(int tripId) =>
      list('/trips/$tripId/expenses/balances');

  Future<KivaMap> addPollOption(int tripId, int pollId, String text) => map(
    'POST',
    '/trips/$tripId/polls/$pollId/options',
    data: {'option_text': text},
  );
  Future<KivaMap> updatePollOption(
    int tripId,
    int pollId,
    int optionId,
    Map<String, dynamic> data,
  ) => map(
    'PATCH',
    '/trips/$tripId/polls/$pollId/options/$optionId',
    data: data,
  );
  Future<void> deletePollOption(int tripId, int pollId, int optionId) =>
      empty('DELETE', '/trips/$tripId/polls/$pollId/options/$optionId');
  Future<KivaMap> pollResults(int tripId, int pollId) =>
      map('GET', '/trips/$tripId/polls/$pollId/results');

  Future<KivaMap> selectDestination(int tripId, int id, bool selected) => map(
    'PUT',
    '/trips/$tripId/destinations/$id/selection',
    data: {'is_selected': selected},
  );
  Future<List<KivaMap>> destinationPhotos(
    int tripId,
    int destinationId,
  ) async => list('/trips/$tripId/destinations/$destinationId/photos');

  Future<Uint8List> destinationPhotoBytes(
    int tripId,
    int destinationId,
    int photoId,
  ) => client.bytes(
    '/trips/$tripId/destinations/$destinationId/photos/$photoId/file',
  );

  Future<KivaMap> uploadDestinationPhoto(
    int tripId,
    int destinationId,
    Uint8List bytes,
    String filename,
  ) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return map(
      'POST',
      '/trips/$tripId/destinations/$destinationId/photos',
      data: form,
    );
  }

  Future<List<KivaMap>> reorderDestinationPhotos(
    int tripId,
    int destinationId,
    List<int> photoIds,
  ) async {
    final value = await _request(
      'PUT',
      '/trips/$tripId/destinations/$destinationId/photos/order',
      data: <String, dynamic>{'photo_ids': photoIds},
    );
    return value is List
        ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <KivaMap>[];
  }

  Future<void> deleteDestinationPhoto(
    int tripId,
    int destinationId,
    int photoId,
  ) => empty(
    'DELETE',
    '/trips/$tripId/destinations/$destinationId/photos/$photoId',
  );

  Future<List<KivaMap>> calendar({
    required String startDate,
    required String endDate,
    int? tripId,
  }) => list(
    '/calendar',
    query: {'start_date': startDate, 'end_date': endDate, 'trip_id': tripId},
  );

  Future<List<KivaMap>> searchUsers(String username) async {
    final response = await page(
      '/users/search',
      filters: {'username': username},
    );
    final items = response['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <KivaMap>[];
  }

  Future<KivaMap> me() => map('GET', '/users/me');
  Future<KivaMap> updateMe(Map<String, dynamic> data) =>
      map('PATCH', '/users/me', data: data);
  Future<void> changePassword(Map<String, dynamic> data) =>
      empty('PUT', '/users/me/password', data: data);
  Future<KivaMap> changeEmail(Map<String, dynamic> data) =>
      map('PUT', '/users/me/email', data: data);
  Future<KivaMap> uploadProfileImage(Uint8List bytes, String filename) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return map('PUT', '/users/me/profile-image', data: form);
  }

  Future<void> deleteProfileImage() =>
      empty('DELETE', '/users/me/profile-image');
  Future<List<KivaMap>> sessions() async => list('/auth/sessions');
  Future<void> revokeSession(int id) => empty('DELETE', '/auth/sessions/$id');
  Future<void> logoutAll() =>
      empty('POST', '/auth/logout-all', data: <String, dynamic>{});

  Future<List<KivaMap>> notifications({bool? isRead}) async {
    return all('/notifications', filters: {'is_read': isRead});
  }

  Future<KivaMap> unreadCount() => map('GET', '/notifications/unread-count');
  Future<KivaMap> markNotificationRead(int id, bool value) =>
      map('PATCH', '/notifications/$id', data: {'is_read': value});
  Future<void> markAllNotificationsRead() =>
      empty('POST', '/notifications/read-all', data: <String, dynamic>{});
  Future<void> deleteNotification(int id) =>
      empty('DELETE', '/notifications/$id');

  Future<List<KivaMap>> catalog(String name) => list('/catalogs/$name');

  Future<KivaMap> supportDashboard() => map('GET', '/support/dashboard');
  Future<List<KivaMap>> supportReports({Map<String, Object?>? filters}) async {
    return all('/support/reports', filters: filters);
  }

  Future<KivaMap> supportReport(int id) => map('GET', '/support/reports/$id');
  Future<KivaMap> assignSupportSelf(int id) => map(
    'POST',
    '/support/reports/$id/assign-self',
    data: <String, dynamic>{},
  );
  Future<KivaMap> assignSupport(int id, int userId) => map(
    'POST',
    '/support/reports/$id/assign',
    data: <String, dynamic>{'user_id': userId},
  );
  Future<KivaMap> updateSupportReport(int id, Map<String, dynamic> data) =>
      map('PATCH', '/support/reports/$id', data: data);
  Future<KivaMap> escalateSupport(int id, String reason) => map(
    'POST',
    '/support/reports/$id/escalate',
    data: <String, dynamic>{'reason': reason},
  );
  Future<List<KivaMap>> supportAgents() => list('/support/agents');
  Future<List<KivaMap>> supportUsers({Map<String, Object?>? filters}) async {
    return all('/support/users', filters: filters);
  }

  Future<KivaMap> supportUser(int id) => map('GET', '/support/users/$id');
  Future<List<KivaMap>> supportUserGroups(int id) async {
    return all('/support/users/$id/groups');
  }

  Future<List<KivaMap>> supportUserTrips(int id) async {
    return all('/support/users/$id/trips');
  }

  Future<KivaMap> supportTrip(int id) => map('GET', '/support/trips/$id');
  Future<List<KivaMap>> diagnostic(int tripId, String section) async {
    final response = await page(
      '/support/trips/$tripId/diagnostic/$section',
      pageSize: 100,
    );
    final items = response['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <KivaMap>[];
  }

  Future<List<KivaMap>> reportMessages(int id, {bool staff = false}) async {
    final path = staff
        ? '/support/reports/$id/messages'
        : '/support-reports/$id/messages';
    final response = await page(path, pageSize: 100);
    final items = response['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <KivaMap>[];
  }

  Future<KivaMap> sendReportMessage(
    int id,
    String body, {
    bool staff = false,
    bool internal = false,
  }) => map(
    'POST',
    staff ? '/support/reports/$id/messages' : '/support-reports/$id/messages',
    data: <String, dynamic>{'body': body, 'is_internal': internal},
  );
  Future<KivaMap> createReport(Map<String, dynamic> data) =>
      map('POST', '/support-reports', data: data);
  Future<List<KivaMap>> myReports() async {
    return all('/support-reports');
  }

  Future<KivaMap> publicReport(Map<String, dynamic> data) =>
      map('POST', '/support-reports/public', data: data, auth: false);
  Future<KivaMap> lookupPublicReport(int reportId, String trackingToken) => map(
    'POST',
    '/support-reports/public/lookup',
    data: <String, dynamic>{
      'report_id': reportId,
      'tracking_token': trackingToken,
    },
    auth: false,
  );
  Future<List<KivaMap>> publicMessages(
    int reportId,
    String trackingToken,
  ) async {
    final response = await map(
      'POST',
      '/support-reports/public/messages',
      data: <String, dynamic>{
        'report_id': reportId,
        'tracking_token': trackingToken,
      },
      auth: false,
    );
    final items = response['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <KivaMap>[];
  }

  Future<KivaMap> publicReply(
    int reportId,
    String trackingToken,
    String body,
  ) => map(
    'POST',
    '/support-reports/public/reply',
    data: <String, dynamic>{
      'report_id': reportId,
      'tracking_token': trackingToken,
      'body': body,
    },
    auth: false,
  );

  Future<KivaMap> adminDashboard() => map('GET', '/admin/dashboard');
  Future<KivaMap> superAdminDashboard() => map('GET', '/super-admin/dashboard');
  Future<List<KivaMap>> adminUsers({Map<String, Object?>? filters}) async {
    return all('/admin/users', filters: filters);
  }

  Future<KivaMap> adminUser(int id) => map('GET', '/admin/users/$id');
  Future<KivaMap> updateAdminUser(int id, Map<String, dynamic> data) =>
      map('PATCH', '/admin/users/$id', data: data);
  Future<List<KivaMap>> adminGroups({String? search}) async {
    return all('/admin/groups', filters: {'q': search});
  }

  Future<List<KivaMap>> adminTrips({Map<String, Object?>? filters}) async {
    return all('/admin/trips', filters: filters);
  }

  Future<KivaMap> systemConfig() => map('GET', '/super-admin/config');
  Future<List<KivaMap>> auditLogs({Map<String, Object?>? filters}) async {
    return all('/super-admin/audit-logs', filters: filters);
  }

  Future<KivaMap> systemHealth() => map('GET', '/super-admin/health');
}
