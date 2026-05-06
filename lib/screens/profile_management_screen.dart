import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';

class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  bool _isOffline = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _email;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _listenConnectivity();
    _loadProfile();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _fullNameController.dispose();
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

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Please sign in to manage your profile.';
        _isLoading = false;
      });
      return;
    }

    _email = user.email;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final fullName = (data?['fullName'] as String?) ?? '';
        _fullNameController.text = fullName;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to load profile details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Go online to update your profile.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final fullName = _fullNameController.text.trim();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': fullName,
        'email': _email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(fullName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile right now.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign out',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.manrope(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String _initials() {
    final value = _fullNameController.text.trim();
    if (value.isEmpty) {
      return 'BP';
    }
    final parts =
        value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'BP';
    }
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF0E2A47);
    const brandGreen = Color(0xFF2E8B6B);
    const brandMuted = Color(0xFF5A6B85);
    const inputFill = Color(0xFFF2F6FB);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Text('Profile Management', style: GoogleFonts.manrope()),
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
                            'Manage your account',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep your profile details up to date.',
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
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.04),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
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
                                    color: brandMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              : Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: const Color(
                                            0xFFE5EEFF,
                                          ),
                                          child: Text(
                                            _initials(),
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w700,
                                              color: brandDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Profile details',
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.w700,
                                                  color: brandDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Update your name for the family dashboard.',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color: brandMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _fullNameController,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'Full name',
                                        filled: true,
                                        fillColor: inputFill,
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: brandDark,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: brandGreen,
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter your full name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      initialValue: _email ?? '',
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        labelText: 'Email address',
                                        filled: true,
                                        fillColor: inputFill,
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: brandDark,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: brandGreen,
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed:
                                          _isSaving ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: brandGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _isSaving
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : Text(
                                                'Save changes',
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: _isSaving ? null : _signOut,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFBA1A1A,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFBA1A1A),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Sign out',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
