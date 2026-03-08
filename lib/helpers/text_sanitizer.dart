String sanitizeTextInput(
  String? input, {
  bool preserveNewlines = true,
}) {
  if (input == null) return '';

  var sanitized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final invisibleAsciiPattern = preserveNewlines
      ? RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]')
      : RegExp(r'[\x00-\x1F\x7F]');
  sanitized = sanitized.replaceAll(invisibleAsciiPattern, '');

  return sanitized.trim();
}
