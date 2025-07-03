import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/src/models/custom_event.dart';
import 'package:talklynk_sdk/src/services/websocket_service.dart';

class EventProvider extends ChangeNotifier {
  final WebSocketService _webSocketService;

  final List<CustomEvent> _events = [];
  final Map<String, StreamController<CustomEvent>> _eventStreams = {};

  EventProvider(this._webSocketService) {
    _setupCustomEventListeners();
  }

  // Getters
  List<CustomEvent> get events => List.unmodifiable(_events);

  void _setupCustomEventListeners() {
    // Listen for any custom events (events starting with 'custom.')
    _webSocketService.on<Map<String, dynamic>>('*').listen((data) {
      final eventType = data['event'];
      if (eventType != null && eventType.toString().startsWith('custom.')) {
        _handleCustomEvent(data);
      }
    });
  }

  // Listen to specific custom event types
  Stream<CustomEvent> onCustomEvent(String eventType) {
    final streamKey = 'custom.$eventType';

    if (!_eventStreams.containsKey(streamKey)) {
      _eventStreams[streamKey] = StreamController<CustomEvent>.broadcast();
    }

    return _eventStreams[streamKey]!.stream;
  }

  // Listen to all custom events
  Stream<CustomEvent> onAnyCustomEvent() {
    const streamKey = 'custom.*';

    if (!_eventStreams.containsKey(streamKey)) {
      _eventStreams[streamKey] = StreamController<CustomEvent>.broadcast();
    }

    return _eventStreams[streamKey]!.stream;
  }

  void _handleCustomEvent(Map<String, dynamic> data) {
    try {
      final eventData = data['data'] ?? data;
      final event = CustomEvent.fromJson(eventData);

      _events.add(event);

      // Limit stored events to last 100
      if (_events.length > 100) {
        _events.removeAt(0);
      }

      // Emit to specific event type listeners
      final specificStreamKey = 'custom.${event.eventType}';
      if (_eventStreams.containsKey(specificStreamKey)) {
        _eventStreams[specificStreamKey]!.add(event);
      }

      // Emit to general custom event listeners
      const generalStreamKey = 'custom.*';
      if (_eventStreams.containsKey(generalStreamKey)) {
        _eventStreams[generalStreamKey]!.add(event);
      }

      notifyListeners();
    } catch (e) {
      print('Failed to handle custom event: $e');
    }
  }

  @override
  void dispose() {
    for (final controller in _eventStreams.values) {
      controller.close();
    }
    _eventStreams.clear();
    super.dispose();
  }
}
