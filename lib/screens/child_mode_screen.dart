import 'dart:async';
import 'dart:io';

import 'package:app_usage/app_usage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/platform_channel.dart';
import '../widgets/network_status_banner.dart';

class ChildModeScreen extends StatefulWidget {
  const ChildModeScreen({super.key});

  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;
  StreamSubscription<Position>? _locationSub;
  Timer? _usageTimer;

  bool _isOffline = false;
  bool _isSyncing = false;
  String? _error;
  bool _blockingEnabled = false;

  List<_InstalledApp> _installedApps = [];
  Set<String> _allowedApps = {};
  Map<String, int> _timeLimits = {};
  Set<String> _blockedApps = {};
  String? _parentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _listenConnectivity();
    _ensureChildDoc();
    _listenChildDoc();
    _syncInstalledApps();
    _startLocationSync();
    _startUsageTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _childSub?.cancel();
    _locationSub?.cancel();
    _usageTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markOnline(true);
    } else if (state == AppLifecycleState.paused) {
      _markOnline(false);
    }
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

  Future<void> _ensureChildDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Please sign in to use child mode.';
      });
      return;
    }

    await FirebaseFirestore.instance.collection('children').doc(user.uid).set({
      'childUid': user.uid,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _listenChildDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _childSub = FirebaseFirestore.instance
        .collection('children')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final allowedList =
              (data?['allowed_apps'] as List<dynamic>?)?.cast<String>() ??
              const <String>[];
          final blockedList =
              (data?['blocked_apps'] as List<dynamic>?)?.cast<String>() ??
              const <String>[];
          final limitMap =
              (data?['time_limits'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};

          final parsedLimits = <String, int>{};
          for (final entry in limitMap.entries) {
            final value = entry.value;
            if (value is num) {
              parsedLimits[entry.key] = value.toInt();
            }
          }

          if (!mounted) {
            return;
          }

          setState(() {
            _allowedApps = allowedList.toSet();
            _blockedApps = blockedList.toSet();
            _timeLimits = parsedLimits;
            _parentId = data?['parentId'] as String?;
          });

          _evaluateUsage();
        });
  }

  Future<void> _setBlockingEnabled(bool value) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _blockingEnabled = value;
    });

    if (!value) {
      await _clearBlockedApps(forceNativeClear: true);
      return;
    }

    await _evaluateUsage();
  }

  Future<void> _clearBlockedApps({bool forceNativeClear = false}) async {
    if (!mounted) {
      return;
    }

    final hadBlockedApps = _blockedApps.isNotEmpty;
    if (hadBlockedApps) {
      setState(() {
        _blockedApps = {};
      });
    }

    if (hadBlockedApps || forceNativeClear) {
      await AppBlockerChannel.setBlockedPackages(const []);
    }

    if (!hadBlockedApps) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('children').doc(user.uid).set({
      'blocked_apps': [],
      'usageUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _startUsageTimer() {
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _evaluateUsage();
    });
  }

  Future<void> _markOnline(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('children').doc(user.uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _startLocationSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      final point = GeoPoint(position.latitude, position.longitude);

      await FirebaseFirestore.instance
          .collection('children')
          .doc(user.uid)
          .set({
            'lastLocation': point,
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('devices').doc(user.uid).set({
        'deviceUid': user.uid,
        'lastLocation': point,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _syncInstalledApps() async {
    if (!Platform.isAndroid) {
      setState(() {
        _error = 'Installed app sync is only supported on Android.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSyncing = true;
      _error = null;
    });

    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        includeAppIcons: false,
        onlyAppsWithLaunchIntent: true,
      );

      final mapped =
          apps
              .map(
                (app) => _InstalledApp(
                  packageName: app.packageName,
                  appName: app.appName,
                ),
              )
              .toList()
            ..sort((a, b) => a.appName.compareTo(b.appName));

      if (mounted) {
        setState(() {
          _installedApps = mapped;
        });
      }

      final payload =
          mapped
              .map(
                (app) => {
                  'packageName': app.packageName,
                  'appName': app.appName,
                },
              )
              .toList();

      await FirebaseFirestore.instance
          .collection('children')
          .doc(user.uid)
          .set({
            'installed_apps': payload,
            'installed_count': payload.length,
            'installedUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        _error =
            'Unable to read installed apps. Please enable access and try again.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSyncing = false;
      });
    }
  }

  DateTime _startOfDay(DateTime time) {
    return DateTime(time.year, time.month, time.day);
  }

  Future<void> _evaluateUsage() async {
    if (!mounted || !Platform.isAndroid) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    if (_parentId == null || !_blockingEnabled || _allowedApps.isEmpty) {
      await _clearBlockedApps();
      return;
    }

    if (_installedApps.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final start = _startOfDay(now);

    try {
      final usageInfo = await AppUsage().getAppUsage(start, now);
      final usageMap = <String, int>{
        for (final info in usageInfo) info.packageName: info.usage.inMinutes,
      };

      final blocked = <String>{};
      for (final app in _installedApps) {
        final isAllowed = _allowedApps.contains(app.packageName);
        final limit = _timeLimits[app.packageName];
        final usage = usageMap[app.packageName] ?? 0;

        if (!isAllowed) {
          blocked.add(app.packageName);
        } else if (limit != null && usage >= limit) {
          blocked.add(app.packageName);
        }
      }

      if (blocked.length == _blockedApps.length &&
          blocked.difference(_blockedApps).isEmpty) {
        return;
      }

      _blockedApps = blocked;
      await AppBlockerChannel.setBlockedPackages(blocked.toList());
      await FirebaseFirestore.instance
          .collection('children')
          .doc(user.uid)
          .set({
            'blocked_apps': blocked.toList(),
            'usageUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Grant usage access to enable time limits.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF0E2A47);
    const brandMuted = Color(0xFF5A6B85);
    const surface = Color(0xFFF8F9FF);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text('Child Mode', style: GoogleFonts.manrope()),
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
                            'Live protection',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _parentId == null
                                ? 'Waiting for parent pairing.'
                                : 'Connected to parent.',
                            style: GoogleFonts.manrope(
                              color: brandMuted,
                              fontSize: 13,
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFC9C9)),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF9A1C1C),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device stats',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: brandDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Installed apps',
                          value: _installedApps.length.toString(),
                        ),
                        _InfoRow(
                          label: 'Allowed apps',
                          value: _allowedApps.length.toString(),
                        ),
                        _InfoRow(
                          label: 'Blocked apps',
                          value: _blockedApps.length.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                                'App blocker',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: brandDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _parentId == null
                                    ? 'Pair with a parent to enable blocking.'
                                    : 'Blocks apps after limits are reached.',
                                style: GoogleFonts.manrope(
                                  color: brandMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _blockingEnabled,
                          onChanged:
                              _parentId == null ? null : _setBlockingEnabled,
                          activeColor: const Color(0xFF2E8B6B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        _isOffline || _isSyncing ? null : _syncInstalledApps,
                    icon:
                        _isSyncing
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.apps),
                    label: Text(
                      _isSyncing ? 'Syncing apps...' : 'Sync installed apps',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: AppBlockerChannel.requestUsageAccess,
                    icon: const Icon(Icons.lock_clock),
                    label: Text(
                      'Grant usage access',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: AppBlockerChannel.requestAccessibilitySettings,
                    icon: const Icon(Icons.shield),
                    label: Text(
                      'Enable app blocker',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/child-launcher');
                    },
                    icon: const Icon(Icons.home),
                    label: Text(
                      'Open child launcher',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: Keep this screen open while testing app limits.',
                    style: GoogleFonts.manrope(fontSize: 12, color: brandMuted),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: const Color(0xFF5A6B85),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: const Color(0xFF0D1C2E),
              fontWeight: FontWeight.w700,
            ),
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
