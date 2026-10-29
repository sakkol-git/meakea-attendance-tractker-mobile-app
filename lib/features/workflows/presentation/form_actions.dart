import 'package:flutter/material.dart';

/// Keeps the form's primary action reachable while the fields scroll.
class FormActions extends StatelessWidget {
  final bool saving, draft;
  final VoidCallback submit;
  final String? error;
  const FormActions({
    super.key,
    required this.saving,
    required this.draft,
    required this.submit,
    this.error,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .18,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: saving ? null : submit,
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Saving request',
                    ),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              saving
                  ? 'Saving…'
                  : draft
                  ? 'Save request draft'
                  : 'Send for approval',
            ),
          ),
        ],
      ),
    ),
  );
}
