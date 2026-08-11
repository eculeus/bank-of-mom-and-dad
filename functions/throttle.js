export const REQUEST_PUSH_WINDOW_MS = 10 * 60 * 1000;

export function shouldSendRequestPush(lastPushMillis, nowMillis, windowMs = REQUEST_PUSH_WINDOW_MS) {
  return lastPushMillis == null || nowMillis - lastPushMillis >= windowMs;
}
