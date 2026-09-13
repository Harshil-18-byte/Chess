import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { InputSchemaGuard } from './inputSchemaGuard';

/**
 * Callable function for explicit client timeout claims.
 */
export const claimTimeout = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  let payload;
  try {
    payload = InputSchemaGuard.validateTimeoutPayload(data);
  } catch (err: any) {
    throw new functions.https.HttpsError('invalid-argument', err.message);
  }

  const db = admin.firestore();
  const matchRef = db.collection('matches').doc(payload.matchId);

  return await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(matchRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Match does not exist.');
    }

    const match = snap.data()!;
    if (!match.isTimedMatch) {
      throw new functions.https.HttpsError('failed-precondition', 'Match is not a timed match.');
    }
    if (match.status !== 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'Match is not active.');
    }

    const lastTimestampMs = match.lastMoveServerTimestamp
      ? match.lastMoveServerTimestamp.toMillis()
      : Date.now();
    const elapsedMs = Math.max(0, Date.now() - lastTimestampMs);

    const isWhiteTurn = match.activeTurn === 'w';
    let timedOut = false;
    let newStatus = '';
    let winnerUid = '';

    if (payload.timedOutColor === 'w' && isWhiteTurn) {
      const remaining = match.whiteMillisRemaining - elapsedMs;
      if (remaining <= 0) {
        timedOut = true;
        newStatus = 'whiteTimeout';
        winnerUid = match.blackUid;
      }
    } else if (payload.timedOutColor === 'b' && !isWhiteTurn) {
      const remaining = match.blackMillisRemaining - elapsedMs;
      if (remaining <= 0) {
        timedOut = true;
        newStatus = 'blackTimeout';
        winnerUid = match.whiteUid;
      }
    }

    if (!timedOut) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Clock has not expired according to authoritative server time.'
      );
    }

    transaction.update(matchRef, {
      status: newStatus,
      winnerUid,
      lastMoveServerTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, status: newStatus, winnerUid };
  });
});

/**
 * Scheduled Cloud Function running every minute to auto-finalize expired matches.
 */
export const scheduledTimeoutSweeper = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const activeMatchesSnap = await db
      .collection('matches')
      .where('status', '==', 'active')
      .where('isTimedMatch', '==', true)
      .limit(50)
      .get();

    const now = Date.now();
    const batch = db.batch();
    let updatedCount = 0;

    for (const doc of activeMatchesSnap.docs) {
      const data = doc.data();
      const lastTimestampMs = data.lastMoveServerTimestamp
        ? data.lastMoveServerTimestamp.toMillis()
        : now;
      const elapsedMs = Math.max(0, now - lastTimestampMs);

      if (data.activeTurn === 'w') {
        const remaining = (data.whiteMillisRemaining || 0) - elapsedMs;
        if (remaining <= 0) {
          batch.update(doc.ref, {
            status: 'whiteTimeout',
            winnerUid: data.blackUid,
            lastMoveServerTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
          updatedCount++;
        }
      } else {
        const remaining = (data.blackMillisRemaining || 0) - elapsedMs;
        if (remaining <= 0) {
          batch.update(doc.ref, {
            status: 'blackTimeout',
            winnerUid: data.whiteUid,
            lastMoveServerTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
          updatedCount++;
        }
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`[scheduledTimeoutSweeper] Successfully finalized ${updatedCount} expired matches.`);
    }
    return null;
  });
