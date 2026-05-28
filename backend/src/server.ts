// src/server.ts
import http from 'http';
import app from './app';
import { ENV } from './config/environment';
import { initializeDatabase } from './config/database';
import { initializePartyWebSocket } from './modules/party/party.websocket';

initializeDatabase()
  .then(() => {
    const server = http.createServer(app);
    
    // Wire the real-time WebSocket communication pathways
    initializePartyWebSocket(server);

    server.listen(ENV.PORT, () => {
      console.log(`=========================================`);
      console.log(`THE AUDIOSYNC ENGINE ONLINE`);
      console.log(`Port: ${ENV.PORT}`);
      console.log(`Upstream API Target: ${ENV.SAAVN_API_URL}`);
      console.log(`=========================================`);
    });
  })
  .catch((err) => {
    console.error('Failed to initialize database engine:', err);
    process.exit(1);
  });