/// Inbox and push use the same bounded routes; unknown legacy notices stay readable.
String? notificationRecordPath(Map<String, dynamic> data) {
  final kind = data['kind'], id = data['recordId'];
  if (id is! String || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) return null;
  if (kind == 'attendance') return '/activity';
  return ['leave', 'request', 'correction'].contains(kind)
      ? '/record/$kind/$id'
      : null;
}
