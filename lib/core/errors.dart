import 'package:dio/dio.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    final code = data is Map && data['error'] is Map
        ? data['error']['code']
        : null;
    const messages = {
      'USER_ALREADY_EXISTS':
          'El correo o nombre de usuario ya está registrado.',
      'INVALID_CREDENTIALS': 'Revisa tu correo y contraseña.',
      'ACCOUNT_INACTIVE': 'Tu cuenta está suspendida. Contacta con soporte.',
      'INVALID_SESSION': 'Tu sesión terminó. Vuelve a iniciar sesión.',
      'UNAUTHENTICATED': 'Vuelve a iniciar sesión para continuar.',
      'OWNER_REQUIRED': 'Transfiere la responsabilidad antes de salir.',
      'MEMBER_HAS_TRIPS': 'Primero debes salir de los viajes del grupo.',
      'MEMBER_HAS_RECORDS': 'Esta persona tiene registros asociados al viaje.',
      'GROUP_HAS_TRIPS': 'Elimina los viajes antes de eliminar el grupo.',
      'TRIP_HAS_EXPENSES':
          'El viaje tiene gastos registrados y no se puede eliminar.',
      'TRIP_NOT_EDITABLE': 'Este viaje ya no permite cambios.',
      'INVALID_STATUS': 'Este cambio de estado no está disponible.',
      'POLL_CLOSED': 'Esta votación ya terminó.',
      'POLL_HAS_VOTES':
          'La pregunta y las opciones no se pueden cambiar después de recibir votos.',
      'MEMBER_EXISTS': 'Esta persona ya forma parte del grupo o viaje.',
      'INVALID_SPLITS':
          'Los repartos deben sumar exactamente el total del gasto.',
      'PHOTO_LIMIT': 'Este destino alcanzó el límite de fotos.',
      'IMAGE_SIZE': 'La imagen supera el tamaño permitido.',
      'INVALID_IMAGE': 'Elige una foto JPEG, PNG o WebP sin animación.',
      'REPORT_ASSIGNED': 'Otra persona ya está atendiendo este reporte.',
      'REPORT_NOT_ASSIGNED': 'Toma el reporte antes de responder.',
      'REPORT_FINISHED': 'Este reporte ya está cerrado.',
      'REPORT_ESCALATED': 'Administración está atendiendo este reporte.',
      'REPORT_RATE_LIMIT': 'Espera una hora antes de enviar otra solicitud.',
      'INVALID_PASSWORD': 'La contraseña actual no es correcta.',
    };
    if (messages[code] != null) return messages[code]!;
    switch (error.response?.statusCode) {
      case 401:
        return 'Revisa tus datos o vuelve a iniciar sesión.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'El contenido ya no está disponible.';
      case 409:
        return 'No se pudo guardar el cambio. Actualiza e inténtalo de nuevo.';
      case 413:
        return 'El archivo supera el tamaño permitido.';
      case 422:
        return 'Revisa los datos y vuelve a intentarlo.';
      case 429:
        return 'Has realizado varios intentos. Espera un momento.';
    }
    if (error.response == null) {
      return 'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.';
    }
  }
  return 'No pudimos completar la solicitud. Inténtalo de nuevo.';
}
