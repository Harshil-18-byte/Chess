import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { Chess, Square } from 'chess.js';
import { InputSchemaGuard } from './inputSchemaGuard';
import { RateLimiter } from './rateLimiter';

export const validateMove = functions.https.onCall(async (data, context) => {
  // 1. Authentication Check
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Move execution requires an authenticated user session.'
    );
  }
  const uid = context.auth.uid;

  // 2. Rate Limiting Check
  const rateLimit = RateLimiter.checkRateLimit(uid);
  if (!rateLimit.allowed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Rate limit exceeded. Please retry in ${rateLimit.retryAfterSeconds} seconds.`
    );
  }

  // 3. Payload Schema Validation
  let payload;
  try {
    payload = InputSchemaGuard.validateMovePayload(data);
  } catch (err: any) {
    throw new functions.https.HttpsError('invalid-argument', err.message);
  }

  const db = admin.firestore();
  const matchRef = db.collection('matches').doc(payload.matchId);
  const movesColRef = matchRef.collection('moves');
  const userRef = db.collection('users').doc(uid);

  // 4. Ban check
  const userDoc = await userRef.get();
  if (userDoc.exists && userDoc.data()?.isBanned === true) {
    throw new functions.https.HttpsError('permission-denied', 'Account is suspended.');
  }

  // 5. Authoritative Firestore Transaction
  return await db.runTransaction(async (transaction) => {
    const matchSnap = await transaction.get(matchRef);
    if (!matchSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Match not found.');
    }

    const matchData = matchSnap.data()!;

    // Check Match Active
    if (matchData.status !== 'active') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Match is not active (${matchData.status}).`
      );
    }

    // Idempotency check (UUID clientMoveId)
    const processedIds: string[] = matchData.processedClientMoveIds || [];
    if (processedIds.includes(payload.clientMoveId)) {
      throw new functions.https.HttpsError(
        'already-exists',
        'This move was already processed.'
      );
    }

    // Authorization & Turn Verification
    const activeTurn: 'w' | 'b' = matchData.activeTurn;
    const isWhite = matchData.whiteUid === uid;
    const isBlack = matchData.blackUid === uid;

    if (!isWhite && !isBlack) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Caller is not a registered player in this match.'
      );
    }

    if (activeTurn === 'w' && !isWhite) {
      throw new functions.https.HttpsError(
        'permission-denied',
        "It is White's turn, but caller is Black."
      );
    }

    if (activeTurn === 'b' && !isBlack) {
      throw new functions.https.HttpsError(
        'permission-denied',
        "It is Black's turn, but caller is White."
      );
    }

    // Authoritative Move Validation via chess.js
    const chess = new Chess(matchData.currentFen);
    let moveResult;
    try {
      moveResult = chess.move({
        from: payload.from as Square,
        to: payload.to as Square,
        promotion: payload.promotion,
      });
    } catch {
      moveResult = null;
    }

    if (!moveResult) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Illegal chess move: ${payload.from}->${payload.to}`
      );
    }

    // Authoritative Clock Calculation
    const lastTimestampMs = matchData.lastMoveServerTimestamp
      ? matchData.lastMoveServerTimestamp.toMillis()
      : Date.now();
    const nowMs = Date.now();
    const elapsedMs = Math.max(0, nowMs - lastTimestampMs);

    let whiteMillisRemaining: number = matchData.whiteMillisRemaining;
    let blackMillisRemaining: number = matchData.blackMillisRemaining;
    let newStatus = 'active';

    if (activeTurn === 'w') {
      whiteMillisRemaining = Math.max(0, whiteMillisRemaining - elapsedMs);
      if (whiteMillisRemaining <= 0) {
        newStatus = 'whiteTimeout';
      }
    } else {
      blackMillisRemaining = Math.max(0, blackMillisRemaining - elapsedMs);
      if (blackMillisRemaining <= 0) {
        newStatus = 'blackTimeout';
      }
    }

    const nextTurn = activeTurn === 'w' ? 'b' : 'w';
    const newFen = chess.fen();
    const isCheck = chess.inCheck();
    const isCheckmate = chess.isCheckmate();
    const isStalemate = chess.isStalemate();
    const isThreefold = chess.isThreefoldRepetition();
    const isInsufficient = chess.isInsufficientMaterial();
    const isDraw50 = chess.isDraw();

    if (newStatus === 'active') {
      if (isCheckmate) {
        newStatus = activeTurn === 'w' ? 'whiteWonCheckmate' : 'blackWonCheckmate';
      } else if (isStalemate) {
        newStatus = 'drawStalemate';
      } else if (isThreefold) {
        newStatus = 'drawThreefoldRepetition';
      } else if (isInsufficient) {
        newStatus = 'drawInsufficientMaterial';
      } else if (isDraw50) {
        newStatus = 'drawFiftyMoveRule';
      }
    }

    const moveCount = (matchData.moveCount || 0) + 1;
    const positionHistory: string[] = [...(matchData.positionHistory || []), newFen];
    const updatedProcessedIds: string[] = [...processedIds, payload.clientMoveId];

    const updatePayload: Record<string, any> = {
      currentFen: newFen,
      activeTurn: nextTurn,
      status: newStatus,
      whiteMillisRemaining,
      blackMillisRemaining,
      lastMoveSan: moveResult.san,
      moveCount,
      positionHistory,
      processedClientMoveIds: updatedProcessedIds,
      lastMoveServerTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      drawOfferedBy: null,
    };

    if (newStatus === 'whiteWonCheckmate' || newStatus === 'blackTimeout') {
      updatePayload.winnerUid = matchData.whiteUid;
    } else if (newStatus === 'blackWonCheckmate' || newStatus === 'whiteTimeout') {
      updatePayload.winnerUid = matchData.blackUid;
    }

    transaction.update(matchRef, updatePayload);

    // Record immutable move doc
    const moveDocRef = movesColRef.doc(String(moveCount).padStart(4, '0'));
    transaction.set(moveDocRef, {
      moveNumber: moveCount,
      san: moveResult.san,
      fenAfterMove: newFen,
      movedBy: uid,
      clientMoveId: payload.clientMoveId,
      isCheck,
      isCheckmate,
      capturedPiece: moveResult.captured || null,
      promotionPiece: payload.promotion || null,
      serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      newFen,
      san: moveResult.san,
      status: newStatus,
    };
  });
});
