import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../widgets/network_status_banner.dart';

class DeviceQrScreen extends StatefulWidget {
  const DeviceQrScreen({super.key});

  @override
  State<DeviceQrScreen> createState() => _DeviceQrScreenState();
}

class _DeviceQrScreenState extends State<DeviceQrScreen> {
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isOffline = false;
  bool _isLoading = true;
  String? _deviceUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _listenConnectivity();
    _loadDeviceUid();
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

  Future<void> _loadDeviceUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Please sign in to view your device QR code.';
        _isLoading = false;
      });
      return;
    }

    final uid = user.uid;
    try {
      await FirebaseFirestore.instance.collection('device_qr').doc(uid).set({
        'deviceUid': uid,
        'ownerUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _deviceUid = uid;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to load device QR code.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF0E2A47);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Text('Device QR', style: GoogleFonts.manrope()),
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
                            'Share this code',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Let another phone scan to pair this device.',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF5A6B85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      NetworkStatusPill(isOffline: _isOffline),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isOffline) const SizedBox(height: 12),
                  if (_isOffline)
                    NetworkStatusBanner(
                      isOffline: _isOffline,
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                  if (_isOffline) const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                              ? Center(
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF5A6B85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  QrImageView(
                                    data: _deviceUid ?? '',
                                    size: 220,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Device UID',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF5A6B85),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SelectableText(
                                    _deviceUid ?? '',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                      color: brandDark,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
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
