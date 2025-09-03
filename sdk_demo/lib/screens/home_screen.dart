// example/lib/screens/home_screen.dart - Corrected Version

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sdk_demo/screens/call_screen.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

import 'profile_tab.dart';
import 'rooms_tab.dart';
import 'users_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  OverlayEntry? _callOverlay;

  // Call state tracking to prevent duplicate navigation
  bool _isNavigatingToCall = false;
  String? _lastIncomingCallId;

  // Store reference to CallProvider to properly remove listener
  CallProvider? _callProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Setup call listeners after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupCallListeners();
      }
    });
  }

  @override
  void dispose() {
    // Remove the listener before disposing
    _callProvider?.removeListener(_handleCallStateChange);
    _tabController.dispose();
    _hideIncomingCallOverlay();
    super.dispose();
  }

  void _setupCallListeners() {
    if (!mounted) return;

    // Get reference to CallProvider and add listener
    _callProvider = context.read<CallProvider>();

    // Ensure call event listeners are setup
    _callProvider!.ensureListenersSetup();

    // Add state change listener
    _callProvider!.addListener(_handleCallStateChange);

    print('📞 Home screen call listeners setup completed');
    print('📞 CallProvider listeners setup: ${_callProvider!.listenersSetup}');
  }

  void _handleCallStateChange() {
    // Always check if widget is still mounted
    if (!mounted || _callProvider == null) return;

    final callProvider = _callProvider!;

    // Handle incoming call overlay
    _handleIncomingCall(callProvider);

    // Handle active call navigation
    _handleActiveCall(callProvider);
  }

  void _handleIncomingCall(CallProvider callProvider) {
    if (!mounted) return;

    if (callProvider.hasIncomingCall) {
      final incomingCall = callProvider.incomingCall!;

      // Only show overlay if it's a new call or no overlay exists
      if (_callOverlay == null || _lastIncomingCallId != incomingCall.callId) {
        _hideIncomingCallOverlay(); // Hide existing overlay first
        _showIncomingCallOverlay(incomingCall);
        _lastIncomingCallId = incomingCall.callId;
      }
    } else {
      // No incoming call, hide overlay if it exists
      if (_callOverlay != null) {
        _hideIncomingCallOverlay();
        _lastIncomingCallId = null;
      }
    }
  }

  void _handleActiveCall(CallProvider callProvider) {
    if (!mounted) return;

    if (callProvider.hasActiveCall && !_isNavigatingToCall) {
      _isNavigatingToCall = true;
      _hideIncomingCallOverlay(); // Hide incoming call overlay
      _navigateToCallScreen(callProvider.currentCall!);
    } else if (!callProvider.hasActiveCall) {
      _isNavigatingToCall = false;
    }
  }

  void _showIncomingCallOverlay(Call call) {
    if (!mounted) return;

    try {
      _callOverlay = OverlayEntry(
        builder: (context) => IncomingCallOverlay(
          call: call,
          onCallAccepted: () {
            if (mounted) {
              _hideIncomingCallOverlay();
              // Navigation to call screen will be handled by _handleActiveCall
            }
          },
          onCallRejected: () {
            if (mounted) {
              _hideIncomingCallOverlay();
            }
          },
        ),
      );

      Overlay.of(context).insert(_callOverlay!);
    } catch (e) {
      debugPrint('Error showing incoming call overlay: $e');
      _callOverlay = null;
    }
  }

  void _hideIncomingCallOverlay() {
    if (_callOverlay != null) {
      try {
        _callOverlay!.remove();
      } catch (e) {
        debugPrint('Error removing call overlay: $e');
      } finally {
        _callOverlay = null;
      }
    }
  }

  void _navigateToCallScreen(Call call) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          call: call,
          onCallEnded: () {
            // Reset navigation state when call ends
            if (mounted) {
              _isNavigatingToCall = false;
            }
          },
        ),
      ),
    ).then((_) {
      // Reset navigation state when returning from call screen
      if (mounted) {
        _isNavigatingToCall = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalkLynk'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Connection status indicator
          Consumer<CallProvider>(
            builder: (context, callProvider, child) {
              return IconButton(
                onPressed: () {
                  _showConnectionStatus();
                },
                icon: Icon(
                  TalkLynkSDK.instance.websocket.isConnected
                      ? Icons.wifi
                      : Icons.wifi_off,
                  color: TalkLynkSDK.instance.websocket.isConnected
                      ? Colors.white
                      : Colors.red,
                ),
                tooltip: TalkLynkSDK.instance.websocket.isConnected
                    ? 'Connected'
                    : 'Disconnected',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.video_call),
              text: 'Rooms',
            ),
            Tab(
              icon: Icon(Icons.people),
              text: 'Users',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: 'Profile',
            ),
          ],
        ),
      ),
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          // Show loading overlay if call is being processed
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: const [
                  RoomsTab(),
                  UsersTab(),
                  ProfileTab(),
                ],
              ),

              // Show loading overlay for call operations
              if (callProvider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing call...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Show error snackbar if there's an error
              if (callProvider.error != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              callProvider.error!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              callProvider.clearError();
                            },
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showConnectionStatus() {
    if (!mounted) return;

    final isConnected = TalkLynkSDK.instance.websocket.isConnected;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isConnected ? 'Connected' : 'Disconnected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnected
                  ? 'You are connected to TalkLynk servers and can receive calls.'
                  : 'You are disconnected from TalkLynk servers. You may not receive calls.',
            ),
            const SizedBox(height: 16),
            if (!isConnected) ...[
              const Text(
                'Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Check your internet connection'),
              const Text('• Try restarting the app'),
              const Text('• Contact support if issue persists'),
            ],
          ],
        ),
        actions: [
          if (!isConnected)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                TalkLynkSDK.instance.websocket.connect();
              },
              child: const Text('Retry Connection'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
