import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/lawyer/lawyer_edit_profile_screen.dart';
import 'package:frontend/screens/shared/case_history_screen.dart';
import 'package:frontend/screens/shared/chat_screen.dart';
import 'package:frontend/screens/shared/support_tickets_screen.dart';
// 🚀 CHANGED: Now imports the Lawyer's specific AI screen
import 'package:frontend/screens/lawyer/lawyer_ai_chat_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  bool _isOnlineForEmergencies = false;
  bool _isStatusInitialized = false;
  Map<String, dynamic>? _lawyerProfile;

  final AudioPlayer _sirenPlayer = AudioPlayer();
  int _previousSosCount = 0;
  bool _isFirstLoad = true;

  final Set<String> _declinedCaseIds = {};

  @override
  void initState() {
    super.initState();
    _fetchLawyerProfile();
    _setupPushNotifications();
    _sirenPlayer.setPlayerMode(PlayerMode.lowLatency);
    _sirenPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': token});
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          if (mounted) {
            showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(message.notification!.title ?? "New Alert", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                      ),
                    ],
                  ),
                  content: Text(message.notification!.body ?? "You have a new emergency request.", style: const TextStyle(fontSize: 16)),
                  actions: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Acknowledge")
                    )
                  ],
                )
            );
          }
        }
      });
    }
  }

  void _fetchLawyerProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _lawyerProfile = doc.data() as Map<String, dynamic>;
            if (!_isStatusInitialized) {
              _isOnlineForEmergencies = _lawyerProfile!['isOnline'] ?? false;
              _isStatusInitialized = true;
            }
          });
        }
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _sirenPlayer.stop();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  void dispose() {
    _sirenPlayer.dispose();
    super.dispose();
  }

  Future<void> _acceptCase(String caseId, String clientId, String clientName) async {
    try {
      await _sirenPlayer.stop();
      final lawyerId = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('cases').doc(caseId).update({
        'status': 'accepted',
        'lawyerId': lawyerId,
        'acceptedBy': lawyerId,
        'lawyerName': _lawyerProfile!['name'],
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      final lawyerName = _lawyerProfile!['name'] ?? 'Advocate';
      final lawyerPhone = _lawyerProfile!['phone'] ?? FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Number not provided';

      String clientPhone = 'Number not provided';
      if (clientId.isNotEmpty) {
        try {
          final clientDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
          if (clientDoc.exists && clientDoc.data()!.containsKey('phone')) {
            clientPhone = clientDoc.data()!['phone'];
          }
        } catch (e) {
          debugPrint("Could not fetch client phone: $e");
        }
      }

      final messagesRef = FirebaseFirestore.instance.collection('cases').doc(caseId).collection('messages');

      await messagesRef.add({
        'text': '🤖 AUTOMATED SYSTEM: Advocate $lawyerName has accepted the case. Direct Contact: $lawyerPhone',
        'senderId': lawyerId ?? 'lawyer_system',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(milliseconds: 500));

      await messagesRef.add({
        'text': '🤖 AUTOMATED SYSTEM: Client $clientName contact info: $clientPhone',
        'senderId': clientId.isNotEmpty ? clientId : 'client_system',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case Accepted!"), backgroundColor: Colors.green));
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(caseId: caseId, clientName: clientName)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to accept case. It may have been claimed."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lawyerProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final lawyerCity = _lawyerProfile!['city'] ?? '';
    final lawyerSpecialties = List<String>.from(_lawyerProfile!['specialties'] ?? []);
    final int lawyerFee = (_lawyerProfile!['consultationFee'] as num?)?.toInt() ?? 0;
    final int emergencyFee = (_lawyerProfile!['emergencyFee'] as num?)?.toInt() ?? lawyerFee;

    const Color primaryDark = Color(0xFF1E293B);
    const Color bgLight = Color(0xFFF8FAFC);
    const Color onlineGreen = Color(0xFF10B981);
    const Color alertRed = Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0.5,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Advocate Portal", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text(_lawyerProfile!['name'] ?? 'Advocate', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Colors.black45, size: 28),
            onPressed: () {
              _sirenPlayer.stop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportTicketsScreen(role: 'lawyer')));
            },
          ),
          IconButton(
              icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.manage_accounts, color: Colors.blue)),
              onPressed: () {
                _sirenPlayer.stop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerEditProfileScreen()));
              }
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black45),
            onPressed: () => _logout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _isOnlineForEmergencies ? onlineGreen.withOpacity(0.5) : Colors.grey.shade200, width: 2),
                          boxShadow: [BoxShadow(color: _isOnlineForEmergencies ? onlineGreen.withOpacity(0.15) : Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                  height: 16, width: 16,
                                  decoration: BoxDecoration(
                                      color: _isOnlineForEmergencies ? onlineGreen : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: _isOnlineForEmergencies ? [BoxShadow(color: onlineGreen.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)] : []
                                  )
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Duty Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primaryDark)),
                                  const SizedBox(height: 4),
                                  Text(_isOnlineForEmergencies ? "Receiving SOS Alerts" : "Currently Offline", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnlineForEmergencies,
                            activeColor: Colors.white,
                            activeTrackColor: onlineGreen,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.grey.shade300,
                            onChanged: (value) async {
                              if (!value) await _sirenPlayer.stop();

                              setState(() => _isOnlineForEmergencies = value);

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': value});
                              }

                              String safeCity = lawyerCity.toLowerCase().replaceAll(' ', '_').replaceAll('/', '');
                              if (value) {
                                await FirebaseMessaging.instance.subscribeToTopic('sos_$safeCity');
                              } else {
                                await FirebaseMessaging.instance.unsubscribeFromTopic('sos_$safeCity');
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(value ? "You are ONLINE and receiving SOS Push Alerts." : "You are now OFFLINE."),
                                        backgroundColor: value ? onlineGreen : Colors.grey.shade800
                                    )
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Row(children: [Icon(Icons.radar, color: alertRed, size: 24), SizedBox(width: 10), Text("Live Emergency Radar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark))]),
                    const SizedBox(height: 16),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('cases').where('status', isEqualTo: 'searching').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          _sirenPlayer.stop();
                          _previousSosCount = 0;
                          _isFirstLoad = false;
                          return Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200, width: 2, style: BorderStyle.solid)),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16),
                                Text("Area Secure", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)), const SizedBox(height: 4),
                                Text("No active SOS cases in your jurisdiction.", style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          );
                        }

                        final filteredDocs = snapshot.data!.docs.where((doc) {
                          if (!_isOnlineForEmergencies) return false;
                          if (_declinedCaseIds.contains(doc.id)) return false;

                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp = data['timestamp'] as Timestamp?;
                          if (timestamp != null) {
                            final difference = DateTime.now().difference(timestamp.toDate());
                            if (difference.inMinutes > 10) return false;
                          }

                          final caseCity = (data['city'] ?? '').toString().trim().toLowerCase();
                          final myCitySafe = lawyerCity.trim().toLowerCase();
                          final caseCategory = data['category'] ?? '';
                          final int? caseMaxFee = (data['maxFee'] as num?)?.toInt();

                          if (caseCity != myCitySafe) return false;
                          if (!lawyerSpecialties.contains(caseCategory)) return false;
                          if (caseMaxFee != null && emergencyFee > caseMaxFee) return false;
                          return true;
                        }).toList();

                        final currentSosCount = filteredDocs.length;

                        if (currentSosCount == 0) {
                          _sirenPlayer.stop();
                        } else if (!_isFirstLoad && currentSosCount > _previousSosCount && _isOnlineForEmergencies) {
                          _sirenPlayer.play(AssetSource('audio/siren.mp3'));
                        }

                        _previousSosCount = currentSosCount;
                        _isFirstLoad = false;

                        filteredDocs.sort((a, b) {
                          final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                          final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                          if (tA == null || tB == null) return 0;
                          return tB.compareTo(tA);
                        });

                        if (filteredDocs.isEmpty) {
                          return Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(children: [Icon(Icons.search_off, size: 50, color: Colors.grey.shade300), const SizedBox(height: 12), Text("No cases match your specialty.", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600))]),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: alertRed.withOpacity(0.5), width: 2),
                                  boxShadow: [BoxShadow(color: alertRed.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: alertRed, borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text("ACTIVE SOS", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5))])),
                                      Text("Just now", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(data['clientName'] ?? 'Anonymous Client', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: primaryDark)),
                                  const SizedBox(height: 6),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on, color: Colors.red.shade700, size: 18), const SizedBox(width: 6),
                                      Expanded(child: Text(data['location'] ?? data['city'] ?? 'Location not provided', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 15))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text("Budget: ${data['maxFee'] != null ? 'Up to ₹${data['maxFee']}' : 'Not Specified'}", style: const TextStyle(color: onlineGreen, fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 12),

                                  if (data['audioUrl'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.mic, color: Colors.orange), const SizedBox(width: 8),
                                          const Expanded(child: Text("Voice Evidence Attached", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
                                          SosAudioPlayerWidget(audioUrl: data['audioUrl'])
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  Container(
                                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                    child: Text(data['aiSummary'] ?? 'No summary provided.', style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontWeight: FontWeight.w500)),
                                  ),
                                  const SizedBox(height: 20),

                                  Row(
                                    children: [
                                      Expanded(flex: 1, child: SizedBox(height: 50, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600, side: BorderSide(color: Colors.grey.shade300, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { setState(() { _declinedCaseIds.add(doc.id); }); }, child: const Text("DECLINE", style: TextStyle(fontWeight: FontWeight.w800))))),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 2, child: SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: alertRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5, shadowColor: alertRed.withOpacity(0.5)), onPressed: () { _acceptCase(doc.id, data['clientId'] ?? '', data['clientName'] ?? 'Anonymous Client'); }, child: const Text("ACCEPT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))))),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Cases", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark)),
                        TextButton(onPressed: () { _sirenPlayer.stop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const CaseHistoryScreen(role: 'lawyer'))); }, child: const Text("View All", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)))
                      ],
                    ),
                    const SizedBox(height: 12),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('cases').where('lawyerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("No active cases right now.", style: TextStyle(color: Colors.grey.shade500)));

                        var activeDocs = snapshot.data!.docs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return data['status'] == 'accepted' || data['status'] == 'pending';
                        }).toList();

                        activeDocs.sort((a, b) {
                          var tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                          var tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                          if (tA == null || tB == null) return 0;
                          return tB.compareTo(tA);
                        });

                        var previewDocs = activeDocs.take(2).toList();
                        if (previewDocs.isEmpty) return Center(child: Text("No ongoing chats. Tap 'View All' for history.", style: TextStyle(color: Colors.grey.shade500)));

                        return ListView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: previewDocs.length,
                          itemBuilder: (context, index) {
                            final doc = previewDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final clientName = data['clientName'] ?? 'Client';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.blue)),
                                title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text(data['category'] ?? 'General Case', style: TextStyle(color: Colors.grey.shade600)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                onTap: () { _sirenPlayer.stop(); Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(caseId: doc.id, clientName: clientName))); },
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),

                    const Text("Tools & Resources", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark)),
                    const SizedBox(height: 16),

                    GestureDetector(
                      // 🚀 CHANGED: This button now explicitly routes to the LawyerAiChatScreen
                      onTap: () { _sirenPlayer.stop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerAiChatScreen())); },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFFE94057).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28)),
                            const SizedBox(width: 16),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("AI Legal Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), SizedBox(height: 4), Text("Quickly lookup IPC sections or verify case laws.", style: TextStyle(color: Colors.white70, fontSize: 13))])),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
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

class SosAudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const SosAudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<SosAudioPlayerWidget> createState() => _SosAudioPlayerWidgetState();
}

class _SosAudioPlayerWidgetState extends State<SosAudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(backgroundColor: Colors.orange.shade100),
      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.deepOrange),
      label: Text(_isPlaying ? "STOP" : "PLAY", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
      onPressed: () {
        if (_isPlaying) {
          _player.stop();
        } else {
          _player.play(UrlSource(widget.audioUrl));
        }
      },
    );
  }
}
