# RunMate — Firebase Database & Storage Reference

## Firebase Projects

| Environment | Project ID | RTDB URL | Storage Bucket | Entry Points |
|---|---|---|---|---|
| **Dev** | `runmate-252e5` | `https://runmate-252e5-default-rtdb.firebaseio.com` | `runmate-252e5.firebasestorage.app` | `main.dart`, `main_admin.dart` |
| **Live** | `runmate-live` | `https://runmate-live-default-rtdb.firebaseio.com` | `runmate-live.firebasestorage.app` | `main_live.dart`, `main_admin_live.dart` |

Firebase is initialised in each entry point with a duplicate-app-safe try/catch:
```dart
try {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
} on FirebaseException catch (e) {
  if (!e.code.contains('duplicate-app')) rethrow;
}
```

Firebase Auth (`FirebaseAuth.instance`) is used for user identity across all services. All RTDB rules require `auth != null`.

---

## Realtime Database (RTDB)

### `users/{uid}`
Profile index used for search.

```
{
  email:            String,
  displayName:      String,
  displayNameLower: String   // lowercase copy for prefix search
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `FriendsService.registerProfile` | On sign-up / profile update |
| Query | `FriendsService.searchByQuery` | `orderByChild('displayNameLower').startAt().endAt()` |

**RTDB index:** `.indexOn: ["email", "displayNameLower"]`  
**Rule:** Read: any authenticated user. Write: own UID only.

---

### `user_stats/{uid}`
Running stats and leaderboard data.

```
{
  email:           String,
  displayName:     String,
  photoUrl:        String,
  totalDistanceKm: double,
  totalRuns:       int,
  totalSeconds:    int,
  age:             int?,
  gender:          int?    // 0 = male, 1 = female
}
```

| Operation | Service | Detail |
|---|---|---|
| Write/Update | `UserStatsService.registerOrUpdate` | On first run / profile update |
| Update | `UserStatsService.addRunStats` | After each completed run |
| Update | `UserStatsService.updateAge`, `.updateGender` | Profile edits |
| Listen | `UserStatsService.watchFriendLeaderboard` | Ordered by `totalDistanceKm`, client-filtered to friends |
| Read | `AdminService` | Enriching live runner data |

**Rule:** Read: any authenticated user. Write: own UID only.  
**Note:** `keepSynced(true)` is set on this node for offline leaderboard access.

---

### `admins/{uid}`
Admin and organizer account records.

```
{
  role:        String,   // 'super_admin' | 'organizer'
  email:       String,
  displayName: String,
  createdAt:   int       // ms since epoch
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `AdminService.registerOrganizerRecord` | Super admin creates organizer |
| Read | `AdminService.fetchAdminUser` | Role check on login |
| Delete | `AdminService.deleteOrganizer` | Super admin removes organizer |
| Listen | `AdminService.watchOrganizers` | Real-time organizer list in admin panel |

**Rule:** Read: super admin only (`role === 'super_admin'`). Write: super admin only. Own node: readable by self.

---

### `events/{eventId}`
All event data.

```
{
  name:                  String,
  date:                  String,    // 'yyyy-MM-dd'
  startTime:             String,    // 'HH:mm'
  endTime:               String,    // 'HH:mm' — auto-computed: startTime + max(category cutoff)
  cutoffMinutes:         int,       // event-level fallback; 0 = none
  location:              String,
  bannerUrl:             String,    // Firebase Storage download URL
  createdAt:             int,       // ms since epoch
  organizerUid:          String,
  registrationStartDate: String,    // 'yyyy-MM-dd'
  registrationEndDate:   String,    // 'yyyy-MM-dd'
  registrationUrl:       String,
  chipTimeMinutes:       int,       // minutes after startTime runners may start
  graceTimeMinutes:      int,       // minutes after finish line before auto-stop
  categories: {
    'cat_0': {
      label:   String,   // e.g. '21.1K Half Marathon'
      cutoff:  String,   // e.g. '03:45 Hours' or '90 Minutes' or 'No Cut-Off Time'
      kmlPath: String,   // Storage path: 'events/{eventId}/kml/cat_0.kml'
      kmlUrl:  String,   // Firebase Storage download URL
      endTime: String    // 'HH:mm' — startTime + this category's cutoff
    },
    'cat_1': { ... },
    ...
  }
}
```

**`endTime` computation (admin form):**  
`endTime = startTime + max(cutoff minutes across all categories)`  
Each category also stores its own `endTime = startTime + that category's cutoff`.  
This is computed in `EventFormScreen._computeEndTime()` / `._endTimeForCutoff()` on save — no UI field.

| Operation | Service | Detail |
|---|---|---|
| Write | `AdminService.createEvent` | Admin / organizer creates event |
| Update | `AdminService.updateEvent` | Admin / organizer edits event |
| Delete | `AdminService.deleteEvent` | Cascades to Storage banner + KML |
| Listen | `AdminService.watchEvents` | Real-time stream ordered by `createdAt` |
| Listen | `MapController` | Mobile — `onValue` stream with `keepSynced(true)` |
| Query | `AdminService.fetchEventsPage` | Paginated: `orderByChild('createdAt').limitToLast(N)` |

**Rule:** Read: any authenticated user. Write: super admin or organizer role only.

**Mobile event state logic (from `EventModel`):**

| State | Condition |
|---|---|
| Upcoming | `now < eventDateTime` (startTime not yet reached) |
| LIVE | `eventDateTime < now < finishDateTime` |
| Finished | `now > finishDateTime` OR event date is before today |

`finishDateTime` resolves in order: explicit `endTime` field → `startTime + max(category cutoffs)` → `23:59` on event day.

---

### `live_runners/{uid}`
Active runner positions during an event.

```
{
  uid:          String,
  email:        String,
  displayName:  String,
  photoUrl:     String,
  lat:          double,
  lng:          double,
  startedAt:    int,      // ms since epoch
  lastSeen:     int,      // ms since epoch
  distanceKm:   double,
  eventId:      String,
  categoryId:   String,
  gender:       int       // 0 = male, 1 = female
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `LiveTrackingService.startBroadcasting` | On run start |
| Update | `LiveTrackingService.updateLocation` | Every GPS point |
| Delete | `LiveTrackingService.stopBroadcasting` | On run end |
| Auto-delete | `onDisconnect().remove()` | Cleans up on connection loss |
| Listen | `AdminService.watchLiveRunners` | All active runners (admin leaderboard) |
| Listen (filtered) | `AdminService.watchLiveRunnersForEvent` | `orderByChild('eventId').equalTo(eventId)` |

**RTDB index:** `.indexOn: ["eventId"]`  
**Rule:** Read: any authenticated user. Write: own UID only.

---

### `event_stats/{eventId}/{uid}`
Per-event finish results. Only the best (longest distance) run is kept per user.

```
{
  distanceKm:  double,
  seconds:     int,
  displayName: String,
  photoUrl:    String,
  completedAt: int     // ms since epoch
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `UserStatsService.addEventRunStats` | After finishing — overwrites only if new distance is greater |
| Listen | `AdminService.watchEventResults` | Admin event leaderboard |
| Listen | `AdminService.watchEventLeaderboard` | Joined with `user_stats` for display names |

**Rule:** Read: any authenticated user. Write: own UID only.

---

### `event_comments/{eventKey}/{commentId}`
Event comments. `eventKey` is the event ID with special characters replaced: `[.#$\[\]/]` → `-`.

```
{
  uid:         String,
  email:       String,
  displayName: String,
  photoUrl:    String,
  text:        String,
  timestamp:   int,     // ms since epoch
  likes: {
    '{uid}': true,
    ...
  },
  replies: {
    '{replyId}': {
      uid:         String,
      displayName: String,
      photoUrl:    String,
      text:        String,
      timestamp:   int
    },
    ...
  }
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `CommentService.addComment` | New comment |
| Delete | `CommentService.deleteComment` | Own comment |
| Toggle | `CommentService.toggleLike` | Sets `likes/{uid}: true` or removes it |
| Write | `CommentService.addReply` | Nested reply |
| Delete | `CommentService.deleteReply` | Own reply |
| Listen | `CommentService.watchComments` | `orderByChild('timestamp')` real-time stream |

**Rule:** Read: any authenticated user. Write: any authenticated user.

---

### `group_comments/{groupId}/{commentId}`
Same structure as `event_comments`. Same operations via `CommentService` with group-specific methods (`addGroupComment`, `watchGroupComments`, etc.).

---

### `friends/{uid}/{friendUid}`
Accepted friend relationships (bidirectional — stored under both UIDs).

```
{
  email:       String,
  displayName: String,
  photoUrl:    String,
  since:       int     // ms since epoch
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `FriendsService.acceptRequest` | On request acceptance (writes both sides) |
| Delete | `FriendsService.removeFriend` | Removes both sides |
| Read | `FriendsService.isFriend` | Single lookup |
| Listen | `FriendsService.watchFriendUids` | Stream of friend UIDs for leaderboard filtering |

**Rule:** Read: own UID only. Write: own UID or friend UID.

---

### `friend_requests/{toUid}/{fromUid}`
Incoming friend requests.

```
{
  email:       String,
  displayName: String,
  photoUrl:    String,
  sentAt:      int
}
```

### `friend_requests_sent/{uid}/{targetUid}`
Outgoing friend requests (mirror index for sent-request display).

```
{
  email:       String,
  displayName: String,
  sentAt:      int
}
```

| Operation | Service | Detail |
|---|---|---|
| Write | `FriendsService.sendRequest` | Writes both `friend_requests` and `friend_requests_sent` |
| Delete | `FriendsService.rejectRequest` / `.cancelSentRequest` / `.acceptRequest` | Clears both nodes |
| Listen | `FriendsService.watchRequests` | Incoming requests |
| Listen | `FriendsService.watchSentRequests` | Outgoing requests |

**Rule:** `friend_requests_sent/{uid}`: read/write own UID only. `friend_requests/{toUid}/{fromUid}`: read by sender or receiver, write by either.

---

### `groups/{groupId}`
Running groups tied to an event.

```
{
  eventId:          String,
  name:             String,
  adminUid:         String,
  adminDisplayName: String,
  adminPhotoUrl:    String,
  createdAt:        int,
  memberCount:      int
}
```

### `group_members/{groupId}/{uid}`
```
{
  uid:         String,
  displayName: String,
  photoUrl:    String,
  email:       String,
  joinedAt:    int,
  isAdmin:     bool
}
```

### Cross-reference nodes (presence sets)
| Path | Value | Purpose |
|---|---|---|
| `event_groups/{eventId}/{groupId}` | `true` | Look up all groups for an event |
| `user_groups/{uid}/{groupId}` | `true` | Look up all groups a user belongs to |
| `user_owned_groups/{uid}/{groupId}` | `true` | Groups a user created (for ownership cap) |
| `group_join_requests/{groupId}/{uid}` | `{uid, displayName, photoUrl, email, joinedAt}` | Pending join requests |
| `group_join_responses/{groupId}/{uid}` | `{status, groupName}` | Accept/decline notification to requester |

---

## Firebase Storage

### Event Files
| Path | Content | Written by |
|---|---|---|
| `events/{eventId}/banner.jpg` | Event banner image | `AdminService.uploadBanner` |
| `events/{eventId}/kml/{categoryId}.kml` | KML route for that category | `AdminService.uploadKml` |

`categoryId` matches the RTDB key (`cat_0`, `cat_1`, …).  
On event delete, the entire `events/{eventId}/` folder is removed recursively.

### User Files
| Path | Content | Written by |
|---|---|---|
| `profile_images/{uid}.jpg` | Profile photo | `MyPageController.uploadProfileImage` |
| `routes/{uid}/{fileName}.json` | Recorded GPS route | `FirebaseService.saveTrackedRoute` |
| `routes/{uid}/photos/{runStartMs}/photo_{photoTs}.jpg` | Run photo | `FirebaseService.saveRunPhoto` |

### Legacy KML Bucket
| Path | Content |
|---|---|
| `kpl/` | Pre-existing KML files (read-only; bucket name must not change — see `AppConfig.kmlStoragePath`) |

---

## Key Patterns

### Offline caching
`ref.keepSynced(true)` is set on `user_stats` and `events` so leaderboard and event data remain available when offline.

### Auto-cleanup on disconnect
`live_runners/{uid}` sets `onDisconnect().remove()` before broadcasting so stale runner markers are always removed even on ungraceful disconnects.

### Event ID sanitisation for comments
Event IDs can contain characters illegal in RTDB keys. `CommentService.eventKey()` replaces `[.#$\[\]/]` with `-` before using the ID as an RTDB path segment.

### Cross-node joins (client-side)
RTDB doesn't support joins. Several read paths combine two nodes:
- `event_stats` + `user_stats` → enriched leaderboard rows
- `live_runners` + `user_stats` → display names / photos on map
- `group_members` + `user_stats` → missing profile data backfill

### Timestamp format
All `createdAt` / `sentAt` / `completedAt` fields use `DateTime.now().millisecondsSinceEpoch` (client clock). `live_runners.lastSeen` uses the same. `ServerValue.timestamp` is not used.

### Admin write authorisation
Events and admin records are write-protected by role check directly in RTDB rules:
```
root.child('admins').child(auth.uid).child('role').val() === 'super_admin'
```
Organizers can also write to `events` (role `'organizer'`).
