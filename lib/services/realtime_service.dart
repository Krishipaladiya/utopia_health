import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../data/appointments_store.dart';
import '../data/clinic_store.dart';
import 'api_client.dart';
import 'session.dart';
import '../data/network_stores.dart';

/// Live connection to the .NET SignalR hub. When the server reports a change
/// the matching part of [clinic] is refreshed, so every screen updates by
/// itself on every device of the clinic.
class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  HubConnection? _hub;

  /// true while the socket is connected (shown as a small status in the UI).
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Future<void> start() async {
    if (_hub != null) return;

    final hub = HubConnectionBuilder()
        .withUrl(
          '${ApiConfig.baseUrl}/hubs/clinic',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => api.token ?? '',
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();

    hub.on('queue.changed', (_) => clinic.refreshQueue());
    hub.on('patients.changed', (_) => clinic.refreshPatients());
    hub.on('ledger.changed', (_) => clinic.refreshFinance());
    hub.on('appointments.changed', (_) => appointments.refresh());
    hub.on('facility.changed', (_) => facilityStore.refresh());
    hub.on('notification.created', (args) {
      if (args == null || args.isEmpty) return;
      final payload = args.first;
      if (payload is! Map) return;
      final json = Map<String, dynamic>.from(payload);
      if (session.isClinicTeam) {
        notifications.addFromServer(json);
      } else {
        inbox.addFromServer(json);
        // A patient's turn, prescription or report changes what the app shows.
        if (session.isPatient) patientStore.loadAll();
        if (session.isFacility) facilityStore.refresh();
      }
    });

    hub.onclose(({error}) => connected.value = false);
    hub.onreconnected(({connectionId}) {
      connected.value = true;
      // Events may have been missed while offline.
      if (session.isPatient) {
        patientStore.loadAll();
      } else if (session.isFacility) {
        facilityStore.loadAll();
      } else {
        clinic.loadAll();
        appointments.refresh();
      }
    });

    _hub = hub;
    try {
      await hub.start();
      connected.value = true;
    } catch (e) {
      debugPrint('Realtime connect failed: $e');
      connected.value = false;
    }
  }

  Future<void> stop() async {
    final hub = _hub;
    _hub = null;
    connected.value = false;
    try {
      await hub?.stop();
    } catch (_) {}
  }
}
