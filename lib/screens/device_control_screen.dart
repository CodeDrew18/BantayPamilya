// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// import '../widgets/network_status_banner.dart';
// import 'logs_screen.dart';

// class DeviceControlScreen extends StatefulWidget {
//   const DeviceControlScreen({
//     super.key,
//     required this.deviceUid,
//     required this.label,
//   });

//   final String deviceUid;
//   final String label;

//   @override
//   State<DeviceControlScreen> createState() => _DeviceControlScreenState();
// }

// class _DeviceControlScreenState extends State<DeviceControlScreen> {
//   StreamSubscription<ConnectivityResult>? _connectivitySub;
//   bool _isOffline = false;

//   @override
//   void initState() {
//     super.initState();
//     _initConnectivity();
//     _listenConnectivity();
//   }

//   @override
//   void dispose() {
//     _connectivitySub?.cancel();
//     super.dispose();
//   }

//   Future<void> _initConnectivity() async {
//     final result = await Connectivity().checkConnectivity();
//     if (!mounted) {
//       return;
//     }
//     setState(() {
//       _isOffline = result == ConnectivityResult.none;
//     });
//   }

//   void _listenConnectivity() {
//     _connectivitySub = Connectivity().onConnectivityChanged.listen((
//       ConnectivityResult result,
//     ) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {
//         _isOffline = result == ConnectivityResult.none;
//       });
//     });
//   }

//   String _formatLastSeen(Timestamp? timestamp) {
//     if (timestamp == null) {
//       return 'Last active: unknown';
//     }
//     final delta = DateTime.now().difference(timestamp.toDate());
//     if (delta.inMinutes < 1) {
//       return 'Last active: just now';
//     }
//     if (delta.inHours < 1) {
//       return 'Last active: ${delta.inMinutes}m ago';
//     }
//     if (delta.inDays < 1) {
//       return 'Last active: ${delta.inHours}h ago';
//     }
//     return 'Last active: ${delta.inDays}d ago';
//   }

//   String _formatInstalledSync(Timestamp? timestamp, int? installedCount) {
//     if (timestamp == null) {
//       return 'App list not synced yet';
//     }
//     final delta = DateTime.now().difference(timestamp.toDate());
//     final when =
//         delta.inMinutes < 1
//             ? 'just now'
//             : delta.inHours < 1
//             ? '${delta.inMinutes}m ago'
//             : delta.inDays < 1
//             ? '${delta.inHours}h ago'
//             : '${delta.inDays}d ago';
//     final count = installedCount ?? 0;
//     return 'Synced $when ($count apps)';
//   }

//   Future<void> _toggleAllowedApp(String packageName, bool isAllowed) async {
//     if (_isOffline) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Go online to update app rules.')),
//       );
//       return;
//     }

//     final childRef = FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid);

//     try {
//       if (isAllowed) {
//         await childRef.set({
//           'allowed_apps': FieldValue.arrayUnion([packageName]),
//         }, SetOptions(merge: true));
//       } else {
//         await childRef.update({
//           'allowed_apps': FieldValue.arrayRemove([packageName]),
//           'time_limits.$packageName': FieldValue.delete(),
//         });
//       }
//     } catch (e) {
//       if (!mounted) {
//         return;
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to update app rule right now.')),
//       );
//     }
//   }

//   Future<void> _editLimit(String packageName, int? currentLimit) async {
//     final limitController = TextEditingController(
//       text: currentLimit?.toString() ?? '',
//     );

//     final updated = await showModalBottomSheet<bool>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return Container(
//               padding: EdgeInsets.only(
//                 left: 20,
//                 right: 20,
//                 top: 20,
//                 bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
//               ),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'App limits',
//                     style: GoogleFonts.manrope(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w700,
//                       color: const Color(0xFF0D1C2E),
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     packageName,
//                     style: GoogleFonts.manrope(
//                       fontSize: 12,
//                       color: const Color(0xFF5A6B85),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   TextField(
//                     controller: limitController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       labelText: 'Daily limit (minutes)',
//                       filled: true,
//                       fillColor: const Color(0xFFF2F6FB),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(16),
//                         borderSide: BorderSide.none,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton(
//                           onPressed: () => Navigator.of(context).pop(false),
//                           style: OutlinedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                           ),
//                           child: const Text('Cancel'),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () => Navigator.of(context).pop(true),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF2E8B6B),
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                           ),
//                           child: Text(
//                             'Save',
//                             style: GoogleFonts.manrope(
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );

