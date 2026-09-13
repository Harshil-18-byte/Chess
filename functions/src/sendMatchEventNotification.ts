import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const sendMatchEventNotification = functions.firestore
  .document('matches/{matchId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const matchId = context.params.matchId;

    // Detect events: Game Ended, Draw Offered
    let eventType = '';
    let targetUserId = '';
    let title = '';
    let body = '';

    // Check if Game Ended
    if (before.status === 'active' && after.status !== 'active') {
      eventType = 'ended';
      // Notify both players if possible, but let's just do a broadcast approach or individual.
      // Wait, we need to notify the loser or the draw recipient. Since the game is over, we can notify both,
      // but let's notify the player whose turn it WAS, or just both if we want.
      // To keep it simple, we notify both players that the match ended.
      // We will handle this in a loop below.
    } 
    // Check if Draw Offered
    else if (before.drawOfferedBy !== after.drawOfferedBy && after.drawOfferedBy) {
      eventType = 'draw_offered';
      targetUserId = after.drawOfferedBy === after.whiteUid ? after.blackUid : after.whiteUid;
      title = 'Draw Offered';
      body = 'Your opponent has offered a draw.';
    }

    if (!eventType) {
      return null;
    }

    const sendPush = async (uid: string, pushTitle: string, pushBody: string) => {
      if (!uid || uid === 'engine_stockfish' || uid === 'anonymous') return;

      // Check presence
      const db = admin.database();
      const presenceSnapshot = await db.ref(`presence/\${matchId}/\${uid}`).once('value');
      if (presenceSnapshot.exists() && presenceSnapshot.val() === true) {
        return; // User is active, no push needed
      }

      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      const fcmTokens = userDoc.data()?.fcmTokens;
      if (!fcmTokens || Object.keys(fcmTokens).length === 0) return;

      const tokens = Object.keys(fcmTokens);
      const payload: admin.messaging.MessagingPayload = {
        notification: { title: pushTitle, body: pushBody },
        data: { matchId },
      };

      try {
        const response = await admin.messaging().sendToDevice(tokens, payload);
        const tokensToRemove: string[] = [];
        response.results.forEach((result, index) => {
          if (result.error && (result.error.code === 'messaging/invalid-registration-token' || result.error.code === 'messaging/registration-token-not-registered')) {
            tokensToRemove.push(tokens[index]);
          }
        });

        if (tokensToRemove.length > 0) {
          const updates: any = {};
          tokensToRemove.forEach((token) => updates[`fcmTokens.\${token}`] = admin.firestore.FieldValue.delete());
          await userDoc.ref.update(updates);
        }
      } catch (e) {
        functions.logger.error('Error sending match event push:', e);
      }
    };

    if (eventType === 'ended') {
      const winner = after.status === 'checkmate_w' || after.status === 'resignation_b' || after.status === 'blackTimeout' ? 'White' :
                     after.status === 'checkmate_b' || after.status === 'resignation_w' || after.status === 'whiteTimeout' ? 'Black' : 'Draw';
      
      let wBody = winner === 'White' ? 'You won!' : winner === 'Black' ? 'You lost.' : 'Match ended in a draw.';
      let bBody = winner === 'Black' ? 'You won!' : winner === 'White' ? 'You lost.' : 'Match ended in a draw.';

      if (after.status === 'abandoned') {
        wBody = bBody = 'Match was abandoned.';
      }

      await sendPush(after.whiteUid, 'Match Ended', wBody);
      await sendPush(after.blackUid, 'Match Ended', bBody);
    } else if (eventType === 'draw_offered') {
      await sendPush(targetUserId, title, body);
    }

    return null;
  });
