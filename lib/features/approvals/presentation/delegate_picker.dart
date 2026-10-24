import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/delegation.dart';

Future<EligibleDelegate?> pickDelegate(BuildContext context) =>
    showDialog<EligibleDelegate>(
      context: context,
      builder: (_) => const _DelegatePicker(),
    );

class _DelegatePicker extends ConsumerStatefulWidget {
  const _DelegatePicker();
  @override
  ConsumerState<_DelegatePicker> createState() => _DelegatePickerState();
}

class _DelegatePickerState extends ConsumerState<_DelegatePicker> {
  String search = '';
  int page = 0;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose an eligible reviewer'),
    content: SizedBox(
      width: 460,
      height: 420,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search reviewers',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    search = value.trim();
                    page = 0;
                  });
                }
              });
            },
          ),
          Expanded(
            child: FutureBuilder<List<EligibleDelegate>>(
              key: ValueKey('$search:$page'),
              future: ref
                  .read(delegationRepositoryProvider)
                  .candidates(search: search, page: page),
              builder: (context, result) {
                if (result.hasError) {
                  return const Center(
                    child: Text('Reviewers unavailable. Try again.'),
                  );
                }
                if (!result.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = result.data!;
                return Column(
                  children: [
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('No eligible reviewers'))
                          : ListView(
                              children: [
                                for (final reviewer in rows)
                                  ListTile(
                                    title: Text(reviewer.name),
                                    subtitle: Text(reviewer.id),
                                    onTap: () =>
                                        Navigator.pop(context, reviewer),
                                  ),
                              ],
                            ),
                    ),
                    Row(
                      children: [
                        Text('Page ${page + 1}'),
                        const Spacer(),
                        TextButton(
                          onPressed: page == 0
                              ? null
                              : () => setState(() => page--),
                          child: const Text('Previous'),
                        ),
                        TextButton(
                          onPressed: rows.length < 25
                              ? null
                              : () => setState(() => page++),
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
