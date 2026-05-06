import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';

class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({
    super.key,
    required this.deviceUid,
    required this.label,
  });

  final String deviceUid;
  final String label;

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _listenConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) {
      return;
    }
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  void _listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Last active: unknown';
    }
    final delta = DateTime.now().difference(timestamp.toDate());
    if (delta.inMinutes < 1) {
      return 'Last active: just now';
    }
    if (delta.inHours < 1) {
      return 'Last active: ${delta.inMinutes}m ago';
    }
    if (delta.inDays < 1) {
      return 'Last active: ${delta.inHours}h ago';
    }
    return 'Last active: ${delta.inDays}d ago';
  }

  String _formatInstalledSync(Timestamp? timestamp, int? installedCount) {
    if (timestamp == null) {
      return 'App list not synced yet';
    }
    final delta = DateTime.now().difference(timestamp.toDate());
    final when =
        delta.inMinutes < 1
            ? 'just now'
            : delta.inHours < 1
            ? '${delta.inMinutes}m ago'
            : delta.inDays < 1
            ? '${delta.inHours}h ago'
            : '${delta.inDays}d ago';
    final count = installedCount ?? 0;
    return 'Synced $when ($count apps)';
  }

  Future<void> _toggleAllowedApp(String packageName, bool isAllowed) async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Go online to update app rules.')),
      );
      return;
    }

    final childRef = FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid);

    try {
      if (isAllowed) {
        await childRef.set({
          'allowed_apps': FieldValue.arrayUnion([packageName]),
        }, SetOptions(merge: true));
      } else {
        await childRef.update({
          'allowed_apps': FieldValue.arrayRemove([packageName]),
          'time_limits.$packageName': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update app rule right now.')),
      );
    }
  }

  Future<void> _editLimit(String packageName, int? currentLimit) async {
    final limitController = TextEditingController(
      text: currentLimit?.toString() ?? '',
    );

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App limits',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D1C2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    packageName,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A6B85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Daily limit (minutes)',
                      filled: true,
                      fillColor: const Color(0xFFF2F6FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B6B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (updated != true) {
      limitController.dispose();
      return;
    }

    final childRef = FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid);
    final limitText = limitController.text.trim();

    if (limitText.isEmpty) {
      await childRef.update({'time_limits.$packageName': FieldValue.delete()});
    } else {
      final parsedLimit = int.tryParse(limitText);
      if (parsedLimit != null) {
        await childRef.set({
          'time_limits.$packageName': parsedLimit,
          'allowed_apps': FieldValue.arrayUnion([packageName]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    limitController.dispose();
  }

  List<_InstalledApp> _parseInstalledApps(List<dynamic>? raw) {
    final apps = <_InstalledApp>[];
    for (final item in raw ?? const []) {
      if (item is Map) {
        final packageName = item['packageName'] as String? ?? '';
        if (packageName.isEmpty) {
          continue;
        }
        final appName = item['appName'] as String? ?? packageName;
        apps.add(_InstalledApp(packageName: packageName, appName: appName));
      }
    }
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF1A365D);
    const brandMuted = Color(0xFF5A6B85);
    const surface = Color(0xFFF8F9FF);

    final childStream =
        FirebaseFirestore.instance
            .collection('children')
            .doc(widget.deviceUid)
            .snapshots();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(widget.label, style: GoogleFonts.manrope()),
        backgroundColor: Colors.white,
        foregroundColor: brandDark,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1F6FF), Color(0xFFE6F3EE)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: childStream,
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      final isOnline = data?['isOnline'] == true;
                      final lastSeen = _formatLastSeen(
                        data?['lastSeen'] as Timestamp?,
                      );
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.04),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device UID',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: brandMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.deviceUid,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0D1C2E),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lastSeen,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: brandMuted,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:
                                        isOnline
                                            ? const Color(0xFF2E8B6B)
                                            : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isOnline
                                            ? const Color(0xFF2E8B6B)
                                            : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_isOffline) const SizedBox(height: 12),
                  if (_isOffline)
                    NetworkStatusBanner(
                      isOffline: _isOffline,
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                  if (_isOffline) const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  Text(
                    'Installed apps',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: brandDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select allowed apps and set daily limits.',
                    style: GoogleFonts.manrope(fontSize: 12, color: brandMuted),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: childStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _EmptyState(
                            message: 'Unable to load installed apps right now.',
                          );
                        }

                        final data = snapshot.data?.data();
                        final installedApps = _parseInstalledApps(
                          data?['installed_apps'] as List<dynamic>?,
                        );
                        final allowedApps =
                            (data?['allowed_apps'] as List<dynamic>?)
                                ?.cast<String>() ??
                            <String>[];
                        final blockedApps =
                            (data?['blocked_apps'] as List<dynamic>?)
                                ?.cast<String>() ??
                            <String>[];
                        final limits =
                            (data?['time_limits'] as Map<String, dynamic>?) ??
                            const <String, dynamic>{};
                        final installedUpdatedAt =
                            data?['installedUpdatedAt'] as Timestamp?;
                        final installedCount =
                            (data?['installed_count'] as num?)?.toInt() ??
                            installedApps.length;

                        if (installedApps.isEmpty) {
                          return _EmptyState(
                            message:
                                'No installed apps yet. Open child mode on the child device, allow app access, then tap "Sync installed apps".',
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                right: 4,
                                bottom: 10,
                              ),
                              child: Text(
                                _formatInstalledSync(
                                  installedUpdatedAt,
                                  installedCount,
                                ),
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: brandMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: installedApps.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final app = installedApps[index];
                                  final isAllowed = allowedApps.contains(
                                    app.packageName,
                                  );
                                  final limitValue = limits[app.packageName];
                                  final limitMinutes =
                                      limitValue is num
                                          ? limitValue.toInt()
                                          : null;
                                  final isBlocked = blockedApps.contains(
                                    app.packageName,
                                  );

                                  return _AppRuleTile(
                                    appName: app.appName,
                                    packageName: app.packageName,
                                    isAllowed: isAllowed,
                                    isBlocked: isBlocked,
                                    limitMinutes: limitMinutes,
                                    onToggle: (value) {
                                      _toggleAllowedApp(app.packageName, value);
                                    },
                                    onEditLimit: () {
                                      _editLimit(app.packageName, limitMinutes);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRuleTile extends StatelessWidget {
  const _AppRuleTile({
    required this.appName,
    required this.packageName,
    required this.isAllowed,
    required this.isBlocked,
    required this.limitMinutes,
    required this.onToggle,
    required this.onEditLimit,
  });

  final String appName;
  final String packageName;
  final bool isAllowed;
  final bool isBlocked;
  final int? limitMinutes;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditLimit;

  @override
  Widget build(BuildContext context) {
    final limitText =
        limitMinutes == null ? 'No limit' : 'Limit: ${limitMinutes}m';
    final statusText =
        isBlocked ? 'Blocked' : (isAllowed ? 'Allowed' : 'Not allowed');
    final statusColor =
        isBlocked ? const Color(0xFFBA1A1A) : const Color(0xFF2E8B6B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isAllowed,
            onChanged: (value) {
              onToggle(value ?? false);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1C2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  packageName,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFF5A6B85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusText · $limitText',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditLimit,
            icon: const Icon(Icons.timer, color: Color(0xFF1A365D)),
            tooltip: 'Set time limit',
          ),
        ],
      ),
    );
  }
}

class _InstalledApp {
  const _InstalledApp({required this.packageName, required this.appName});

  final String packageName;
  final String appName;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.apps, color: Color(0xFF1A365D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                color: const Color(0xFF5A6B85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
