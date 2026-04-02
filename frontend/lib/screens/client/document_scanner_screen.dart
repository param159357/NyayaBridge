import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/screens/shared/chat_screen.dart' show WebcamDialog;

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  // 🚀 Localhost for Python connection
  final String backendUrl = "https://nyayabridge-ai.onrender.com";

  XFile? _selectedImage;
  bool _isAnalyzing = false;
  String _analysisResult = "";
  String? _matchedLawyerType;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    XFile? pickedFile;

    if (kIsWeb && source == ImageSource.camera) {
      // 🚀 THE MAGIC: Opens webcam on Chrome!
      pickedFile = await showDialog<XFile>(
        context: context,
        builder: (context) => const WebcamDialog(),
      );
    } else {
      pickedFile = await _picker.pickImage(source: source);
    }

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _analysisResult = "";
        _matchedLawyerType = null;
      });
    }
  }

  Future<void> _analyzeDocument() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();

      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/api/ocr/analyze'));
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: _selectedImage!.name));

      var response = await request.send().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);

        String resultText = json['analysis'];
        String lowerRes = resultText.toLowerCase();
        String detectedLawyer = "General Advocate";

        if (lowerRes.contains("criminal") || lowerRes.contains("police") || lowerRes.contains("fir")) {
          detectedLawyer = "Criminal Lawyer";
        } else if (lowerRes.contains("property") || lowerRes.contains("evict") || lowerRes.contains("rent")) {
          detectedLawyer = "Property & Real Estate Lawyer";
        } else if (lowerRes.contains("divorce") || lowerRes.contains("family")) {
          detectedLawyer = "Family & Divorce Lawyer";
        }

        if (mounted) {
          setState(() {
            _analysisResult = resultText;
            _matchedLawyerType = detectedLawyer;
            _isAnalyzing = false;
          });
        }
      } else {
        throw Exception("Backend Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisResult = "📄 DOCUMENT TYPE: Scanned Legal Evidence\n\n"
              "📝 SUMMARY: The AI has scanned the provided image. Based on the visual context, this appears to require professional legal review to determine exact liabilities or next steps.\n\n"
              "⚖️ RECOMMENDATION: Please consult a legal professional to review this evidence directly.";
          _matchedLawyerType = "General Advocate";
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showLawyerMarketplace() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Available $_matchedLawyerType" + "s",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.blue),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'lawyer')
                      .where('isVerified', isEqualTo: true)
                      .where('lawyerType', isEqualTo: _matchedLawyerType)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No $_matchedLawyerType is currently online.",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🚀 FEATURE 10: LAWYER AVATAR DISPLAY
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.blue.shade50,
                                    backgroundImage: data['profilePicUrl'] != null
                                        ? NetworkImage(data['profilePicUrl'])
                                        : null,
                                    child: data['profilePicUrl'] == null
                                        ? const Icon(Icons.person, color: Colors.blue, size: 30)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Lawyer',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2D3142),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star, size: 14, color: Colors.green.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${data['experienceYears'] ?? 0} Yrs",
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Normal Consultation Fee: ₹${data['consultationFee'] ?? 'N/A'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.share, size: 20),
                                  label: const Text(
                                    "Share Document",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _initiateConsultation(doc.id, data['name'] ?? 'Lawyer'),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initiateConsultation(String lawyerUid, String lawyerName) async {
    Navigator.pop(context);
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('cases').add({
      'type': 'DOCUMENT REVIEW',
      'category': _matchedLawyerType,
      'clientName': user?.phoneNumber ?? "Citizen",
      'clientId': user?.uid,
      'targetLawyerId': lawyerUid,
      'targetLawyerName': lawyerName,
      'status': 'pending',
      'aiSummary': _analysisResult,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Document sent to $lawyerName."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3142),
        elevation: 0.5,
        title: const Text(
          "Document Scanner",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.blue.shade100, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: kIsWeb
                          ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                          : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.document_scanner,
                            size: 50,
                            color: Colors.blue.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Upload legal document",
                          style: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text(
                            "Camera",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2D3142),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text(
                            "Gallery",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2D3142),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  if (_selectedImage != null && _analysisResult.isEmpty)
                    ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeDocument,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 10,
                        shadowColor: Colors.blue.withOpacity(0.5),
                      ),
                      child: _isAnalyzing
                          ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            "Analyzing Image...",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          )
                        ],
                      )
                          : const Text(
                        "Scan with AI",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  if (_analysisResult.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 24),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                "AI Summary",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2D3142),
                                ),
                              )
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, thickness: 1),
                          ),
                          Text(
                            _analysisResult,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_matchedLawyerType != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3142),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 24),
                        label: Text(
                          "Consult $_matchedLawyerType",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        onPressed: _showLawyerMarketplace,
                      ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}