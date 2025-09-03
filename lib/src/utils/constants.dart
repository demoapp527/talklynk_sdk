class TalkLynkConstants {
  static const String sdkVersion = '1.0.0';
  static const String userAgent = 'Flutter-TalkLynk-SDK/$sdkVersion';

  // WebSocket constants
  static const Duration defaultConnectionTimeout = Duration(seconds: 30);
  static const Duration defaultHeartbeatInterval = Duration(seconds: 30);
  static const int maxReconnectAttempts = 20;
  static const Duration minReconnectDelay = Duration(seconds: 1);
  static const Duration maxReconnectDelay = Duration(seconds: 30);

  // API constants
  static const Duration defaultApiTimeout = Duration(seconds: 30);
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Call constants
  static const Duration callRingTimeout = Duration(minutes: 1);
  static const Duration maxCallDuration = Duration(hours: 4);

  // Room constants
  static const int defaultMaxParticipants = 10;
  static const int maxRoomNameLength = 255;

  // User constants
  static const int maxUsernameLength = 50;
  static const int maxDisplayNameLength = 100;

  // Custom events
  static const int maxCustomEventDataSize = 10 * 1024; // 10KB
  static const int maxCustomEventHistorySize = 100;

  // File upload
  static const int maxFileUploadSize = 50 * 1024 * 1024; // 50MB
  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ];
  static const List<String> supportedVideoTypes = [
    'video/mp4',
    'video/webm',
    'video/quicktime'
  ];
  static const List<String> supportedAudioTypes = [
    'audio/mpeg',
    'audio/wav',
    'audio/webm',
    'audio/ogg'
  ];
}

/// Event type constants
class EventTypes {
  // Connection events
  static const String connectionEstablished = 'connection:established';
  static const String connectionError = 'connection:error';
  static const String connectionDisconnected = 'connection:disconnected';
  static const String connectionFailed = 'connection:failed';

  // Room events
  static const String userJoined = 'user.joined';
  static const String userLeft = 'user.left';
  static const String roomSubscriptionSucceeded = 'room:subscription_succeeded';
  static const String subscriptionError = 'subscription:error';

  // Call events
  static const String callRinging = 'call.ringing';
  static const String callAccepted = 'call.accepted';
  static const String callRejected = 'call.rejected';
  static const String callEnded = 'call.ended';

  // WebRTC events
  static const String webrtcSignal = 'webrtc.signaling';

  // Admin events
  static const String adminTransferred = 'admin.transferred';
  static const String participantKicked = 'participant.kicked';
  static const String allParticipantsMuted = 'participants.muted_all';

  // Chat events
  static const String newMessage = 'new_message';
  static const String typingIndicator = 'typing_indicator';

  // Custom events (prefix)
  static const String customEventPrefix = 'custom.';

  // Common custom events
  static const String userRaisedHand = 'custom.user_raised_hand';
  static const String screenShareStarted = 'custom.screen_share_started';
  static const String screenShareEnded = 'custom.screen_share_ended';
  static const String reactionAdded = 'custom.reaction_added';
}

/// API endpoint constants
class ApiEndpoints {
  // Authentication
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/profile';

  // Users
  static const String users = '/users';
  static const String usersCreate = '/users';
  static const String usersBulkCreate = '/users/bulk';

  // Rooms
  static const String rooms = '/rooms';
  static const String roomsCreate = '/rooms';
  static String roomJoin(String roomId) => '/rooms/$roomId/join';
  static String roomLeave(String roomId) => '/rooms/$roomId/leave';
  static String roomParticipants(String roomId) =>
      '/rooms/$roomId/participants';
  static String roomMessages(String roomId) => '/rooms/$roomId/messages';
  static String roomEvents(String roomId) => '/rooms/$roomId/events';

  // Calls
  static const String callsInitiate = '/calls/initiate';
  static String callAccept(String callId) => '/calls/$callId/accept';
  static String callReject(String callId) => '/calls/$callId/reject';

  // WebRTC
  static const String webrtcOffer = '/webrtc/offer';
  static const String webrtcAnswer = '/webrtc/answer';
  static const String webrtcIceCandidate = '/webrtc/ice-candidate';

  // File upload
  static const String upload = '/upload';

  // Billing
  static const String billingSubscription = '/billing/subscription';
  static const String billingUsage = '/billing/usage';
  static const String billingCheckout = '/billing/checkout';

  // Usage analytics
  static const String usage = '/usage';
  static const String usageSummary = '/usage/summary';
}

/// WebSocket channel patterns
class ChannelPatterns {
  static String roomChannel(String roomId) => 'private-room.$roomId';
  static String userChannel(String clientId, String userId) =>
      'private-client.$clientId.user.$userId';
  static String clientChannel(String clientId) => 'private-client.$clientId';
}

/// Validation helpers
class ValidationUtils {
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(email);
  }

  static bool isValidUsername(String username) {
    return username.length >= 3 &&
        username.length <= TalkLynkConstants.maxUsernameLength &&
        RegExp(r'^[a-zA-Z0-9_-]+').hasMatch(username);
  }

  static bool isValidRoomName(String roomName) {
    return roomName.trim().isNotEmpty &&
        roomName.length <= TalkLynkConstants.maxRoomNameLength;
  }

  static bool isValidDisplayName(String displayName) {
    return displayName.trim().isNotEmpty &&
        displayName.length <= TalkLynkConstants.maxDisplayNameLength;
  }

  static bool isValidFileSize(int size, int maxSize) {
    return size > 0 && size <= maxSize;
  }

  static bool isSupportedImageType(String mimeType) {
    return TalkLynkConstants.supportedImageTypes
        .contains(mimeType.toLowerCase());
  }

  static bool isSupportedVideoType(String mimeType) {
    return TalkLynkConstants.supportedVideoTypes
        .contains(mimeType.toLowerCase());
  }

  static bool isSupportedAudioType(String mimeType) {
    return TalkLynkConstants.supportedAudioTypes
        .contains(mimeType.toLowerCase());
  }
}

/// Formatting utilities
class FormatUtils {
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  static String getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }
}

/// Logging utilities
class LogUtils {
  static void logInfo(String tag, String message) {
    print('[INFO] $tag: $message');
  }

  static void logError(String tag, String message,
      [dynamic error, StackTrace? stackTrace]) {
    print('[ERROR] $tag: $message');
    if (error != null) {
      print('[ERROR] $tag: Error details: $error');
    }
    if (stackTrace != null) {
      print('[ERROR] $tag: Stack trace: $stackTrace');
    }
  }

  static void logWarning(String tag, String message) {
    print('[WARNING] $tag: $message');
  }

  static void logDebug(String tag, String message) {
    print('[DEBUG] $tag: $message');
  }
}
