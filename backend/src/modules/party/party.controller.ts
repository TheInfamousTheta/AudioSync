import { Router, Request, Response } from 'express';
import { PartyService } from './party.service';
import { AuthService } from '../auth/auth.service';

export const partyRouter = Router();
const partyService = new PartyService();
const authService = new AuthService();

// Middleware helper to authenticate requests
async function authenticateUser(req: Request, res: Response): Promise<any | null> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'No authorization credentials provided.' });
    return null;
  }

  const token = authHeader.split(' ')[1];
  try {
    const user = await authService.verifySession(token);
    if (!user) {
      res.status(401).json({ error: 'Session credentials have expired.' });
      return null;
    }
    return user;
  } catch (err: any) {
    res.status(500).json({ error: 'Authentication internal error', detail: err.message });
    return null;
  }
}

// Host initiates party
partyRouter.post('/create', async (req: Request, res: Response) => {
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/party/create`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    const party = await partyService.createParty(user.id);
    console.log(`   └─ Party created successfully: ${party.inviteCode} (ID: ${party.id})`);
    res.status(201).json({ party });
  } catch (err: any) {
    console.error('❌ Create party error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Resolve short invite code
partyRouter.get('/invite/:code', async (req: Request, res: Response) => {
  const inviteCode = req.params.code as string;
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/party/invite/${inviteCode}`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    const party = await partyService.getPartyByInviteCode(inviteCode);
    if (!party) {
      res.status(404).json({ error: 'No active party found with this invite code.' });
      return;
    }

    const members = await partyService.getPartyMembers(party.id);
    const isMember = members.some(m => m.userId === user.id);

    console.log(`   └─ Resolved invite code successfully. Active member status: ${isMember}`);
    res.json({ party, isMember });
  } catch (err: any) {
    console.error('❌ Resolve invite error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Join party
partyRouter.post('/:id/join', async (req: Request, res: Response) => {
  const partyId = req.params.id as string;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/party/${partyId}/join`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    const party = await partyService.getPartyById(partyId);
    if (!party) {
      res.status(404).json({ error: 'Target party not found.' });
      return;
    }

    const member = await partyService.joinParty(partyId, user.id);
    console.log(`   └─ User "${user.username}" joined party "${party.inviteCode}"`);
    res.json({ success: true, member });
  } catch (err: any) {
    console.error('❌ Join party error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Fetch complete party details (members, playlist)
partyRouter.get('/:id/details', async (req: Request, res: Response) => {
  const partyId = req.params.id as string;
  console.log(`\n[${new Date().toISOString()}] 📥 GET /api/v1/party/${partyId}/details`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    const party = await partyService.getPartyById(partyId);
    if (!party) {
      res.status(404).json({ error: 'Target party not found.' });
      return;
    }

    const members = await partyService.getPartyMembers(partyId);
    const playlist = await partyService.getPartyPlaylist(partyId);

    console.log(`   ├─ Members Count: ${members.length}`);
    console.log(`   └─ Playlist Songs: ${playlist.length}`);
    res.json({ party, members, playlist });
  } catch (err: any) {
    console.error('❌ Fetch party details error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Append song to collaborative playlist
partyRouter.post('/:id/playlist/add', async (req: Request, res: Response) => {
  const partyId = req.params.id as string;
  const { trackId, title, durationInSeconds, audioStreamUrl, coverArtUrl, artistName, albumTitle } = req.body;
  console.log(`\n[${new Date().toISOString()}] 📥 POST /api/v1/party/${partyId}/playlist/add - Track: "${title}"`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    // Check membership authorization
    const members = await partyService.getPartyMembers(partyId);
    const isMember = members.some(m => m.userId === user.id);
    if (!isMember) {
      res.status(403).json({ error: 'Access denied. You must be an active member of this party to add songs.' });
      return;
    }

    if (!trackId || !title || !audioStreamUrl) {
      res.status(400).json({ error: 'Malformed request: trackId, title, and audioStreamUrl parameters required.' });
      return;
    }

    const track = await partyService.addTrackToPlaylist(partyId, user.id, {
      trackId,
      title,
      durationInSeconds: parseInt(durationInSeconds || '0', 10),
      audioStreamUrl,
      coverArtUrl: coverArtUrl || '',
      artistName: artistName || 'Unknown Artist',
      albumTitle: albumTitle || 'Unknown Album',
    });

    console.log(`   └─ Track queued successfully. Track queue ID: ${track.id}`);
    res.status(201).json({ success: true, track });
  } catch (err: any) {
    console.error('❌ Add track error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Remove song from collaborative playlist
partyRouter.delete('/:id/playlist/remove/:trackId', async (req: Request, res: Response) => {
  const partyId = req.params.id as string;
  const trackId = req.params.trackId as string;
  console.log(`\n[${new Date().toISOString()}] 📥 DELETE /api/v1/party/${partyId}/playlist/remove/${trackId}`);
  const user = await authenticateUser(req, res);
  if (!user) return;

  try {
    const success = await partyService.removeTrackFromPlaylist(partyId, trackId, user.id);
    console.log(`   └─ Track removed. Successful status: ${success}`);
    res.json({ success });
  } catch (err: any) {
    console.error('❌ Remove track error:', err.message);
    res.status(400).json({ error: err.message });
  }
});
