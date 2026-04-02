import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🚀 Added Auth to track the lawyer
import 'package:frontend/screens/shared/chat_screen.dart';

class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  final Map<String, String> caseData;

  const CaseDetailScreen({super.key, required this.caseId, required this.caseData});

  Future<void> _acceptCase(BuildContext context) async {
    // 🚀 Grab the current lawyer's data
    final user = FirebaseAuth.instance.currentUser;

    // 1. Update the database to show THIS specific lawyer took the case
    await FirebaseFirestore.instance.collection('cases').doc(caseId).update({
      'status': 'accepted',
      'acceptedBy': user?.phoneNumber ?? "Unknown Lawyer", // 🚀 Tracks who took it for the Admin Logs
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    // 2. Open the Chat Room!
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          caseId: caseId,
          clientName: caseData["client"]!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = caseData["type"] == "EMERGENCY SOS";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: isEmergency ? Colors.red.shade700 : Colors.blue.shade800,
        foregroundColor: Colors.white,
        title: const Text("Case File"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEmergency ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    caseData["type"]!,
                    style: TextStyle(
                      color: isEmergency ? Colors.red.shade800 : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  caseData["time"]!,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("Client Information", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(caseData["client"]!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("📍 ${caseData["distance"]}", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const Divider(height: 48, thickness: 1),
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text("AI Case Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                caseData["issue"]!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _acceptCase(context),
                child: const Text("Accept Case & Open Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Decline & Return to Radar", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}