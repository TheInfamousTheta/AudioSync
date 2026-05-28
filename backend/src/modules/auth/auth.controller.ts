import { Router, Request, Response } from 'express';
import { AuthService } from './auth.service';

export const authRouter = Router();
const authService = new AuthService();

// Register a new user session
authRouter.post('/register', async (req: Request, res: Response) => {
  const { username, password } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/auth/register - Username: "${username}"`);
  try {
    if (!username || typeof username !== 'string' || username.trim().length < 3) {
      res.status(400).json({ error: 'Username must be at least 3 characters long.' });
      return;
    }
    if (!password || typeof password !== 'string' || password.trim().length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters long.' });
      return;
    }

    const result = await authService.register(username.trim(), password);
    res.status(201).json(result);
  } catch (err: any) {
    console.error(`❌ Register error:`, err.message);
    res.status(400).json({ error: err.message });
  }
});

// Login existing user session
authRouter.post('/login', async (req: Request, res: Response) => {
  const { username, password } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/auth/login - Username: "${username}"`);
  try {
    if (!username || !password) {
      res.status(400).json({ error: 'Username and password parameters are required.' });
      return;
    }

    const result = await authService.login(username.trim(), password);
    res.json(result);
  } catch (err: any) {
    console.error(`❌ Login error:`, err.message);
    res.status(401).json({ error: err.message });
  }
});

// Retrieve verified profile matching active session token
authRouter.get('/me', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/auth/me`);
  try {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'No authorization session credentials provided.' });
      return;
    }

    const token = authHeader.split(' ')[1];
    const user = await authService.verifySession(token);
    if (!user) {
      res.status(401).json({ error: 'Session credentials have expired.' });
      return;
    }

    res.json({ user });
  } catch (err: any) {
    res.status(500).json({ error: 'Verification pipeline error', detail: err.message });
  }
});

// Update user genre preferences during onboarding
authRouter.post('/preferences', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  const { preferences } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/auth/preferences - Preferences:`, preferences);
  try {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'No authorization session credentials provided.' });
      return;
    }

    const token = authHeader.split(' ')[1];
    const user = await authService.verifySession(token);
    if (!user) {
      res.status(401).json({ error: 'Session credentials have expired.' });
      return;
    }

    if (!Array.isArray(preferences)) {
      res.status(400).json({ error: 'Preferences must be an array of genre strings.' });
      return;
    }

    const updatedUser = await authService.updatePreferences(user.id, preferences);
    res.json({ user: updatedUser });
  } catch (err: any) {
    res.status(500).json({ error: 'Preferences save pipeline error', detail: err.message });
  }
});

// Destroy active session
authRouter.post('/logout', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/auth/logout`);
  try {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(200).json({ success: true });
      return;
    }

    const token = authHeader.split(' ')[1];
    await authService.logout(token);
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: 'Logout pipeline error', detail: err.message });
  }
});
