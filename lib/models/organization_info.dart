import 'event_model.dart';

/// An event organizer ("organization") whose events the current user has run,
/// together with all events that organizer has created.
class OrganizationInfo {
  final String uid;
  final String name;
  final List<EventModel> events;

  const OrganizationInfo({
    required this.uid,
    required this.name,
    required this.events,
  });
}
