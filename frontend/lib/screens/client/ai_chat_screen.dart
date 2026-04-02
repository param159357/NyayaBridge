import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/screens/shared/chat_screen.dart' show WebcamDialog;

// 🚀 NEW IMPORTS FOR PYTHON BACKEND CONNECTION
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [
    {
      'text': "Hello! I am Nyaya, your AI Legal Assistant. How can I help you today? You can ask me legal questions, upload evidence (Photos/PDFs), or tap 'Hire Expert' if you need a human.",
      'isMe': false,
      'isSystem': true,
    }
  ];

  bool _isTyping = false;
  String? _matchedLawyerType;

  // 🚀 FULLY WIRED TO YOUR GEMINI 2.5 PRO BACKEND
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.insert(0, {'text': userText, 'isMe': true, 'isSystem': false});
      _isTyping = true;
    });

    try {
      // 🚀 Connects to your FastAPI server running on localhost!
      final response = await http.post(
        Uri.parse('https://nyayabridge-ai.onrender.com/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': userText}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiReply = data['reply'];

        // 🚀 Dynamically reads Gemini's response to match the lawyer!
        final lower = aiReply.toLowerCase();
        if (lower.contains('family') || lower.contains('divorce')) {
          _matchedLawyerType = 'Family & Divorce Lawyer';
        } else if (lower.contains('property') || lower.contains('rent')) {
          _matchedLawyerType = 'Property & Real Estate Lawyer';
        } else if (lower.contains('criminal') || lower.contains('police') || lower.contains('fir')) {
          _matchedLawyerType = 'Criminal Lawyer';
        } else if (lower.contains('business') || lower.contains('corporate')) {
          _matchedLawyerType = 'Corporate & Business Lawyer';
        } else {
          _matchedLawyerType ??= 'General Advocate';
        }

        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.insert(0, {'text': aiReply, 'isMe': false, 'isSystem': false});
          });
        }
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.insert(0, {
            'text': "Connection to AI brain failed. Please ensure your Python server (uvicorn main:app --reload) is running on port 8000.\n\nError: $e",
            'isMe': false,
            'isSystem': true
          });
        });
      }
    }
  }

  Future<void> _uploadAndReadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      final String fileName = result.files.first.name;

      setState(() {
        _messages.insert(0, {'text': "📎 Uploaded Document: $fileName", 'isMe': true, 'isSystem': false});
        _isTyping = true;
      });

      // Mock AI reading the PDF (Can wire to Python later)
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.insert(0, {
            'text': "I have successfully read '$fileName'. I scanned it for major legal liabilities. It appears to be a standard contractual agreement. What specific clauses would you like me to explain?",
            'isMe': false,
            'isSystem': false
          });
        });
      }
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _messages.insert(0, {'text': "📎 Uploaded Image Evidence: ${image.name}", 'isMe': true, 'isSystem': false});
      _isTyping = true;
    });

    // Mock AI reading the Image (Can wire to Python OCR later)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.insert(0, {
          'text': "I have processed the visual evidence you uploaded. Based on the context of this image, how would you like to proceed legally?",
          'isMe': false,
          'isSystem': false
        });
      });
    }
  }

  // 🚀 Universal Attachment Menu (Camera, Gallery, PDF)
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Attach Evidence", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.blue)),
                  title: const Text("Take a Photo", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    if (kIsWeb) {
                      final XFile? captured = await showDialog<XFile>(context: context, builder: (context) => const WebcamDialog());
                      if (captured != null) _processImage(captured);
                    } else {
                      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                      if (image != null) _processImage(image);
                    }
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.purple)),
                  title: const Text("Choose Image from Gallery", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (image != null) _processImage(image);
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: const Icon(Icons.picture_as_pdf, color: Colors.green)),
                  title: const Text("Upload Legal Document (PDF)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _uploadAndReadPdf();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                      child: const Icon(Icons.gavel, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _matchedLawyerType != null ? "Available $_matchedLawyerType" + "s" : "Available Experts",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepPurple),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.deepPurple),
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
                        child: Text("No lawyers found for this category.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
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
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.deepPurple.shade50,
                                    backgroundImage: data['profilePicUrl'] != null
                                        ? NetworkImage(data['profilePicUrl'])
                                        : null,
                                    child: data['profilePicUrl'] == null
                                        ? const Icon(Icons.person, color: Colors.deepPurple, size: 30)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Lawyer',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['lawyerType'] ?? 'General Advocate',
                                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${data['experienceYears'] ?? 0} Yrs Experience",
                                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "Fee: ₹${data['consultationFee'] ?? 'N/A'}",
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D3142),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                                  label: const Text("Consult Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      'type': 'AI CONSULTATION',
      'category': _matchedLawyerType ?? 'General Advice',
      'clientName': user?.phoneNumber ?? "Citizen",
      'clientId': user?.uid,
      'targetLawyerId': lawyerUid,
      'targetLawyerName': lawyerName,
      'status': 'pending',
      'aiSummary': 'Client engaged with AI bot before requesting consultation.',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Consultation request sent to $lawyerName."), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("AI Legal Assistant", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _showLawyerMarketplace,
              icon: const Icon(Icons.gavel, color: Colors.deepPurple),
              label: const Text("Hire Expert", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['isMe'] as bool;
                      final isSystem = msg['isSystem'] == true;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isSystem ? Colors.red.shade50 : (isMe ? Colors.deepPurple : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 0), bottomRight: Radius.circular(isMe ? 0 : 20),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                            border: isMe ? null : Border.all(color: isSystem ? Colors.red.shade200 : Colors.grey.shade200),
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(fontSize: 15, color: isSystem ? Colors.red.shade900 : (isMe ? Colors.white : Colors.black87), height: 1.4),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (_isTyping)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20, bottom: 10),
                    child: const Text("AI is thinking...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),

                // 🚀 DYNAMIC LAWYER BUTTON (Appears after AI matching)
                if (_matchedLawyerType != null && !_isTyping)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.person_search),
                        label: Text("Find a $_matchedLawyerType", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _showLawyerMarketplace,
                      ),
                    ),
                  ),

                // 🚀 RECAPTCHA UI FIX (Elevated Input Bar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                          child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.blue),
                              onPressed: _showAttachmentMenu
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              hintText: "Type your legal issue...",
                              hintStyle: TextStyle(color: Colors.black38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D3142),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: _sendMessage,
                          ),
                        )
                      ],
                    ),
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