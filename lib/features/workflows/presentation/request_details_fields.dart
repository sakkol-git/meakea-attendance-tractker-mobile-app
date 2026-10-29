import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets.dart';

class RequestDetailsFields extends ConsumerWidget {
  final TextEditingController title;
  final String requestType;
  final bool locked, saving;
  final ValueChanged<String> onTypeChanged;
  const RequestDetailsFields({
    super.key,
    required this.title,
    required this.requestType,
    required this.locked,
    required this.saving,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Request details', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextFormField(
        controller: title,
        decoration: const InputDecoration(
          labelText: 'Request title',
          hintText: 'What do you need?',
        ),
        maxLength: 100,
        validator: (value) => (value?.trim().length ?? 0) < 3
            ? 'Enter at least 3 characters'
            : null,
      ),
      const SizedBox(height: 16),
      AsyncPanel(
        value: ref.watch(collectionProvider('/requests/types')),
        retry: () => ref.invalidate(collectionProvider('/requests/types')),
        builder: (types) => DropdownButtonFormField<String>(
          isExpanded: true,
          itemHeight: null,
          initialValue: types.any((type) => type['code'] == requestType)
              ? requestType
              : null,
          decoration: const InputDecoration(labelText: 'Request type'),
          items: [
            for (final type in types.where((type) => type['active'] != false))
              DropdownMenuItem(
                value: type['code'] as String,
                child: Text(type['name'] as String),
              ),
          ],
          validator: (value) =>
              value == null ? 'Choose an available request type' : null,
          onChanged: saving || locked
              ? null
              : (value) {
                  if (value != null) onTypeChanged(value);
                },
        ),
      ),
      if (locked) const Text('Create a new draft to change the request type.'),
    ],
  );
}
