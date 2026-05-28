import { Router, Request, Response } from 'express';
import { LibraryService } from './library.service';

export const libraryRouter = Router();
const libraryService = new LibraryService();

// Playlists CRUD
libraryRouter.get('/playlists', async (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/library/playlists`);
  try {
    const playlists = await libraryService.getPlaylists();
    res.json(playlists);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to retrieve playlists', detail: err.message });
  }
});

libraryRouter.post('/playlists', async (req: Request, res: Response) => {
  const { name, description, tags } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/library/playlists - Name: "${name}"`);
  try {
    if (!name || typeof name !== 'string') {
      res.status(400).json({ error: 'Missing standard string: name' });
      return;
    }
    const playlist = await libraryService.createPlaylist(name, description, tags);
    res.status(201).json(playlist);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to create playlist', detail: err.message });
  }
});

libraryRouter.delete('/playlists/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  console.log(`\n[${new Date().toISOString()}] 📥 DELETE /api/v1/library/playlists/${id}`);
  try {
    const deleted = await libraryService.deletePlaylist(id as string);
    if (!deleted) {
      res.status(404).json({ error: 'Playlist not found' });
      return;
    }
    res.json({ success: true, message: 'Playlist deleted' });
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to delete playlist', detail: err.message });
  }
});

// Playlist Track Management
libraryRouter.post('/playlists/:id/tracks', async (req: Request, res: Response) => {
  const { id } = req.params;
  const { track } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/library/playlists/${id}/tracks - Track: ${track?.title}`);
  try {
    if (!track || !track.id) {
      res.status(400).json({ error: 'Missing track object containing ID' });
      return;
    }
    const playlist = await libraryService.addTrackToPlaylist(id as string, track);
    if (!playlist) {
      res.status(404).json({ error: 'Playlist not found' });
      return;
    }
    res.json(playlist);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to add track to playlist', detail: err.message });
  }
});

libraryRouter.delete('/playlists/:id/tracks/:trackId', async (req: Request, res: Response) => {
  const { id, trackId } = req.params;
  console.log(`\n[${new Date().toISOString()}] 📥 DELETE /api/v1/library/playlists/${id}/tracks/${trackId}`);
  try {
    const playlist = await libraryService.removeTrackFromPlaylist(id as string, trackId as string);
    if (!playlist) {
      res.status(404).json({ error: 'Playlist not found' });
      return;
    }
    res.json(playlist);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to remove track from playlist', detail: err.message });
  }
});

// Favorites CRUD
libraryRouter.get('/favorites', async (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/library/favorites`);
  try {
    const favorites = await libraryService.getFavorites();
    res.json(favorites);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to retrieve favorites', detail: err.message });
  }
});

libraryRouter.post('/favorites', async (req: Request, res: Response) => {
  const { type, item } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/library/favorites - Type: ${type}`);
  try {
    if (!type || !item || !item.id) {
      res.status(400).json({ error: 'Missing type ("track" | "album") or item with id' });
      return;
    }

    if (type === 'track') {
      const added = await libraryService.toggleFavoriteTrack(item);
      res.json({ success: true, favorited: added, type: 'track' });
    } else if (type === 'album') {
      const added = await libraryService.toggleFavoriteAlbum(item);
      res.json({ success: true, favorited: added, type: 'album' });
    } else {
      res.status(400).json({ error: 'Invalid favorite type. Supported: "track", "album"' });
    }
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to toggle favorite status', detail: err.message });
  }
});

// Downloaded Tracks Sync
libraryRouter.get('/downloads', async (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/library/downloads`);
  try {
    const downloads = await libraryService.getDownloadedTracks();
    res.json(downloads);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to retrieve downloaded tracks', detail: err.message });
  }
});

libraryRouter.post('/downloads', async (req: Request, res: Response) => {
  const { track } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/library/downloads - Track: ${track?.title}`);
  try {
    if (!track || !track.id) {
      res.status(400).json({ error: 'Missing track object containing ID' });
      return;
    }
    await libraryService.addDownloadedTrack(track);
    res.status(201).json({ success: true, message: 'Track synced to downloads' });
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to sync downloaded track', detail: err.message });
  }
});

libraryRouter.delete('/downloads/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  console.log(`\n[${new Date().toISOString()}] 📥 DELETE /api/v1/library/downloads/${id}`);
  try {
    const deleted = await libraryService.removeDownloadedTrack(id as string);
    if (!deleted) {
      res.status(404).json({ error: 'Track not found in download sync logs' });
      return;
    }
    res.json({ success: true, message: 'Track removed from download sync logs' });
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to remove track from download sync logs', detail: err.message });
  }
});

