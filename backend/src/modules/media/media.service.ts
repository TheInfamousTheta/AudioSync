import axios from 'axios';
import { ENV } from '../../config/environment';
import { SaavnTransformer, CleanTrack, CleanAlbum } from './utils/saavn-transformer';

export class MediaService {
  private readonly apiBase = ENV.SAAVN_API_URL;

  // Helper to resolve bulk song details to get decrypted download URLs
  private async resolveFullTracks(lightTracks: any[]): Promise<any[]> {
    const ids = lightTracks.map((t: any) => t.id).filter(Boolean);
    if (ids.length === 0) return [];
    
    try {
      const response = await axios.get(`${this.apiBase}/api/songs?ids=${ids.join(',')}`);
      return response.data?.data || [];
    } catch (err: any) {
      console.error('Failed to resolve bulk track details:', err.message);
      return [];
    }
  }

  async getHomeDashboard(): Promise<any> {
    // Dynamically compile a composite feed using standard search vectors
    const response = await axios.get(`${this.apiBase}/api/search?query=Lofi`);
    const data = response.data?.data;

    const compiledTracks = data?.songs?.results || [];
    const compiledAlbums = data?.albums?.results || [];

    // Resolve full metadata for the tracks to get active downloadUrls
    const resolvedTracks = await this.resolveFullTracks(compiledTracks.slice(0, 6));

    return {
      greeting: "Evening, Maestro.",
      subtext: "Your curated stage is ready for the night.",
      
      featured: compiledAlbums.length > 0 ? SaavnTransformer.transformAlbum(compiledAlbums[0]) : null,
      
      // Map fully resolved tracks to Recently Played (first 3)
      recentlyPlayed: resolvedTracks.slice(0, 3).map(SaavnTransformer.transformTrack),
      
      madeForYou: compiledAlbums.slice(1, 6).map(SaavnTransformer.transformAlbum),
      
      // Map fully resolved tracks to New Releases (next 3)
      newReleases: resolvedTracks.slice(3, 6).map(SaavnTransformer.transformTrack)
    };
  }

  async getTrack(id: string): Promise<CleanTrack> {
    let url = `${this.apiBase}/api/songs/${id}`;
    
    const response = await axios.get(url);
    const trackData = response.data?.data?.[0];
    
    if (!trackData) {
      throw new Error(`Upstream wrapper failed to resolve song data elements for reference: ${id}`);
    }

    return SaavnTransformer.transformTrack(trackData);
  }

  async getArtist(id: string): Promise<any> {
    const response = await axios.get(`${this.apiBase}/api/artists/${id}`);
    const artistData = response.data?.data;
    
    if (!artistData) {
      throw new Error(`Upstream wrapper failed to resolve artist profile for reference: ${id}`);
    }

    const resolvedTracks = await this.resolveFullTracks(artistData.topSongs || []);
    const cleanTracks = resolvedTracks.map(SaavnTransformer.transformTrack);
    const cleanAlbums = (artistData.topAlbums || []).map(SaavnTransformer.transformAlbum);

    const followerCountNum = artistData.followerCount;
    const followersFormatted = this.formatFollowersCount(followerCountNum);

    let biography = 'Velvet Echoes blends late-night saxophone melodies with atmospheric electronic production.';
    if (artistData.bio && Array.isArray(artistData.bio) && artistData.bio.length > 0) {
      biography = artistData.bio.map((b: any) => b.text).filter(Boolean).join(' ');
    }

    let coverImageUrl = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800';
    if (artistData.image && artistData.image.length > 0) {
      coverImageUrl = artistData.image[artistData.image.length - 1].link || artistData.image[artistData.image.length - 1].url || coverImageUrl;
    }

    return {
      id: artistData.id || id,
      name: artistData.name || 'Velvet Echoes',
      description: artistData.dominantLanguage 
        ? `${artistData.dominantLanguage.toUpperCase()} Ambient Soul` 
        : 'Neo-Jazz & Ambient Soul',
      coverImageUrl: coverImageUrl,
      bioImageUrl: coverImageUrl,
      monthlyListeners: followersFormatted,
      followersCount: followersFormatted,
      releasesCount: cleanAlbums.length > 0 ? cleanAlbums.length.toString() : '24',
      awardsCount: '12',
      isVerified: artistData.isVerified !== null ? artistData.isVerified : true,
      biography: biography,
      popularTracks: cleanTracks,
      playlists: cleanAlbums.map((album: CleanAlbum) => ({
        id: album.id,
        title: album.title,
        coverArtUrl: album.coverArtUrl
      }))
    };
  }

  private formatFollowersCount(count: number | null): string {
    if (!count) return '158K';
    if (count >= 1000000) {
      return (count / 1000000).toFixed(1) + 'M';
    }
    if (count >= 1000) {
      return (count / 1000).toFixed(0) + 'K';
    }
    return count.toString();
  }

  async searchAll(query: string): Promise<{ songs: CleanTrack[]; albums: CleanAlbum[] }> {
    const response = await axios.get(`${this.apiBase}/api/search?query=${encodeURIComponent(query)}`);
    const data = response.data?.data;
    
    const lightTracks = (data?.songs?.results || []).slice(0, 5);
    const resolvedTracks = await this.resolveFullTracks(lightTracks);
    
    return {
      songs: resolvedTracks.map(SaavnTransformer.transformTrack),
      albums: (data?.albums?.results || []).slice(0, 5).map(SaavnTransformer.transformAlbum)
    };
  }

  async getExplore(): Promise<any> {
    // Curated high-fidelity "Midnight Picks"
    const picksResponse = await axios.get(`${this.apiBase}/api/search?query=Lofi`);
    const pickTracksLight = (picksResponse.data?.data?.songs?.results || []).slice(0, 6);
    const pickTracksResolved = await this.resolveFullTracks(pickTracksLight);
    const cleanPicks = pickTracksResolved.map(SaavnTransformer.transformTrack);

    return {
      moodsAndGenres: [
        { id: "energetic", title: "Energetic", colors: ["#FF4E50", "#F9D423"] },
        { id: "chill", title: "Chill Blue", colors: ["#6a11cb", "#2575fc"] },
        { id: "focus", title: "Focus Flow", colors: ["#00b09b", "#96c93d"] },
        { id: "night", title: "Night Drive", colors: ["#8E2DE2", "#4A00E0"] },
        { id: "romance", title: "Romance", colors: ["#f857a6", "#ff5858"] }
      ],
      midnightPicks: cleanPicks
    };
  }

  async getAlbum(id: string): Promise<any> {
    const response = await axios.get(`${this.apiBase}/api/albums?id=${id}`);
    const albumData = response.data?.data;
    
    if (!albumData) {
      throw new Error(`Upstream wrapper failed to resolve album details for reference: ${id}`);
    }

    const resolvedTracks = await this.resolveFullTracks(albumData.songs || []);
    const cleanTracks = resolvedTracks.map(SaavnTransformer.transformTrack);

    const images = albumData.image || [];
    let crispArt = '';
    if (images && images.length > 0) {
      crispArt = images[images.length - 1].url || images[images.length - 1].link || '';
    }

    return {
      id: albumData.id || id,
      title: albumData.name || albumData.title || 'Curated Stage Collection',
      coverArtUrl: crispArt || 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
      artistName: albumData.artists?.primary?.[0]?.name || albumData.primaryArtists || 'Various Maestros',
      releaseDate: albumData.year || '2026',
      playCount: albumData.playCount || '1.2M',
      songs: cleanTracks
    };
  }
}