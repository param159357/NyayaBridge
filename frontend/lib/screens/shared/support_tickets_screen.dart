import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/shared/chat_screen.dart';
import 'dart:math';

class SupportTicketsScreen extends StatefulWidget {
  final String role; // 'client' or 'lawyer'
  const SupportTicketsScreen({super.key, required this.role});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final TextEditingController _subjectController = TextEditingController();

  void _createNewTicket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Create Support Ticket", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D3142))),
                const SizedBox(height: 8),
                const Text("Describe your issue briefly. You can add details and images in the chat.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    hintText: "E.g., Cannot update my profile",
                    filled: true, fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A3AFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () async {
                      if (_subjectController.text.trim().isEmpty) return;
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      // Fetch name
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                      final userName = userDoc.data()?['name'] ?? user.phoneNumber ?? 'User';

                      final String ticketNumber = 'TKT-${Random().nextInt(90000) + 10000}';

                      await FirebaseFirestore.instance.collection('cases').add({
                        'type': 'SUPPORT TICKET',
                        'ticketNumber': ticketNumber,
                        'subject': _subjectController.text.trim(),
                        'clientName': userName,
                        'clientId': user.uid,
                        'targetLawyerId': 'ADMIN', // Routes to admin
                        'status': 'open',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      _subjectController.clear();
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket Created!"), backgroundColor: Colors.green));
                    },
                    child: const Text("Submit Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: const Color(0xFF2D3142), elevation: 0.5,
        title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTicket,
        backgroundColor: const Color(0xFF4A3AFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cases')
            .where('type', isEqualTo: 'SUPPORT TICKET')
            .where('clientId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No support tickets yet.", style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA); // Newest first
          });

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isClosed = data['status'] == 'closed' || data['status'] == 'resolved';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isClosed ? Colors.grey.shade100 : Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.headset_mic, color: isClosed ? Colors.grey : Colors.blue.shade700),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['ticketNumber'] ?? 'TKT-XXXXX', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4A3AFF))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: isClosed ? Colors.grey.shade200 : Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Text(isClosed ? "CLOSED" : "OPEN", style: TextStyle(color: isClosed ? Colors.grey.shade700 : Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(data['subject'] ?? 'No Subject', style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(caseId: doc.id, clientName: "Support: ${data['ticketNumber']}")));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}