const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const REGION = 'asia-southeast1';

// Mirrors Flutter enums
const CATEGORY_LABELS = ['Crime', 'Infrastructure', 'Suspicious', 'Traffic', 'Environmental', 'Emergency'];
const STATUS_LABELS = ['Pending', 'Under Review', 'Verified', 'Resolved', 'Dismissed'];

// Default alert settings fallbacks
const DEFAULT_SEVERITY_FILTERS = [1, 2]; // moderate + high
const DEFAULT_CATEGORY_FILTERS = [0, 2, 3, 5]; // crime, suspicious, traffic, emergency
const DEFAULT_RADIUS_KM = 2.0;

// ─── Helper: send to a single token ──────────────────────────────────────────

async function sendToToken(token, title, body, data = {}) {
  try {
    await getMessaging().send({
      notification: { title, body },
      data,
      android: { notification: { channelId: 'safetrace_incidents', priority: 'high' } },
      apns: { payload: { aps: { sound: 'default' } } },
      token,
    });
  } catch (e) {
    console.error(`sendToToken failed: ${e.message}`);
  }
}

// ─── Helper: send to multiple tokens ─────────────────────────────────────────

async function sendToTokens(tokens, title, body, data = {}) {
  if (tokens.length === 0) return;
  try {
    const response = await getMessaging().sendEachForMulticast({
      notification: { title, body },
      data,
      android: { notification: { channelId: 'safetrace_incidents', priority: 'high' } },
      apns: { payload: { aps: { sound: 'default' } } },
      tokens,
    });
    console.log(`Sent ${response.successCount}/${tokens.length} notifications`);
  } catch (e) {
    console.error(`sendToTokens failed: ${e.message}`);
  }
}

// ─── 1. Notify nearby users when a new incident is created ───────────────────

exports.notifyNearbyUsers = onDocumentCreated(
  { document: 'incidents/{incidentId}', region: REGION },
  async (event) => {
    const incident = event.data.data();
    const incidentId = event.params.incidentId;
    const { latitude, longitude, category, severity, title } = incident;

    if (latitude == null || longitude == null) return;

    const db = getFirestore();
    const usersSnapshot = await db.collection('users').get();

    const tokens = [];

    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data();
      if (!user.fcmToken) continue;
      if (user.lastLatitude == null || user.lastLongitude == null) continue;

      const alertSettings = user.alertSettings || {};
      const radiusKm = alertSettings.radiusKm ?? DEFAULT_RADIUS_KM;
      const severityFilters = alertSettings.severityFilters ?? DEFAULT_SEVERITY_FILTERS;
      const categoryFilters = alertSettings.categoryFilters ?? DEFAULT_CATEGORY_FILTERS;

      if (!severityFilters.includes(severity)) continue;
      if (!categoryFilters.includes(category)) continue;

      // Active hours check
      if (alertSettings.activeHoursEnabled) {
        const now = new Date();
        const currentMinutes = now.getHours() * 60 + now.getMinutes();
        const fromMinutes = parseTime(alertSettings.activeFrom ?? '07:00 AM');
        const toMinutes = parseTime(alertSettings.activeTo ?? '11:00 PM');
        if (currentMinutes < fromMinutes || currentMinutes > toMinutes) continue;
      }

      const distance = calcDistanceKm(
        user.lastLatitude, user.lastLongitude,
        latitude, longitude,
      );
      if (distance > radiusKm) continue;

      tokens.push(user.fcmToken);
    }

    if (tokens.length === 0) return;

    const categoryLabel = CATEGORY_LABELS[category] ?? 'Incident';
    await sendToTokens(
      tokens,
      `${categoryLabel} Alert Nearby`,
      title || 'A new incident was reported near you.',
      { incidentId, latitude: String(latitude), longitude: String(longitude), type: 'nearby_incident' },
    );
  },
);

// ─── 2. Notify reporter when their incident status changes ────────────────────

