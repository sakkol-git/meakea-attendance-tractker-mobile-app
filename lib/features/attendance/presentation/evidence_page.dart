import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/cases.dart';
import '../../../core/widgets.dart';
import '../../../core/protocol.dart';
import '../application/evidence.dart';
import '../domain/evidence.dart';

class EvidenceCapturePage extends ConsumerStatefulWidget {
  const EvidenceCapturePage({super.key});
  @override
  ConsumerState<EvidenceCapturePage> createState() => _EvidenceState();
}

class _EvidenceState extends ConsumerState<EvidenceCapturePage> {
  AttendanceObservation? observation;
  String? capturedActor;
  String? siteId;
  String transition = 'GEOFENCE_ENTER';
  String? error;
  bool busy = false;
  String key = commandKey();
  Future<void> capture() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await ref.read(locationCaptureProvider).capture();
      if (mounted) {
        setState(() {
          observation = value;
          capturedActor = ref.read(sessionProvider).profile?.id;
          key = commandKey();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final value = observation;
    if (value == null) return;
    if (capturedActor != ref.read(sessionProvider).profile?.id) {
      setState(
        () => error = 'Your account changed. Capture a new observation.',
      );
      return;
    }
    final site = ref
        .read(caseOptionsProvider('attendance.sites'))
        .asData
        ?.value
        .where((s) => s.id == siteId)
        .firstOrNull;
    if (site == null) {
      setState(() => error = 'Select an available work site.');
      return;
    }
    final supported = supportsGeofenceTransition(
      value,
      latitude: (site.values['latitude'] as num).toDouble(),
      longitude: (site.values['longitude'] as num).toDouble(),
      radius: (site.values['radiusMeters'] as num).toDouble(),
      entering: transition == 'GEOFENCE_ENTER',
    );
    if (!supported) {
      setState(
        () => error =
            'This sample does not reliably place you ${transition == 'GEOFENCE_ENTER' ? 'inside' : 'outside'} the site boundary. Capture again or request a correction.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(attendanceRepositoryProvider).changeCase(
        'attendance.capture',
        null,
        {...value.toInput(), 'siteId': siteId, 'kind': transition},
        key: key,
      );
      ref.invalidate(caseRowsProvider);
      if (mounted) {
        toast(context, 'Observation submitted for processing');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(clientProvider).isLocal;
    return AppPage(
      title: 'Record work-site arrival',
      subtitle: 'Review a work-site arrival or departure. Evidence does not replace clocking in or confirm attendance.',
      children: [
        AsyncPanel(
          value: ref.watch(caseOptionsProvider('attendance.sites')),
          retry: () => ref.invalidate(caseOptionsProvider('attendance.sites')),
          builder: (sites) => DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            initialValue: siteId,
            decoration: const InputDecoration(labelText: 'Work site'),
            items: [
              for (final s in sites)
                DropdownMenuItem(value: s.id, child: Text(s.title)),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    siteId = v;
                    key = commandKey();
                  }),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: transition,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Site event'),
          items: const [
            DropdownMenuItem(
              value: 'GEOFENCE_ENTER',
              child: Text('Arrived inside the site'),
            ),
            DropdownMenuItem(
              value: 'GEOFENCE_EXIT',
              child: Text('Departed outside the site'),
            ),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  transition = v!;
                  key = commandKey();
                }),
        ),
        const SizedBox(height: 16),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                local
                    ? 'Demo uses a fictional location. Your device location is not requested.'
                    : 'Capture your current location once, review its accuracy, then choose whether to submit it. Background tracking is disabled.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : capture,
                icon: const Icon(Icons.my_location),
                label: Text(
                  observation == null ? 'Capture location' : 'Capture again',
                ),
              ),
              if (observation != null) ...[
                InfoRow('Latitude', observation!.latitude.toStringAsFixed(5)),
                InfoRow('Longitude', observation!.longitude.toStringAsFixed(5)),
                InfoRow(
                  'Accuracy',
                  '${observation!.accuracyMeters.toStringAsFixed(0)} meters',
                ),
                InfoRow(
                  'Captured',
                  observation!.capturedAt.toLocal().toString(),
                ),
                if (observation!.mocked)
                  const Text(
                    'This device reports a simulated location. The server must evaluate it.',
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Submitting…' : 'Submit observation'),
                ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
