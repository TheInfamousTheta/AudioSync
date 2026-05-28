import crypto from 'crypto';
import { dbGet, dbRun, dbAll } from '../../config/database';

export interface Party {
  id: string;
  hostId: string;
  inviteCode: string;
  status: 'active' | 'archived';
  createdAt: string;
}

export interface PartyMember {
  partyId: string;
  userId: string;
  username: string;
  joinedAt: string;
  status: string;
}

export interface PartyTrack {
  id: string;
  partyId: string;
  trackId: string;
  title: string;
  durationInSeconds: number;
  audioStreamUrl: string;
  coverArtUrl: string;
  artistName: string;
  albumTitle: string;
  addedBy: string;
  addedByName?: string;
  createdAt: string;
}

export class PartyService {
  private generateInviteCode(): string {
    // Generate a 6-character alphanumeric uppercase code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(mathRandomInt(chars.length));
    }
    return code;
  }

  async createParty(hostId: string): Promise<Party> {
    const id = crypto.randomBytes(16).toString('hex');
    let inviteCode = this.generateInviteCode();
    
    // Safety check for collisions
    let attempts = 0;
    while (attempts < 10) {
      const existing = await dbGet('SELECT id FROM parties WHERE inviteCode = ?', [inviteCode]);
      if (!existing) break;
      inviteCode = this.generateInviteCode();
      attempts++;
    }

    const createdAt = new Date().toISOString();
    await dbRun(
      'INSERT INTO parties (id, hostId, inviteCode, status, createdAt) VALUES (?, ?, ?, ?, ?)',
      [id, hostId, inviteCode, 'active', createdAt]
    );

    // Auto-join host as primary member
    await dbRun(
      'INSERT INTO party_members (partyId, userId, joinedAt, status) VALUES (?, ?, ?, ?)',
      [id, hostId, createdAt, 'active']
    );

    return { id, hostId, inviteCode, status: 'active', createdAt };
  }

  async getPartyByInviteCode(inviteCode: string): Promise<Party | null> {
    const row = await dbGet('SELECT * FROM parties WHERE LOWER(inviteCode) = ? AND status = ?', [inviteCode.toLowerCase(), 'active']);
    if (!row) return null;
    return {
      id: row.id,
      hostId: row.hostId,
      inviteCode: row.inviteCode,
      status: row.status as any,
      createdAt: row.createdAt,
    };
  }

  async getPartyById(id: string): Promise<Party | null> {
    const row = await dbGet('SELECT * FROM parties WHERE id = ?', [id]);
    if (!row) return null;
    return {
      id: row.id,
      hostId: row.hostId,
      inviteCode: row.inviteCode,
      status: row.status as any,
      createdAt: row.createdAt,
    };
  }

  async joinParty(partyId: string, userId: string): Promise<PartyMember> {
    const joinedAt = new Date().toISOString();
    
    const existing = await dbGet('SELECT * FROM party_members WHERE partyId = ? AND userId = ?', [partyId, userId]);
    if (existing) {
      const user = await dbGet('SELECT username FROM users WHERE id = ?', [userId]);
      return {
        partyId,
        userId,
        username: user?.username || 'Guest',
        joinedAt: existing.joinedAt,
        status: existing.status,
      };
    }

    await dbRun(
      'INSERT INTO party_members (partyId, userId, joinedAt, status) VALUES (?, ?, ?, ?)',
      [partyId, userId, joinedAt, 'active']
    );

    const user = await dbGet('SELECT username FROM users WHERE id = ?', [userId]);
    return {
      partyId,
      userId,
      username: user?.username || 'Guest',
      joinedAt,
      status: 'active',
    };
  }

  async getPartyMembers(partyId: string): Promise<PartyMember[]> {
    const rows = await dbAll(
      'SELECT pm.partyId, pm.userId, pm.joinedAt, pm.status, u.username FROM party_members pm INNER JOIN users u ON pm.userId = u.id WHERE pm.partyId = ?',
      [partyId]
    );
    return rows.map((r) => ({
      partyId: r.partyId,
      userId: r.userId,
      username: r.username,
      joinedAt: r.joinedAt,
      status: r.status,
    }));
  }

  async getPartyPlaylist(partyId: string): Promise<PartyTrack[]> {
    const rows = await dbAll(
      'SELECT pp.*, u.username as addedByName FROM party_playlist pp LEFT JOIN users u ON pp.addedBy = u.id WHERE pp.partyId = ? ORDER BY pp.createdAt ASC',
      [partyId]
    );
    return rows.map((r) => ({
      id: r.id,
      partyId: r.partyId,
      trackId: r.trackId,
      title: r.title,
      durationInSeconds: r.durationInSeconds,
      audioStreamUrl: r.audioStreamUrl,
      coverArtUrl: r.coverArtUrl,
      artistName: r.artistName,
      albumTitle: r.albumTitle,
      addedBy: r.addedBy,
      addedByName: r.addedByName || 'System',
      createdAt: r.createdAt,
    }));
  }

  async addTrackToPlaylist(
    partyId: string,
    addedBy: string,
    track: {
      trackId: string;
      title: string;
      durationInSeconds: number;
      audioStreamUrl: string;
      coverArtUrl: string;
      artistName: string;
      albumTitle: string;
    }
  ): Promise<PartyTrack> {
    const id = crypto.randomBytes(16).toString('hex');
    const createdAt = new Date().toISOString();

    await dbRun(
      `INSERT INTO party_playlist (id, partyId, trackId, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, addedBy, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        partyId,
        track.trackId,
        track.title,
        track.durationInSeconds,
        track.audioStreamUrl,
        track.coverArtUrl,
        track.artistName,
        track.albumTitle,
        addedBy,
        createdAt,
      ]
    );

    const user = await dbGet('SELECT username FROM users WHERE id = ?', [addedBy]);

    return {
      id,
      partyId,
      trackId: track.trackId,
      title: track.title,
      durationInSeconds: track.durationInSeconds,
      audioStreamUrl: track.audioStreamUrl,
      coverArtUrl: track.coverArtUrl,
      artistName: track.artistName,
      albumTitle: track.albumTitle,
      addedBy,
      addedByName: user?.username || 'Guest',
      createdAt,
    };
  }

  async removeTrackFromPlaylist(partyId: string, trackId: string, userId: string): Promise<boolean> {
    const party = await this.getPartyById(partyId);
    if (!party) throw new Error('Party not found.');

    const track = await dbGet('SELECT * FROM party_playlist WHERE partyId = ? AND id = ?', [partyId, trackId]);
    if (!track) throw new Error('Track not found in party playlist.');

    // Host can delete any; member can only delete their own
    const isHost = party.hostId === userId;
    const isOwner = track.addedBy === userId;

    if (!isHost && !isOwner) {
      throw new Error('Not authorized. Members can only remove their own queued tracks.');
    }

    const result = await dbRun('DELETE FROM party_playlist WHERE partyId = ? AND id = ?', [partyId, trackId]);
    return result.changes > 0;
  }
}

function mathRandomInt(max: number): number {
  return Math.floor(Math.random() * max);
}
