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
    // Professional color palette
    const Color primaryDark = Color(0xFF0F172A);
    const Color primaryAccent = Color(0xFF3B82F6);
    const Color successColor = Color(0xFF10B981);
    const Color warningColor = Color(0xFFEF4444);
    const Color neutralLight = Color(0xFFF8FAFC);
    const Color neutralMuted = Color(0xFF64748B);

    final user = FirebaseAuth.instance.currentUser;
    final devicesStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('children')
                .where('parentId', isEqualTo: user.uid)
                .snapshots();

    return Scaffold(
      backgroundColor: neutralLight,
      appBar: AppBar(
        title: Text(
          'Parental Controls',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  neutralLight.withOpacity(0.5),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Managed Devices',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: primaryDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Monitor and manage your child\'s devices',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: neutralMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      NetworkStatusPill(isOffline: _isOffline),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Network status banner
                  if (_isOffline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: NetworkStatusBanner(
                        isOffline: _isOffline,
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                    ),
                  // Devices list
                  Expanded(
                    child:
                        devicesStream == null
                            ? _EmptyState(
                              message: 'Sign in to manage parental controls.',
                              primaryDark: primaryDark,
                              primaryAccent: primaryAccent,
                            )
                            : StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: devicesStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(
                                          color: primaryAccent,
                                          strokeWidth: 2.5,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Loading devices...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            color: neutralMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return _EmptyState(
                                    message:
                                        'Unable to load devices. Please try again.',
                                    primaryDark: primaryDark,
                                    primaryAccent: primaryAccent,
                                  );
                                }

                                final docs = snapshot.data?.docs ?? [];
                                if (docs.isEmpty) {
                                  return _EmptyState(
                                    message:
                                        'No paired devices yet. Scan a QR code to get started.',
                                    primaryDark: primaryDark,
                                    primaryAccent: primaryAccent,
                                  );
                                }

                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 16),
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
                                      primaryDark: primaryDark,
                                      primaryAccent: primaryAccent,
                                      successColor: successColor,
                                      warningColor: warningColor,
                                      neutralMuted: neutralMuted,
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

class _DeviceCard extends StatefulWidget {
  const _DeviceCard({
    required this.deviceUid,
    required this.label,
    required this.formatLastSeen,
    required this.onTap,
    required this.primaryDark,
    required this.primaryAccent,
    required this.successColor,
    required this.warningColor,
    required this.neutralMuted,
  });

  final String deviceUid;
  final String label;
  final String Function(Timestamp?) formatLastSeen;
  final VoidCallback onTap;
  final Color primaryDark;
  final Color primaryAccent;
  final Color successColor;
  final Color warningColor;
  final Color neutralMuted;

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('children')
              .doc(widget.deviceUid)
              .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isOnline = data?['isOnline'] == true;
        final lastSeen = widget.formatLastSeen(data?['lastSeen'] as Timestamp?);
        final geofenceBreached = data?['geofenceBreached'] == true;

        return MouseRegion(
          onEnter: (_) => _hoverController.forward(),
          onExit: (_) => _hoverController.reverse(),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _hoverController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -2 * _hoverController.value),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.04 + (0.08 * _hoverController.value),
                          ),
                          blurRadius: 16 + (8 * _hoverController.value),
                          offset: Offset(0, 4 + (4 * _hoverController.value)),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Device header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Device info
                              Row(
                                children: [
                                  // Device icon
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: widget.primaryAccent
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.devices,
                                      color: widget.primaryAccent,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: widget.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        lastSeen,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: widget.neutralMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? widget.successColor.withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? widget.successColor
                                            : Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? 'ONLINE' : 'OFFLINE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isOnline
                                            ? widget.successColor
                                            : Colors.grey.shade500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Geofence alert
                          if (geofenceBreached) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.warningColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.warningColor.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    color: widget.warningColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Geo-fence alert: device outside boundary',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: widget.warningColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.primaryDark,
    required this.primaryAccent,
  });

  final String message;
  final Color primaryDark;
  final Color primaryAccent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: primaryAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 44,
              color: primaryAccent,
            ),
          ),
          const SizedBox(height: 24),
          // Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your first device to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: primaryDark.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}