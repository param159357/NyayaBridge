import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/onboarding_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // 🚀 Added for ID generation

class ClientProfileSetupScreen extends StatefulWidget {
  const ClientProfileSetupScreen({super.key});

  @override
  State<ClientProfileSetupScreen> createState() => _ClientProfileSetupScreenState();
}

class _ClientProfileSetupScreenState extends State<ClientProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select your Date of Birth.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {

        // 🚀 FIX: We generate the ID and create the document ONLY when they click save!
        String uniqueId = 'CIT-${Random().nextInt(9000) + 1000}';

        // Notice we are using .set() instead of .update() because the document doesn't exist yet!
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': 'client',
          'uniqueId': uniqueId,
          'phone': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'city': _cityController.text.trim(),
          'dob': Timestamp.fromDate(_selectedDate!),
        });

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen(role: 'client')),
              (route) => false, // Clears the navigation stack
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Complete Profile", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // 🚀 FIX: Removed automaticallyImplyLeading: false so the Back Arrow appears!
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_outline, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text("Tell us about yourself", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("This helps lawyers know who they are assisting.", style: TextStyle(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
                const SizedBox(height: 48),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: "Full Name", prefixIcon: const Icon(Icons.badge), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value == null || value.isEmpty ? "Please enter your name" : null,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: "Email Address", prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value == null || !value.contains('@') ? "Please enter a valid email" : null,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(labelText: "City", prefixIcon: const Icon(Icons.location_city), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value == null || value.isEmpty ? "Please enter your city" : null,
                ),
                const SizedBox(height: 24),

                InkWell(
                  onTap: () => _pickDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: "Date of Birth", prefixIcon: const Icon(Icons.calendar_today), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(
                      _selectedDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                      style: TextStyle(fontSize: 16, color: _selectedDate == null ? Colors.grey.shade600 : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save & Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}