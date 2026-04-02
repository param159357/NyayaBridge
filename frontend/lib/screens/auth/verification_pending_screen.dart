import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/auth/lawyer_registration_screen.dart'; // Needed for re-apply

class VerificationPendingScreen extends StatelessWidget {
  final bool isRejected;
  final String rejectionReason;

  const VerificationPendingScreen({
    super.key,
    this.isRejected = false,
    this.rejectionReason = ''
  });

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Dynamic UI based on their status
    final iconColor = isRejected ? Colors.red : Colors.deepPurple;
    final iconData = isRejected ? Icons.cancel : Icons.admin_panel_settings;
    final titleText = isRejected ? "Application Rejected" : "Profile Under Review";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.black87), onPressed: () => _logout(context))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(iconData, size: 100, color: iconColor),
            const SizedBox(height: 32),
            Text(titleText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),

            // 🚀 The dynamic message
            if (isRejected) ...[
              const Text("Your application to join the Live Radar was not approved for the following reason:", style: TextStyle(fontSize: 16, color: Colors.black87), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Text(rejectionReason, style: TextStyle(fontSize: 16, color: Colors.red.shade900, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              ),
            ] else ...[
              Text(
                "To ensure the safety of our citizens, all lawyer accounts must be manually verified by our team.\n\nWe are currently checking your Bar Council credentials. You will be granted access to the panel once approved.",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 48),

            // 🚀 The dynamic button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (isRejected) {
                    // Send them back to the form to try again!
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LawyerRegistrationScreen()));
                  } else {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
                child: Text(isRejected ? "Edit Details & Re-Apply" : "Check Status", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}