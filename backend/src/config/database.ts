import sqlite3 from 'sqlite3';
import path from 'path';
import fs from 'fs';
import bcrypt from 'bcrypt';


const dbPath = path.resolve(__dirname, '../../db.sqlite');
console.log(`[DB] Database path: ${dbPath}`);

export const db = new sqlite3.Database(dbPath);

export function initializeDatabase(): Promise<void> {
  return new Promise((resolve, reject) => {
    db.serialize(() => {
      // Users Table
      db.run(`
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          username TEXT UNIQUE,
          passwordHash TEXT,
          salt TEXT,
          preferences TEXT,
          createdAt TEXT
        )
      `, (err) => { if (err) reject(err); });

      // Sessions Table
      db.run(`
        CREATE TABLE IF NOT EXISTS sessions (
          token TEXT PRIMARY KEY,
          userId TEXT,
          FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
        )
      `, (err) => { if (err) reject(err); });

      // Playlists Table
      db.run(`
        CREATE TABLE IF NOT EXISTS playlists (
          id TEXT PRIMARY KEY,
          name TEXT,
          description TEXT,
          tags TEXT,
          createdAt TEXT
        )
      `, (err) => { if (err) reject(err); });

      // Playlist Tracks Table
      db.run(`
        CREATE TABLE IF NOT EXISTS playlist_tracks (
          playlistId TEXT,
          trackId TEXT,
          title TEXT,
          durationInSeconds INTEGER,
          audioStreamUrl TEXT,
          coverArtUrl TEXT,
          artistName TEXT,
          albumTitle TEXT,
          formatBadge TEXT,
          PRIMARY KEY(playlistId, trackId),
          FOREIGN KEY(playlistId) REFERENCES playlists(id) ON DELETE CASCADE
        )
      `, (err) => { if (err) reject(err); });

      // Favorite Tracks Table
      db.run(`
        CREATE TABLE IF NOT EXISTS favorite_tracks (
          id TEXT PRIMARY KEY,
          title TEXT,
          durationInSeconds INTEGER,
          audioStreamUrl TEXT,
          coverArtUrl TEXT,
          artistName TEXT,
          albumTitle TEXT,
          formatBadge TEXT
        )
      `, (err) => { if (err) reject(err); });

      // Favorite Albums Table
      db.run(`
        CREATE TABLE IF NOT EXISTS favorite_albums (
          id TEXT PRIMARY KEY,
          title TEXT,
          coverArtUrl TEXT,
          releaseDate TEXT,
          artistName TEXT,
          formatBadge TEXT
        )
      `, (err) => { if (err) reject(err); });

      // Downloaded Tracks Table
      db.run(`
        CREATE TABLE IF NOT EXISTS downloaded_tracks (
          id TEXT PRIMARY KEY,
          title TEXT,
          durationInSeconds INTEGER,
          audioStreamUrl TEXT,
          coverArtUrl TEXT,
          artistName TEXT,
          albumTitle TEXT,
          formatBadge TEXT,
          downloadedAt TEXT
        )
      `, (err) => { if (err) reject(err); });

      // Parties Table
      db.run(`
        CREATE TABLE IF NOT EXISTS parties (
          id TEXT PRIMARY KEY,
          hostId TEXT,
          inviteCode TEXT UNIQUE,
          status TEXT,
          createdAt TEXT,
          FOREIGN KEY(hostId) REFERENCES users(id) ON DELETE CASCADE
        )
      `, (err) => { if (err) reject(err); });

      // Party Members Table
      db.run(`
        CREATE TABLE IF NOT EXISTS party_members (
          partyId TEXT,
          userId TEXT,
          joinedAt TEXT,
          status TEXT,
          PRIMARY KEY(partyId, userId),
          FOREIGN KEY(partyId) REFERENCES parties(id) ON DELETE CASCADE,
          FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
        )
      `, (err) => { if (err) reject(err); });

      // Party Playlist Table
      db.run(`
        CREATE TABLE IF NOT EXISTS party_playlist (
          id TEXT PRIMARY KEY,
          partyId TEXT,
          trackId TEXT,
          title TEXT,
          durationInSeconds INTEGER,
          audioStreamUrl TEXT,
          coverArtUrl TEXT,
          artistName TEXT,
          albumTitle TEXT,
          addedBy TEXT,
          createdAt TEXT,
          FOREIGN KEY(partyId) REFERENCES parties(id) ON DELETE CASCADE,
          FOREIGN KEY(addedBy) REFERENCES users(id) ON DELETE SET NULL
        )
      `, (err) => { if (err) reject(err); });

      // Seed Default User (maestro / midnight)
      const demoUserId = 'maestro-id';
      // Hash using bcrypt to match upgraded AuthService hashing standard
      const demoUserHash = bcrypt.hashSync('midnight', 10);
      const demoUserSalt = 'bcrypt-managed';
      const demoUserPrefs = JSON.stringify(['Lofi', 'Chill Blue', 'Night Drive']);
      
      db.run(`
        INSERT OR IGNORE INTO users (id, username, passwordHash, salt, preferences, createdAt)
        VALUES (?, ?, ?, ?, ?, ?)
      `, [demoUserId, 'maestro', demoUserHash, demoUserSalt, demoUserPrefs, new Date().toISOString()]);

      // Seed Demo Session
      db.run(`
        INSERT OR IGNORE INTO sessions (token, userId)
        VALUES (?, ?)
      `, ['demo-session-token-123456', demoUserId]);

      // Seed Demo Playlist
      db.run(`
        INSERT OR IGNORE INTO playlists (id, name, description, tags, createdAt)
        VALUES (?, ?, ?, ?, ?)
      `, ['1', 'Midnight Drive Mix', 'Lofi vibes for neon-lit night drives.', JSON.stringify(['Lofi', 'Night', 'Chill']), new Date().toISOString()]);

      db.run(`
        INSERT OR IGNORE INTO playlist_tracks (playlistId, trackId, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, formatBadge)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, ['1', 'soundhelix-1', 'Midnight Reverie', 372, 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500', 'Velvet Echoes', 'Midnight City Sessions', 'Hi-Res Lossless']);

      db.run(`
        INSERT OR IGNORE INTO playlists (id, name, description, tags, createdAt)
        VALUES (?, ?, ?, ?, ?)
      `, ['2', 'Barak Hostel Study Sessions', 'Deep focus soundscapes for late night sessions.', JSON.stringify(['Focus', 'Ambient', 'Intellect']), new Date().toISOString()]);

      db.run(`
        INSERT OR IGNORE INTO playlists (id, name, description, tags, createdAt)
        VALUES (?, ?, ?, ?, ?)
      `, ['3', 'Late Night Code Fuel', 'Synthwave rhythms that compile clean code.', JSON.stringify(['Synthwave', 'Coding', 'Energy']), new Date().toISOString()]);

      // Seed Favorite Tracks
      db.run(`
        INSERT OR IGNORE INTO favorite_tracks (id, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, formatBadge)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, ['soundhelix-1', 'Midnight Reverie', 372, 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500', 'Velvet Echoes', 'Midnight City Sessions', 'Hi-Res Lossless']);

      // Seed Favorite Albums
      db.run(`
        INSERT OR IGNORE INTO favorite_albums (id, title, coverArtUrl, releaseDate, artistName, formatBadge)
        VALUES (?, ?, ?, ?, ?, ?)
      `, ['1', 'Lunar Echoes', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500', '2026', 'Solaris', 'Hi-Res Lossless']);

      db.run(`
        INSERT OR IGNORE INTO favorite_albums (id, title, coverArtUrl, releaseDate, artistName, formatBadge)
        VALUES (?, ?, ?, ?, ?, ?)
      `, ['2', 'Neon Nocturne', 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500', '2025', 'The Glitch', 'Dolby Atmos'], (err) => {
        if (err) reject(err);
        else {
          console.log(`[DB] Database schema and initial demonstration seeds populated successfully.`);
          resolve();
        }
      });
    });
  });
}

export function dbRun(sql: string, params: any[] = []): Promise<{ lastID: number; changes: number }> {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

export function dbGet(sql: string, params: any[] = []): Promise<any> {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
}

export function dbAll(sql: string, params: any[] = []): Promise<any[]> {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

