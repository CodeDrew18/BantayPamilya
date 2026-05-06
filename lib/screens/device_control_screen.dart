import 'dart:async';

import 'package:app_usage/app_usage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isSyncing = false;

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

  Future<void> _syncUsage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.deviceUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open this screen on the paired device to sync usage.'),
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 24));
      final usageInfo = await AppUsage().getAppUsage(start, end);

      final deviceRef = FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceUid);
      final batch = FirebaseFirestore.instance.batch();

      for (final info in usageInfo) {
        final minutes = info.usage.inMinutes;
        if (minutes <= 0) {
          continue;
        }
        final usageRef = deviceRef
            .collection('app_usage')
            .doc(info.packageName);
        batch.set(usageRef, {
          'packageName': info.packageName,
          'usageMinutes': minutes,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usage synced successfully.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grant usage access in Android settings to sync apps.'),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _editRule(
    String packageName,
    Map<String, dynamic>? currentRule,
  ) async {
    final limitController = TextEditingController(
      text: currentRule?['limitMinutes']?.toString() ?? '',
    );
    var isHidden = currentRule?['isHidden'] == true;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hide app on device',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D1C2E),
                        ),
                      ),
                      Switch(
                        value: isHidden,
                        activeColor: const Color(0xFF2E8B6B),
                        onChanged: (value) {
                          setModalState(() {
                            isHidden = value;
                          });
                        },
                      ),
                    ],
                  ),
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

    final parent = FirebaseAuth.instance.currentUser;
    if (parent == null) {
      limitController.dispose();
      return;
    }

    final parsedLimit = int.tryParse(limitController.text.trim());
    final rulesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(parent.uid)
        .collection('paired_devices')
        .doc(widget.deviceUid)
        .collection('rules')
        .doc(packageName);

    await rulesRef.set({
      'packageName': packageName,
      'limitMinutes': parsedLimit,
      'isHidden': isHidden,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    limitController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF1A365D);
    const brandMuted = Color(0xFF5A6B85);
    const surface = Color(0xFFF8F9FF);

    final parent = FirebaseAuth.instance.currentUser;
    final rulesStream =
        parent == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(parent.uid)
                .collection('paired_devices')
                .doc(widget.deviceUid)
                .collection('rules')
                .snapshots();

    final usageStream =
        FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.deviceUid)
            .collection('app_usage')
            .orderBy('usageMinutes', descending: true)
            .snapshots();

    final deviceStream =
        FirebaseFirestore.instance
            .collection('devices')
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
                    stream: deviceStream,
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSyncing || _isOffline ? null : _syncUsage,
                          icon:
                              _isSyncing
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.sync),
                          label: Text(
                            _isSyncing ? 'Syncing...' : 'Sync app usage',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A365D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'App usage (last 24 hours)',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: brandDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usage updates when the paired device syncs from its app.',
                    style: GoogleFonts.manrope(fontSize: 12, color: brandMuted),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        rulesStream == null
                            ? _EmptyState(
                              message: 'Sign in to manage app limits.',
                            )
                            : StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: rulesStream,
                              builder: (context, rulesSnapshot) {
                                final rules = <String, Map<String, dynamic>>{};
                                for (final doc
                                    in rulesSnapshot.data?.docs ?? []) {
                                  rules[doc.id] = doc.data();
                                }
                                return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: usageStream,
                                  builder: (context, usageSnapshot) {
                                    if (usageSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (usageSnapshot.hasError) {
                                      return _EmptyState(
                                        message:
                                            'Unable to load app usage right now.',
                                      );
                                    }

                                    final docs = usageSnapshot.data?.docs ?? [];
                                    if (docs.isEmpty) {
                                      return _EmptyState(
                                        message:
                                            'No usage data yet. Sync from the paired device.',
                                      );
                                    }

                                    return ListView.separated(
                                      itemCount: docs.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final data = docs[index].data();
                                        final packageName =
                                            (data['packageName'] as String?) ??
                                            docs[index].id;
                                        final minutes =
                                            (data['usageMinutes'] as num?)
                                                ?.toInt() ??
                                            0;
                                        final rule = rules[packageName];
                                        final limitMinutes =
                                            (rule?['limitMinutes'] as num?)
                                                ?.toInt();
                                        final isHidden =
                                            rule?['isHidden'] == true;

                                        return _AppUsageTile(
                                          packageName: packageName,
                                          minutes: minutes,
                                          limitMinutes: limitMinutes,
                                          isHidden: isHidden,
                                          onTap:
                                              () =>
                                                  _editRule(packageName, rule),
                                        );
                                      },
                                    );
                                  },
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

class _AppUsageTile extends StatelessWidget {
  const _AppUsageTile({
    required this.packageName,
    required this.minutes,
    required this.limitMinutes,
    required this.isHidden,
    required this.onTap,
  });

  final String packageName;
  final int minutes;
  final int? limitMinutes;
  final bool isHidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limitText =
        limitMinutes == null ? 'No limit' : 'Limit: ${limitMinutes}m';
    final hiddenText = isHidden ? 'Hidden' : 'Visible';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    packageName,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D1C2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$minutes minutes · $limitText · $hiddenText',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5A6B85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.tune, color: Color(0xFF1A365D)),
          ],
        ),
      ),
    );
  }
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
