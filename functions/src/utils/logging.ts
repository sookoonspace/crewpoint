import {logger} from "firebase-functions/v2";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Wraps a callable handler in structured start/end logs.
 *
 * Every log line carries:
 *   - `op`     — function name (e.g. "joinEvent")
 *   - `uid`    — caller uid (or `null` for unauth requests)
 *   - `args`   — sanitized request payload (caller picks fields safe to log)
 *   - status / elapsedMs (end-line only)
 *
 * On thrown `HttpsError` the error is logged with its canonical code.
 * Any other thrown error is logged with code `"internal"`.
 */
export interface CallableLogContext {
  op: string;
  uid: string | null;
  args?: Record<string, unknown>;
}

export async function withStructuredLogs<T>(
  ctx: CallableLogContext,
  fn: () => Promise<T>
): Promise<T> {
  const startedAt = Date.now();
  logger.info(`${ctx.op} start`, {
    op: ctx.op,
    uid: ctx.uid,
    args: ctx.args ?? {},
  });
  try {
    const result = await fn();
    logger.info(`${ctx.op} ok`, {
      op: ctx.op,
      uid: ctx.uid,
      elapsedMs: Date.now() - startedAt,
    });
    return result;
  } catch (err) {
    const code = err instanceof HttpsError ? err.code : "internal";
    logger.error(`${ctx.op} fail`, {
      op: ctx.op,
      uid: ctx.uid,
      code,
      elapsedMs: Date.now() - startedAt,
      error: err instanceof Error ? err.message : String(err),
    });
    throw err;
  }
}

/**
 * Validates that a value is a non-empty string. Throws `invalid-argument`
 * with a stable message shape if not.
 */
export function requireString(
  value: unknown,
  fieldName: string
): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is required and must be a non-empty string.`
    );
  }
  return value;
}
