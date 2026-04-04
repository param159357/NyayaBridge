import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LawyerEditProfileScreen extends StatefulWidget {
  const LawyerEditProfileScreen({super.key});

  @override
  State<LawyerEditProfileScreen> createState() => _LawyerEditProfileScreenState();
}

class _LawyerEditProfileScreenState extends State<LawyerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _casesSolvedController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _emergencyFeeController = TextEditingController(); // 🚀 FIX: Added Emergency Fee

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLawyerData();
  }

  Future<void> _loadLawyerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _cityController.text = data['city'] ?? '';
          _experienceController.text = (data['experienceYears'] ?? 0).toString();
          _casesSolvedController.text = (data['casesSolved'] ?? 0).toString();
          _feeController.text = (data['consultationFee'] ?? 0).toString();
          _emergencyFeeController.text = (data['emergencyFee'] ?? 0).toString(); // 🚀 FIX: Loaded
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'city': _cityController.text.trim(),
          'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
          'casesSolved': int.tryParse(_casesSolvedController.text.trim()) ?? 0,
          'consultationFee': int.tryParse(_feeController.text.trim()) ?? 0,
          'emergencyFee': int.tryParse(_emergencyFeeController.text.trim()) ?? 0, // 🚀 FIX: Saved
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile & Track Record updated!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Professional Profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Center( // 🚀 FIX: Center for Chrome Web View
          child: ConstrainedBox( // 🚀 FIX: Constrain width for Chrome Web View
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Basic Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: "Full Legal Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(labelText: "Primary City", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),

                    const SizedBox(height: 32),
                    const Text("Track Record & Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Keep these updated. The AI uses these metrics to recommend you to clients.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _experienceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Years Exp.", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _casesSolvedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Cases Solved", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🚀 FIX: Added Emergency Fee input field next to Normal Fee
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _feeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Normal Fee (₹)", prefixIcon: const Icon(Icons.currency_rupee), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emergencyFeeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "SOS Fee (₹)", prefixIcon: const Icon(Icons.currency_rupee), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _isSaving ? null : _updateProfile,
                        child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
