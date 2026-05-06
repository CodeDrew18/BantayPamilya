import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({
    super.key,
    required this.isOffline,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final bool isOffline;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD64545),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline mode: some features may be unavailable.',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkStatusPill extends StatelessWidget {
  const NetworkStatusPill({super.key, required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final label = isOffline ? 'Offline' : 'Online';
    final color = isOffline ? const Color(0xFFD64545) : const Color(0xFF2E8B6B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
