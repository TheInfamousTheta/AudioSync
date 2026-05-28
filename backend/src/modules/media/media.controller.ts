// src/modules/media/media.controller.ts
import { Router, Request, Response } from 'express';
import { MediaService } from './media.service';
import axios from 'axios';
import https from 'https';
import http from 'http';

export const mediaRouter = Router();
const mediaService = new MediaService();

// HTTP/HTTPS Keep-Alive agents for high-speed connection reuse across range requests
const httpsKeepAliveAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 100,
  maxFreeSockets: 10,
  timeout: 60000,
});

const httpKeepAliveAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 100,
  maxFreeSockets: 10,
  timeout: 60000,
});

// Helper to rewrite stream URLs to proxy through our backend
function proxyStreamUrl(req: Request, originalUrl: string): string {
  if (!originalUrl || originalUrl.includes('soundhelix.com')) return originalUrl;
  const host = req.get('host');
  // Support standard forwarded protocol if behind a reverse proxy, else fallback
  const protocol = req.headers['x-forwarded-proto'] || req.protocol;
  return `${protocol}://${host}/api/v1/media/stream?url=${encodeURIComponent(originalUrl)}`;
}

// Streaming proxy route to bypass geo-restrictions, headers, and CORS blocks
mediaRouter.get('/stream', async (req: Request, res: Response) => {
  const targetUrl = req.query.url as string;
  console.log(`\n[${new Date().toISOString()}] 🔄 Proxy Streaming Request: ${targetUrl}`);
  
  if (!targetUrl) {
    res.status(400).send('Missing url query parameter: url');
    return;
  }

  try {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.jiosaavn.com/',
    };

    if (req.headers.range) {
      headers['Range'] = req.headers.range;
      console.log(`   ├─ Range Request: ${req.headers.range}`);
    }

    const streamResponse = await axios.get(targetUrl, {
      headers,
      responseType: 'stream',
      httpsAgent: httpsKeepAliveAgent,
      httpAgent: httpKeepAliveAgent,
      validateStatus: (status) => (status >= 200 && status < 300) || status === 206,
    });

    res.status(streamResponse.status);
    
    const headersToForward = [
      'content-type',
      'content-length',
      'content-range',
      'accept-ranges',
    ];
    
    headersToForward.forEach(header => {
      const val = streamResponse.headers[header];
      if (val) {
        res.setHeader(header, val);
      }
    });

    streamResponse.data.pipe(res);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Proxy Streaming Error:`, err.message);
    res.status(500).send('Streaming operational failure: ' + err.message);
  }
});

mediaRouter.get('/broadcast', (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/broadcast`);
  res.json({
    id: 'midnight-session-live',
    title: 'Midnight Session Live Broadcast',
    artistName: 'Midnight DJ Team',
    albumTitle: 'Midnight Broadcasts',
    coverArtUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
    audioStreamUrl: proxyStreamUrl(req, 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'),
    formatBadge: 'Hi-Res Lossless',
    durationInSeconds: 422,
    listeners: '4,812',
    quality: '128 kbps',
    genre: 'Ambient'
  });
});

mediaRouter.get('/dashboard', async (req: Request, res: Response) => {

  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/dashboard`);
  try {
    const data = await mediaService.getHomeDashboard();
    
    // Rewrite URLs to route through the secure proxy
    if (data.recentlyPlayed) {
      data.recentlyPlayed = data.recentlyPlayed.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }
    if (data.newReleases) {
      data.newReleases = data.newReleases.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }
    
    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Dashboard to Frontend:`);
    console.log(`   ├─ Greeting: "${data.greeting}"`);
    console.log(`   ├─ Featured Album: ${data.featured ? `"${data.featured.title}" by ${data.featured.artistName}` : 'None'}`);
    console.log(`   ├─ Recently Played Track Count: ${data.recentlyPlayed?.length || 0}`);
    if (data.recentlyPlayed?.length > 0) {
      console.log(`   │  └─ Top Recent Track: "${data.recentlyPlayed[0].title}" -> URL: ${data.recentlyPlayed[0].audioStreamUrl}`);
    }
    console.log(`   └─ New Releases Track Count: ${data.newReleases?.length || 0}`);
    // ----------------------

    res.json(data);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Dashboard Route Error:`, err.message);
    res.status(502).json({ error: 'Upstream gateway execution failure', detail: err.message });
  }
});

mediaRouter.get('/tracks/:id', async (req: Request, res: Response) => {
  const trackId = req.params.id;

  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/tracks/${trackId}`);
  
  try {
    if (typeof trackId !== 'string') {
      res.status(400).json({ error: 'Malformed request: track ID must be a single string parameter.' });
      return;
    }

    const track = await mediaService.getTrack(trackId);
    track.audioStreamUrl = proxyStreamUrl(req, track.audioStreamUrl);
    
    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Track Normalization to Frontend:`);
    console.log(`   ├─ ID: ${track.id}`);
    console.log(`   ├─ Title: "${track.title}"`);
    console.log(`   ├─ Artist: "${track.artistName}"`);
    console.log(`   ├─ Album: "${track.albumTitle}"`);
    console.log(`   ├─ Cover Art URL: ${track.coverArtUrl || 'EMPTY ❌'}`);
    console.log(`   └─ Audio Stream URL: ${track.audioStreamUrl}`);
    // ----------------------

    res.json(track);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Track Lookup Route Error for ID ${trackId}:`, err.message);
    res.status(404).json({ error: 'Track entity lookup failed', detail: err.message });
  }
});

