import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sdk_demo/screens/call_screen.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

import 'incoming_call_screen.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({Key? key}) : super(key: key);

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
    _setupCallCallbacks();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _setupCallCallbacks() {
    // Setup call event callbacks for navigation
    context.read<CallProvider>().setCallCallbacks(
          onCallAccepted: _onCallAccepted,
          onIncomingCall: _onIncomingCall,
          onCallRejected: _onCallRejected,
          onCallEnded: _onCallEnded,
        );
  }

  void _onCallAccepted(Call call) {
    _logger.d('📞 Call accepted, navigating to call screen');

    // Navigate to call screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          call: call,
          onCallEnded: () {
            _logger.d('📞 Call ended from call screen');
          },
        ),
      ),
    );
  }

  void _onIncomingCall(Call call) {
    _logger.d('📞 Incoming call received, showing incoming call screen');

    // Show incoming call screen as overlay or navigate
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallScreen(
        call: call,
        onAccept: () async {
          Navigator.pop(context); // Close incoming call dialog

          final currentUser = context.read<AuthProvider>().currentUser;
          if (currentUser != null) {
            final success = await context.read<CallProvider>().acceptCall(
                  currentUser.externalId ?? currentUser.id,
                );

            if (success) {
              // Navigation to call screen will be handled by onCallAccepted callback
              _logger.d('📞 Call accepted successfully');
            } else {
              _showErrorSnackBar('Failed to accept call');
            }
          }
        },
        onReject: () async {
          Navigator.pop(context); // Close incoming call dialog

          final currentUser = context.read<AuthProvider>().currentUser;
          if (currentUser != null) {
            await context.read<CallProvider>().rejectCall(
                  currentUser.externalId ?? currentUser.id,
                  reason: 'declined',
                );
          }
        },
      ),
    );
  }

  void _onCallRejected(Call call) {
    _logger.d('📞 Call rejected');
    _showErrorSnackBar('Call was rejected');
  }

  void _onCallEnded(Call call) {
    _logger.d('📞 Call ended');
    // Close call screen if it's open
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _filterUsers();
      });
    });
  }

  void _filterUsers() {
    final currentUser = context.read<AuthProvider>().currentUser;
    final otherUsers =
        _users.where((user) => user.id != currentUser?.id).toList();

    if (_searchQuery.isEmpty) {
      _filteredUsers = otherUsers;
    } else {
      _filteredUsers = otherUsers.where((user) {
        final name = user.name.toLowerCase();
        final externalId = (user.externalId ?? '').toLowerCase();
        final email = (user.email ?? '').toLowerCase();

        return name.contains(_searchQuery) ||
            externalId.contains(_searchQuery) ||
            email.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await TalkLynkSDK.instance.api.getUsers(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _filterUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchUserByUsername() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await TalkLynkSDK.instance.api.searchUsers(
        query: searchText,
        perPage: 50,
      );

      if (users.isNotEmpty && mounted) {
        for (final user in users) {
          final existingIndex = _users.indexWhere((u) => u.id == user.id);
          if (existingIndex == -1) {
            _users.add(user);
          }
        }

        setState(() {
          _searchQuery = searchText.toLowerCase();
        });
        _filterUsers();

        _showSuccessSnackBar('Found ${users.length} user(s) for "$searchText"');
      } else if (mounted) {
        _showErrorSnackBar('No users found for "$searchText"');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error searching users: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by username, email, or external ID...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _searchUserByUsername(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchUserByUsername,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_search),
                      label: const Text('Find'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Search Results Info
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _filteredUsers.isEmpty
                            ? 'No users found for "$_searchQuery"'
                            : '${_filteredUsers.length} user(s) found for "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Call Status Widget
          Consumer<CallProvider>(
            builder: (context, callProvider, child) {
              if (callProvider.hasActiveCall || callProvider.isLoading) {
                return _buildCallStatusWidget(callProvider);
              }
              return const SizedBox.shrink();
            },
          ),

          // Users List
          Expanded(
            child: _filteredUsers.isEmpty && _searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching with a different username',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty && _searchQuery.isEmpty
                    ? const Center(
                        child: Text(
                          'No other users available for calls.\nInvite friends to join!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatusWidget(CallProvider callProvider) {
    if (callProvider.isLoading && callProvider.currentCall != null) {
      final call = callProvider.currentCall!;
      final isOutgoing =
          call.caller.id == context.read<AuthProvider>().currentUser?.id;

      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOutgoing
                        ? 'Calling ${call.callee.name}...'
                        : 'Connecting...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOutgoing
                        ? 'Waiting for response (30s timeout)'
                        : 'Establishing connection',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isOutgoing)
              TextButton(
                onPressed: () async {
                  final currentUser = context.read<AuthProvider>().currentUser;
                  if (currentUser != null) {
                    await callProvider.endCall(
                      userId: currentUser.externalId ?? currentUser.id,
                      reason: 'cancelled',
                    );
                  }
                },
                child: const Text('Cancel'),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUserCard(User user) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        final isCallInProgress =
            callProvider.isLoading || callProvider.hasActiveCall;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              backgroundColor: Colors.blue,
              child: user.avatarUrl == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            title: Text(
              user.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.status == 'active'
                            ? Colors.green
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.status == 'active' ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: user.status == 'active'
                            ? Colors.green
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (user.externalId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${user.externalId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
                if (user.lastActiveAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last seen: ${_formatLastSeen(user.lastActiveAt!)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio call button
                IconButton(
                  onPressed: isCallInProgress
                      ? null
                      : () => _initiateCall(user, CallType.audio),
                  icon: const Icon(Icons.phone),
                  color: isCallInProgress ? Colors.grey : Colors.green,
                  tooltip: 'Audio Call',
                ),
                // Video call button
                IconButton(
                  onPressed: isCallInProgress
                      ? null
                      : () => _initiateCall(user, CallType.video),
                  icon: const Icon(Icons.videocam),
                  color: isCallInProgress ? Colors.grey : Colors.blue,
                  tooltip: 'Video Call',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initiateCall(User user, CallType callType) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    try {
      final success = await context.read<CallProvider>().initiateCall(
        callerId: currentUser.externalId ?? currentUser.id,
        calleeId: user.externalId ?? user.id,
        type: callType,
        metadata: {
          'initiated_from': 'users_tab',
          'caller_name': currentUser.name,
          'callee_name': user.name,
        },
      );

      if (mounted) {
        if (success) {
          _showSuccessSnackBar('Calling ${user.name}...');
        } else {
          _showErrorSnackBar('Failed to call ${user.name}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
