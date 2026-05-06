import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.of(context).pushNamed('/map');
      return;
    }
    if (index == 2) {
      Navigator.of(context).pushNamed('/parental-control');
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF1A365D);
    const brandGreen = Color(0xFF48BB78);
    const brandMuted = Color(0xFF5A6B85);
    const accentBlue = Color(0xFF1F6F8B);
    const surface = Color(0xFFF8F9FF);
    const surfaceHigh = Color(0xFFDCE9FF);
    const surfaceContainer = Color(0xFFE5EEFF);
    const errorRed = Color(0xFFBA1A1A);

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
            child: Column(
              children: [
                _TopAppBar(
                  title: 'BantayPamilya',
                  iconColor: brandDark,
                  status: NetworkStatusPill(isOffline: _isOffline),
                  onProfileTap: () {
                    Navigator.of(context).pushNamed('/profile');
                  },
                ),
                if (_isOffline) const SizedBox(height: 8),
                if (_isOffline)
                  NetworkStatusBanner(
                    isOffline: _isOffline,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusCard(
                          title: 'All devices secure',
                          subtitle: 'System Status',
                          icon: Icons.verified_user,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Send SOS',
                                icon: Icons.sos,
                                background: errorRed,
                                shadow: errorRed.withOpacity(0.2),
                                onPressed: () {},
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                label: 'View Map',
                                icon: Icons.map,
                                background: brandDark,
                                shadow: brandDark.withOpacity(0.2),
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/map');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _HeroCard(
                          title: 'Pair New Device',
                          description:
                              'Instantly connect your family members\' devices. '
                              'Scan the code to start protecting what matters most.',
                          primaryText: 'Start Scanning',
                          secondaryText: 'Show Device QR',
                          accent: brandGreen,
                          onPrimaryPressed: () {
                            Navigator.of(context).pushNamed('/scan');
                          },
                          onSecondaryPressed: () {
                            Navigator.of(context).pushNamed('/device-qr');
                          },
                        ),
                        const SizedBox(height: 20),
                        _ChildModeCard(
                          onOpenChildMode: () {
                            Navigator.of(context).pushNamed('/child-mode');
                          },
                          onOpenLauncher: () {
                            Navigator.of(context).pushNamed('/child-launcher');
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Connected Devices',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: brandDark,
                              ),
                            ),
                            if (devicesStream != null)
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: devicesStream,
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  return Text(
                                    '$count Total',
                                    style: GoogleFonts.manrope(
                                      color: brandMuted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              )
                            else
                              Text(
                                'Sign in',
                                style: GoogleFonts.manrope(
                                  color: brandMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (devicesStream == null)
                          _EmptyState(
                            message: 'Sign in to manage your paired devices.',
                            surface: surfaceContainer,
                          )
                        else
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: devicesStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return _EmptyState(
                                  message: 'Unable to load devices right now.',
                                  surface: surfaceContainer,
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return _EmptyState(
                                  message:
                                      'No devices paired yet. Scan a QR code to begin.',
                                  surface: surfaceContainer,
                                );
                              }

                              final tiles = <Widget>[];
                              for (var i = 0; i < docs.length; i++) {
                                final data = docs[i].data();
                                final label =
                                    (data['label'] as String?) ??
                                    'Unnamed device';
                                final isOnline = data['isOnline'] == true;
                                tiles.add(
                                  _DeviceTile(
                                    name: label,
                                    status: isOnline ? 'Online' : 'Offline',
                                    statusColor:
                                        isOnline
                                            ? brandGreen
                                            : Colors.grey.shade400,
                                    subtitle: _formatLastSeen(
                                      data['lastSeen'] as Timestamp?,
                                    ),
                                    icon: Icons.devices,
                                    surface: surfaceContainer,
                                    accent: brandDark,
                                  ),
                                );
                                if (i != docs.length - 1) {
                                  tiles.add(const SizedBox(height: 8));
                                }
                              }
                              return Column(children: tiles);
                            },
                          ),
                        const SizedBox(height: 8),
                        Container(height: 1, color: surfaceHigh),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        activeColor: brandGreen,
        inactiveColor: Colors.grey.shade400,
        highlightColor: accentBlue,
        selectedIndex: 0,
        onTap: _onNavTap,
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.title,
    required this.iconColor,
    this.status,
    this.onProfileTap,
  });

  final String title;
  final Color iconColor;
  final Widget? status;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.04)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: iconColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (status != null) status!,
              const SizedBox(width: 12),
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.account_circle, color: iconColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF85F6AD).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF00723F)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  color: Color(0xFF43474E),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Color(0xFF1A365D),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.shadow,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color shadow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.description,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String title;
  final String description;
  final String primaryText;
  final String secondaryText;
  final Color accent;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A365D),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onPrimaryPressed,
                      style: TextButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            primaryText,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.qr_code_scanner, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: onSecondaryPressed,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            secondaryText,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.qr_code, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChildModeCard extends StatelessWidget {
  const _ChildModeCard({
    required this.onOpenChildMode,
    required this.onOpenLauncher,
  });

  final VoidCallback onOpenChildMode;
  final VoidCallback onOpenLauncher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Child Mode',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A365D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Open the child device dashboard or the simplified launcher.',
            style: GoogleFonts.manrope(
              color: const Color(0xFF5A6B85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenChildMode,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Child dashboard',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpenLauncher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Open launcher',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.subtitle,
    required this.icon,
    required this.surface,
    required this.accent,
  });

  final String name;
  final String status;
  final Color statusColor;
  final String subtitle;
  final IconData icon;
  final Color surface;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1C2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      color: Color(0xFF43474E),
                      fontSize: 12,
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
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status.toUpperCase(),
                style: GoogleFonts.manrope(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.activeColor,
    required this.inactiveColor,
    required this.highlightColor,
    required this.selectedIndex,
    required this.onTap,
  });

  final Color activeColor;
  final Color inactiveColor;
  final Color highlightColor;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  color: selectedIndex == 0 ? activeColor : inactiveColor,
                  isActive: selectedIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.family_restroom_rounded,
                  label: 'Parental Control',
                  color: selectedIndex == 2 ? highlightColor : inactiveColor,
                  isActive: selectedIndex == 2,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
          _CenterNavButton(
            label: 'Map',
            isActive: selectedIndex == 1,
            onTap: () => onTap(1),
            background: activeColor,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = isActive ? color : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: resolvedColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: resolvedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterNavButton extends StatelessWidget {
  const _CenterNavButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.background,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [background, background.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: background.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.map_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: isActive ? background : const Color(0xFF5A6B85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.surface});

  final String message;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2, color: Color(0xFF1A365D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                color: const Color(0xFF43474E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
