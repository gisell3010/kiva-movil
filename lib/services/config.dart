class ApiConfig {
  static const defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kiva-api.onrender.com/api',
  );
  static Uri validate(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.path.replaceAll(RegExp(r'/$'), '') != '/api') {
      throw const FormatException('La dirección del servicio no es válida.');
    }
    return uri.replace(path: '/api');
  }
}
