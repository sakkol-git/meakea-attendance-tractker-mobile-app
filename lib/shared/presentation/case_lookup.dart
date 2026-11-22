import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cases.dart';
import '../../core/widgets.dart';
import '../domain/cases.dart';

Future<CaseRecord?> showPagedCaseLookup(
  BuildContext context,
  String collection,
  String label,
) => showDialog<CaseRecord>(
  context: context,
  builder: (_) => _PagedLookupDialog(collection, label),
);

class _PagedLookupDialog extends ConsumerStatefulWidget {
  final String collection, label;

  const _PagedLookupDialog(this.collection, this.label);

  @override
  ConsumerState<_PagedLookupDialog> createState() => _PagedLookupDialogState();
}

class _PagedLookupDialogState extends ConsumerState<_PagedLookupDialog> {
  final searchInput = TextEditingController();
  String search = '';
  int page = 0;
  Timer? debounce;

  @override
  void dispose() {
    searchInput.dispose();
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = caseLookupPageProvider((
      collection: widget.collection,
      search: search,
      page: page,
    ));
    final value = ref.watch(provider);
    return AlertDialog(
      title: Text('Choose ${widget.label.toLowerCase()}'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: searchInput,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search all records',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          debounce?.cancel();
                          searchInput.clear();
                          setState(() {
                            search = '';
                            page = 0;
                          });
                        },
                      ),
              ),
              onChanged: (text) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      search = text.trim();
                      page = 0;
                    });
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncPanel(
                value: value,
                retry: () => ref.invalidate(provider),
                builder: (rows) => rows.isEmpty
                    ? Center(
                        child: Semantics(
                          liveRegion: true,
                          child: const Text('No matches'),
                        ),
                      )
                    : ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          for (final row in rows)
                            ListTile(
                              title: Text(row.title),
                              subtitle: Text(row.id),
                              onTap: () => Navigator.pop(context, row),
                            ),
                        ],
                      ),
              ),
            ),
            if (value.asData != null)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(liveRegion: true, child: Text('Page ${page + 1}')),
                  TextButton(
                    onPressed: page == 0 ? null : () => setState(() => page--),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: value.asData!.value.length < 25
                        ? null
                        : () => setState(() => page++),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
