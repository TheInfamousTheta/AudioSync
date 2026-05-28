// lib/core/network/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audio_sync/core/app_config.dart';

class ApiClient {
  static final String baseUrl = AppConfig.apiBaseUrl;

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches dynamic live broadcast stream and metadata
  Future<Map<String, dynamic>> fetchLiveBroadcast() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/broadcast'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Broadcast lookup failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to broadcast stream: $e');
    }
  }

  /// Fetches real-time composite dashboard information
  Future<Map<String, dynamic>> fetchHomeDashboard() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/dashboard'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Gateway responded with code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network conduit execution failure: $e');
    }
  }

  /// Resolves strict track normalization metadata models on-the-fly
  Future<Map<String, dynamic>> fetchTrackMetadata(String trackId) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/tracks/$trackId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Track lookup failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to communicate with media server: $e');
    }
  }

  /// Resolves the detailed profile of an artist by ID
  Future<Map<String, dynamic>> fetchArtistProfile(String artistId) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/artists/$artistId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Artist profile retrieval failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to artist module: $e');
    }
  }

  /// Connects query paths straight to the search filtering engine
  Future<Map<String, dynamic>> searchTracks(String query) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/media/search?q=${Uri.encodeComponent(query)}'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Search execution failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Search pipeline network exception: $e');
    }
  }

  /// Fetches curated explore feed
  Future<Map<String, dynamic>> fetchExploreFeed() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/explore'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Explore gateway responded with code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Explore pipeline execution exception: $e');
    }
  }

  /// Fetches details for a specific album by ID
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/media/albums/$albumId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Album details retrieval failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to album module: $e');
    }
  }

  // --- LIBRARY MODULE CONDUITS ---

  /// Retrieves all custom/built-in playlists from the library backend
  Future<List<dynamic>> fetchPlaylists() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/library/playlists'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Playlists retrieval failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Playlists fetch conduit error: $e');
    }
  }

  /// Creates a new custom playlist
  Future<Map<String, dynamic>> createPlaylist(
    String name, {
    String description = '',
    List<String> tags = const [],
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/library/playlists'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': description,
          'tags': tags,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Playlist creation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Playlist write pipeline error: $e');
    }
  }

  /// Deletes a playlist by ID
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/library/playlists/$playlistId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Playlist deletion failed: $e');
    }
  }

  /// Appends a song/track to an existing playlist
  Future<Map<String, dynamic>> addTrackToPlaylist(
    String playlistId,
    Map<String, dynamic> trackJson,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/library/playlists/$playlistId/tracks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'track': trackJson}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Track insertion failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Playlist append error: $e');
    }
  }

  /// Removes a song/track from an existing playlist
  Future<Map<String, dynamic>> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/library/playlists/$playlistId/tracks/$trackId'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Track removal failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Playlist track remove error: $e');
    }
  }

  /// Retrieves the current set of favorite tracks and albums
  Future<Map<String, dynamic>> fetchFavorites() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/library/favorites'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Favorites retrieval failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Favorites fetch error: $e');
    }
  }

  /// Toggles favorite status on a track or album
  Future<Map<String, dynamic>> toggleFavorite(
    String type,
    Map<String, dynamic> itemJson,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/library/favorites'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': type,
          'item': itemJson,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Favorite toggling failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Favorite toggle write error: $e');
    }
  }

  /// Retrieves synced download records from backend
  Future<List<dynamic>> fetchDownloadedTracks() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/library/downloads'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Downloads sync fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Downloads fetch conduit error: $e');
    }
  }

  /// Syncs a new downloaded track to backend database
  Future<void> syncDownloadedTrack(Map<String, dynamic> trackJson) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/library/downloads'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'track': trackJson}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Downloads sync write failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Downloads sync write error: $e');
    }
  }

  /// Deletes a synced download record from backend
  Future<void> deleteSyncedTrack(String trackId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/library/downloads/$trackId'),
      );
      if (response.statusCode != 200) {
        throw Exception('Downloads sync delete failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Downloads sync delete error: $e');
    }
  }

  // --- PARTY SYNC MODULE CONDUITS ---

  /// Host initiates a collaborative party room
  Future<Map<String, dynamic>> createParty(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/party/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to build party room';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Party creation conduit error: $e');
    }
  }

  /// Resolves standard 6-digit short invite slug code
  Future<Map<String, dynamic>> resolveInviteCode(String code, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/party/invite/$code'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Invite code resolution failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Invite code lookup conduit error: $e');
    }
  }

  /// Registers user as a member of a party room
  Future<Map<String, dynamic>> joinParty(String partyId, String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/party/$partyId/join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to join party room';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Party join conduit error: $e');
    }
  }

  /// Fetches complete party details including active members list and playlist queue
  Future<Map<String, dynamic>> fetchPartyDetails(String partyId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/party/$partyId/details'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to load party room details';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Party details lookup conduit error: $e');
    }
  }

  /// Appends a new track to the collaborative party playlist queue
  Future<Map<String, dynamic>> addTrackToPartyPlaylist(
    String partyId,
    Map<String, dynamic> trackJson,
    String token,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/party/$partyId/playlist/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(trackJson),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to queue song in party';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Party playlist add error: $e');
    }
  }

  /// Removes a song from the collaborative party playlist queue
  Future<bool> removeTrackFromPartyPlaylist(
    String partyId,
    String trackId,
    String token,
  ) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/party/$partyId/playlist/remove/$trackId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['success'] == true;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Failed to remove song from party queue';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Party playlist delete error: $e');
    }
  }

  // --- AUTH MODULE CONDUITS ---

  /// Submits username and password to authenticate session
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Authentication failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Authentication conduit error: $e');
    }
  }

  /// Submits username and password to register a new user
  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Registration failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Registration conduit error: $e');
    }
  }

  /// Saves the selected genres during onboarding
  Future<Map<String, dynamic>> savePreferences(String token, List<String> preferences) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'preferences': preferences,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Preferences save failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Preferences save conduit error: $e');
    }
  }

  /// Verifies active session token on startup
  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Session credentials expired');
      }
    } catch (e) {
      throw Exception('Session verification conduit error: $e');
    }
  }

  /// Logs out active session
  Future<bool> logout(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
