import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { dbGet, dbRun } from '../../config/database';

export interface User {
  id: string;
  username: string;
  passwordHash: string;
  salt: string;
  preferences: string[];
  createdAt: string;
}

export class AuthService {
  // Helper to generate a secure random hex token
  private generateToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  async register(username: string, password: string): Promise<{ user: Omit<User, 'passwordHash' | 'salt'>; token: string }> {
    // Check if user exists
    const existing = await dbGet('SELECT * FROM users WHERE LOWER(username) = ?', [username.toLowerCase()]);
    if (existing) {
      throw new Error('Username is already taken by another Maestro.');
    }

    const id = crypto.randomBytes(16).toString('hex');
    const salt = 'bcrypt-managed';
    // Use bcrypt with 10 salt rounds
    const passwordHash = await bcrypt.hash(password, 10);
    const preferences: string[] = [];
    const createdAt = new Date().toISOString();

    await dbRun(
      'INSERT INTO users (id, username, passwordHash, salt, preferences, createdAt) VALUES (?, ?, ?, ?, ?, ?)',
      [id, username, passwordHash, salt, JSON.stringify(preferences), createdAt]
    );

    const token = this.generateToken();
    await dbRun('INSERT INTO sessions (token, userId) VALUES (?, ?)', [token, id]);

    return {
      user: {
        id,
        username,
        preferences,
        createdAt
      },
      token
    };
  }

  async login(username: string, password: string): Promise<{ user: Omit<User, 'passwordHash' | 'salt'>; token: string }> {
    const user = await dbGet('SELECT * FROM users WHERE LOWER(username) = ?', [username.toLowerCase()]);
    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Verify bcrypt password
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      throw new Error('Invalid credentials');
    }

    const token = this.generateToken();
    await dbRun('INSERT INTO sessions (token, userId) VALUES (?, ?)', [token, user.id]);

    return {
      user: {
        id: user.id,
        username: user.username,
        preferences: JSON.parse(user.preferences || '[]'),
        createdAt: user.createdAt
      },
      token
    };
  }

  async verifySession(token: string): Promise<Omit<User, 'passwordHash' | 'salt'> | null> {
    const user = await dbGet(
      'SELECT u.* FROM users u INNER JOIN sessions s ON u.id = s.userId WHERE s.token = ?',
      [token]
    );
    if (!user) return null;

    return {
      id: user.id,
      username: user.username,
      preferences: JSON.parse(user.preferences || '[]'),
      createdAt: user.createdAt
    };
  }

  async updatePreferences(userId: string, preferences: string[]): Promise<Omit<User, 'passwordHash' | 'salt'> | null> {
    const user = await dbGet('SELECT * FROM users WHERE id = ?', [userId]);
    if (!user) return null;

    await dbRun('UPDATE users SET preferences = ? WHERE id = ?', [JSON.stringify(preferences), userId]);

    return {
      id: user.id,
      username: user.username,
      preferences,
      createdAt: user.createdAt
    };
  }

  async logout(token: string): Promise<boolean> {
    const result = await dbRun('DELETE FROM sessions WHERE token = ?', [token]);
    return result.changes > 0;
  }
}
