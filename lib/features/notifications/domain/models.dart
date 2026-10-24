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
