import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/shared/chat_screen.dart';

class CaseHistoryScreen extends StatefulWidget {
  final String role; // 'client' or 'lawyer'
  const CaseHistoryScreen({super.key, required this.role});

  @override
  State<CaseHistoryScreen> createState() => _CaseHistoryScreenState();
}

class _CaseHistoryScreenState extends State<CaseHistoryScreen> {
  String _clientName = "";
  String _clientPhone = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _clientPhone = user.phoneNumber ?? "";
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _clientName = doc.data()?['name'] ?? "";
        });
      }
    }
  }

  Future<void> _acceptRequest(String docId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('cases').doc(docId).update({
      'status': 'accepted',
      'acceptedBy': user?.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(caseId: docId, clientName: data['clientName'])));
  }

  Future<void> _declineRequest(String docId) async {
    await FirebaseFirestore.instance.collection('cases').doc(docId).update({
      'status': 'declined',
    });
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case declined."), backgroundColor: Colors.red));
  }

  void _showLawyerReviewDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Consultation Request", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Client: ${data['clientName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Type: ${data['type']}"),
              const SizedBox(height: 16),
              const Text("AI Summary / Case Details:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(data['aiSummary'] ?? 'No summary available.'),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => _declineRequest(docId), child: const Text("Decline", style: TextStyle(color: Colors.red))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => _acceptRequest(docId, data),
              child: const Text("Accept & Open Chat")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLawyer = widget.role == 'lawyer';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Active & Past Cases", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isLawyer ? Colors.black87 : Colors.white,
        foregroundColor: isLawyer ? Colors.white : Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cases').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No case history found."));

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';

            // 🚀 THE FIX: We now allow closed/resolved cases to remain in the history view!
            if (status != 'accepted' && status != 'pending' && status != 'closed' && status != 'resolved') return false;

            if (isLawyer) {
              return data['acceptedBy'] == user?.uid || data['lawyerId'] == user?.uid || (data['targetLawyerId'] == user?.uid && status == 'pending');
            } else {
              return data['clientId'] == user?.uid || data['clientName'] == _clientName || data['clientName'] == _clientPhone;
            }
          }).toList();

          docs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          if (docs.isEmpty) return const Center(child: Text("No active cases or pending requests found."));

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800), // Web centering
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'General';
                  final status = data['status'] ?? 'unknown';

                  final isPending = status == 'pending';
                  final isClosed = status == 'closed' || status == 'resolved'; // 🚀 Identifies closed cases

                  String displayTitle;
                  if (isLawyer) {
                    displayTitle = "Client: ${data['clientName']}";
                  } else {
                    displayTitle = "Lawyer: ${data['lawyerName'] ?? data['targetLawyerName'] ?? 'Assigned Lawyer'}";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isPending ? Colors.orange.shade300 : Colors.transparent, width: isPending ? 2 : 0)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: isClosed ? Colors.grey.shade200 : (isPending ? Colors.orange.shade50 : (isLawyer ? Colors.blue.shade50 : Colors.deepPurple.shade50)),
                        child: Icon(isClosed ? Icons.lock : (isPending ? Icons.hourglass_top : Icons.chat), color: isClosed ? Colors.grey : (isPending ? Colors.orange : (isLawyer ? Colors.blue : Colors.deepPurple))),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(displayTitle, style: TextStyle(fontWeight: FontWeight.bold, color: isClosed ? Colors.grey.shade600 : Colors.black))),
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                              child: const Text("Pending", style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ),
                          // 🚀 ADDED A RED BADGE FOR CLOSED CASES
                          if (isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                              child: const Text("Closed", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(isPending && !isLawyer ? "Waiting for lawyer to accept..." : "Category: ${data['category']}\nSource: $type"),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (isPending) {
                          if (isLawyer) {
                            _showLawyerReviewDialog(doc.id, data);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The lawyer has not accepted the request yet.")));
                          }
                        } else {
                          // Allow opening ChatScreen even if closed (chat screen disables input automatically!)
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(caseId: doc.id, clientName: isLawyer ? data['clientName'] : (data['lawyerName'] ?? data['targetLawyerName'] ?? "Assigned Lawyer"))));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}