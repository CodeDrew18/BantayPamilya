import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.deviceUid, required this.label});

  final String deviceUid;
  final String label;

  String _formatEpoch(dynamic raw) {
    if (raw is! num) {
      return 'Unknown time';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$label logs', style: GoogleFonts.manrope()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A365D),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('children').doc(deviceUid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final calls = (data['call_logs'] as List<dynamic>? ?? const []);
          final sms = (data['sms_logs'] as List<dynamic>? ?? const []);
          final contacts = (data['contacts_logs'] as List<dynamic>? ?? const []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Call Logs',
                children: calls
                    .take(20)
                    .map((row) => _row(
                          title: '${row['name'] ?? row['number'] ?? 'Unknown'}',
                          subtitle:
                              '${row['number'] ?? ''} · ${_formatEpoch(row['date'])}',
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'SMS Logs',
                children: sms
                    .take(20)
                    .map((row) => _row(
                          title: '${row['address'] ?? 'Unknown'}',
                          subtitle:
                              '${(row['body'] ?? '').toString().replaceAll('\n', ' ')} · ${_formatEpoch(row['date'])}',
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Contacts',
                children: contacts
                    .take(40)
                    .map((row) => _row(
                          title: '${row['name'] ?? 'Unknown'}',
                          subtitle: '${row['number'] ?? ''}',
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row({required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D1C2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: const Color(0xFF5A6B85),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A365D),
            ),
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              'No records yet.',
              style: GoogleFonts.manrope(
                color: const Color(0xFF5A6B85),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
