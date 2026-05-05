import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  Future<void> _listenConnectivity() async {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
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

    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _updatePosition(current);

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

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permission permanently denied.';
      });
      return false;
    }

    return true;
  }

  void _updatePosition(Position position) {
    setState(() {
      _currentPosition = position;
      _locationError = null;
    });

    final target = LatLng(position.latitude, position.longitude);
    _mapController?.animateCamera(CameraUpdate.newLatLng(target));
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentPosition;
    final initialTarget = current == null
        ? _fallbackPosition
        : LatLng(current.latitude, current.longitude);

    final markers = <Marker>{};
    if (current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(current.latitude, current.longitude),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A365D),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15,
            ),
            mapType: MapType.normal,
            myLocationEnabled: _locationReady,
            myLocationButtonEnabled: true,
            markers: markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          if (_isOffline)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _StatusBanner(
                message: 'No internet connection',
                background: Colors.red.shade600,
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
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.background,
  });

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
              style: const TextStyle(
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
