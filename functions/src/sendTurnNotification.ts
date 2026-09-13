import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const sendTurnNotification = functions.firestore
  .document('matches/{matchId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger if activeTurn changed
    if (before.activeTurn === after.activeTurn) {
      return null;
    }

    // Determine whose turn it is now
    const newTurn = after.activeTurn; // 'w' or 'b'
    const targetUserId = newTurn === 'w' ? after.whiteUid : after.blackUid;
    
    // Ignore AI matches or if somehow null
    if (!targetUserId || targetUserId === 'engine_stockfish' || targetUserId === 'anonymous') {
      return null;
    }

    const matchId = context.params.matchId;

    // Check presence marker in Realtime Database to suppress push if user is in-game
    const db = admin.database();
    const presenceSnapshot = await db.ref(`presence/\${matchId}/\${targetUserId}`).once('value');
    if (presenceSnapshot.exists() && presenceSnapshot.val() === true) {
      functions.logger.info(`User \${targetUserId} is currently viewing match \${matchId}. Suppressing turn notification.`);
      return null;
    }

    // Fetch user profile to get FCM tokens
    const userDoc = await admin.firestore().collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      functions.logger.warn(`User \${targetUserId} not found.`);
      return null;
    }

    const userData = userDoc.data();
    const fcmTokens = userData?.fcmTokens;
    if (!fcmTokens || Object.keys(fcmTokens).length === 0) {
      return null; // No tokens to send to
    }

    const tokens = Object.keys(fcmTokens);

    const payload: admin.messaging.MessagingPayload = {
      notification: {
        title: 'Your move!',
        body: 'It is your turn in a Chessical match.',
      },
      data: {
        matchId: matchId,
      },
    };

    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      
      // Cleanup stale tokens
      const tokensToRemove: string[] = [];
      response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
          functions.logger.warn(`Failure sending notification to \${tokens[index]}: \${error.code}`);
          if (
            error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(tokens[index]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        const updates: any = {};
        tokensToRemove.forEach((token) => {
          updates[`fcmTokens.\${token}`] = admin.firestore.FieldValue.delete();
        });
        await userDoc.ref.update(updates);
        functions.logger.info(`Removed \${tokensToRemove.length} stale FCM tokens for user \${targetUserId}.`);
      }
    } catch (error) {
      functions.logger.error(`Error sending turn notification for match \${matchId}:`, error);
    }

    return null;
  });
