import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class ApiService {
  final Dio _dio;
  final Logger _logger;
  final String baseUrl;
  final String apiKey;

  ApiService({
    required this.baseUrl,
    required this.apiKey,
    bool enableLogs = false,
  })  : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        ),
        _dio = Dio() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: '$baseUrl/api/sdk',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
        'User-Agent': 'Flutter-TalkLynk-SDK/1.0',
      },
    );

    // Add logging interceptor
    if (Logger.level == Level.debug) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
        logPrint: (obj) => _logger.d(obj),
      ));
    }

    // Add error handling interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        _handleDioError(error);
        handler.next(error);
      },
    ));
  }

  void _handleDioError(DioException error) {
    _logger.e('API Error: ${error.message}');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw NetworkException(
            'Request timeout. Please check your connection.');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        if (statusCode == 401) {
          throw AuthenticationException(
              'Invalid API key or authentication failed.');
        } else if (statusCode == 403) {
          throw AuthorizationException(
              'Access forbidden. Check your permissions.');
        } else if (statusCode == 404) {
          throw NotFoundException('Resource not found.');
        } else if (statusCode == 429) {
          throw RateLimitException(
              'Rate limit exceeded. Please try again later.');
        } else if (statusCode != null && statusCode >= 500) {
          throw ServerException('Server error. Please try again later.');
        } else {
          final message = data is Map && data.containsKey('error')
              ? data['error']
              : 'Request failed with status $statusCode';
          throw ApiException(message);
        }
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException')) {
          throw NetworkException('No internet connection.');
        }
        throw ApiException('Unknown error occurred: ${error.message}');
      default:
        throw ApiException('Request failed: ${error.message}');
    }
  }

  Future<Map<String, dynamic>> post({
    required Uri url,
    required Object data,
  }) async {
    try {
      final response = await _dio.post(url.toString(), data: data);
      return response.data;
    } catch (e) {
      _logger.e('Failed to join room: $e');
      rethrow;
    }
  }

  // ===== USER ENDPOINTS =====

  // Future<List<User>> getUsers({int page = 1, int perPage = 20}) async {
  //   try {
  //     final response = await _dio.get('/users', queryParameters: {
  //       'page': page,
  //       'per_page': perPage,
  //     });

  //     final List<dynamic> data = response.data['data'] ?? response.data;
  //     _logger.d('✅ Users list: ${data.length}');
  //     return data.map((json) => User.fromJson(json)).toList();
  //   } catch (e) {
  //     _logger.e('Failed to get users: $e');
  //     rethrow;
  //   }
  // }

  // Future<User?> findUserByExternalId(String externalId) async {
  //   try {
  //     _logger.d('🔍 Finding user by external_id: $externalId');

  //     final users = await getUsers(perPage: 100); // Get more users to search

  //     final user = users.firstWhere(
  //       (u) => u.externalId == externalId,
  //       orElse: () => throw Exception('User not found'),
  //     );

  //     _logger.d('✅ Found user: ${user.name}');
  //     return user;
  //   } catch (e) {
  //     _logger.d('❌ User not found by external_id: $externalId');
  //     return null;
  //   }
  // }

  // /// Find user by username
  // Future<User?> findUserByUsername(String username) async {
  //   try {
  //     _logger.d('🔍 Finding user by username: $username');

  //     final users = await getUsers(perPage: 100);

  //     final user = users.firstWhere(
  //       (u) => u.name.toLowerCase() == username.toLowerCase(),
  //       orElse: () => throw Exception('User not found'),
  //     );

  //     _logger.d('✅ Found user: ${user.name}');
  //     return user;
  //   } catch (e) {
  //     _logger.d('❌ User not found by username: $username');
  //     return null;
  //   }
  // }

  /// Find user by email
  // Future<User?> findUserByEmail(String email) async {
  //   try {
  //     _logger.d('🔍 Finding user by email: $email');

  //     final users = await getUsers(perPage: 100);

  //     final user = users.firstWhere(
  //       (u) => u.email?.toLowerCase() == email.toLowerCase(),
  //       orElse: () => throw Exception('User not found'),
  //     );

  //     _logger.d('✅ Found user: ${user.name}');
  //     return user;
  //   } catch (e) {
  //     _logger.d('❌ User not found by email: $email');
  //     return null;
  //   }
  // }

  /// Smart user lookup - try multiple methods
  // Future<User?> findUser({
  //   String? username,
  //   String? externalId,
  //   String? email,
  // }) async {
  //   _logger.d(
  //       '🔍 Smart user lookup - username: $username, externalId: $externalId, email: $email');

  //   // Try external_id first (most reliable)
  //   if (externalId != null) {
  //     final user = await findUserByExternalId(externalId);
  //     if (user != null) return user;
  //   }

  //   // Try email second
  //   if (email != null) {
  //     final user = await findUserByEmail(email);
  //     if (user != null) return user;
  //   }

  //   // Try username last
  //   if (username != null) {
  //     final user = await findUserByUsername(username);
  //     if (user != null) return user;
  //   }

  //   _logger.d('❌ User not found with any method');
  //   return null;
  // }

  Future<User> loginOrCreateUser({
    required String username,
    String? email,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final userEmail =
        email ?? '${username.toLowerCase().replaceAll(' ', '_')}@sdk.user';
    try {
      _logger.d('🔄 Login or create user: $username');

      // Generate email (consistent across attempts)

      // First, try to find existing user
      final existingUser = await findUser(
        username: username,
        externalId: externalId,
        email: email,
      );

      if (existingUser != null) {
        _logger.d('✅ Found existing user: ${existingUser.name}');
        return existingUser;
      }

      // User doesn't exist, create new one
      _logger.d('👤 Creating new user: $username');

      return await createUser(
        name: username,
        email: email,
        externalId: externalId,
        avatarUrl: avatarUrl,
        metadata: metadata,
      );
    } catch (e) {
      _logger.e('❌ Login or create user failed: $e');

      // If creation failed due to duplicate, try to find the user again
      if (e.toString().contains('already exists') ||
          e.toString().contains('duplicate') ||
          e.toString().contains('Email already exists')) {
        _logger.d('🔄 User might exist, trying to find again...');

        // Wait a bit and try finding user again
        await Future.delayed(Duration(milliseconds: 500));

        final existingUser = await findUser(
          username: username,
          externalId: externalId,
          email: userEmail,
        );

        if (existingUser != null) {
          _logger
              .d('✅ Found user after creation failure: ${existingUser.name}');
          return existingUser;
        }
      }

      rethrow;
    }
  }

  Future<User> createUser({
    required String name,
    String? email,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.d('🌐 Making request to: ${_dio.options.baseUrl}/users');
      final userEmail =
          email ?? '${name.toLowerCase().replaceAll(' ', '_')}@sdk.user';
      final response = await _dio.post('/users', data: {
        'name': name,
        'email': userEmail,
        'external_id': externalId,
        'avatar_url': avatarUrl,
        'metadata': metadata,
      });
      return User.fromJson(response.data['data']);
    } catch (e) {
      _logger.e('Failed to create user: $e');
      rethrow;
    }
  }

  // ===== ROOM ENDPOINTS =====

  Future<List<Room>> getRooms({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/rooms', queryParameters: {
        'page': page,
        'per_page': perPage,
      });

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Failed to get rooms: $e');
      rethrow;
    }
  }

  Future<Room> createRoom({
    required String name,
    required RoomType type,
    int maxParticipants = 10,
    bool isOneToOne = false,
  }) async {
    try {
      final response = await _dio.post('/rooms', data: {
        'name': name,
        'type': type.name,
        'max_participants': maxParticipants,
        'is_one_to_one': isOneToOne,
      });

      return Room.fromJson(response.data);
    } catch (e) {
      _logger.e('Failed to create room: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String username,
    String? externalId,
    String? displayName,
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final response = await _dio.post('/rooms/$roomId/join', data: {
        'username': username,
        'external_id': externalId,
        'display_name': displayName,
        'user_metadata': userMetadata,
      });

      return response.data;
    } catch (e) {
      _logger.e('Failed to join room: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom({
    required String roomId,
    String? username,
    String? externalId,
  }) async {
    try {
      await _dio.post('/rooms/$roomId/leave', data: {
        'username': username,
        'external_id': externalId,
      });
    } catch (e) {
      _logger.e('Failed to leave room: $e');
      rethrow;
    }
  }

  Future<List<Participant>> getRoomParticipants(String roomId) async {
    try {
      final response = await _dio.get('/rooms/$roomId/participants');

      final List<dynamic> data = response.data['data']['data'] ?? [];
      return data.map((json) => Participant.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Failed to get room participants: $e');
      rethrow;
    }
  }

  // ===== USER ENDPOINTS =====

  Future<List<User>> getUsers({
    int page = 1,
    int perPage = 20,
    String? username,
    String? search,
    String? email,
    String? externalId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      // Add search parameters if provided
      if (username != null && username.isNotEmpty) {
        queryParams['username'] = username;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (email != null && email.isNotEmpty) {
        queryParams['email'] = email;
      }
      if (externalId != null && externalId.isNotEmpty) {
        queryParams['external_id'] = externalId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      _logger.d('🔍 Getting users with params: $queryParams');

      final response = await _dio.get('/users', queryParameters: queryParams);

      // Handle Laravel pagination response structure
      List<dynamic> data;
      if (response.data is Map && response.data.containsKey('data')) {
        // Laravel pagination response: {"data": [...], "current_page": 1, "total": 10, ...}
        data = response.data['data'] ?? [];
      } else if (response.data is List) {
        // Direct array response
        data = response.data;
      } else {
        // Fallback
        data = [];
      }

      _logger.d('✅ Users list retrieved: ${data.length} users');

      final users = data.map((json) => User.fromJson(json)).toList();

      // Client-side filtering if search was not handled by backend
      if ((username != null || search != null) && users.isNotEmpty) {
        final searchTerm = (username ?? search ?? '').toLowerCase();
        final filteredUsers = users.where((user) {
          final name = user.name.toLowerCase();
          final userExternalId = (user.externalId ?? '').toLowerCase();
          final userEmail = (user.email ?? '').toLowerCase();

          return name.contains(searchTerm) ||
              userExternalId.contains(searchTerm) ||
              userEmail.contains(searchTerm);
        }).toList();

        _logger.d(
            '🔍 Filtered ${users.length} users to ${filteredUsers.length} results');
        return filteredUsers;
      }

      return users;
    } catch (e) {
      _logger.e('Failed to get users: $e');
      rethrow;
    }
  }

  Future<User?> findUserByExternalId(String externalId) async {
    try {
      _logger.d('🔍 Finding user by external_id: $externalId');

      // Try direct API lookup first
      try {
        final response = await _dio.get('/users/$externalId');
        final user = User.fromJson(response.data);
        _logger.d('✅ Found user by external_id: ${user.name}');
        return user;
      } catch (e) {
        // If direct lookup fails, try searching in users list
        _logger.d('Direct lookup failed, searching in users list...');
      }

      // Fallback to search in users list
      final users = await getUsers(perPage: 100, externalId: externalId);

      final user = users.firstWhere(
        (u) => u.externalId == externalId,
        orElse: () => throw Exception('User not found'),
      );

      _logger.d('✅ Found user: ${user.name}');
      return user;
    } catch (e) {
      _logger.d('❌ User not found by external_id: $externalId');
      return null;
    }
  }

  /// Find user by username with optimized search
  Future<User?> findUserByUsername(String username) async {
    try {
      _logger.d('🔍 Finding user by username: $username');

      // Try direct API lookup first
      try {
        final response = await _dio.get('/users/$username');
        final user = User.fromJson(response.data);
        _logger.d('✅ Found user by username: ${user.name}');
        return user;
      } catch (e) {
        // If direct lookup fails, try searching with username filter
        _logger.d('Direct lookup failed, searching with username filter...');
      }

      // Fallback to search in users list
      final users = await getUsers(perPage: 100, username: username);

      final user = users.firstWhere(
        (u) => u.name.toLowerCase() == username.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );

      _logger.d('✅ Found user: ${user.name}');
      return user;
    } catch (e) {
      _logger.d('❌ User not found by username: $username');
      return null;
    }
  }

  /// Find user by email with optimized search
  Future<User?> findUserByEmail(String email) async {
    try {
      _logger.d('🔍 Finding user by email: $email');

      // Try searching with email parameter
      final users = await getUsers(perPage: 100, email: email);

      final user = users.firstWhere(
        (u) => u.email?.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );

      _logger.d('✅ Found user: ${user.name}');
      return user;
    } catch (e) {
      _logger.d('❌ User not found by email: $email');
      return null;
    }
  }

  /// Smart user lookup with multiple search strategies
  Future<User?> findUser({
    String? username,
    String? externalId,
    String? email,
  }) async {
    _logger.d(
        '🔍 Smart user lookup - username: $username, externalId: $externalId, email: $email');

    // Try external_id first (most reliable)
    if (externalId != null && externalId.isNotEmpty) {
      final user = await findUserByExternalId(externalId);
      if (user != null) return user;
    }

    // Try username second
    if (username != null && username.isNotEmpty) {
      final user = await findUserByUsername(username);
      if (user != null) return user;
    }

    // Try email last
    if (email != null && email.isNotEmpty) {
      final user = await findUserByEmail(email);
      if (user != null) return user;
    }

    _logger.d('❌ User not found with any method');
    return null;
  }

  /// Search users with multiple criteria
  Future<List<User>> searchUsers({
    String? query,
    String? username,
    String? email,
    String? externalId,
    String? status,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      _logger
          .d('🔍 Searching users with query: "$query", username: "$username"');

      // Try dedicated search endpoint first if we have a general query
      if (query != null && query.isNotEmpty) {
        try {
          final response = await _dio.get('/users/search', queryParameters: {
            'query': query,
            'page': page,
            'per_page': perPage,
          });

          List<dynamic> data;
          if (response.data is Map) {
            if (response.data.containsKey('results') &&
                response.data['results'].containsKey('data')) {
              // Search endpoint with pagination: {"results": {"data": [...], ...}}
              data = response.data['results']['data'] ?? [];
            } else if (response.data.containsKey('data')) {
              // Standard pagination: {"data": [...], ...}
              data = response.data['data'] ?? [];
            } else {
              // Fallback
              data = [];
            }
          } else if (response.data is List) {
            data = response.data;
          } else {
            data = [];
          }

          final users = data.map((json) => User.fromJson(json)).toList();
          _logger.d('✅ Search endpoint returned: ${users.length} users');
          return users;
        } catch (e) {
          _logger.d(
              'Search endpoint failed, falling back to general getUsers: $e');
        }
      }

      // Fallback to general getUsers with filters
      final users = await getUsers(
        page: page,
        perPage: perPage,
        search: query,
        username: username,
        email: email,
        externalId: externalId,
        status: status ?? 'active',
      );

      _logger.d('✅ Search completed: ${users.length} users found');
      return users;
    } catch (e) {
      _logger.e('❌ Search failed: $e');
      return [];
    }
  }

  /// Get users by status (active, inactive, banned)
  Future<List<User>> getUsersByStatus(String status,
      {int page = 1, int perPage = 20}) async {
    try {
      _logger.d('🔍 Getting users by status: $status');

      return await getUsers(
        page: page,
        perPage: perPage,
        status: status,
      );
    } catch (e) {
      _logger.e('Failed to get users by status: $e');
      rethrow;
    }
  }

  /// Get active users only
  Future<List<User>> getActiveUsers({int page = 1, int perPage = 20}) async {
    return await getUsersByStatus('active', page: page, perPage: perPage);
  }

  /// Advanced user search with multiple filters
  Future<List<User>> advancedUserSearch({
    String? nameQuery,
    String? emailQuery,
    String? externalIdQuery,
    String? status = 'active',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      _logger.d('🔍 Advanced user search with multiple filters');

      final users = await getUsers(
        page: page,
        perPage: perPage,
        username: nameQuery,
        email: emailQuery,
        externalId: externalIdQuery,
        status: status,
      );

      _logger.d('✅ Advanced search completed: ${users.length} users found');
      return users;
    } catch (e) {
      _logger.e('❌ Advanced search failed: $e');
      return [];
    }
  }

  //====Webrtc endpoints ====
  Future<TurnCredentials> getTurnCredentials() async {
    try {
      final response = await _dio.get('/turn-credentials');
      return TurnCredentials.fromJson(response.data);
    } catch (e) {
      _logger.e('Failed to get room participants: $e');
      rethrow;
    }
  }

  Future<void> postOffer({
    Object? data,
  }) async {
    try {
      await _dio.post('/webrtc/offer', data: data);
    } catch (e) {
      _logger.e('Failed to leave room: $e');
      rethrow;
    }
  }

  Future<void> postAnswer({
    Object? data,
  }) async {
    try {
      await _dio.post('/webrtc/answer', data: data);
    } catch (e) {
      _logger.e('Failed to leave room: $e');
      rethrow;
    }
  }

  Future<void> postIceCandidate({
    Object? data,
  }) async {
    try {
      await _dio.post('/webrtc/ice-candidate', data: data);
    } catch (e) {
      _logger.e('Failed to leave room: $e');
      rethrow;
    }
  }

  // ===== CALL ENDPOINTS =====

  Future<Call> initiateCall({
    required String callerId,
    required String calleeId,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post('/calls/initiate', data: {
        'caller_id': callerId,
        'callee_id': calleeId,
        'call_type': type.name,
        'metadata': metadata,
      });

      return Call.fromJson(response.data);
    } catch (e) {
      _logger.e('Failed to initiate call: $e');
      rethrow;
    }
  }

  Future<Call> acceptCall({
    required String callId,
    required String calleeId,
  }) async {
    try {
      final response = await _dio.post('/calls/$callId/accept', data: {
        'callee_id': calleeId,
      });

      return Call.fromJson(response.data);
    } catch (e) {
      _logger.e('Failed to accept call: $e');
      rethrow;
    }
  }

  Future<void> rejectCall({
    required String callId,
    required String calleeId,
    String? reason,
  }) async {
    try {
      await _dio.post('/calls/$callId/reject', data: {
        'callee_id': calleeId,
        'reason': reason,
      });
    } catch (e) {
      _logger.e('Failed to reject call: $e');
      rethrow;
    }
  }

  Future<void> endCall({
    required String callId,
    required String userId,
    String? reason,
  }) async {
    try {
      await _dio.post('/calls/$callId/end', data: {
        'user_id': userId,
        'reason': reason,
      });
    } catch (e) {
      _logger.e('Failed to end call: $e');
      rethrow;
    }
  }

  // ===== CUSTOM EVENTS =====

  Future<void> sendCustomEvent({
    required String roomId,
    required String eventType,
    required String senderId,
    List<String> targetIds = const [],
    bool broadcastToAll = false,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await _dio.post('/rooms/$roomId/events', data: {
        'event_type': eventType,
        'sender_id': senderId,
        'target_ids': targetIds,
        'broadcast_to_all': broadcastToAll,
        'data': data,
      });
    } catch (e) {
      _logger.e('Failed to send custom event: $e');
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}
