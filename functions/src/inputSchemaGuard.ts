/**
 * Input Schema Guard for validating runtime payload structures.
 */

export interface MovePayload {
  matchId: string;
  from: string;
  to: string;
  promotion?: string;
  clientMoveId: string;
}

export interface TimeoutPayload {
  matchId: string;
  timedOutColor: 'w' | 'b';
}

const SQUARE_REGEX = /^[a-h][1-8]$/;
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class InputSchemaGuard {
  /**
   * Validates move submission payload.
   */
  static validateMovePayload(data: unknown): MovePayload {
    if (!data || typeof data !== 'object') {
      throw new Error('Invalid payload: expected an object.');
    }

    const payload = data as Record<string, unknown>;

    if (typeof payload.matchId !== 'string' || payload.matchId.trim().length === 0) {
      throw new Error('Invalid matchId: must be a non-empty string.');
    }

    if (typeof payload.from !== 'string' || !SQUARE_REGEX.test(payload.from.toLowerCase())) {
      throw new Error(`Invalid source square "from": "${payload.from}". Must be a1-h8.`);
    }

    if (typeof payload.to !== 'string' || !SQUARE_REGEX.test(payload.to.toLowerCase())) {
      throw new Error(`Invalid destination square "to": "${payload.to}". Must be a1-h8.`);
    }

    if (payload.promotion !== undefined) {
      if (typeof payload.promotion !== 'string' || !/^[qrbn]$/i.test(payload.promotion)) {
        throw new Error(`Invalid promotion piece: "${payload.promotion}". Must be q, r, b, or n.`);
      }
    }

    if (typeof payload.clientMoveId !== 'string' || !UUID_REGEX.test(payload.clientMoveId.trim())) {
      throw new Error('Invalid clientMoveId: must be a valid UUID v4 string.');
    }

    return {
      matchId: payload.matchId.trim(),
      from: payload.from.toLowerCase(),
      to: payload.to.toLowerCase(),
      promotion: payload.promotion ? (payload.promotion as string).toLowerCase() : undefined,
      clientMoveId: payload.clientMoveId.trim(),
    };
  }

  /**
   * Validates timeout claim payload.
   */
  static validateTimeoutPayload(data: unknown): TimeoutPayload {
    if (!data || typeof data !== 'object') {
      throw new Error('Invalid payload: expected an object.');
    }

    const payload = data as Record<string, unknown>;

    if (typeof payload.matchId !== 'string' || payload.matchId.trim().length === 0) {
      throw new Error('Invalid matchId: must be a non-empty string.');
    }

    if (payload.timedOutColor !== 'w' && payload.timedOutColor !== 'b') {
      throw new Error('Invalid timedOutColor: must be "w" or "b".');
    }

    return {
      matchId: payload.matchId.trim(),
      timedOutColor: payload.timedOutColor,
    };
  }
}
