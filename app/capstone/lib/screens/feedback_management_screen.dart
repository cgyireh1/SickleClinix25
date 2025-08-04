// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import '../theme.dart';

// class FeedbackManagementScreen extends StatefulWidget {
//   const FeedbackManagementScreen({super.key});

//   @override
//   State<FeedbackManagementScreen> createState() =>
//       _FeedbackManagementScreenState();
// }

// class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
//   List<Map<String, dynamic>> _allFeedback = [];
//   bool _isLoading = true;
//   String _selectedFilter = 'All';

//   @override
//   void initState() {
//     super.initState();
//     _loadFeedback();
//   }

//   Future<void> _loadFeedback() async {
//     setState(() => _isLoading = true);

//     try {
//       // Load from Firebase
//       final firestore = FirebaseFirestore.instance;
//       final feedbackSnapshot = await firestore.collection('feedback').get();

//       List<Map<String, dynamic>> firebaseFeedback = [];
//       for (var doc in feedbackSnapshot.docs) {
//         firebaseFeedback.add({
//           ...doc.data(),
//           'id': doc.id,
//           'source': 'Firebase',
//         });
//       }

//       // Load from local storage
//       final prefs = await SharedPreferences.getInstance();
//       final offlineFeedback = prefs.getStringList('offline_feedback') ?? [];

//       List<Map<String, dynamic>> localFeedback = [];
//       for (String feedbackJson in offlineFeedback) {
//         try {
//           final feedback = jsonDecode(feedbackJson) as Map<String, dynamic>;
//           localFeedback.add({
//             ...feedback,
//             'id': DateTime.now().millisecondsSinceEpoch.toString(),
//             'source': 'Local',
//           });
//         } catch (e) {
//           debugPrint('Error parsing local feedback: $e');
//         }
//       }

//       // Combine and sort by timestamp
//       _allFeedback = [...firebaseFeedback, ...localFeedback];
//       _allFeedback.sort((a, b) {
//         final aTime = DateTime.parse(
//           a['timestamp'] ?? DateTime.now().toIso8601String(),
//         );
//         final bTime = DateTime.parse(
//           b['timestamp'] ?? DateTime.now().toIso8601String(),
//         );
//         return bTime.compareTo(aTime);
//       });
//     } catch (e) {
//       debugPrint('Error loading feedback: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   List<Map<String, dynamic>> get _filteredFeedback {
//     if (_selectedFilter == 'All') return _allFeedback;
//     return _allFeedback
//         .where((feedback) => feedback['source'] == _selectedFilter)
//         .toList();
//   }

//   void _showFeedbackDetails(Map<String, dynamic> feedback) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Feedback from ${feedback['name'] ?? 'Anonymous'}'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _detailRow('Name', feedback['name'] ?? 'Anonymous'),
//               _detailRow('Email', feedback['email'] ?? 'No email'),
//               _detailRow('Message', feedback['message'] ?? 'No message'),
//               _detailRow('Date', _formatDate(feedback['timestamp'])),
//               _detailRow('Source', feedback['source'] ?? 'Unknown'),
//               if (feedback['userId'] != null)
//                 _detailRow('User ID', feedback['userId']),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//           if (feedback['email'] != null)
//             TextButton(
//               onPressed: () => _replyToFeedback(feedback),
//               child: const Text('Reply'),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _detailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(
//               fontWeight: FontWeight.bold,
//               color: Colors.grey,
//             ),
//           ),
//           Text(value),
//           const Divider(),
//         ],
//       ),
//     );
//   }

//   String _formatDate(String? timestamp) {
//     if (timestamp == null) return 'Unknown date';
//     try {
//       final date = DateTime.parse(timestamp);
//       return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     } catch (e) {
//       return 'Invalid date';
//     }
//   }

//   void _replyToFeedback(Map<String, dynamic> feedback) {
//     final email = feedback['email'];
//     if (email == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No email address available for reply')),
//       );
//       return;
//     }

//     final subject = 'Re: SickleClinix Feedback';
//     final body =
//         'Thank you for your feedback. We will review it and get back to you soon.';

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Reply to: $email'),
//         action: SnackBarAction(label: 'Copy Email', onPressed: () {}),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Feedback Management'),
//         backgroundColor: const Color(0xFFB71C1C),
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFeedback),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Filter buttons
//           Container(
//             padding: const EdgeInsets.all(16),
//             child: Row(
//               children: [
//                 const Text(
//                   'Filter: ',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(width: 8),
//                 DropdownButton<String>(
//                   value: _selectedFilter,
//                   items: ['All', 'Firebase', 'Local'].map((String value) {
//                     return DropdownMenuItem<String>(
//                       value: value,
//                       child: Text(value),
//                     );
//                   }).toList(),
//                   onChanged: (String? newValue) {
//                     setState(() {
//                       _selectedFilter = newValue!;
//                     });
//                   },
//                 ),
//                 const Spacer(),
//                 Text('${_filteredFeedback.length} feedback items'),
//               ],
//             ),
//           ),

//           // Feedback list
//           Expanded(
//             child: _isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : _filteredFeedback.isEmpty
//                 ? const Center(
//                     child: Text(
//                       'No feedback found',
//                       style: TextStyle(fontSize: 18, color: Colors.grey),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _filteredFeedback.length,
//                     itemBuilder: (context, index) {
//                       final feedback = _filteredFeedback[index];
//                       return Card(
//                         margin: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 4,
//                         ),
//                         child: ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: feedback['source'] == 'Firebase'
//                                 ? Colors.green
//                                 : Colors.orange,
//                             child: Icon(
//                               feedback['source'] == 'Firebase'
//                                   ? Icons.cloud
//                                   : Icons.phone_android,
//                               color: Colors.white,
//                             ),
//                           ),
//                           title: Text(
//                             feedback['name'] ?? 'Anonymous',
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 feedback['message'] ?? 'No message',
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                               const SizedBox(height: 4),
//                               Row(
//                                 children: [
//                                   Icon(
//                                     Icons.access_time,
//                                     size: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     _formatDate(feedback['timestamp']),
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   const Spacer(),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 2,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: feedback['source'] == 'Firebase'
//                                           ? Colors.green.withOpacity(0.2)
//                                           : Colors.orange.withOpacity(0.2),
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       feedback['source'] ?? 'Unknown',
//                                       style: TextStyle(
//                                         fontSize: 10,
//                                         color: feedback['source'] == 'Firebase'
//                                             ? Colors.green[700]
//                                             : Colors.orange[700],
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           onTap: () => _showFeedbackDetails(feedback),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
