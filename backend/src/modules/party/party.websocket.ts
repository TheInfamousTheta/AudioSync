import { Server as HttpServer } from 'http';
import WebSocket, { WebSocketServer } from 'ws';
import url from 'url';
import { AuthService } from '../auth/auth.service';

const authService = new AuthService();

// Registry mapping partyId -> Set of active client sockets
const partyRooms = new Map<string, Set<WebSocket>>();

// Registry mapping socket -> partyId & userId for quick lookups
const socketMetadata = new Map<WebSocket, { partyId?: string; userId: string; username: string }>();

export function initializePartyWebSocket(server: HttpServer) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', async (request, socket, head) => {
    const pathname = url.parse(request.url || '').pathname;
    
    if (pathname === '/api/v1/party/sync') {
      const query = url.parse(request.url || '', true).query;
      const token = query.token as string;

      if (!token) {
        console.log('[WS] Handshake rejected: Missing session token');
        socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
        socket.destroy();
        return;
      }

      try {
        const user = await authService.verifySession(token);
        if (!user) {
          console.log('[WS] Handshake rejected: Invalid session token');
          socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
          socket.destroy();
          return;
        }

        wss.handleUpgrade(request, socket, head, (ws: any) => {
          socketMetadata.set(ws, { userId: user.id, username: user.username });
          wss.emit('connection', ws, request);
        });
      } catch (err) {
        console.error('[WS] Connection upgrade error:', err);
        socket.write('HTTP/1.1 500 Internal Server Error\r\n\r\n');
        socket.destroy();
      }
    } else {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
    }
  });

  wss.on('connection', (ws: WebSocket) => {
    const meta = socketMetadata.get(ws);
    console.log(`[WS] Connection opened. User: "${meta?.username}" (ID: ${meta?.userId})`);

    ws.on('message', (message: string) => {
      try {
        const payload = JSON.parse(message);
        handleSocketMessage(ws, payload);
      } catch (err: any) {
        console.error('[WS] Failed to parse message frame:', err.message);
        ws.send(JSON.stringify({ event: 'error', data: { message: 'Invalid JSON frame.' } }));
      }
    });

    ws.on('close', () => {
      const meta = socketMetadata.get(ws);
      console.log(`[WS] Connection closed. User: "${meta?.username}"`);
      if (meta?.partyId) {
        leaveRoom(ws, meta.partyId);
      }
      socketMetadata.delete(ws);
    });

    ws.on('error', (err: any) => {
      console.error(`[WS] Error on socket for user "${meta?.username}":`, err);
    });
  });
}

function handleSocketMessage(ws: WebSocket, payload: { event: string; data: any }) {
  const meta = socketMetadata.get(ws);
  if (!meta) return;

  const { event, data } = payload;
  console.log(`[WS] Message received from "${meta.username}": Event: "${event}"`);

  switch (event) {
    case 'party:join': {
      const { partyId } = data;
      if (!partyId) return;
      meta.partyId = partyId;
      joinRoom(ws, partyId);
      broadcastToRoom(partyId, 'party:member_joined', {
        userId: meta.userId,
        username: meta.username,
        timestamp: new Date().toISOString(),
      }, ws);
      break;
    }

    case 'sync:ping': {
      // WAN Latency Time Calibration (NTP-like handshake)
      // Client transmits a client-side timestamp.
      // Server immediately appends its own server-time timestamp and echoes it back.
      const clientTxTime = data.clientTx;
      ws.send(JSON.stringify({
        event: 'sync:pong',
        data: {
          clientTx: clientTxTime,
          serverRx: Date.now(),
        }
      }));
      break;
    }

    case 'sync:trigger': {
      // Host triggers dynamic acoustic calibration
      if (meta.partyId) {
        console.log(`[WS] Sync pulse trigger initiated by "${meta.username}" in party room: ${meta.partyId}`);
        broadcastToRoom(meta.partyId, 'sync:trigger', {
          triggeredBy: meta.userId,
          serverTimestamp: Date.now(),
        });
      }
      break;
    }

    case 'playback:play': {
      if (meta.partyId) {
        const { trackId, title, audioStreamUrl, coverArtUrl, artistName, albumTitle, playAt } = data;
        console.log(`[WS] Directing synchronized playback: "${title}" in party room: ${meta.partyId}. Target Start Time: ${playAt}`);
        broadcastToRoom(meta.partyId, 'playback:play', {
          trackId,
          title,
          audioStreamUrl,
          coverArtUrl,
          artistName,
          albumTitle,
          playAt: playAt || (Date.now() + 1000), // Default to start in 1 second if not specified
          directedBy: meta.userId,
        });
      }
      break;
    }

    case 'playback:pause': {
      if (meta.partyId) {
        console.log(`[WS] Pausing synchronized playback in party room: ${meta.partyId}`);
        broadcastToRoom(meta.partyId, 'playback:pause', {
          pausedBy: meta.userId,
        });
      }
      break;
    }

    case 'playback:seek': {
      if (meta.partyId) {
        const { positionInSeconds } = data;
        console.log(`[WS] Seeking synchronized playback to ${positionInSeconds}s in party room: ${meta.partyId}`);
        broadcastToRoom(meta.partyId, 'playback:seek', {
          positionInSeconds,
          seekedBy: meta.userId,
        });
      }
      break;
    }

    case 'playlist:update': {
      if (meta.partyId) {
        console.log(`[WS] Playlist updated in party room: ${meta.partyId}`);
        broadcastToRoom(meta.partyId, 'playlist:update', {
          updatedBy: meta.userId,
        });
      }
      break;
    }

    default:
      console.log(`[WS] Unrecognized socket event: "${event}"`);
      break;
  }
}

function joinRoom(ws: WebSocket, partyId: string) {
  if (!partyRooms.has(partyId)) {
    partyRooms.set(partyId, new Set<WebSocket>());
  }
  partyRooms.get(partyId)!.add(ws);
  console.log(`[WS] Client joined party room: ${partyId}. Total active connections: ${partyRooms.get(partyId)!.size}`);
}

function leaveRoom(ws: WebSocket, partyId: string) {
  const room = partyRooms.get(partyId);
  if (room) {
    room.delete(ws);
    console.log(`[WS] Client left party room: ${partyId}. Remaining active connections: ${room.size}`);
    if (room.size === 0) {
      partyRooms.delete(partyId);
      console.log(`[WS] Room ${partyId} is empty. Disposing room instance.`);
    }
  }
}

function broadcastToRoom(partyId: string, event: string, data: any, excludeSocket?: WebSocket) {
  const room = partyRooms.get(partyId);
  if (!room) return;

  const payload = JSON.stringify({ event, data });
  room.forEach((client) => {
    if (client !== excludeSocket && client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  });
}
