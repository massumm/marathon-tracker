import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/event_model.dart';
import '../models/organization_info.dart';

class OrganizationService {
  OrganizationService._();
  static final OrganizationService instance = OrganizationService._();

  final _db = FirebaseDatabase.instance;

  /// Organizations (event organizers) whose events the current user has run.
  /// Driven by the per-user event index (user_stats/{uid}/events) and the
  /// publicly-readable events node — the admins node is NOT read (it's
  /// restricted), so the organizer name comes from the denormalized
  /// `organizerName` field stored on each event.
  Stream<List<OrganizationInfo>> watchMyOrganizations() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db.ref('user_stats/$uid/events').onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <OrganizationInfo>[];
      }
      final myEventIds = (event.snapshot.value as Map<dynamic, dynamic>)
          .keys
          .cast<String>()
          .toSet();

      final eventsSnap = await _db.ref('events').get();
      if (!eventsSnap.exists || eventsSnap.value == null) {
        return <OrganizationInfo>[];
      }
      final eventsMap = eventsSnap.value as Map<dynamic, dynamic>;

      // Organizer UIDs the user has actually run with.
      final myOrgUids = <String>{};
      for (final eid in myEventIds) {
        final e = eventsMap[eid];
        if (e is Map) {
          final org = e['organizerUid'] as String? ?? '';
          if (org.isNotEmpty) myOrgUids.add(org);
        }
      }
      if (myOrgUids.isEmpty) return <OrganizationInfo>[];

      // For each such organizer, collect ALL events they created.
      final orgs = <OrganizationInfo>[];
      for (final orgUid in myOrgUids) {
        final orgEvents = <EventModel>[];
        var name = '';
        eventsMap.forEach((key, value) {
          if (value is! Map) return;
          if ((value['organizerUid'] as String? ?? '') != orgUid) return;
          final model = EventModel.fromMap(key as String, value);
          orgEvents.add(model);
          if (name.isEmpty && model.organizerName.isNotEmpty) {
            name = model.organizerName;
          }
        });
        orgEvents.sort((a, b) => b.date.compareTo(a.date));
        orgs.add(OrganizationInfo(
          uid: orgUid,
          name: name.isNotEmpty ? name : 'Organizer',
          events: orgEvents,
        ));
      }
      orgs.sort((a, b) => a.name.compareTo(b.name));
      return orgs;
    });
  }
}
