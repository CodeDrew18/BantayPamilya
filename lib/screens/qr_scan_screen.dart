import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/network_status_banner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isOffline = false;
  bool _isHandling = false;
  String? _lastValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _listenConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandling) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) {
      return;
    }

    if (value == _lastValue) {
      return;
    }

    setState(() {
      _isHandling = true;
      _lastValue = value;
    });

    await _scannerController.stop();
    await _handleDeviceUid(value.trim());

    if (!mounted) {
      return;
    }

    await _scannerController.start();
    setState(() {
      _isHandling = false;
    });
  }

  Future<void> _handleDeviceUid(String deviceUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await _showMessageDialog(
        title: 'Sign in required',
        message: 'Please sign in to pair a device.',
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('paired_devices')
        .doc(deviceUid);

    try {
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data();
        await _showMessageDialog(
          title: 'Device already paired',
          message:
              data?['label'] == null
                  ? 'This device UID is already registered.'
                  : 'This device is already registered as ${data?['label']}.',
          deviceUid: deviceUid,
        );
        return;
      }

      final saved = await _showRegistrationSheet(deviceUid, docRef);
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device saved successfully.')),
        );
      }
    } catch (e) {
      await _showMessageDialog(
        title: 'Unable to check device',
        message: 'Please try again when you are online.',
        deviceUid: deviceUid,
      );
    }
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
    String? deviceUid,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: GoogleFonts.manrope()),
              if (deviceUid != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Device UID',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A6B85),
                  ),
                ),
                SelectableText(
                  deviceUid,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              NetworkStatusPill(isOffline: _isOffline),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showRegistrationSheet(
    String deviceUid,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    final controller = TextEditingController();
    String? errorText;

    final saved = await showModalBottomSheet<bool>(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Register device',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1C2E),
                        ),
                      ),
                      NetworkStatusPill(isOffline: _isOffline),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a friendly name so you can recognize the device later.',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF5A6B85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    deviceUid,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Andrew's Phone",
                      errorText: errorText,
                      filled: true,
                      fillColor: const Color(0xFFF2F6FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final label = controller.text.trim();
                        if (label.isEmpty) {
                          setModalState(() {
                            errorText = 'Please enter a name';
                          });
                          return;
                        }

                        try {
                          await docRef.set({
                            'deviceUid': deviceUid,
                            'label': label,
                            'isOnline': !_isOffline,
                            'createdAt': FieldValue.serverTimestamp(),
                            'lastSeen': FieldValue.serverTimestamp(),
                          });

                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          setModalState(() {
                            errorText = 'Unable to save device. Try again.';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save device',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    return saved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF7F9FF);
    const brandDark = Color(0xFF0E2A47);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text('Scan device', style: GoogleFonts.manrope()),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pair a device',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Align the QR code inside the frame.',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF5A6B85),
                            ),
                          ),
                        ],
                      ),
                      NetworkStatusPill(isOffline: _isOffline),
                    ],
                  ),
                ),
                if (_isOffline) const SizedBox(height: 12),
                if (_isOffline)
                  NetworkStatusBanner(
                    isOffline: _isOffline,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.7),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                            if (_isHandling)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: Center(
                                    child: Text(
                                      'Processing...',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_lastValue != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          'Last scanned UID',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFF5A6B85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _lastValue!,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: brandDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
