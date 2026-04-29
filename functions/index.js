const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.database();

// ── Notify admin when a new group join request arrives ────────────────────────
exports.onJoinRequest = functions.database
  .ref('group_join_requests/{groupId}/{uid}')
  .onCreate(async (snapshot, context) => {
    const { groupId, uid } = context.params;
    const request = snapshot.val();
    if (!request) return null;

    const groupSnap = await db.ref(`groups/${groupId}`).get();
    if (!groupSnap.exists()) return null;
    const group = groupSnap.val();
    const adminUid = group.adminUid;
    if (!adminUid || adminUid === uid) return null;

    const tokenSnap = await db.ref(`user_stats/${adminUid}/fcmToken`).get();
    if (!tokenSnap.exists()) return null;
    const token = tokenSnap.val();
    if (!token) return null;

    const requesterName = request.displayName || request.email || 'Someone';
    const groupName = group.name || 'your group';

    await admin.messaging().send({
      token,
      notification: {
        title: '👥 New Join Request',
        body: `${requesterName} wants to join ${groupName}`,
      },
      data: { type: 'group_join_request', groupId },
      android: {
        notification: {
          channelId: 'runmate_channel',
          priority: 'high',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });

    return null;
  });
