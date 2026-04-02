import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/auth/role_selection_screen.dart';
import 'package:frontend/screens/auth/verification_pending_screen.dart';
import 'package:frontend/screens/auth/client_profile_setup_screen.dart'; // 🚀 Added import

import 'package:frontend/screens/client/client_dashboard.dart';
import 'package:frontend/screens/lawyer/lawyer_dashboard.dart';
import 'package:frontend/screens/admin/admin_dashboard.dart';

class AuthGatekeeper extends StatelessWidget {
  const AuthGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = data['role'];

              if (role == 'admin') {
                return const AdminDashboard();
              }
              else if (role == 'lawyer') {
                final isVerified = data['isVerified'] ?? false;
                final isRejected = data['isRejected'] ?? false;
                final rejectionReason = data['rejectionReason'] ?? '';

                if (isVerified == true) {
                  return const LawyerDashboard();
                } else {
                  return VerificationPendingScreen(isRejected: isRejected, rejectionReason: rejectionReason);
                }
              }
              else {
                // 🚀 POINT 1 FIX: Force to setup screen if name is missing!
                if (data['name'] == null || data['name'].toString().trim().isEmpty) {
                  return const ClientProfileSetupScreen();
                }
                return const ClientDashboard();
              }
            } else {
              return const RoleSelectionScreen();
            }
          },
        );
      },
    );
  }
}