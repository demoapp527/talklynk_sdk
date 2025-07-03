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
        'Authorization': 'Bearer $apiKey',
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

  Future<List<User>> getUsers({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get('/users', queryParameters: {
        'page': page,
        'per_page': perPage,
      });

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Failed to get users: $e');
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
      final response = await _dio.post('/users', data: {
        'name': name,
        'email': email,
        'external_id': externalId,
        'avatar_url': avatarUrl,
        'metadata': metadata,
      });

      return User.fromJson(response.data);
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

      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => Participant.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Failed to get room participants: $e');
      rethrow;
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