//     if (updated != true) {
//       limitController.dispose();
//       return;
//     }

//     final childRef = FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid);
//     final limitText = limitController.text.trim();

//     if (limitText.isEmpty) {
//       await childRef.update({'time_limits.$packageName': FieldValue.delete()});
//     } else {
//       final parsedLimit = int.tryParse(limitText);
//       if (parsedLimit != null) {
//         await childRef.set({
//           'time_limits.$packageName': parsedLimit,
//           'allowed_apps': FieldValue.arrayUnion([packageName]),
//           'updatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//       }
//     }

//     limitController.dispose();
//   }

//   Future<void> _requestChildAppSync() async {
//     if (_isOffline) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Go online to request app sync.')),
//       );
//       return;
//     }

//     try {
//       await FirebaseFirestore.instance
//           .collection('children')
//           .doc(widget.deviceUid)
//           .set({
//             'syncAppsRequestedAt': FieldValue.serverTimestamp(),
//             'updatedAt': FieldValue.serverTimestamp(),
//           }, SetOptions(merge: true));
//       if (!mounted) {
//         return;
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Sync request sent to child device.')),
//       );
//     } catch (_) {
//       if (!mounted) {
//         return;
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to send sync request right now.')),
//       );
//     }
//   }

//   Future<void> _requestChildLogsSync() async {
//     if (_isOffline) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Go online to request logs sync.')),
//       );
//       return;
//     }
//     await FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid)
//         .set({
//           'syncLogsRequestedAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//     if (!mounted) {
//       return;
//     }
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Logs sync requested.')));
//   }

//   Future<void> _setLockState(bool isLocked) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('children')
//           .doc(widget.deviceUid)
//           .set({
//             'is_locked': isLocked,
//             'updatedAt': FieldValue.serverTimestamp(),
//             if (!isLocked) 'lock_reason': FieldValue.delete(),
//           }, SetOptions(merge: true));
//     } catch (_) {
//       if (!mounted) {
//         return;
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Unable to update lock state.')),
//       );
//     }
//   }

//   Future<void> _editDailyScreenTimeLimit(int? currentLimit) async {
//     final controller = TextEditingController(
//       text: currentLimit?.toString() ?? '',
//     );
//     final updated = await showModalBottomSheet<bool>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.only(
//             left: 20,
//             right: 20,
//             top: 20,
//             bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
//           ),
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: controller,
//                 keyboardType: TextInputType.number,
//                 decoration: InputDecoration(
//                   labelText: 'Daily screen time limit (minutes)',
//                   filled: true,
//                   fillColor: const Color(0xFFF2F6FB),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(16),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.of(context).pop(true),
//                   child: const Text('Save'),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//     if (updated != true) {
//       controller.dispose();
//       return;
//     }
//     final text = controller.text.trim();
//     final ref = FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid);
//     if (text.isEmpty) {
//       await ref.set({
//         'daily_screen_limit_minutes': FieldValue.delete(),
//       }, SetOptions(merge: true));
//     } else {
//       final parsed = int.tryParse(text);
//       if (parsed != null) {
//         await ref.set({
//           'daily_screen_limit_minutes': parsed,
//           'updatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//       }
//     }
//     controller.dispose();
//   }

//   Future<void> _setGeofenceFromChildLocation(
//     DocumentSnapshot<Map<String, dynamic>> snapshot,
//   ) async {
//     final point = snapshot.data()?['lastLocation'];
//     if (point is! GeoPoint) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No child location available yet.')),
//       );
//       return;
//     }
//     await FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid)
//         .set({
//           'geofence': {
//             'enabled': true,
//             'center': point,
//             'radiusMeters': 200,
//             'mode': 'child',
//           },
//           'updatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//   }

