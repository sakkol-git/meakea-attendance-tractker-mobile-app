import 'package:flutter/material.dart';

import '../../../core/protocol.dart';
import '../../../core/theme.dart';
import '../../../shared/domain/cases.dart';
import '../../../shared/presentation/case_lookup.dart';

class MaterialRequestFields extends StatelessWidget {
  final String? material, materialName;
  final TextEditingController quantity;
  final List<JsonMap> additional;
  final Map<String, String> labels;
  final bool saving;
  final ValueChanged<CaseRecord> select;
  final ValueChanged<JsonMap> remove;
  final ValueChanged<String> fail;
  final VoidCallback add;
  const MaterialRequestFields({
    super.key,
    this.material,
    this.materialName,
    required this.quantity,
    required this.additional,
    required this.labels,
    required this.saving,
    required this.select,
    required this.remove,
    required this.fail,
    required this.add,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Text('Materials', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FormField<String>(
        key: ValueKey('material-${additional.length}-$material'),
        initialValue: material,
        validator: (value) =>
            value == null && additional.isEmpty ? 'Choose a material' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Material · Required'),
            OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(materialName ?? material ?? 'Search materials'),
              onPressed: saving
                  ? null
                  : () async {
                      final selected = await showPagedCaseLookup(
                        context,
                        'requests.inventory',
                        'material',
                      );
                      if (selected == null || !context.mounted) return;
                      if (additional.any(
                        (item) => item['materialId'] == selected.id,
                      )) {
                        fail('This material is already added.');
                        return;
                      }
                      select(selected);
                      field.didChange(selected.id);
                    },
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: context.semantic.error),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: quantity,
        decoration: const InputDecoration(labelText: 'Quantity'),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (material == null && additional.isNotEmpty) return null;
          final count = int.tryParse(value ?? '');
          return count == null || count < 1 || count > 100
              ? 'Enter a quantity from 1 to 100'
              : null;
        },
      ),
      const SizedBox(height: 12),
      for (final item in additional)
        Card(
          child: ListTile(
            title: Text(
              labels[item['materialId']] ??
                  item['materialId']?.toString() ??
                  'Material',
            ),
            subtitle: Text('Quantity: ${item['quantity']}'),
            trailing: IconButton(
              tooltip: 'Remove material',
              onPressed: saving ? null : () => remove(item),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      TextButton.icon(
        onPressed: saving || material == null ? null : add,
        icon: const Icon(Icons.add),
        label: const Text('Add another material'),
      ),
    ],
  );
}
