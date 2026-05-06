import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _fallbackPosition = LatLng(14.5995, 120.9842);

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Position? _currentPosition;
  String? _locationError;
  bool _locationReady = false;
  bool _isOffline = false;
  
String? _currentAddress;
Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _listenConnectivity();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _connectivitySub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

Future<void> _updateAddress(double lat, double lng) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lng);

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      setState(() {
        _currentAddress =
            '${place.street ?? ''}, '
            '${place.locality ?? ''}, '
            '${place.administrativeArea ?? ''}, '
            '${place.country ?? ''}'
                .replaceAll(RegExp(r', ,'), ',')
                .trim();
      });
    }
  } catch (_) {
    setState(() {
      _currentAddress = 'Unable to resolve address';
    });
  }
}  

  Future<void> _listenConnectivity() async {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
      _syncOnlineStatus(result != ConnectivityResult.none);
    });
  }

  Future<void> _startLocationStream() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    setState(() {
      _locationReady = true;
      _locationError = null;
    });

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _updatePosition(lastKnown);
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _updatePosition(current);
    } catch (e) {
      if (_currentPosition == null) {
        setState(() {
          _locationError = 'Unable to get current location.';
        });
      }
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_updatePosition);
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled.';
      });
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _locationError = 'Location permission denied.';
      });
      return false;
    }

    // if (permission == LocationPermission.deniedForever) {
    //   setState(() {
    //     _locationError = 'Location permission permanently denied.';
    //   });
    //   return false;
    // }

    if (permission == LocationPermission.deniedForever) {
  await Geolocator.openAppSettings();
  return false;
}

    return true;
  }

  Future<void> _handleLocationAction() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    if (permission == LocationPermission.denied) {
      return;
    }

    await _startLocationStream();
  }

  void _updatePosition(Position position) {
  setState(() {
    _currentPosition = position;
    _locationError = null;
  });

  final target = LatLng(position.latitude, position.longitude);
  _mapController?.animateCamera(CameraUpdate.newLatLng(target));

  _syncLocation(position);

  _geocodeDebounce?.cancel();
  _geocodeDebounce = Timer(const Duration(seconds: 2), () {
    _updateAddress(position.latitude, position.longitude);
  });
}

  Future<void> _syncOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('devices').doc(user.uid).set({
        'deviceUid': user.uid,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _syncLocation(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('devices').doc(user.uid).set({
        'deviceUid': user.uid,
        'lastLocation': GeoPoint(position.latitude, position.longitude),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': !_isOffline,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  LatLng? _latLngFrom(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['lat'] ?? value['latitude'];
      final lng = value['lng'] ?? value['longitude'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  Future<Map<String, LatLng>> _loadFallbackLocations(List<String> ids) async {
    final fallback = <String, LatLng>{};
    if (ids.isEmpty) {
      return fallback;
    }

    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);
      final snapshot =
          await FirebaseFirestore.instance
              .collection('devices')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snapshot.docs) {
        final latLng = _latLngFrom(doc.data()['lastLocation']);
        if (latLng != null) {
          fallback[doc.id] = latLng;
        }
      }
    }

    return fallback;
  }

  Future<Set<Marker>> _buildPairedMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<Marker> baseMarkers,
  ) async {
    final allMarkers = <Marker>{}..addAll(baseMarkers);
    final missingLocationIds = <String>[];
    for (final doc in docs) {
      final data = doc.data();
      final latLng = _latLngFrom(data['lastLocation']);
      if (latLng == null) {
        missingLocationIds.add(doc.id);
        continue;
      }
      allMarkers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: latLng,
          infoWindow: InfoWindow(
            title: (data['label'] as String?) ?? 'Paired device',
            snippet: (data['isOnline'] == true) ? 'Online' : 'Offline',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (missingLocationIds.isEmpty) {
      return allMarkers;
    }

    final fallbackLocations = await _loadFallbackLocations(missingLocationIds);
    for (final doc in docs) {
      final data = doc.data();
      final latLng = fallbackLocations[doc.id];
      if (latLng == null) {
        continue;
      }
      allMarkers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: latLng,
          infoWindow: InfoWindow(
            title: (data['label'] as String?) ?? 'Paired device',
            snippet: (data['isOnline'] == true) ? 'Online' : 'Offline',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return allMarkers;
  }

  Widget _buildMap(Set<Marker> markers, LatLng initialTarget) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      markers: markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        final current = _currentPosition;
        if (current != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(current.latitude, current.longitude),
              16,
            ),
          );
        }
      },
    );
  }

  void _recenter() {
    final current = _currentPosition;
    if (current == null) {
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(current.latitude, current.longitude),
        16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentPosition;
    final initialTarget =
        current == null
            ? _fallbackPosition
            : LatLng(current.latitude, current.longitude);

    final markers = <Marker>{};
    if (current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(current.latitude, current.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    final locationText =
    _locationError ??
    (_currentAddress ??
        (current == null
            ? 'Enable location to see your position.'
            : '${current.latitude.toStringAsFixed(5)}, '
              '${current.longitude.toStringAsFixed(5)}'));

    final showLocationAction = current == null;
    final infoCardTop = _isOffline ? 76.0 : 16.0;

    final user = FirebaseAuth.instance.currentUser;
    final pairedStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('children')
                .where('parentId', isEqualTo: user.uid)
                .snapshots();

    Widget mapWidget = _buildMap(markers, initialTarget);
    if (pairedStream != null) {
      mapWidget = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pairedStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          return FutureBuilder<Set<Marker>>(
            future: _buildPairedMarkers(docs, markers),
            builder: (context, markerSnapshot) {
              final allMarkers = markerSnapshot.data ?? markers;
              return _buildMap(allMarkers, initialTarget);
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Map', style: GoogleFonts.manrope()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A365D),
        elevation: 0,
      ),
      body: Stack(
        children: [
          mapWidget,
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: NetworkStatusBanner(isOffline: _isOffline),
          ),
          Positioned(
            top: infoCardTop,
            left: 16,
            right: 16,
            child: _MapInfoCard(
              isReady: _locationReady,
              locationText: locationText,
              accuracy: current?.accuracy,
              isOffline: _isOffline,
              showAction: showLocationAction,
              onActionTap: _handleLocationAction,
            ),
          ),
          if (_locationError != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _StatusBanner(
                message: _locationError!,
                background: Colors.orange.shade700,
              ),
            ),
          Positioned(
            bottom: 28,
            right: 16,
            child: FloatingActionButton(
              onPressed: _recenter,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A365D),
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  const _MapInfoCard({
    required this.isReady,
    required this.locationText,
    required this.accuracy,
    required this.isOffline,
    required this.showAction,
    required this.onActionTap,
  });

  final bool isReady;
  final String locationText;
  final double? accuracy;
  final bool isOffline;
  final bool showAction;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F3EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_on, color: Color(0xFF1A365D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady ? 'Live location' : 'Locating device',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A6B85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationText,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1C2E),
                  ),
                ),
                if (accuracy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Accuracy: ${accuracy!.toStringAsFixed(0)}m',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF5A6B85),
                      ),
                    ),
                  ),
                if (showAction)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onActionTap,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Enable location'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A365D),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          NetworkStatusPill(isOffline: isOffline),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.background});

  final String message;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
