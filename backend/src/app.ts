// src/app.ts
import express from 'express';
import cors from 'cors';
import { mediaRouter } from './modules/media/media.controller';
import { libraryRouter } from './modules/library/library.controller';
import { authRouter } from './modules/auth/auth.controller';
import { partyRouter } from './modules/party/party.controller';
import { httpRateLimiter } from './config/rateLimit';

const app = express();

app.use(cors());
app.use(express.json());

// Apply HTTP rate limiting to protect SQLite queries from abuse
app.use('/api/v1', httpRateLimiter(60 * 1000, 100));

// Mount the normalized music streams base path
app.use('/api/v1/media', mediaRouter);
// Mount the library management pathways
app.use('/api/v1/library', libraryRouter);
// Mount the authentication credentials and sessions pathways
app.use('/api/v1/auth', authRouter);
// Mount the collaborative party sync pathways
app.use('/api/v1/party', partyRouter);

app.get(/^\/party\/join\/(.*)/, (req, res) => {
  const fullPath = req.path;
  const fullParam = fullPath.replace('/party/join/', '');
  
  // Extract 6-character code (alphanumeric, case-insensitive)
  let cleanCode = '';
  const codeRegex = /[A-Z0-9]{6}/i;
  const match = fullParam.match(codeRegex);
  if (match) {
    cleanCode = match[0].toUpperCase();
  } else {
    cleanCode = fullParam.replace(/[^A-Za-z0-9]/g, '').slice(-6).toUpperCase();
  }

  // Self-heal: If dirty relative URL, redirect cleanly
  if (fullParam.includes('audio_sync://') || fullParam !== cleanCode) {
    console.log(`[ROUTE] Dirty URL detected: "${fullParam}". Redirecting cleanly to: "${cleanCode}"`);
    return res.redirect(`/party/join/${cleanCode}`);
  }

  const code = cleanCode;
  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Join Audio Sync Party</title>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800&family=Manrope:wght@500;700&display=swap" rel="stylesheet">
  <style>
    body {
      background: linear-gradient(135deg, #0b1a30 0%, #030a16 100%);
      color: #ffffff;
      font-family: 'Manrope', sans-serif;
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      overflow: hidden;
    }
    .container {
      background: rgba(255, 255, 255, 0.03);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px rgba(255, 255, 255, 0.08) solid;
      border-radius: 24px;
      padding: 40px;
      text-align: center;
      max-width: 400px;
      width: 90%;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.4);
      position: relative;
    }
    .container::before {
      content: '';
      position: absolute;
      top: -2px; left: -2px; right: -2px; bottom: -2px;
      background: linear-gradient(135deg, rgba(0, 255, 136, 0.4) 0%, rgba(0, 102, 255, 0) 100%);
      border-radius: 24px;
      z-index: -1;
    }
    .logo {
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-size: 32px;
      font-weight: 800;
      background: linear-gradient(90deg, #00FF88 0%, #00E5FF 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 24px;
      letter-spacing: -0.5px;
    }
    h1 {
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-size: 20px;
      margin-bottom: 8px;
    }
    p {
      color: #8c9ba5;
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 32px;
    }
    .code-box {
      background: rgba(255, 255, 255, 0.05);
      border-radius: 16px;
      padding: 16px;
      font-size: 28px;
      font-weight: 800;
      letter-spacing: 4px;
      color: #00FF88;
      border: 1px rgba(255, 255, 255, 0.1) solid;
      margin-bottom: 32px;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    .code-box:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(0, 255, 136, 0.4);
    }
    .btn {
      display: inline-block;
      background: #00FF88;
      color: #041329;
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-weight: 700;
      text-decoration: none;
      padding: 16px 32px;
      border-radius: 30px;
      font-size: 15px;
      transition: all 0.3s ease;
      box-shadow: 0 4px 20px rgba(0, 255, 136, 0.3);
      cursor: pointer;
      border: none;
      width: 100%;
      box-sizing: border-box;
    }
    .btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 30px rgba(0, 255, 136, 0.5);
    }
    .footer-text {
      font-size: 11px;
      color: #5b6871;
      margin-top: 24px;
    }
  </style>
  <script>
    function copyCode() {
      navigator.clipboard.writeText("${code}");
      alert("Party code copied: " + "${code}");
    }
  </script>
</head>
<body>
  <div class="container">
    <div class="logo">AUDIO SYNC</div>
    <h1>You are invited to join!</h1>
    <p>Tap the button below to switch to the app. If it doesn't open automatically, use the code below inside the app.</p>
    
    <div class="code-box" onclick="copyCode()">${code}</div>
    
    <button class="btn" onclick="window.location.href='audio_sync://party/join/${code}'">OPEN IN AUDIO SYNC</button>
    <div class="footer-text">Click the green box to copy code manually.</div>
  </div>
</body>
</html>
  `;
  res.send(html);
});

app.get('/health', (req, res) => {
  res.json({ status: 'active', gateway: 'Direct JioSaavn Conduit' });
});

export default app;