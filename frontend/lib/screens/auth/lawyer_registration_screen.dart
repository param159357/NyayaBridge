import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/verification_pending_screen.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart'; // 🚀 ADDED FOR IMAGES
import 'package:firebase_storage/firebase_storage.dart'; // 🚀 ADDED FOR UPLOADING
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class LawyerRegistrationScreen extends StatefulWidget {
  const LawyerRegistrationScreen({super.key});

  @override
  State<LawyerRegistrationScreen> createState() => _LawyerRegistrationScreenState();
}

class _LawyerRegistrationScreenState extends State<LawyerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _barNumberController = TextEditingController();
  final TextEditingController _stateBarController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _casesSolvedController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _emergencyFeeController = TextEditingController();

  bool _isLoading = false;

  // 🚀 FEATURE 9: IMAGE VARIABLES
  XFile? _profilePhoto;
  XFile? _barIdPhoto;
  final ImagePicker _picker = ImagePicker();

  String? _selectedLawyerType;
  final List<String> _lawyerTypes = [
    'Criminal Lawyer', 'Civil Lawyer', 'Corporate & Business Lawyer',
    'Family & Divorce Lawyer', 'Property & Real Estate Lawyer',
    'Constitutional Lawyer', 'General Advocate'
  ];

  final List<String> _availableSpecialties = [
    "Police / Arrest", "Physical Violence", "Eviction / Property",
    "Accident / Medical", "Other Emergency"
  ];
  final List<String> _selectedSpecialties = [];

  // 🚀 FEATURE 9: HELPER TO UPLOAD IMAGES TO FIREBASE
  Future<String?> _uploadImage(XFile image, String folder) async {
    try {
      final bytes = await image.readAsBytes(); // Read bytes so it doesn't crash on Web
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('lawyer_verifications/$folder/$fileName');

      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image Upload Error: $e");
      return null;
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    // 🚀 NEW VALIDATIONS FOR PHOTOS
    if (_profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please take a live profile photo.")));
      return;
    }
    if (_barIdPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload your Bar Council ID.")));
      return;
    }
    if (_selectedLawyerType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select your Lawyer Type.")));
      return;
    }
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one emergency specialty.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {

        // 🚀 UPLOAD IMAGES FIRST
        String? profilePicUrl = await _uploadImage(_profilePhoto!, 'profile_photos');
        String? barIdUrl = await _uploadImage(_barIdPhoto!, 'id_cards');

        if (profilePicUrl == null || barIdUrl == null) {
          throw Exception("Failed to securely upload images. Check connection.");
        }

        String uniqueId = 'LWY-${Random().nextInt(9000) + 1000}';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': 'lawyer',
          'uniqueId': uniqueId,
          'phone': user.phoneNumber,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),

          // 🚀 SAVED SECURE IMAGE URLS FOR AVATARS
          'profilePicUrl': profilePicUrl,
          'barIdUrl': barIdUrl,

          'barNumber': _barNumberController.text.trim().toUpperCase(),
          'stateBar': _stateBarController.text.trim(),
          'enrollmentYear': _yearController.text.trim(),
          'city': _cityController.text.trim(),
          'languages': _languagesController.text.trim(),
          'lawyerType': _selectedLawyerType,

          'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
          'casesSolved': int.tryParse(_casesSolvedController.text.trim()) ?? 0,
          'consultationFee': int.tryParse(_feeController.text.trim()) ?? 0,
          'emergencyFee': int.tryParse(_emergencyFeeController.text.trim()) ?? 0,

          'specialties': _selectedSpecialties,
          'isVerified': false, // Admin must check the Bar ID photo!
          'isRejected': false,
          'rejectionReason': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': false,
        });

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VerificationPendingScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Lawyer Verification"), backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox( // Web centering
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Professional Credentials", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // 🚀 FEATURE 9: LIVE SELFIE UPLOAD
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          // Force camera for live verification
                          final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (picked != null) setState(() => _profilePhoto = picked);
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.blue.shade50,
                              backgroundImage: _profilePhoto != null
                                  ? (kIsWeb ? NetworkImage(_profilePhoto!.path) : FileImage(File(_profilePhoto!.path)) as ImageProvider)
                                  : null,
                              child: _profilePhoto == null ? const Icon(Icons.person, size: 60, color: Colors.blue) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(child: Text("Take a Live Professional Selfie", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full Legal Name", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Professional Email", border: OutlineInputBorder()),
                      validator: (v) => v!.contains('@') ? null : "Invalid Email",
                    ),
                    const SizedBox(height: 24),

                    const Text("Bar Registration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // 🚀 FEATURE 9: BAR ID CARD UPLOAD
                    GestureDetector(
                      onTap: () async {
                        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (picked != null) setState(() => _barIdPhoto = picked);
                      },
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _barIdPhoto != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb ? Image.network(_barIdPhoto!.path, fit: BoxFit.cover) : Image.file(File(_barIdPhoto!.path), fit: BoxFit.cover),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                              child: const Icon(Icons.badge, size: 32, color: Colors.blue),
                            ),
                            const SizedBox(height: 12),
                            const Text("Upload Bar Council ID Card", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            const Text("JPEG or PNG format", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _barNumberController,
                      decoration: const InputDecoration(labelText: "Bar Enrollment No.", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stateBarController,
                            decoration: const InputDecoration(labelText: "State Bar", border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Enrollment Year", border: OutlineInputBorder()),
                            validator: (v) => v!.length == 4 ? null : "Invalid Year",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text("Practice & Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedLawyerType,
                      decoration: const InputDecoration(labelText: "Primary Lawyer Type", border: OutlineInputBorder()),
                      items: _lawyerTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _selectedLawyerType = val),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: "Primary City", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _experienceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Years Exp.", border: OutlineInputBorder()),
                            validator: (v) {
                              if (v!.isEmpty) return "Required";
                              if ((int.tryParse(v) ?? 0) < 2) return "Min 2 years req.";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _casesSolvedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Cases Solved", border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _feeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Normal Fee (₹)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emergencyFeeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "SOS Fee (₹)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text("Emergency Radar Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSpecialties.map((specialty) {
                        final isSelected = _selectedSpecialties.contains(specialty);
                        return FilterChip(
                          label: Text(specialty),
                          selected: isSelected,
                          selectedColor: Colors.red.shade100,
                          checkmarkColor: Colors.red.shade900,
                          onSelected: (selected) {
                            setState(() { selected ? _selectedSpecialties.add(specialty) : _selectedSpecialties.remove(specialty); });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        onPressed: _isLoading ? null : _submitApplication,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Submit for Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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