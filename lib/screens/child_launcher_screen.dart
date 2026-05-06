import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_apps/device_apps.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChildLauncherScreen extends StatefulWidget {
  const ChildLauncherScreen({super.key});

  @override
  State<ChildLauncherScreen> createState() => _ChildLauncherScreenState();
}

class _ChildLauncherScreenState extends State<ChildLauncherScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;

  bool _isLoading = true;
  String? _error;

  List<_LauncherApp> _installedApps = [];
  Set<String> _allowedApps = {};
  Set<String> _blockedApps = {};
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _listenChildDoc();
  }

  @override
  void dispose() {
    _childSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    if (!Platform.isAndroid) {
      setState(() {
        _error = 'Launcher mode is only supported on Android.';
        _isLoading = false;
      });
      return;
    }

    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      final mapped =
          apps.map((app) {
              final iconBytes =
                  app is ApplicationWithIcon ? app.icon : Uint8List(0);
              return _LauncherApp(
                packageName: app.packageName,
                appName: app.appName,
                icon: iconBytes,
              );
            }).toList()
            ..sort((a, b) => a.appName.compareTo(b.appName));

      if (!mounted) {
        return;
      }
      setState(() {
        _installedApps = mapped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to load installed apps.';
        _isLoading = false;
      });
    }
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

          if (!mounted) {
            return;
          }
          setState(() {
            _allowedApps = allowedList.toSet();
            _blockedApps = blockedList.toSet();
            _isLocked = data?['is_locked'] == true;
          });
        });
  }

  List<_LauncherApp> _visibleApps() {
    if (_isLocked) {
      return [];
    }
    if (_allowedApps.isEmpty) {
      return [];
    }

    return _installedApps
        .where(
          (app) =>
              _allowedApps.contains(app.packageName) &&
              !_blockedApps.contains(app.packageName),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF0E2A47);
    const surface = Color(0xFFF8F9FF);

    final apps = _visibleApps();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text('Child Launcher', style: GoogleFonts.manrope()),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
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
                    )
                  else
                    Text(
                      'Allowed apps only',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: brandDark,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : apps.isEmpty
                            ? _EmptyState(
                              message:
                                  _isLocked
                                      ? 'This phone is locked by the parent.'
                                      : _allowedApps.isEmpty
                                      ? 'No allowed apps yet. Ask a parent to allow apps.'
                                      : 'No available apps to show.',
                            )
                            : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.9,
                                  ),
                              itemCount: apps.length,
                              itemBuilder: (context, index) {
                                final app = apps[index];
                                return _LauncherTile(
                                  app: app,
                                  onTap: () {
                                    DeviceApps.openApp(app.packageName);
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

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.app, required this.onTap});

  final _LauncherApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (app.icon.isNotEmpty)
              Image.memory(app.icon, width: 36, height: 36)
            else
              const Icon(Icons.apps, color: Color(0xFF1A365D), size: 34),
            const SizedBox(height: 10),
            Text(
              app.appName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D1C2E),
              ),
            ),
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
    return Center(
      child: Text(
        message,
        style: GoogleFonts.manrope(
          color: const Color(0xFF5A6B85),
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LauncherApp {
  const _LauncherApp({
    required this.packageName,
    required this.appName,
    required this.icon,
  });

  final String packageName;
  final String appName;
  final Uint8List icon;
}
