import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Stream controller to broadcast detected invite codes to listeners
  final _inviteCodeController = StreamController<String>.broadcast();
  Stream<String> get onInviteCodeReceived => _inviteCodeController.stream;

  String? pendingInviteCode;

  DeepLinkService._internal();

  /// Starts listening to cold start and incoming dynamic deep link intents
  void initialize() async {
    // 1. Check if application was launched from a closed state via deep link (Cold Start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLinkUri(initialUri);
      }
    } catch (e) {
      // Quietly bypass deep link parsing exceptions during cold start
    }

    // 2. Listen to incoming deep links while application is running in background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLinkUri(uri);
    }, onError: (err) {
      // Log deep link stream errors silently
    });
  }

  void _handleDeepLinkUri(Uri uri) {
    String inviteCode = '';
    final pathSegments = uri.pathSegments;

    if (uri.scheme == 'audio_sync') {
      if (uri.host == 'party' && pathSegments.isNotEmpty) {
        if (pathSegments.length >= 2 && pathSegments[0] == 'join') {
          inviteCode = pathSegments[1].trim().toUpperCase();
        } else {
          inviteCode = pathSegments[0].trim().toUpperCase();
        }
      }
    } else {
      // https://audio_sync.com/party/join/<invite_code>
      if (pathSegments.length >= 3 && pathSegments[0] == 'party' && pathSegments[1] == 'join') {
        inviteCode = pathSegments[2].trim().toUpperCase();
      }
    }

    if (inviteCode.isNotEmpty) {
      pendingInviteCode = inviteCode;
      _inviteCodeController.add(inviteCode);
    }
  }

  /// Clears any cached pending invite codes after user handles redirect
  void clearPendingCode() {
    pendingInviteCode = null;
  }

  void dispose() {
    _linkSubscription?.cancel();
    _inviteCodeController.close();
  }
}
