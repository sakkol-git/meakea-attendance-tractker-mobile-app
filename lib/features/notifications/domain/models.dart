class InboxMessage {
  final String id, title, body;
  final bool read;
  final String? recordId, kind;
  const InboxMessage(
    this.id,
    this.title,
    this.body,
    this.read,
    this.recordId,
    this.kind,
  );
}

class NotificationPreferences {
  final Map<String, bool> values;
  final String? revisionToken;
  NotificationPreferences(Map<String, bool> values, {this.revisionToken})
    : values = Map.unmodifiable(values);

  NotificationPreferences withValue(String key, bool value) =>
      NotificationPreferences({
        ...values,
        key: value,
      }, revisionToken: revisionToken);
}
