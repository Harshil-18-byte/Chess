/**
 * Token-bucket rate limiter protecting cloud functions from abuse and flood attacks.
 */

interface Bucket {
  tokens: number;
  lastRefillTimestamp: number;
}

export class RateLimiter {
  private static readonly MAX_TOKENS = 10;
  private static readonly REFILL_RATE_PER_SECOND = 2; // Adds 2 tokens per second
  private static buckets = new Map<string, Bucket>();

  /**
   * Consumes a single token for the given UID.
   * Returns true if allowed, false if rate limit exceeded.
   */
  static checkRateLimit(uid: string): { allowed: boolean; retryAfterSeconds: number } {
    const now = Date.now();
    let bucket = this.buckets.get(uid);

    if (!bucket) {
      bucket = {
        tokens: this.MAX_TOKENS - 1,
        lastRefillTimestamp: now,
      };
      this.buckets.set(uid, bucket);
      return { allowed: true, retryAfterSeconds: 0 };
    }

    // Refill tokens based on elapsed time
    const elapsedSeconds = (now - bucket.lastRefillTimestamp) / 1000;
    const tokensToAdd = elapsedSeconds * this.REFILL_RATE_PER_SECOND;
    bucket.tokens = Math.min(this.MAX_TOKENS, bucket.tokens + tokensToAdd);
    bucket.lastRefillTimestamp = now;

    if (bucket.tokens >= 1) {
      bucket.tokens -= 1;
      return { allowed: true, retryAfterSeconds: 0 };
    }

    const deficit = 1 - bucket.tokens;
    const retryAfter = Math.ceil(deficit / this.REFILL_RATE_PER_SECOND);
    return { allowed: false, retryAfterSeconds: Math.max(1, retryAfter) };
  }

  /**
   * Cleans up stale buckets older than 10 minutes.
   */
  static cleanup(): void {
    const now = Date.now();
    const tenMinutesMs = 10 * 60 * 1000;
    for (const [uid, bucket] of this.buckets.entries()) {
      if (now - bucket.lastRefillTimestamp > tenMinutesMs) {
        this.buckets.delete(uid);
      }
    }
  }
}