//   Future<void> _setGeofenceAroundParent() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       return;
//     }
//     final parentDevice =
//         await FirebaseFirestore.instance
//             .collection('devices')
//             .doc(user.uid)
//             .get();
//     final point = parentDevice.data()?['lastLocation'];
//     if (point is! GeoPoint) {
//       if (!mounted) {
//         return;
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No parent location found on map yet.')),
//       );
//       return;
//     }
//     await FirebaseFirestore.instance
//         .collection('children')
//         .doc(widget.deviceUid)
//         .set({
//           'geofence': {
//             'enabled': true,
//             'center': point,
//             'radiusMeters': 200,
//             'mode': 'parent',
//           },
//           'updatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//   }

//   List<_InstalledApp> _parseInstalledApps(List<dynamic>? raw) {
//     final apps = <_InstalledApp>[];
//     for (final item in raw ?? const []) {
//       if (item is Map) {
//         final packageName = item['packageName'] as String? ?? '';
//         if (packageName.isEmpty) {
//           continue;
//         }
//         final appName = item['appName'] as String? ?? packageName;
//         apps.add(_InstalledApp(packageName: packageName, appName: appName));
//       }
//     }
//     apps.sort((a, b) => a.appName.compareTo(b.appName));
//     return apps;
//   }

//   @override
//   Widget build(BuildContext context) {
//     const brandDark = Color(0xFF1A365D);
//     const brandMuted = Color(0xFF5A6B85);
//     const surface = Color(0xFFF8F9FF);

//     final childStream =
//         FirebaseFirestore.instance
//             .collection('children')
//             .doc(widget.deviceUid)
//             .snapshots();

