import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';

import 'form_page.dart';

class EditRequestPage extends ConsumerWidget {
  final String id;
  const EditRequestPage(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = detailProvider((kind: 'request', id: id));
    return ref
        .watch(provider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) => AppPage(
            title: 'Edit draft',
            children: [
              Text(message(e)),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: Text('Try again'),
              ),
            ],
          ),
          data: (record) =>
              record.status == 'DRAFT' &&
                  record.employeeId == ref.watch(sessionProvider).profile?.id
              ? RequestFormPage('request', initial: record)
              : AppPage(
                  title: 'Draft unavailable',
                  children: const [
                    Text('Only your draft request can be edited.'),
                  ],
                ),
        );
  }
}
