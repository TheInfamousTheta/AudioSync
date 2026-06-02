import { Request, Response, NextFunction } from 'express';

interface RateLimitInfo {
  count: number;
  resetTime: number;
}

const httpCache = new Map<string, RateLimitInfo>();
const wsCache = new Map<string, RateLimitInfo>();

/**
 * Creates an in-memory Express rate limiting middleware
 */
export function httpRateLimiter(windowMs: number, max: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const ip = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || 'unknown';
    const now = Date.now();

    let info = httpCache.get(ip);
    if (!info || now > info.resetTime) {
      info = {
        count: 0,
        resetTime: now + windowMs,
      };
    }

    info.count += 1;
    httpCache.set(ip, info);

    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, max - info.count));
    res.setHeader('X-RateLimit-Reset', Math.ceil(info.resetTime / 1000));

    if (info.count > max) {
      console.warn(`[RateLimit] HTTP Rate limit exceeded for IP: ${ip}`);
      res.status(429).json({
        error: 'Too Many Requests',
        message: 'Rate limit exceeded, please try again later.',
      });
      return;
    }

    next();
  };
}

/**
 * Validates if a WebSocket upgrade request is within limits
 */
export function checkWsRateLimit(ip: string, windowMs: number, max: number): boolean {
  const now = Date.now();
  let info = wsCache.get(ip);
  if (!info || now > info.resetTime) {
    info = {
      count: 0,
      resetTime: now + windowMs,
    };
  }

  info.count += 1;
  wsCache.set(ip, info);

  if (info.count > max) {
    console.warn(`[RateLimit] WS Upgrade Rate limit exceeded for IP: ${ip}`);
    return false;
  }

  return true;
}
