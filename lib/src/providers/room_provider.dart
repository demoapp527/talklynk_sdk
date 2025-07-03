import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/src/models/participant.dart';
import 'package:talklynk_sdk/src/models/room.dart';
import 'package:talklynk_sdk/src/services/api_service.dart';
import 'package:talklynk_sdk/src/services/websocket_service.dart';

class RoomProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _webSocketService;

  List<Room> _rooms = [];
  Room? _currentRoom;
  List<Participant> _currentRoomParticipants = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _roomEventsSubscription;

  RoomProvider(this._apiService, this._webSocketService) {
    _setupRoomEventListeners();
  }

  // Getters
  List<Room> get rooms => _rooms;
  Room? get currentRoom => _currentRoom;
  List<Participant> get currentRoomParticipants => _currentRoomParticipants;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInRoom => _currentRoom != null;

  void _setupRoomEventListeners() {
    // Listen for user joined events
    _webSocketService.on<Map<String, dynamic>>('user.joined').listen((data) {
      _handleUserJoined(data);
    });

    // Listen for user left events
    _webSocketService.on<Map<String, dynamic>>('user.left').listen((data) {
      _handleUserLeft(data);
    });

    // Listen for room subscription success
    _webSocketService
        .on<Map<String, dynamic>>('room:subscription_succeeded')
        .listen((data) {
      _handleRoomSubscriptionSucceeded(data);
    });
  }

  // Load rooms list
  Future<bool> loadRooms() async {
    _setLoading(true);
    _setError(null);

    try {
      final rooms = await _apiService.getRooms();
      _rooms = rooms;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to load rooms: $e');
      _setLoading(false);
      return false;
    }
  }

  // Create new room
  Future<Room?> createRoom({
    required String name,
    required RoomType type,
    int maxParticipants = 10,
    bool isOneToOne = false,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final room = await _apiService.createRoom(
        name: name,
        type: type,
        maxParticipants: maxParticipants,
        isOneToOne: isOneToOne,
      );

      _rooms.insert(0, room);
      _setLoading(false);
      notifyListeners();
      return room;
    } catch (e) {
      _setError('Failed to create room: $e');
      _setLoading(false);
      return null;
    }
  }

  // Join room
  Future<bool> joinRoom({
    required String roomId,
    required String username,
    String? externalId,
    String? displayName,
    Map<String, dynamic>? userMetadata,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _apiService.joinRoom(
        roomId: roomId,
        username: username,
        externalId: externalId,
        displayName: displayName,
        userMetadata: userMetadata,
      );

      if (result['success'] == true) {
        _currentRoom = Room.fromJson(result['room']);

        // Subscribe to room events via WebSocket
        await _webSocketService.connect();
        _webSocketService.subscribeToRoom(roomId);

        // Load participants
        await _loadRoomParticipants(roomId);

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        throw Exception(result['error'] ?? 'Failed to join room');
      }
    } catch (e) {
      _setError('Failed to join room: $e');
      _setLoading(false);
      return false;
    }
  }

  // Leave current room
  Future<bool> leaveRoom({
    String? username,
    String? externalId,
  }) async {
    if (_currentRoom == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      await _apiService.leaveRoom(
        roomId: _currentRoom!.roomId,
        username: username,
        externalId: externalId,
      );

      // Unsubscribe from room events
      _webSocketService.unsubscribeFromRoom(_currentRoom!.roomId);

      _currentRoom = null;
      _currentRoomParticipants.clear();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to leave room: $e');
      _setLoading(false);
      return false;
    }
  }

  // Load room participants
  Future<bool> _loadRoomParticipants(String roomId) async {
    try {
      final participants = await _apiService.getRoomParticipants(roomId);
      _currentRoomParticipants = participants;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to load participants: $e');
      return false;
    }
  }

  // Event handlers
  void _handleUserJoined(Map<String, dynamic> data) {
    try {
      if (data['room_id'] == _currentRoom?.roomId) {
        final participant = Participant.fromJson(data['participant'] ?? data);

        // Check if participant already exists
        final existingIndex = _currentRoomParticipants.indexWhere(
          (p) => p.userId == participant.userId,
        );

        if (existingIndex >= 0) {
          _currentRoomParticipants[existingIndex] = participant;
        } else {
          _currentRoomParticipants.add(participant);
        }

        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to handle user joined: $e');
    }
  }

  void _handleUserLeft(Map<String, dynamic> data) {
    try {
      if (data['room_id'] == _currentRoom?.roomId) {
        final userId =
            data['user']?['id']?.toString() ?? data['user_id']?.toString();

        if (userId != null) {
          _currentRoomParticipants.removeWhere((p) => p.userId == userId);
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Failed to handle user left: $e');
    }
  }

  void _handleRoomSubscriptionSucceeded(Map<String, dynamic> data) {
    // Room subscription succeeded, we can now receive real-time updates
    print('Successfully subscribed to room: ${data['room_id']}');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _roomEventsSubscription?.cancel();
    super.dispose();
  }
}
