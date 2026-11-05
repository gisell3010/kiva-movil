class Validators {
  static final _namePattern = RegExp(
    r"^[\p{L}][\p{L}\p{M}]*(?:\.|[ '’-][\p{L}][\p{L}\p{M}]*\.?)*$",
    unicode: true,
  );
  static final _emailLocal = RegExp(
    r"^[\p{L}\p{N}!#$%&'*+/=?^_`{|}~.-]+$",
    unicode: true,
  );
  static final _domainLabel = RegExp(
    r'^[\p{L}\p{N}](?:[\p{L}\p{N}-]*[\p{L}\p{N}])?$',
    unicode: true,
  );
  static final _lettersOnly = RegExp(r'^[\p{L}]+$', unicode: true);

  static String? requiredText(String? value, {int max = 150, int min = 1}) {
    final text = value?.trim() ?? '';
    if (text.length < min) {
      return min == 1
          ? 'Completa este campo.'
          : 'Escribe al menos $min caracteres.';
    }
    if (text.length > max) return 'Usa hasta $max caracteres.';
    return null;
  }

  static String? personName(
    String? value, {
    bool optional = false,
    int max = 60,
  }) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final lengthError = requiredText(text, min: 1, max: max);
    if (lengthError != null) return lengthError;
    if (text.contains('..') || !_namePattern.hasMatch(text)) {
      return 'Usa letras, espacios, guiones o apóstrofos.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    const error = 'Escribe un correo válido.';
    if (text.isEmpty || text.length > 150 || text.contains('..')) return error;
    if (RegExp(r'\s').hasMatch(text)) return error;

    final parts = text.split('@');
    if (parts.length != 2) return error;
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty || local.length > 64 ||
        local.startsWith('.') || local.endsWith('.') ||
        !_emailLocal.hasMatch(local)) return error;

    final labels = domain.split('.');
    if (labels.length < 2 ||
        labels.any(
          (label) => label.length > 63 || !_domainLabel.hasMatch(label),
        )) {
      return error;
    }
    final topLevel = labels.last;
    if (topLevel.length < 2 ||
        !(_lettersOnly.hasMatch(topLevel) ||
            (topLevel.startsWith('xn--') && topLevel.length > 4))) {
      return error;
    }
    return null;
  }

  static String? username(String? value) =>
      RegExp(r'^[a-z0-9._]{3,50}$').hasMatch(value?.trim().toLowerCase() ?? '')
      ? null
      : 'Usa de 3 a 50 letras, números, puntos o guiones bajos.';

  static String? password(String? value, {bool registration = false}) {
    final length = value?.length ?? 0;
    if (length == 0) return 'Escribe tu contraseña.';
    if (registration && length < 10) return 'Usa al menos 10 caracteres.';
    if (length > 128) return 'Usa hasta 128 caracteres.';
    return null;
  }

  static String? reportId(String? value) {
    final id = int.tryParse(value?.trim() ?? '');
    if (id == null || id < 1 || id > 2147483647) {
      return 'Escribe un número de reporte válido.';
    }
    return null;
  }
}
