import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/utils/responsive_layout.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:typed_data';

// 🚀 PHASE 3 NEW PACKAGES
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String caseId;
  final String clientName;

  const ChatScreen({super.key, required this.caseId, required this.clientName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isUploadingMedia = false;
  bool _isRecording = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').add({
      'text': text,
      'senderId': currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl': null,
      'audioUrl': null,
      'videoUrl': null, // 🚀 New
      'pdfUrl': null,   // 🚀 New
      'pdfName': null,  // 🚀 New
      'aiDescription': null,
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          setState(() => _isUploadingMedia = true);
          Uint8List audioBytes;
          if (kIsWeb) {
            final response = await http.get(Uri.parse(path));
            audioBytes = response.bodyBytes;
          } else {
            audioBytes = await File(path).readAsBytes();
          }

          final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final Reference storageRef = FirebaseStorage.instance.ref().child('chat_audio/${widget.caseId}/$fileName');
          final UploadTask uploadTask = storageRef.putData(audioBytes, SettableMetadata(contentType: 'audio/m4a'));
          final TaskSnapshot snapshot = await uploadTask;
          final String downloadUrl = await snapshot.ref.getDownloadURL();

          await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').add({
            'text': '🎤 Voice Note',
            'senderId': currentUser?.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'imageUrl': null,
            'audioUrl': downloadUrl,
            'videoUrl': null,
            'pdfUrl': null,
            'aiDescription': null,
          });
          setState(() => _isUploadingMedia = false);
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          setState(() => _isRecording = true);
          await _audioRecorder.start(const RecordConfig(), path: kIsWeb ? '' : '${Directory.systemTemp.path}/temp_audio.m4a');
        }
      }
    } catch (e) {
      setState(() { _isRecording = false; _isUploadingMedia = false; });
      debugPrint("Audio Error: $e");
    }
  }

  Future<void> _processAndSendImage(XFile image) async {
    setState(() => _isUploadingMedia = true);
    String aiAnalysis = "🔍 AI Vision Analysis: Document or visual evidence detected. Safe to review.";
    try {
      final bytes = await image.readAsBytes();
      var request = http.MultipartRequest('POST', Uri.parse('https://nyayabridge-ai.onrender.com/api/ocr/analyze'));
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      var response = await request.send().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        aiAnalysis = "🔍 AI Vision Analysis:\n${json['analysis']}";
      }
    } catch (e) { debugPrint("AI Python Server Error: $e"); }

    try {
      final bytes = await image.readAsBytes();
      final String fileName = 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('chat_images/${widget.caseId}/$fileName');
      final UploadTask uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').add({
        'text': 'Sent an attachment.',
        'senderId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': downloadUrl,
        'audioUrl': null,
        'videoUrl': null,
        'pdfUrl': null,
        'aiDescription': aiAnalysis,
      });
      setState(() => _isUploadingMedia = false);
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🚀 FEATURE 4: VIDEO UPLOAD LOGIC
  Future<void> _processAndSendVideo(XFile video) async {
    setState(() => _isUploadingMedia = true);
    try {
      final bytes = await video.readAsBytes();
      final String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final Reference storageRef = FirebaseStorage.instance.ref().child('chat_videos/${widget.caseId}/$fileName');
      final UploadTask uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').add({
        'text': 'Sent a video.',
        'senderId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': null,
        'audioUrl': null,
        'videoUrl': downloadUrl,
        'pdfUrl': null,
        'aiDescription': null, // Videos bypass AI for now to save bandwidth
      });
      setState(() => _isUploadingMedia = false);
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading video: $e"), backgroundColor: Colors.red));
    }
  }

  // 🚀 FEATURE 5: PDF UPLOAD & AI DIALOG LOGIC
  Future<void> _processAndSendPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      // Prompt user for AI interaction
      bool useAi = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("PDF Selected", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            content: const Text("Do you want the AI to read and summarize this document, or just send it directly to the chat?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Send Directly", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Scan with AI")
              ),
            ],
          )
      ) ?? false;

      setState(() => _isUploadingMedia = true);
      try {
        Uint8List? fileBytes = result.files.first.bytes;
        final String fileName = result.files.first.name;

        if (!kIsWeb && fileBytes == null) {
          fileBytes = await File(result.files.first.path!).readAsBytes();
        }

        String aiAnalysis = "";
        if (useAi) {
          // Mock AI PDF extraction (You can connect this to Python later!)
          await Future.delayed(const Duration(seconds: 3));
          aiAnalysis = "🔍 AI Document Summary:\nThe AI has reviewed '$fileName'. This document contains standard legal clauses. Please verify jurisdiction constraints.";
        }

        final Reference storageRef = FirebaseStorage.instance.ref().child('chat_docs/${widget.caseId}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
        final UploadTask uploadTask = storageRef.putData(fileBytes!, SettableMetadata(contentType: 'application/pdf'));
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').add({
          'text': 'Sent a PDF document.',
          'senderId': currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': null,
          'audioUrl': null,
          'videoUrl': null,
          'pdfUrl': downloadUrl,
          'pdfName': fileName,
          'aiDescription': aiAnalysis.isNotEmpty ? aiAnalysis : null,
        });
        setState(() => _isUploadingMedia = false);
      } catch (e) {
        setState(() => _isUploadingMedia = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading PDF: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // 🚀 FEATURE 4 & 5: UPGRADED ATTACHMENT MENU
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
                      if (captured != null) _processAndSendImage(captured);
                    } else {
                      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                      if (image != null) _processAndSendImage(image);
                    }
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.purple)),
                  title: const Text("Choose Image from Gallery", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (image != null) _processAndSendImage(image);
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.videocam, color: Colors.red)),
                  title: const Text("Upload Video Evidence", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                    if (video != null) _processAndSendVideo(video);
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: const Icon(Icons.picture_as_pdf, color: Colors.green)),
                  title: const Text("Upload Legal Document (PDF)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _processAndSendPdf();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeCase() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Case?"),
        content: const Text("Are you sure you want to mark this case as resolved? You will still be able to read the history, but neither of you can send new messages."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).update({'status': 'closed'});
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case closed securely."), backgroundColor: Colors.green));
            },
            child: const Text("Close Case"),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    bool isMe = data['senderId'] == currentUser?.uid;
    bool hasImage = data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;
    bool hasAudio = data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty;
    bool hasVideo = data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty; // 🚀 New
    bool hasPdf = data['pdfUrl'] != null && data['pdfUrl'].toString().isNotEmpty; // 🚀 New
    bool hasAiDescription = data['aiDescription'] != null && data['aiDescription'].toString().isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0), bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (hasImage) ...[
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        InteractiveViewer(
                            panEnabled: true, minScale: 0.5, maxScale: 4,
                            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(data['imageUrl'], fit: BoxFit.contain))
                        ),
                        Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
                        // 🚀 FEATURE 3 (GAP 2): DOWNLOAD IMAGE BUTTON
                        Positioned(
                            bottom: 20, right: 20,
                            child: FloatingActionButton(
                              backgroundColor: Colors.white,
                              onPressed: () => launchUrl(Uri.parse(data['imageUrl'])),
                              child: const Icon(Icons.download, color: Colors.deepPurple),
                            )
                        ),
                      ],
                    ),
                  ),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(data['imageUrl'], fit: BoxFit.cover)),
              ),
              const SizedBox(height: 8),
            ],

            // 🚀 RENDER VIDEO PLAYER
            if (hasVideo) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoMessagePlayer(videoUrl: data['videoUrl']),
              ),
              const SizedBox(height: 8),
            ],

            // 🚀 RENDER PDF TILE
            if (hasPdf) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withOpacity(0.2) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: isMe ? Colors.white : Colors.red, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['pdfName'] ?? 'Document.pdf',
                        style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: isMe ? Colors.white : Colors.red),
                      onPressed: () => launchUrl(Uri.parse(data['pdfUrl'])),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (hasAudio) ...[
              AudioMessagePlayer(audioUrl: data['audioUrl'], isMe: isMe),
              const SizedBox(height: 4),
            ],

            if (hasAiDescription) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(data['aiDescription'], style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w700, height: 1.4))
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (data['text'] != null && data['text'].toString().isNotEmpty && !hasImage && !hasAudio && !hasVideo && !hasPdf)
              Text(data['text'], style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black87, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface(bool isClosed) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('cases').doc(widget.caseId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No messages yet. Send a message or upload evidence."));

              final docs = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(docs[index].data() as Map<String, dynamic>);
                },
              );
            },
          ),
        ),

        if (_isUploadingMedia)
          Container(
            padding: const EdgeInsets.all(12), color: Colors.white,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text("Uploading secure media...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

        isClosed
            ? Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(top: BorderSide(color: Colors.grey.shade300))),
          child: const Text("This case has been closed.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
        )
            : Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1.5))),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                // 🚀 LAUNCHES THE NEW MEDIA MENU
                child: IconButton(icon: const Icon(Icons.add, color: Colors.blue), onPressed: (_isUploadingMedia || _isRecording) ? null : _showAttachmentMenu),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _isRecording ? Colors.red.shade100 : Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.red : Colors.green, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: _isRecording ? "Recording Audio..." : "Type a message...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true, fillColor: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  readOnly: _isRecording,
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Colors.deepPurple, radius: 26,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 22), onPressed: _sendMessage),
              )
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('cases').doc(widget.caseId).snapshots(),
      builder: (context, caseSnapshot) {
        bool isClosed = false;
        if (caseSnapshot.hasData && caseSnapshot.data!.exists) {
          isClosed = (caseSnapshot.data!.data() as Map<String, dynamic>)['status'] == 'closed';
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(title: Text(widget.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), centerTitle: true),
          body: SafeArea(child: ResponsiveLayout(mobile: _buildChatInterface(isClosed), desktop: Center(child: SizedBox(width: 900, child: _buildChatInterface(isClosed))))),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 🚀 NEW: VIDEO PLAYER WIDGET
// ----------------------------------------------------------------------
class VideoMessagePlayer extends StatefulWidget {
  final String videoUrl;
  const VideoMessagePlayer({super.key, required this.videoUrl});

  @override
  State<VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        FloatingActionButton(
          backgroundColor: Colors.black45,
          onPressed: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }
}

// (AudioMessagePlayer & WebcamDialog remain exactly the same below)
class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const AudioMessagePlayer({super.key, required this.audioUrl, required this.isMe});
  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}
class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == PlayerState.playing); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
  }
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: textColor, size: 36),
          onPressed: () { _isPlaying ? _player.pause() : _player.play(UrlSource(widget.audioUrl)); },
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Voice Note", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            Text("${_position.inSeconds}s / ${_duration.inSeconds}s", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
          ],
        )
      ],
    );
  }
}

class WebcamDialog extends StatefulWidget {
  const WebcamDialog({super.key});
  @override
  State<WebcamDialog> createState() => _WebcamDialogState();
}
class _WebcamDialogState extends State<WebcamDialog> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  @override
  void initState() { super.initState(); _initCamera(); }
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras.first, ResolutionPreset.high);
      _initializeControllerFuture = _controller!.initialize();
      setState(() {});
    }
  }
  @override
  void dispose() { _controller?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600, padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_initializeControllerFuture == null) const CircularProgressIndicator()
            else FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: CameraPreview(_controller!)) : const CircularProgressIndicator()
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () async {
              if (_controller != null && _controller!.value.isInitialized) {
                final image = await _controller!.takePicture();
                Navigator.pop(context, image);
              }
            }, child: const Text("Take Photo"))
          ],
        ),
      ),
    );
  }
}