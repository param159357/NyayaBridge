import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/client_profile_setup_screen.dart';
import 'package:frontend/screens/auth/lawyer_registration_screen.dart';
import 'package:frontend/screens/auth/login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {

  // 🚀 FIX: This safely logs the user out if they press the back button here
  Future<void> _cancelRegistration() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Intercepts the physical Android back button
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelRegistration();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          // 🚀 FIX: Added a back button that actually works!
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            onPressed: _cancelRegistration,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "How will you use NyayaBridge?",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(24),
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  // 🚀 FIX: Using normal 'push' instead of 'pushReplacement' so the back button works!
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ClientProfileSetupScreen())
                  );
                },
                child: const Column(
                  children: [
                    Icon(Icons.person, size: 48),
                    SizedBox(height: 8),
                    Text("I am a Citizen", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("I need legal help or want to use the SOS radar.", textAlign: TextAlign.center),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(24),
                  backgroundColor: Colors.deepPurple.shade50,
                  foregroundColor: Colors.deepPurple.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  // 🚀 FIX: Using normal 'push' so they can return to this screen
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LawyerRegistrationScreen())
                  );
                },
                child: const Column(
                  children: [
                    Icon(Icons.gavel, size: 48),
                    SizedBox(height: 8),
                    Text("I am a Lawyer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("I want to receive cases and assist citizens.", textAlign: TextAlign.center),
                  ],
                ),
              ),

              const Spacer(),
              TextButton(
                  onPressed: _cancelRegistration,
                  child: const Text("Cancel and Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}