exports.notifyStatusChange = onDocumentUpdated(
  { document: 'incidents/{incidentId}', region: REGION },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const incidentId = event.params.incidentId;

    // Only proceed if status actually changed
    if (before.status === after.status) return;

    const reporterId = after.reporterId;
    if (!reporterId) return;

    const db = getFirestore();
    const reporterDoc = await db.collection('users').doc(reporterId).get();
    if (!reporterDoc.exists) return;

    const fcmToken = reporterDoc.data().fcmToken;
    if (!fcmToken) return;

    const statusLabel = STATUS_LABELS[after.status] ?? 'Updated';
    const incidentTitle = after.title || 'Your report';

    await sendToToken(
      fcmToken,
      `Report ${statusLabel}`,
      `"${incidentTitle}" has been marked as ${statusLabel}.`,
      { incidentId, type: 'status_change', status: String(after.status) },
    );

    console.log(`Status change notification sent: incident=${incidentId} status=${statusLabel}`);
  },
);

// ─── 3. Notify reporter when their incident gets an upvote ───────────────────

exports.notifyUpvote = onDocumentCreated(
  { document: 'votes/{voteId}', region: REGION },
  async (event) => {
    const vote = event.data.data();

    // VoteType: upvote=0, downvote=1 — only notify on upvote
    if (vote.type !== 0) return;

    const { incidentId, voterId } = vote;
    if (!incidentId || !voterId) return;

    const db = getFirestore();

    // Get the incident to find the reporter
    const incidentDoc = await db.collection('incidents').doc(incidentId).get();
    if (!incidentDoc.exists) return;

    const incident = incidentDoc.data();
    const reporterId = incident.reporterId;
    if (!reporterId || reporterId === voterId) return;

    // Get reporter's FCM token
    const reporterDoc = await db.collection('users').doc(reporterId).get();
    if (!reporterDoc.exists) return;

    const fcmToken = reporterDoc.data().fcmToken;
    if (!fcmToken) return;

    const incidentTitle = incident.title || 'Your report';

    await sendToToken(
      fcmToken,
      'Someone upvoted your report 👍',
      `"${incidentTitle}" received an upvote.`,
      { incidentId, type: 'upvote' },
    );

    console.log(`Upvote notification sent: incident=${incidentId} reporter=${reporterId}`);
  },
);

// ─── 4. Notify community members when a new post is created ──────────────────

exports.notifyCommunityPost = onDocumentCreated(
  { document: 'posts/{postId}', region: REGION },
  async (event) => {
    const post = event.data.data();
    const postId = event.params.postId;
    const { communityId, authorId, title, content } = post;

    if (!communityId || !authorId) return;

    const db = getFirestore();

    // Get community name
    const communityDoc = await db.collection('communities').doc(communityId).get();
    const communityName = communityDoc.exists
      ? (communityDoc.data().name || 'Your Community')
      : 'Your Community';

    // Get all approved members (MemberStatus.approved = index 1)
    const membersSnapshot = await db.collection('community_members')
      .where('communityId', '==', communityId)
      .where('status', '==', 1)
      .get();

    if (membersSnapshot.empty) return;

    // Collect FCM tokens, excluding the post author
    const tokens = [];
    for (const memberDoc of membersSnapshot.docs) {
      const member = memberDoc.data();
      if (member.userId === authorId) continue;

      const userDoc = await db.collection('users').doc(member.userId).get();
      if (!userDoc.exists) continue;

      const fcmToken = userDoc.data().fcmToken;
      if (fcmToken) tokens.push(fcmToken);
    }

    if (tokens.length === 0) return;

    // Use post title, or first 60 chars of content as fallback
    const postPreview = title
      || (content ? content.substring(0, 60) + (content.length > 60 ? '...' : '') : 'New post');

    await sendToTokens(
      tokens,
      `New post in ${communityName}`,
      postPreview,
      { communityId, postId, type: 'community_post' },
    );

    console.log(`Community post notification: communityId=${communityId} sent to ${tokens.length} members`);
  },
);

// ─── Utilities ────────────────────────────────────────────────────────────────

function calcDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

function parseTime(timeStr) {
  const [time, period] = timeStr.split(' ');
  let [hours, minutes] = time.split(':').map(Number);
  if (period === 'PM' && hours !== 12) hours += 12;
  if (period === 'AM' && hours === 12) hours = 0;
  return hours * 60 + minutes;
}
