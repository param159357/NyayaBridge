import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:frontend/screens/shared/chat_screen.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SosRadarScreen extends StatefulWidget {
  const SosRadarScreen({super.key});

  @override
  State<SosRadarScreen> createState() => _SosRadarScreenState();
}

class _SosRadarScreenState extends State<SosRadarScreen> with WidgetsBindingObserver {
  bool _isBroadcasting = false;
  bool _isAnalyzingAI = false;
  StreamSubscription<DocumentSnapshot>? _caseSubscription;
  Timer? _timeoutTimer;

  String _selectedCategory = "Police / Arrest";
  String _userCity = "Unknown City";
  String _userName = "Distressed Citizen";

  final TextEditingController _otherEmergencyController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _currentActiveCaseId;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingSOS = false;
  String? _recordedAudioPath;

  // 🚀 NOTIFICATION VARIABLES
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final List<String> _categories = [
    "Police / Arrest",
    "Physical Violence",
    "Eviction / Property",
    "Accident / Medical",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _fetchUserDetails();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  void _initNotifications() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _showNativeNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sos_emergency_channel',
      'SOS Alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SOS Accepted',
      playSound: true,
      enableVibration: true,
      color: Colors.red,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '🚨 Advocate Found!',
      'A lawyer has accepted your SOS. Tap to open the secure chat.',
      platformChannelSpecifics,
    );
  }

  Future<void> _fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userCity = data['city'] ?? "Unknown City";
            _cityController.text = _userCity;
            _userName = data['name'] ?? user.phoneNumber ?? "Citizen";
          });
        }
      }
    }
  }

  Future<void> _cancelSearch({bool timeout = false}) async {
    _timeoutTimer?.cancel();
    _caseSubscription?.cancel();

    if (_currentActiveCaseId != null) {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(_currentActiveCaseId)
          .update({'status': timeout ? 'timeout' : 'cancelled'});
      _currentActiveCaseId = null;
    }

    if (mounted) {
      setState(() {
        _isBroadcasting = false;
        _recordedAudioPath = null;
      });
      if (timeout) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("SOS Timeout: No lawyers available.", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red
            )
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelSearch();
    _audioRecorder.dispose();
    _otherEmergencyController.dispose();
    _feeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _toggleAudioRecording() async {
    if (_isRecordingSOS) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecordingSOS = false;
        _recordedAudioPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice Evidence Attached!"), backgroundColor: Colors.green)
      );
    } else {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecordingSOS = true;
          _recordedAudioPath = null;
        });
        await _audioRecorder.start(
            const RecordConfig(),
            path: kIsWeb ? '' : '${Directory.systemTemp.path}/sos_temp.m4a'
        );
      }
    }
  }

  Future<void> _triggerEmergency() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide your exact address or landmark.")));
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide the city or district.")));
      return;
    }

    String finalCategory = _selectedCategory;
    String activeCity = _cityController.text.trim();
    String finalSummary = 'URGENT: Client triggered a $_selectedCategory SOS alert.';

    setState(() => _isBroadcasting = true);

    try {
      String? uploadedAudioUrl;
      if (_recordedAudioPath != null) {
        Uint8List audioBytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(_recordedAudioPath!));
          audioBytes = response.bodyBytes;
        } else {
          audioBytes = await File(_recordedAudioPath!).readAsBytes();
        }
        final String fileName = 'sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final Reference storageRef = FirebaseStorage.instance.ref().child('sos_audio/$fileName');

        final UploadTask uploadTask = storageRef.putData(audioBytes, SettableMetadata(contentType: 'audio/m4a'));
        final TaskSnapshot snapshot = await uploadTask;
        uploadedAudioUrl = await snapshot.ref.getDownloadURL();
      }

      final docRef = await FirebaseFirestore.instance.collection('cases').add({
        'type': 'EMERGENCY SOS',
        'category': finalCategory,
        'city': activeCity,
        'clientName': _userName,
        'clientId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'maxFee': int.tryParse(_feeController.text.trim()),
        'aiSummary': finalSummary,
        'location': _addressController.text.trim(),
        'audioUrl': uploadedAudioUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'searching',
      });

      _currentActiveCaseId = docRef.id;

      // 🚀 PYTHON PUSH NOTIFICATION TRIGGER (Replace with your actual IPv4 address from IPConfig)
      try {
        await http.post(
          Uri.parse('https://nyayabridge-ai.onrender.com/api/broadcast-sos'), // e.g., http://192.168.1.5:8000/api/broadcast-sos
          headers: {'Content-Type': 'application/json'},
          body: '{"city": "$activeCity", "category": "$finalCategory"}',
        );
      } catch (e) {
        debugPrint("Push notification broadcast failed: $e");
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("🚨 BROADCASTING to $finalCategory Lawyers in $activeCity!", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green
        ),
      );

      _timeoutTimer = Timer(const Duration(minutes: 10), () => _cancelSearch(timeout: true));

      _caseSubscription = docRef.snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == 'accepted') {
            _timeoutTimer?.cancel();
            _caseSubscription?.cancel();
            _currentActiveCaseId = null;

            if (_appLifecycleState != AppLifecycleState.resumed && !kIsWeb) {
              await _showNativeNotification();
            }

            if (mounted) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(caseId: docRef.id, clientName: "Assigned Lawyer"))
              );
            }
          }
        }
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network Error: $e")));
      setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (_isBroadcasting || _isAnalyzingAI) {
          await _cancelSearch(timeout: false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: const Text("Emergency Radar", style: TextStyle(fontWeight: FontWeight.w800))
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isAnalyzingAI ? "AI is analyzing..." : _isBroadcasting ? "Broadcasting SOS..." : "What is your emergency?",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  if (!_isBroadcasting && !_isAnalyzingAI) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.red.shade600 : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isSelected ? Colors.red.shade400 : Colors.transparent, width: 2),
                            ),
                            child: Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    TextField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                            labelText: "Exact Address / Landmark",
                            labelStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                        )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _cityController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                            labelText: "District",
                            labelStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.location_city, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                        )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                            labelText: "Max Affordable Fee (₹)",
                            labelStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                        )
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _toggleAudioRecording,
                      icon: Icon(_isRecordingSOS ? Icons.stop_circle : (_recordedAudioPath != null ? Icons.check_circle : Icons.mic)),
                      label: Text(_isRecordingSOS ? "Stop Recording" : (_recordedAudioPath != null ? "Voice Attached! Tap to rerecord." : "Add Voice Evidence (Optional)")),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecordingSOS ? Colors.red.shade800 : (_recordedAudioPath != null ? Colors.green.shade800 : Colors.blueGrey.shade800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                    )
                  ],

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: (_isBroadcasting || _isAnalyzingAI) ? null : _triggerEmergency,
                    child: TweenAnimationBuilder(
                        tween: Tween<double>(begin: 1.0, end: (_isBroadcasting || _isAnalyzingAI) ? 1.2 : 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              height: 220, width: 220,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [(_isBroadcasting || _isAnalyzingAI) ? Colors.red.shade600 : Colors.red.shade500, (_isBroadcasting || _isAnalyzingAI) ? Colors.red.shade900 : Colors.red.shade800]),
                                  boxShadow: [BoxShadow(color: Colors.red.withOpacity((_isBroadcasting || _isAnalyzingAI) ? 0.8 : 0.3), blurRadius: (_isBroadcasting || _isAnalyzingAI) ? 50 : 20, spreadRadius: (_isBroadcasting || _isAnalyzingAI) ? 15 : 5)]
                              ),
                              child: Center(
                                child: _isAnalyzingAI
                                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                    : Text(_isBroadcasting ? "SEARCHING\n..." : "TAP FOR\nSOS", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
                              ),
                            ),
                          );
                        }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}