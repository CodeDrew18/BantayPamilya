import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';
import 'device_control_screen.dart';

class ParentalControlScreen extends StatefulWidget {
  const ParentalControlScreen({super.key});

  @override
  State<ParentalControlScreen> createState() => _ParentalControlScreenState();
}

class _ParentalControlScreenState extends State<ParentalControlScreen> {
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

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF1A365D);
    const brandMuted = Color(0xFF5A6B85);
    const surface = Color(0xFFF8F9FF);

    final user = FirebaseAuth.instance.currentUser;
    final devicesStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('children')
                .where('parentId', isEqualTo: user.uid)
                .snapshots();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text('Parental Control', style: GoogleFonts.manrope()),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Managed devices',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review app usage and set limits.',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: brandMuted,
                            ),
                          ),
                        ],
                      ),
                      NetworkStatusPill(isOffline: _isOffline),
                    ],
                  ),
                  if (_isOffline) const SizedBox(height: 12),
                  if (_isOffline)
                    NetworkStatusBanner(
                      isOffline: _isOffline,
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                  if (_isOffline) const SizedBox(height: 12),
                  Expanded(
                    child:
                        devicesStream == null
                            ? _EmptyState(
                              message: 'Sign in to manage parental controls.',
                            )
                            : StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: devicesStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return _EmptyState(
                                    message:
                                        'Unable to load devices right now.',
                                  );
                                }

                                final docs = snapshot.data?.docs ?? [];
                                if (docs.isEmpty) {
                                  return _EmptyState(
                                    message:
                                        'No paired devices yet. Scan a QR code to begin.',
                                  );
                                }

                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final data = docs[index].data();
                                    final deviceUid = docs[index].id;
                                    final label =
                                        (data['label'] as String?) ??
                                        'Unnamed device';
                                    return _DeviceCard(
                                      deviceUid: deviceUid,
                                      label: label,
                                      formatLastSeen: _formatLastSeen,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => DeviceControlScreen(
                                                  deviceUid: deviceUid,
                                                  label: label,
                                                ),
                                          ),
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.deviceUid,
    required this.label,
    required this.formatLastSeen,
    required this.onTap,
  });

  final String deviceUid;
  final String label;
  final String Function(Timestamp?) formatLastSeen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('children')
              .doc(deviceUid)
              .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isOnline = data?['isOnline'] == true;
        final lastSeen = formatLastSeen(data?['lastSeen'] as Timestamp?);
        final geofenceBreached = data?['geofenceBreached'] == true;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EEFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.devices,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D1C2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastSeen,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF5A6B85),
                          ),
                        ),
                        if (geofenceBreached)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Geo-fence alert: outside boundary',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: const Color(0xFFBA1A1A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            isOnline
                                ? const Color(0xFF2E8B6B)
                                : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isOnline
                                ? const Color(0xFF2E8B6B)
                                : Colors.grey.shade500,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            child: const Icon(Icons.shield, color: Color(0xFF1A365D)),
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
