import { dbGet, dbRun, dbAll } from '../../config/database';
import { CleanTrack, CleanAlbum } from '../media/utils/saavn-transformer';

export interface Playlist {
  id: string;
  name: string;
  description: string;
  tags: string[];
  tracks: CleanTrack[];
  createdAt: string;
}

export class LibraryService {
  async getPlaylists(): Promise<Playlist[]> {
    const playlists = await dbAll('SELECT * FROM playlists ORDER BY createdAt DESC');
    const result: Playlist[] = [];

    for (const p of playlists) {
      const tracks = await dbAll('SELECT * FROM playlist_tracks WHERE playlistId = ?', [p.id]);
      result.push({
        id: p.id,
        name: p.name,
        description: p.description,
        tags: JSON.parse(p.tags || '[]'),
        tracks: tracks.map(t => ({
          id: t.trackId,
          title: t.title,
          durationInSeconds: t.durationInSeconds,
          audioStreamUrl: t.audioStreamUrl,
          coverArtUrl: t.coverArtUrl,
          artistName: t.artistName,
          albumTitle: t.albumTitle,
          formatBadge: t.formatBadge
        })),
        createdAt: p.createdAt
      });
    }

    return result;
  }

  async createPlaylist(name: string, description = '', tags: string[] = []): Promise<Playlist> {
    const id = Math.random().toString(36).substring(2, 9);
    const createdAt = new Date().toISOString();

    await dbRun(
      'INSERT INTO playlists (id, name, description, tags, createdAt) VALUES (?, ?, ?, ?, ?)',
      [id, name, description, JSON.stringify(tags), createdAt]
    );

    return {
      id,
      name,
      description,
      tags,
      tracks: [],
      createdAt
    };
  }

  async deletePlaylist(id: string): Promise<boolean> {
    const result = await dbRun('DELETE FROM playlists WHERE id = ?', [id]);
    return result.changes > 0;
  }

  async addTrackToPlaylist(playlistId: string, track: CleanTrack): Promise<Playlist | null> {
    // Check if playlist exists
    const playlistRow = await dbGet('SELECT * FROM playlists WHERE id = ?', [playlistId]);
    if (!playlistRow) return null;

    // Check if track already in playlist
    const existing = await dbGet(
      'SELECT * FROM playlist_tracks WHERE playlistId = ? AND trackId = ?',
      [playlistId, track.id]
    );

    if (!existing) {
      await dbRun(
        `INSERT INTO playlist_tracks (playlistId, trackId, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, formatBadge)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          playlistId,
          track.id,
          track.title,
          track.durationInSeconds,
          track.audioStreamUrl,
          track.coverArtUrl,
          track.artistName,
          track.albumTitle,
          track.formatBadge
        ]
      );
    }

    // Retrieve updated playlist
    const playlists = await this.getPlaylists();
    return playlists.find(p => p.id === playlistId) || null;
  }

  async removeTrackFromPlaylist(playlistId: string, trackId: string): Promise<Playlist | null> {
    await dbRun('DELETE FROM playlist_tracks WHERE playlistId = ? AND trackId = ?', [playlistId, trackId]);

    const playlists = await this.getPlaylists();
    return playlists.find(p => p.id === playlistId) || null;
  }

  async getFavorites(): Promise<{ tracks: CleanTrack[]; albums: CleanAlbum[] }> {
    const tracksRows = await dbAll('SELECT * FROM favorite_tracks');
    const albumsRows = await dbAll('SELECT * FROM favorite_albums');

    const tracks: CleanTrack[] = tracksRows.map(t => ({
      id: t.id,
      title: t.title,
      durationInSeconds: t.durationInSeconds,
      audioStreamUrl: t.audioStreamUrl,
      coverArtUrl: t.coverArtUrl,
      artistName: t.artistName,
      albumTitle: t.albumTitle,
      formatBadge: t.formatBadge
    }));

    const albums: CleanAlbum[] = albumsRows.map(a => ({
      id: a.id,
      title: a.title,
      coverArtUrl: a.coverArtUrl,
      releaseDate: a.releaseDate,
      artistName: a.artistName,
      formatBadge: a.formatBadge
    }));

    return { tracks, albums };
  }

  async toggleFavoriteTrack(track: CleanTrack): Promise<boolean> {
    const existing = await dbGet('SELECT id FROM favorite_tracks WHERE id = ?', [track.id]);
    if (existing) {
      await dbRun('DELETE FROM favorite_tracks WHERE id = ?', [track.id]);
      return false; // removed
    } else {
      await dbRun(
        `INSERT INTO favorite_tracks (id, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, formatBadge)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          track.id,
          track.title,
          track.durationInSeconds,
          track.audioStreamUrl,
          track.coverArtUrl,
          track.artistName,
          track.albumTitle,
          track.formatBadge
        ]
      );
      return true; // added
    }
  }

  async toggleFavoriteAlbum(album: CleanAlbum): Promise<boolean> {
    const existing = await dbGet('SELECT id FROM favorite_albums WHERE id = ?', [album.id]);
    if (existing) {
      await dbRun('DELETE FROM favorite_albums WHERE id = ?', [album.id]);
      return false; // removed
    } else {
      await dbRun(
        `INSERT INTO favorite_albums (id, title, coverArtUrl, releaseDate, artistName, formatBadge)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [album.id, album.title, album.coverArtUrl, album.releaseDate, album.artistName, album.formatBadge]
      );
      return true; // added
    }
  }

  async getDownloadedTracks(): Promise<CleanTrack[]> {
    const rows = await dbAll('SELECT * FROM downloaded_tracks ORDER BY downloadedAt DESC');
    return rows.map(t => ({
      id: t.id,
      title: t.title,
      durationInSeconds: t.durationInSeconds,
      audioStreamUrl: t.audioStreamUrl,
      coverArtUrl: t.coverArtUrl,
      artistName: t.artistName,
      albumTitle: t.albumTitle,
      formatBadge: t.formatBadge
    }));
  }

  async addDownloadedTrack(track: CleanTrack): Promise<void> {
    await dbRun(
      `INSERT OR REPLACE INTO downloaded_tracks (id, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle, formatBadge, downloadedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        track.id,
        track.title,
        track.durationInSeconds,
        track.audioStreamUrl,
        track.coverArtUrl,
        track.artistName,
        track.albumTitle,
        track.formatBadge,
        new Date().toISOString()
      ]
    );
  }

  async removeDownloadedTrack(id: string): Promise<boolean> {
    const result = await dbRun('DELETE FROM downloaded_tracks WHERE id = ?', [id]);
    return result.changes > 0;
  }
}
