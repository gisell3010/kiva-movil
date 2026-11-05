/// Conserva los decimales del servidor sin pasar por coma flotante.
String formatMoney(Object value) {
  final text = value.toString();
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return '—';
  final whole = match
      .group(2)!
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (part) => '${part.group(1)!}.',
      );
  final decimal = (match.group(3) ?? '').padRight(2, '0');
  return '${match.group(1)!}$whole,$decimal COP';
}
