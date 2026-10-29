part of 'people_pages.dart';

Future<void> editEntity(
  BuildContext context,
  WidgetRef ref,
  String path,
  String title, {
  JsonMap? existing,
}) async {
  final typedPanelKey = switch (path) {
    '/employees' => 'identity.people',
    '/departments' => 'identity.departments',
    '/positions' => 'identity.positions',
    '/shifts' => 'identity.shifts',
    _ => null,
  };
  if (typedPanelKey != null) {
    final panel = identityPanels.firstWhere((p) => p.key == typedPanelKey);
    final action = existing == null
        ? panel.create!
        : panel.actions.firstWhere((a) => a.key.endsWith('.edit'));
    final record = existing == null
        ? null
        : CaseRecord(
            id: existing['id'] as String,
            title: (existing['name'] ?? title).toString(),
            status: (existing['status'] ?? 'ACTIVE').toString(),
            version: existing['version'] as int,
            revision: existing['etag'] as String?,
            values: existing,
          );
    await showCaseEditor(context, ref, action, record);
    return;
  }
  final fields = <String, String>{
    'name': 'Name',
    if (path == '/holidays') 'date': 'Date (YYYY-MM-DD)',
    if (path == '/holidays') 'kind': 'Kind (COMPANY or PUBLIC)',
    if (path == '/leave/types') 'entitled': 'Annual entitlement (days)',
    if (path == '/materials') 'unit': 'Unit',
  };
  final controllers = {
    for (final k in fields.keys)
      k: TextEditingController(
        text: existing?[k]?.toString() ?? (k == 'kind' ? 'COMPANY' : ''),
      ),
  };
  final form = GlobalKey<FormState>();
  bool busy = false, dirty = false;
  String? error;
  var key = commandKey();
  String? previousPayload;
  Future<bool> discard(BuildContext dialog) async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: dialog,
          builder: (confirmation) => AlertDialog(
            title: Text(
              'Discard ${existing == null ? 'new' : 'edited'} $title?',
            ),
            content: const Text(
              'Your unsaved changes in this form will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmation, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(confirmation, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => PopScope(
        canPop: !busy && !dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && !busy && await discard(c) && c.mounted) {
            dirty = false;
            Navigator.pop(c);
          }
        },
        child: AlertDialog(
          title: Text('${existing == null ? 'Add' : 'Edit'} $title'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              onChanged: () => dirty = true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: controllers[entry.key],
                          decoration: InputDecoration(labelText: entry.value),
                          keyboardType: entry.key == 'entitled'
                              ? TextInputType.number
                              : entry.key == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty && entry.key != 'managerId') {
                              return 'This field is required';
                            }
                            if (entry.key == 'email' && !value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            if (entry.key == 'date' &&
                                DateTime.tryParse(value) == null) {
                              return 'Use YYYY-MM-DD';
                            }
                            if (entry.key == 'kind' &&
                                !['COMPANY', 'PUBLIC'].contains(value)) {
                              return 'Use COMPANY or PUBLIC';
                            }
                            if (entry.key == 'entitled' &&
                                (double.tryParse(value) == null ||
                                    double.parse(value) < 0)) {
                              return 'Enter a positive amount';
                            }
                            if (['startTime', 'endTime'].contains(entry.key) &&
                                !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                    .hasMatch(value)) {
                              return 'Use HH:mm';
                            }
                            return null;
                          },
                        ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: context.semantic.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (await discard(c) && c.mounted) {
                        dirty = false;
                        Navigator.pop(c);
                      }
                    },
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final values = <String, dynamic>{
                          for (final e in controllers.entries)
                            e.key: e.key == 'entitled'
                                ? double.parse(e.value.text)
                                : e.value.text.trim(),
                        };
                        final payload = canonicalJson(values);
                        if (previousPayload != payload) {
                          key = commandKey();
                          previousPayload = payload;
                        }
                        if (existing == null) {
                          await ref
                              .read(identityRepositoryProvider)
                              .command(path, body: values, key: key);
                        } else {
                          await ref
                              .read(identityRepositoryProvider)
                              .saveEntity(path, values, existing: existing);
                        }
                        ref.invalidate(collectionProvider(path));
                        if (c.mounted) Navigator.pop(c);
                        if (context.mounted) toast(context, 'Changes saved');
                      } catch (e) {
                        if (c.mounted) setDialog(() => error = message(e));
                      } finally {
                        if (c.mounted) setDialog(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
}