//     return Scaffold(
//       backgroundColor: surface,
//       appBar: AppBar(
//         title: Text(widget.label, style: GoogleFonts.manrope()),
//         backgroundColor: Colors.white,
//         foregroundColor: brandDark,
//         elevation: 0,
//       ),
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Color(0xFFF1F6FF), Color(0xFFE6F3EE)],
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//                     stream: childStream,
//                     builder: (context, snapshot) {
//                       final isLocked =
//                           snapshot.data?.data()?['is_locked'] == true;
//                       final limit =
//                           (snapshot.data?.data()?['daily_screen_limit_minutes']
//                                   as num?)
//                               ?.toInt();
//                       return Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(14),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(14),
//                               border: Border.all(
//                                 color: Colors.black.withOpacity(0.04),
//                               ),
//                             ),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   'Lock child phone',
//                                   style: GoogleFonts.manrope(
//                                     fontWeight: FontWeight.w700,
//                                     color: brandDark,
//                                   ),
//                                 ),
//                                 Switch(
//                                   value: isLocked,
//                                   onChanged: _setLockState,
//                                   activeColor: const Color(0xFFBA1A1A),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed: () => _editDailyScreenTimeLimit(limit),
//                             icon: const Icon(Icons.screen_lock_portrait),
//                             label: Text(
//                               limit == null
//                                   ? 'Set daily screen time'
//                                   : 'Edit daily screen time (${limit}m)',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed:
//                                 snapshot.hasData
//                                     ? () => _setGeofenceFromChildLocation(
//                                       snapshot.data!,
//                                     )
//                                     : null,
//                             icon: const Icon(Icons.radar),
//                             label: Text(
//                               'Set geo-fence around child',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed: _setGeofenceAroundParent,
//                             icon: const Icon(Icons.person_pin_circle),
//                             label: Text(
//                               'Set geo-fence around parent',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed: () {
//                               FirebaseFirestore.instance
//                                   .collection('children')
//                                   .doc(widget.deviceUid)
//                                   .set({
//                                     'geofence.enabled': false,
//                                     'geofenceBreached': false,
//                                     'updatedAt': FieldValue.serverTimestamp(),
//                                   }, SetOptions(merge: true));
//                             },
//                             icon: const Icon(Icons.gps_off),
//                             label: Text(
//                               'Disable geo-fence',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed: () {
//                               Navigator.of(context).push(
//                                 MaterialPageRoute(
//                                   builder:
//                                       (_) => LogsScreen(
//                                         deviceUid: widget.deviceUid,
//                                         label: widget.label,
//                                       ),
//                                 ),
//                               );
//                             },
//                             icon: const Icon(Icons.history_toggle_off),
//                             label: Text(
//                               'View call/SMS/contacts logs',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 10),
//                           OutlinedButton.icon(
//                             onPressed: _requestChildLogsSync,
//                             icon: const Icon(Icons.sync_problem),
//                             label: Text(
//                               'Request logs sync',
//                               style: GoogleFonts.manrope(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                         ],
//                       );
//                     },
//                   ),
//                   StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//                     stream: childStream,
//                     builder: (context, snapshot) {
//                       final data = snapshot.data?.data();
//                       final isOnline = data?['isOnline'] == true;
//                       final lastSeen = _formatLastSeen(
//                         data?['lastSeen'] as Timestamp?,
//                       );
//                       return Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(20),
//                           border: Border.all(
//                             color: Colors.black.withOpacity(0.04),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Device UID',
//                                   style: GoogleFonts.manrope(
//                                     fontSize: 12,
//                                     color: brandMuted,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   widget.deviceUid,
//                                   style: GoogleFonts.manrope(
//                                     fontWeight: FontWeight.w600,
//                                     color: const Color(0xFF0D1C2E),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//                                 Text(
//                                   lastSeen,
//                                   style: GoogleFonts.manrope(
//                                     fontSize: 12,
//                                     color: brandMuted,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             Column(
//                               children: [
//                                 Container(
//                                   width: 10,
//                                   height: 10,
//                                   decoration: BoxDecoration(
//                                     color:
//                                         isOnline
//                                             ? const Color(0xFF2E8B6B)
//                                             : Colors.grey.shade400,
//                                     shape: BoxShape.circle,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//                                 Text(
//                                   isOnline ? 'ONLINE' : 'OFFLINE',
//                                   style: GoogleFonts.manrope(
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.w700,
//                                     color:
//                                         isOnline
//                                             ? const Color(0xFF2E8B6B)
//                                             : Colors.grey.shade500,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                   if (_isOffline) const SizedBox(height: 12),
//                   if (_isOffline)
//                     NetworkStatusBanner(
//                       isOffline: _isOffline,
//                       margin: const EdgeInsets.symmetric(horizontal: 0),
//                     ),
//                   if (_isOffline) const SizedBox(height: 12),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Installed apps',
//                     style: GoogleFonts.manrope(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w700,
//                       color: brandDark,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Select allowed apps and set daily limits.',
//                     style: GoogleFonts.manrope(fontSize: 12, color: brandMuted),
//                   ),
//                   const SizedBox(height: 10),
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: OutlinedButton.icon(
//                       onPressed: _requestChildAppSync,
//                       icon: const Icon(Icons.sync),
//                       label: Text(
//                         'Request child app sync',
//                         style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
//                       ),
//                       style: OutlinedButton.styleFrom(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Expanded(
//                     child: StreamBuilder<
//                       DocumentSnapshot<Map<String, dynamic>>
//                     >(
//                       stream: childStream,
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState ==
//                             ConnectionState.waiting) {
//                           return const Center(
//                             child: CircularProgressIndicator(),
//                           );
//                         }

//                         if (snapshot.hasError) {
//                           return _EmptyState(
//                             message: 'Unable to load installed apps right now.',
//                           );
//                         }

//                         final data = snapshot.data?.data();
//                         final installedApps = _parseInstalledApps(
//                           data?['installed_apps'] as List<dynamic>?,
//                         );
//                         final allowedApps =
//                             (data?['allowed_apps'] as List<dynamic>?)
//                                 ?.cast<String>() ??
//                             <String>[];
//                         final blockedApps =
//                             (data?['blocked_apps'] as List<dynamic>?)
//                                 ?.cast<String>() ??
//                             <String>[];
//                         final limits =
//                             (data?['time_limits'] as Map<String, dynamic>?) ??
//                             const <String, dynamic>{};
//                         final installedUpdatedAt =
//                             data?['installedUpdatedAt'] as Timestamp?;
//                         final installedCount =
//                             (data?['installed_count'] as num?)?.toInt() ??
//                             installedApps.length;

//                         if (installedApps.isEmpty) {
//                           return _EmptyState(
//                             message:
//                                 'No installed apps yet. Open child mode on the child device, allow app access, then tap "Sync installed apps".',
//                           );
//                         }

//                         return Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.only(
//                                 left: 4,
//                                 right: 4,
//                                 bottom: 10,
//                               ),
//                               child: Text(
//                                 _formatInstalledSync(
//                                   installedUpdatedAt,
//                                   installedCount,
//                                 ),
//                                 style: GoogleFonts.manrope(
//                                   fontSize: 12,
//                                   color: brandMuted,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                             Expanded(
//                               child: ListView.separated(
//                                 itemCount: installedApps.length,
//                                 separatorBuilder:
//                                     (_, __) => const SizedBox(height: 10),
//                                 itemBuilder: (context, index) {
//                                   final app = installedApps[index];
//                                   final isAllowed = allowedApps.contains(
//                                     app.packageName,
//                                   );
//                                   final limitValue = limits[app.packageName];
//                                   final limitMinutes =
//                                       limitValue is num
//                                           ? limitValue.toInt()
//                                           : null;
//                                   final isBlocked = blockedApps.contains(
//                                     app.packageName,
//                                   );

//                                   return _AppRuleTile(
//                                     appName: app.appName,
//                                     packageName: app.packageName,
//                                     isAllowed: isAllowed,
//                                     isBlocked: isBlocked,
//                                     limitMinutes: limitMinutes,
//                                     onToggle: (value) {
//                                       _toggleAllowedApp(app.packageName, value);
//                                     },
//                                     onEditLimit: () {
//                                       _editLimit(app.packageName, limitMinutes);
//                                     },
//                                   );
//                                 },
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _AppRuleTile extends StatelessWidget {
//   const _AppRuleTile({
//     required this.appName,
//     required this.packageName,
//     required this.isAllowed,
//     required this.isBlocked,
//     required this.limitMinutes,
//     required this.onToggle,
//     required this.onEditLimit,
//   });

//   final String appName;
//   final String packageName;
//   final bool isAllowed;
//   final bool isBlocked;
//   final int? limitMinutes;
//   final ValueChanged<bool> onToggle;
//   final VoidCallback onEditLimit;

//   @override
//   Widget build(BuildContext context) {
//     final limitText =
//         limitMinutes == null ? 'No limit' : 'Limit: ${limitMinutes}m';
//     final statusText =
//         isBlocked ? 'Blocked' : (isAllowed ? 'Allowed' : 'Not allowed');
//     final statusColor =
//         isBlocked ? const Color(0xFFBA1A1A) : const Color(0xFF2E8B6B);

//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.black.withOpacity(0.04)),
//       ),
//       child: Row(
//         children: [
//           Checkbox(
//             value: isAllowed,
//             onChanged: (value) {
//               onToggle(value ?? false);
//             },
//           ),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   appName,
//                   style: GoogleFonts.manrope(
//                     fontWeight: FontWeight.w700,
//                     color: const Color(0xFF0D1C2E),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   packageName,
//                   style: GoogleFonts.manrope(
//                     fontSize: 12,
//                     color: const Color(0xFF5A6B85),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   '$statusText · $limitText',
//                   style: GoogleFonts.manrope(
//                     fontSize: 12,
//                     color: statusColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             onPressed: onEditLimit,
//             icon: const Icon(Icons.timer, color: Color(0xFF1A365D)),
//             tooltip: 'Set time limit',
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InstalledApp {
//   const _InstalledApp({required this.packageName, required this.appName});

//   final String packageName;
//   final String appName;
// }

// class _EmptyState extends StatelessWidget {
//   const _EmptyState({required this.message});

//   final String message;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: Colors.black.withOpacity(0.04)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               color: const Color(0xFFE5EEFF),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(Icons.apps, color: Color(0xFF1A365D)),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               message,
//               style: GoogleFonts.manrope(
//                 color: const Color(0xFF5A6B85),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/network_status_banner.dart';
import 'logs_screen.dart';

class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({
    super.key,
    required this.deviceUid,
    required this.label,
  });

  final String deviceUid;
  final String label;

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
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

  String _formatInstalledSync(Timestamp? timestamp, int? installedCount) {
    if (timestamp == null) {
      return 'App list not synced yet';
    }
    final delta = DateTime.now().difference(timestamp.toDate());
    final when =
        delta.inMinutes < 1
            ? 'just now'
            : delta.inHours < 1
            ? '${delta.inMinutes}m ago'
            : delta.inDays < 1
            ? '${delta.inHours}h ago'
            : '${delta.inDays}d ago';
    final count = installedCount ?? 0;
    return 'Synced $when ($count apps)';
  }

  Future<void> _toggleAllowedApp(String packageName, bool isAllowed) async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Go online to update app rules.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final childRef = FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid);

    try {
      if (isAllowed) {
        await childRef.set({
          'allowed_apps': FieldValue.arrayUnion([packageName]),
        }, SetOptions(merge: true));
      } else {
        await childRef.update({
          'allowed_apps': FieldValue.arrayRemove([packageName]),
          'time_limits.$packageName': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update app rule right now.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _editLimit(String packageName, int? currentLimit) async {
    final limitController = TextEditingController(
      text: currentLimit?.toString() ?? '',
    );

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Daily Time Limit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    packageName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Daily limit (minutes)',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF3B82F6),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Save Limit',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (updated != true) {
      limitController.dispose();
      return;
    }

    final childRef = FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid);
    final limitText = limitController.text.trim();

    if (limitText.isEmpty) {
      await childRef.update({'time_limits.$packageName': FieldValue.delete()});
    } else {
      final parsedLimit = int.tryParse(limitText);
      if (parsedLimit != null) {
        await childRef.set({
          'time_limits.$packageName': parsedLimit,
          'allowed_apps': FieldValue.arrayUnion([packageName]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    limitController.dispose();
  }

  Future<void> _requestChildAppSync() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Go online to request app sync.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('children')
          .doc(widget.deviceUid)
          .set({
            'syncAppsRequestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync request sent to child device.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send sync request right now.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _requestChildLogsSync() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Go online to request logs sync.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid)
        .set({
          'syncLogsRequestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logs sync requested.',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _setLockState(bool isLocked) async {
    try {
      await FirebaseFirestore.instance
          .collection('children')
          .doc(widget.deviceUid)
          .set({
            'is_locked': isLocked,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!isLocked) 'lock_reason': FieldValue.delete(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update lock state.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _editDailyScreenTimeLimit(int? currentLimit) async {
    final controller = TextEditingController(
      text: currentLimit?.toString() ?? '',
    );
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Screen Time Limit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Daily screen time limit (minutes)',
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Limit',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (updated != true) {
      controller.dispose();
      return;
    }
    final text = controller.text.trim();
    final ref = FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid);
    if (text.isEmpty) {
      await ref.set({
        'daily_screen_limit_minutes': FieldValue.delete(),
      }, SetOptions(merge: true));
    } else {
      final parsed = int.tryParse(text);
      if (parsed != null) {
        await ref.set({
          'daily_screen_limit_minutes': parsed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    controller.dispose();
  }

  Future<void> _setGeofenceFromChildLocation(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final point = snapshot.data()?['lastLocation'];
    if (point is! GeoPoint) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No child location available yet.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid)
        .set({
          'geofence': {
            'enabled': true,
            'center': point,
            'radiusMeters': 200,
            'mode': 'child',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _setGeofenceAroundParent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final parentDevice =
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(user.uid)
            .get();
    final point = parentDevice.data()?['lastLocation'];
    if (point is! GeoPoint) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No parent location found on map yet.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('children')
        .doc(widget.deviceUid)
        .set({
          'geofence': {
            'enabled': true,
            'center': point,
            'radiusMeters': 200,
            'mode': 'parent',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  List<_InstalledApp> _parseInstalledApps(List<dynamic>? raw) {
    final apps = <_InstalledApp>[];
    for (final item in raw ?? const []) {
      if (item is Map) {
        final packageName = item['packageName'] as String? ?? '';
        if (packageName.isEmpty) {
          continue;
        }
        final appName = item['appName'] as String? ?? packageName;
        apps.add(_InstalledApp(packageName: packageName, appName: appName));
      }
    }
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F172A);
    const Color primaryAccent = Color(0xFF3B82F6);
    const Color successColor = Color(0xFF10B981);
    const Color warningColor = Color(0xFFEF4444);
    const Color neutralLight = Color(0xFFF8FAFC);
    const Color neutralMuted = Color(0xFF64748B);

    final childStream =
        FirebaseFirestore.instance
            .collection('children')
            .doc(widget.deviceUid)
            .snapshots();

    return Scaffold(
      backgroundColor: neutralLight,
      appBar: AppBar(
        title: Text(
          widget.label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  neutralLight.withOpacity(0.5),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Control Section
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: childStream,
                      builder: (context, snapshot) {
                        final isLocked =
                            snapshot.data?.data()?['is_locked'] == true;
                        final limit =
                            (snapshot.data?.data()?['daily_screen_limit_minutes']
                                    as num?)
                                ?.toInt();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Lock Control Card
                            _ControlCard(
                              title: 'Lock Child Phone',
                              description:
                                  'Instantly lock the device',
                              icon: Icons.lock_outline,
                              iconColor: warningColor,
                              primaryDark: primaryDark,
                              primaryAccent: primaryAccent,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isLocked ? 'Locked' : 'Unlocked',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isLocked,
                                    onChanged: _setLockState,
                                    activeColor: warningColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Screen Time Card
                            _ActionCard(
                              icon: Icons.timer_outlined,
                              iconColor: primaryAccent,
                              title: 'Daily Screen Time',
                              subtitle:
                                  limit == null
                                      ? 'No limit set'
                                      : 'Limit: ${limit}m',
                              onTap: () => _editDailyScreenTimeLimit(limit),
                              primaryDark: primaryDark,
                            ),
                            const SizedBox(height: 12),
                            // Geofence Around Child
                            _ActionCard(
                              icon: Icons.location_on_outlined,
                              iconColor: successColor,
                              title: 'Geofence Around Child',
                              subtitle: 'Set boundary at child\'s location',
                              onTap:
                                  snapshot.hasData
                                      ? () =>
                                          _setGeofenceFromChildLocation(
                                            snapshot.data!,
                                          )
                                      : null,
                              primaryDark: primaryDark,
                            ),
                            const SizedBox(height: 12),
                            // Geofence Around Parent
                            _ActionCard(
                              icon: Icons.person_pin_circle_outlined,
                              iconColor: primaryAccent,
                              title: 'Geofence Around Parent',
                              subtitle: 'Child must stay near you',
                              onTap: _setGeofenceAroundParent,
                              primaryDark: primaryDark,
                            ),
                            const SizedBox(height: 12),
                            // Disable Geofence
                            _ActionCard(
                              icon: Icons.gps_off_outlined,
                              iconColor: neutralMuted,
                              title: 'Disable Geofence',
                              subtitle: 'Remove location boundaries',
                              onTap: () {
                                FirebaseFirestore.instance
                                    .collection('children')
                                    .doc(widget.deviceUid)
                                    .set({
                                      'geofence.enabled': false,
                                      'geofenceBreached': false,
                                      'updatedAt':
                                          FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                              },
                              primaryDark: primaryDark,
                            ),
                            const SizedBox(height: 12),
                            // Logs Section
                            _ActionCard(
                              icon: Icons.history_outlined,
                              iconColor: primaryAccent,
                              title: 'View Activity Logs',
                              subtitle: 'Call, SMS, and contacts history',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => LogsScreen(
                                          deviceUid: widget.deviceUid,
                                          label: widget.label,
                                        ),
                                  ),
                                );
                              },
                              primaryDark: primaryDark,
                            ),
                            const SizedBox(height: 12),
                            // Request Logs Sync
                            _ActionCard(
                              icon: Icons.cloud_sync_outlined,
                              iconColor: primaryAccent,
                              title: 'Request Logs Sync',
                              subtitle: 'Fetch latest activity from device',
                              onTap: _requestChildLogsSync,
                              primaryDark: primaryDark,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Device Status Card
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: childStream,
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final isOnline = data?['isOnline'] == true;
                        final lastSeen = _formatLastSeen(
                          data?['lastSeen'] as Timestamp?,
                        );
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device UID',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: neutralMuted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.deviceUid,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: primaryDark,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lastSeen,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: neutralMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color:
                                          isOnline
                                              ? successColor
                                              : neutralMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isOnline ? 'ONLINE' : 'OFFLINE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isOnline
                                              ? successColor
                                              : neutralMuted,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_isOffline) const SizedBox(height: 12),
                    if (_isOffline)
                      NetworkStatusBanner(
                        isOffline: _isOffline,
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                    const SizedBox(height: 24),
                    // Apps Section
                    Text(
                      'Installed Apps',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Allow or block apps and set daily time limits.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: neutralMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _requestChildAppSync,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          'Request App Sync',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Apps List
                    StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: childStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: primaryAccent,
                                  strokeWidth: 2.5,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading apps...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: neutralMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return _EmptyState(
                            message:
                                'Unable to load installed apps right now.',
                            primaryDark: primaryDark,
                            primaryAccent: primaryAccent,
                          );
                        }

                        final data = snapshot.data?.data();
                        final allowedApps = (data?['allowed_apps'] as List?)
                            ?.cast<String>()
                            .toSet() ?? <String>{};
                        final timeLimits = (data?['time_limits'] as Map?)
                            ?.cast<String, dynamic>() ?? <String, dynamic>{};
                        final installedApps =
                            _parseInstalledApps(data?['installed_apps']);
                        final lastSyncTime =
                            (data?['installedAppsSyncedAt']) as Timestamp?;
                        final installedCount = installedApps.length;

                        if (installedApps.isEmpty) {
                          return _EmptyState(
                            message:
                                'No apps synced yet. Request app sync to get started.',
                            primaryDark: primaryDark,
                            primaryAccent: primaryAccent,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _formatInstalledSync(
                                lastSyncTime,
                                installedCount,
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: neutralMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: installedApps.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final app = installedApps[index];
                                final isAllowed =
                                    allowedApps.contains(app.packageName);
                                final timeLimit =
                                    timeLimits[app.packageName] as int?;

                                return _AppTile(
                                  appName: app.appName,
                                  packageName: app.packageName,
                                  isAllowed: isAllowed,
                                  timeLimit: timeLimit,
                                  onToggleAllow: (newValue) =>
                                      _toggleAllowedApp(
                                        app.packageName,
                                        newValue,
                                      ),
                                  onEditLimit: () => _editLimit(
                                    app.packageName,
                                    timeLimit,
                                  ),
                                  primaryDark: primaryDark,
                                  primaryAccent: primaryAccent,
                                  successColor: successColor,
                                  neutralMuted: neutralMuted,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.primaryDark,
    required this.primaryAccent,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color primaryDark;
  final Color primaryAccent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primaryDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color primaryDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.appName,
    required this.packageName,
    required this.isAllowed,
    required this.timeLimit,
    required this.onToggleAllow,
    required this.onEditLimit,
    required this.primaryDark,
    required this.primaryAccent,
    required this.successColor,
    required this.neutralMuted,
  });

  final String appName;
  final String packageName;
  final bool isAllowed;
  final int? timeLimit;
  final ValueChanged<bool> onToggleAllow;
  final VoidCallback onEditLimit;
  final Color primaryDark;
  final Color primaryAccent;
  final Color successColor;
  final Color neutralMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  packageName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: neutralMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isAllowed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Allowed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: successColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Blocked',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    if (isAllowed && timeLimit != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${timeLimit}m limit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryAccent,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              GestureDetector(
                onTap: () => onToggleAllow(!isAllowed),
                child: Switch(
                  value: isAllowed,
                  onChanged: onToggleAllow,
                  activeColor: successColor,
                ),
              ),
              const SizedBox(height: 4),
              if (isAllowed)
                GestureDetector(
                  onTap: onEditLimit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: primaryAccent,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.primaryDark,
    required this.primaryAccent,
  });

  final String message;
  final Color primaryDark;
  final Color primaryAccent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.apps_outlined,
              size: 40,
              color: primaryAccent,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstalledApp {
  const _InstalledApp({
    required this.packageName,
    required this.appName,
  });

  final String packageName;
  final String appName;
}