mediaRouter.get('/search', async (req: Request, res: Response) => {
  const query = req.query.q as string;
  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/search?q=${query}`);
  try {
    if (!query) {
      res.status(400).json({ error: 'Missing standard string query parameter: q' });
      return;
    }
    const results = await mediaService.searchAll(query);
    if (results.songs) {
      results.songs = results.songs.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }
    
    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Search Results to Frontend:`);
    console.log(`   ├─ Song Results Count: ${results.songs?.length || 0}`);
    if (results.songs?.length > 0) {
      console.log(`   │  └─ First Song Stream Link: ${results.songs[0].audioStreamUrl}`);
    }
    console.log(`   └─ Album Results Count: ${results.albums?.length || 0}`);
    // ----------------------

    res.json(results);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Search Route Error for query "${query}":`, err.message);
    res.status(502).json({ error: 'Search operational failure', detail: err.message });
  }
});

mediaRouter.get('/artists/:id', async (req: Request, res: Response) => {
  const artistId = req.params.id;
  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/artists/${artistId}`);
  try {
    if (!artistId) {
      res.status(400).json({ error: 'Missing standard artist ID parameter' });
      return;
    }
    const profile = await mediaService.getArtist(artistId as string);
    
    // Proxy the popular tracks stream URLs
    if (profile.popularTracks) {
      profile.popularTracks = profile.popularTracks.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }

    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Artist Profile to Frontend:`);
    console.log(`   ├─ ID: ${profile.id}`);
    console.log(`   ├─ Name: "${profile.name}"`);
    console.log(`   ├─ Description: "${profile.description}"`);
    console.log(`   ├─ Followers: "${profile.followersCount}"`);
    console.log(`   ├─ Verified: ${profile.isVerified}`);
    console.log(`   ├─ Popular Tracks Count: ${profile.popularTracks?.length || 0}`);
    if (profile.popularTracks?.length > 0) {
      console.log(`   │  └─ First Track Stream Link: ${profile.popularTracks[0].audioStreamUrl}`);
    }
    console.log(`   └─ Playlists Count: ${profile.playlists?.length || 0}`);
    // ----------------------

    res.json(profile);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Artist Route Error for ID "${artistId}":`, err.message);
    res.status(502).json({ error: 'Artist retrieval gateway operational failure', detail: err.message });
  }
});

mediaRouter.get('/explore', async (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/explore`);
  try {
    const data = await mediaService.getExplore();
    
    // Rewrite URLs to route through the secure proxy
    if (data.midnightPicks) {
      data.midnightPicks = data.midnightPicks.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }
    
    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Explore Feed to Frontend:`);
    console.log(`   ├─ Moods & Genres Count: ${data.moodsAndGenres?.length || 0}`);
    console.log(`   └─ Midnight Picks Count: ${data.midnightPicks?.length || 0}`);
    if (data.midnightPicks?.length > 0) {
      console.log(`      └─ Top Pick: "${data.midnightPicks[0].title}" -> URL: ${data.midnightPicks[0].audioStreamUrl}`);
    }
    // ----------------------

    res.json(data);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Explore Route Error:`, err.message);
    res.status(502).json({ error: 'Explore gateway execution failure', detail: err.message });
  }
});

mediaRouter.get('/albums/:id', async (req: Request, res: Response) => {
  const albumId = req.params.id;
  console.log(`\n[${new Date().toISOString()}] 📥 Incoming Request: GET /api/v1/media/albums/${albumId}`);
  try {
    if (!albumId) {
      res.status(400).json({ error: 'Missing standard album ID parameter' });
      return;
    }
    const album = await mediaService.getAlbum(albumId as string);
    
    // Proxy the album tracks stream URLs
    if (album.songs) {
      album.songs = album.songs.map((t: any) => ({
        ...t,
        audioStreamUrl: proxyStreamUrl(req, t.audioStreamUrl)
      }));
    }

    // --- PAYLOAD LOGGING ---
    console.log(`[${new Date().toISOString()}] 📤 Delivering Album Details to Frontend:`);
    console.log(`   ├─ ID: ${album.id}`);
    console.log(`   ├─ Title: "${album.title}"`);
    console.log(`   ├─ Artist: "${album.artistName}"`);
    console.log(`   ├─ Release Date: "${album.releaseDate}"`);
    console.log(`   └─ Tracks Count: ${album.songs?.length || 0}`);
    // ----------------------

    res.json(album);
  } catch (err: any) {
    console.error(`[${new Date().toISOString()}] ❌ Album Route Error for ID "${albumId}":`, err.message);
    res.status(502).json({ error: 'Album retrieval gateway operational failure', detail: err.message });
  }
});