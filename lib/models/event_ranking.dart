import 'user_stats.dart';

/// The current user's standing in a single event, ranked against all
/// participants (everyone with an entry under event_stats/{eventId}).
class EventRanking {
  final String eventId;
  final String eventName;
  final int myRank;
  final int totalParticipants;
  final UserStats myStats;

  const EventRanking({
    required this.eventId,
    required this.eventName,
    required this.myRank,
    required this.totalParticipants,
    required this.myStats,
  });
}
