import Redis from 'ioredis';

const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);

export let isRedisEnabled = false;
export let pubClient: Redis | null = null;
export let subClient: Redis | null = null;

const retryStrategy = (times: number) => {
  if (times > 3) {
    console.warn(`[Redis] Max retry attempts reached. Falling back to local in-memory pub/sub.`);
    return null;
  }
  return Math.min(times * 200, 1000);
};

export async function initializeRedis(onMessageReceived: (channel: string, message: string) => void): Promise<void> {
  try {
    pubClient = new Redis({
      host: REDIS_HOST,
      port: REDIS_PORT,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy,
    });

    subClient = new Redis({
      host: REDIS_HOST,
      port: REDIS_PORT,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy,
    });

    pubClient.on('error', (err) => {
      console.warn(`[Redis] Pub client connection error:`, err.message);
      isRedisEnabled = false;
    });

    subClient.on('error', (err) => {
      console.warn(`[Redis] Sub client connection error:`, err.message);
      isRedisEnabled = false;
    });

    console.log(`[Redis] Connecting to Redis at ${REDIS_HOST}:${REDIS_PORT}...`);
    await Promise.all([pubClient.connect(), subClient.connect()]);

    isRedisEnabled = true;
    console.log(`[Redis] Successfully connected. Pub/Sub scaling active.`);

    await subClient.subscribe('party:broadcast');
    subClient.on('message', (channel, message) => {
      if (channel === 'party:broadcast') {
        onMessageReceived(channel, message);
      }
    });

  } catch (err: any) {
    console.warn(`[Redis] Initialization failed: ${err.message}. Running in local mode.`);
    isRedisEnabled = false;
    pubClient = null;
    subClient = null;
  }
}

export async function publishToParty(partyId: string, event: string, data: any, excludeUserId?: string, originInstanceId?: string) {
  const payload = JSON.stringify({ partyId, event, data, excludeUserId, originInstanceId });
  if (isRedisEnabled && pubClient) {
    try {
      await pubClient.publish('party:broadcast', payload);
    } catch (err: any) {
      console.error(`[Redis] Failed to publish message:`, err.message);
    }
  }
}
