import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/screens/shared/chat_screen.dart' show WebcamDialog;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LawyerAiChatScreen extends StatefulWidget {
  const LawyerAiChatScreen({super.key});

  @override
  State<LawyerAiChatScreen> createState() => _LawyerAiChatScreenState();
}

class _LawyerAiChatScreenState extends State<LawyerAiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  late final List<Map<String, dynamic>> _messages = [
    {
      'text': "Hello Counsel! I am your AI Legal Assistant. You can ask me to draft notices, research IPC/BNS sections, or analyze case files and legal documents.",
      'isMe': false,
      'isSystem': true,
    }
  ];

  bool _isTyping = false;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.insert(0, {'text': userText, 'isMe': true, 'isSystem': false});
      _isTyping = true;
    });

    try {
      // ⚠️ IMPORTANT: Replace 127.0.0.1 with your laptop's Wi-Fi IPv4 address!
      final response = await http.post(
        Uri.parse('https://nyayabridge-ai.onrender.com/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': userText}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiReply = data['reply'];

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
            'text': "Connection to AI brain failed. Please ensure your Python server is running.\n\nError: $e",
            'isMe': false,
            'isSystem': true
          });
        });
      }
    }
  }

  Future<void> _uploadAndReadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf']
    );

    if (result != null) {
      final String fileName = result.files.first.name;

      setState(() {
        _messages.insert(0, {'text': "📎 Uploaded Case File: $fileName", 'isMe': true, 'isSystem': false});
        _isTyping = true;
      });

      // Simulate backend processing time
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.insert(0, {
            'text': "I have successfully processed '$fileName'. I have scanned it for key liabilities and arguments. What specific sections would you like me to summarize or cross-reference?",
            'isMe': false,
            'isSystem': false
          });
        });
      }
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _messages.insert(0, {'text': "📎 Uploaded Visual Evidence: ${image.name}", 'isMe': true, 'isSystem': false});
      _isTyping = true;
    });

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.insert(0, {
          'text': "I have processed the visual evidence. How would you like me to analyze this for your case?",
          'isMe': false,
          'isSystem': false
        });
      });
    }
  }

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
                const Text(
                    "Attach Case Files",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.blue)
                  ),
                  title: const Text("Scan Document (Camera)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                  leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.photo_library, color: Colors.purple)
                  ),
                  title: const Text("Upload Image Evidence", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (image != null) _processImage(image);
                  },
                ),
                ListTile(
                  leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.green)
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Counsel AI Assistant", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade900,
        foregroundColor: Colors.white,
        elevation: 1,
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
                            color: isSystem ? Colors.blueGrey.shade50 : (isMe ? Colors.deepPurple.shade700 : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                            ],
                            border: isMe ? null : Border.all(color: isSystem ? Colors.blueGrey.shade200 : Colors.grey.shade200),
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(
                                fontSize: 15,
                                color: isSystem ? Colors.blueGrey.shade900 : (isMe ? Colors.white : Colors.black87),
                                height: 1.4
                            ),
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
                    child: const Text("AI is researching...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),

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
                          decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                          child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.deepPurple),
                              onPressed: _showAttachmentMenu
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              hintText: "Ask a legal question...",
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
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade700,
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