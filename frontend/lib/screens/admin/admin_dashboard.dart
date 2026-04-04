import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/shared/chat_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen())
    );
  }

  Future<void> _approveLawyer(BuildContext context, String docId, String lawyerName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isVerified': true,
        'isRejected': false,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$lawyerName approved!"), backgroundColor: Colors.green)
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _showRejectDialog(BuildContext context, String docId, String lawyerName) async {
    final TextEditingController reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            "Reject $lawyerName",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Enter reason (e.g., 'Invalid Bar Number')",
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;

              await FirebaseFirestore.instance.collection('users').doc(docId).update({
                'isRejected': true,
                'rejectionReason': reasonController.text.trim(),
              });

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$lawyerName rejected."), backgroundColor: Colors.red)
              );
            },
            child: const Text("Confirm Rejection", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(BuildContext context, String docId, Map<String, dynamic> currentData) async {
    final TextEditingController nameController = TextEditingController(text: currentData['name'] ?? '');
    final TextEditingController cityController = TextEditingController(text: currentData['city'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: currentData['phone'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
            "Edit User Record",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(nameController, "Full Name"),
              const SizedBox(height: 12),
              _buildDialogTextField(cityController, "City"),
              const SizedBox(height: 12),
              _buildDialogTextField(phoneController, "Phone Number"),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A3AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).update({
                'name': nameController.text.trim(),
                'city': cityController.text.trim(),
                'phone': phoneController.text.trim(),
              });

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User updated successfully!"), backgroundColor: Colors.green)
              );
            },
            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 13)
              )
          ),
          Expanded(
              child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3142), fontSize: 14)
              )
          ),
        ],
      ),
    );
  }

  // 🚀 FIX 4: HELPER WIDGET FOR IMAGE ZOOMING
  Widget _buildImageThumbnail(BuildContext context, String title, String? url) {
    if (url == null || url.isEmpty) return const SizedBox();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveViewer(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(url, fit: BoxFit.contain)
                        )
                    ),
                    Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(ctx)
                        )
                    ),
                  ],
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                  url,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, userSnap) {
          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cases').snapshots(),
              builder: (context, caseSnap) {
                if (userSnap.connectionState == ConnectionState.waiting || caseSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                int totalUsers = 0;
                int totalLawyers = 0;
                int pendingLawyers = 0;

                for(var doc in userSnap.data?.docs ?? []) {
                  final d = doc.data() as Map<String, dynamic>;
                  if(d['role'] == 'client') totalUsers++;
                  if(d['role'] == 'lawyer') {
                    totalLawyers++;
                    if(d['isVerified'] == false && d['isRejected'] != true) {
                      pendingLawyers++;
                    }
                  }
                }

                int totalSOS = 0;
                int totalMatches = 0;
                for(var doc in caseSnap.data?.docs ?? []) {
                  final d = doc.data() as Map<String, dynamic>;
                  if(d['type'] == 'EMERGENCY SOS') totalSOS++;
                  if(d['status'] == 'accepted') totalMatches++;
                }

                return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              "Platform Analytics",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5
                              )
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _buildStatCard("Total Citizens", "$totalUsers", Icons.people_alt_rounded, Colors.blue.shade600, context),
                                _buildStatCard("Verified Lawyers", "${totalLawyers - pendingLawyers}", Icons.gavel_rounded, Colors.deepPurple.shade500, context),
                                _buildStatCard("Pending Lawyers", "$pendingLawyers", Icons.pending_actions_rounded, Colors.orange.shade600, context),
                                _buildStatCard("Total SOS Logs", "$totalSOS", Icons.radar_rounded, Colors.red.shade500, context),
                                _buildStatCard("Active Cases", "$totalMatches", Icons.handshake_rounded, Colors.green.shade600, context),
                              ]
                          )
                        ]
                    )
                );
              }
          );
        }
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, BuildContext context) {
    double cardWidth = (MediaQuery.of(context).size.width - 48 - 16) / 2;
    return Container(
        width: cardWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5)
              )
            ]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle
                  ),
                  child: Icon(icon, size: 28, color: color)
              ),
              const SizedBox(height: 20),
              Text(
                  count,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)
              ),
              const SizedBox(height: 4),
              Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)
              ),
            ]
        )
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'lawyer')
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingDocs = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['isRejected'] ?? false) == false;
        }).toList() ?? [];

        if (pendingDocs.isEmpty) {
          return const Center(
              child: Text(
                  "No pending requests.",
                  style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)
              )
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: pendingDocs.length,
          itemBuilder: (context, index) {
            final doc = pendingDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.orange.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8)
                    )
                  ]
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                              data['name'] ?? "Unknown",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))
                          )
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20)
                        ),
                        child: const Text(
                            "REVIEW REQUIRED",
                            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)
                        ),
                      )
                    ],
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, thickness: 1)
                  ),

                  // 🚀 FIX 4: ADDED THE IMAGE VERIFICATION ROW
                  if (data['profilePicUrl'] != null || data['barIdUrl'] != null) ...[
                    const Text(
                        "UPLOADED DOCUMENTS",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildImageThumbnail(context, "Live Selfie", data['profilePicUrl']),
                        const SizedBox(width: 16),
                        _buildImageThumbnail(context, "Bar ID Card", data['barIdUrl']),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                      "CREDENTIALS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow("Bar Number", data['barNumber'] ?? 'N/A'),
                  _buildDetailRow("State Bar", "${data['stateBar'] ?? 'N/A'} ('${data['enrollmentYear'] ?? 'N/A'}')"),
                  _buildDetailRow("Lawyer Type", data['lawyerType'] ?? 'N/A'),

                  const SizedBox(height: 20),
                  const Text(
                      "CONTACT INFO",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow("Phone", data['phone'] ?? 'N/A'),
                  _buildDetailRow("Email", data['email'] ?? 'N/A'),
                  _buildDetailRow("City", data['city'] ?? 'N/A'),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.shade300, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text("Reject", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () => _showRejectDialog(context, doc.id, data['name'] ?? "Lawyer"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 5,
                              shadowColor: Colors.green.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text("Approve", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () => _approveLawyer(context, doc.id, data['name'] ?? "Lawyer"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSosLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases')
          .where('type', isEqualTo: 'EMERGENCY SOS')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  "No SOS records found.",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16)
              )
          );
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'searching';

            Color statusColor;
            if (status == 'accepted') statusColor = Colors.green;
            else if (status == 'timeout' || status == 'cancelled' || status == 'cancelled_by_admin') statusColor = Colors.red;
            else statusColor = Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ]
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle
                        ),
                        child: Icon(Icons.radar, color: statusColor, size: 24)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "SOS: ${data['clientName']}",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))
                          ),
                          const SizedBox(height: 6),
                          Text(
                              "${data['city']} • ${data['category']}",
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)
                          ),
                          const SizedBox(height: 6),
                          Text(
                              "Budget: ₹${data['maxFee'] ?? 'N/A'}",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 14)
                          ),
                          const SizedBox(height: 12),
                          Text(
                              data['aiSummary'] ?? '',
                              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 10, letterSpacing: 0.5)
                          ),
                        ),
                        if (status == 'searching') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              onPressed: () => FirebaseFirestore.instance.collection('cases').doc(docs[index].id).update({'status': 'cancelled_by_admin'}),
                              child: const Text("Force Cancel", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ]
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSupportTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases')
          .where('type', isEqualTo: 'SUPPORT TICKET')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all, size: 80, color: Colors.green.shade200),
                    const SizedBox(height: 16),
                    const Text(
                        "Inbox Zero. All tickets resolved!",
                        style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)
                    )
                  ]
              )
          );
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isClosed = data['status'] == 'closed' || data['status'] == 'resolved';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isClosed ? Colors.grey.shade100 : Colors.red.shade50,
                        shape: BoxShape.circle
                    ),
                    child: Icon(
                        Icons.headset_mic,
                        color: isClosed ? Colors.grey : Colors.red.shade700
                    )
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        data['ticketNumber'] ?? 'TKT',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4A3AFF))
                    ),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: isClosed ? Colors.grey.shade200 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(
                            isClosed ? "CLOSED" : "NEEDS REPLY",
                            style: TextStyle(
                                color: isClosed ? Colors.grey.shade700 : Colors.red.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w900
                            )
                        )
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "User: ${data['clientName']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                      Text(
                          data['subject'] ?? 'No Subject',
                          style: TextStyle(color: Colors.grey.shade700)
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.reply, color: Color(0xFF4A3AFF)),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatScreen(caseId: doc.id, clientName: "Support: ${data['ticketNumber']}"))
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases')
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  "No connections yet.",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16)
              )
          );
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final tA = (a.data() as Map<String, dynamic>)['acceptedAt'] as Timestamp?;
          final tB = (b.data() as Map<String, dynamic>)['acceptedAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final type = data['type'] ?? 'General';
            IconData icon = type == 'EMERGENCY SOS'
                ? Icons.radar
                : (type == 'DOCUMENT REVIEW' ? Icons.document_scanner : Icons.smart_toy);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ]
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle
                    ),
                    child: Icon(icon, color: Colors.blue.shade700)
                ),
                title: Text(
                    "${data['clientName']} 🤝 Advocate",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Lawyer ID: ${data['acceptedBy'] ?? 'Unknown'}",
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12)
                      ),
                      const SizedBox(height: 4),
                      Text(
                          "Source: $type",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.verified, color: Colors.green, size: 28),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserDirectoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] != 'admin').toList();
        if (docs.isEmpty) return const Center(child: Text("No users found.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isLawyer = data['role'] == 'lawyer';
            final isSuspended = data['isSuspended'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: isSuspended ? Colors.red.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSuspended ? Colors.red.shade200 : Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ]
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isSuspended ? Colors.red.shade100 : (isLawyer ? Colors.deepPurple.shade50 : Colors.blue.shade50),
                        shape: BoxShape.circle
                    ),
                    child: Icon(
                        isLawyer ? Icons.gavel : Icons.person,
                        color: isSuspended ? Colors.red : (isLawyer ? Colors.deepPurple : Colors.blue)
                    )
                ),
                title: Text(
                    data['name'] ?? 'Unnamed User',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: const Color(0xFF1E293B),
                        decoration: isSuspended ? TextDecoration.lineThrough : null
                    )
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "ID: ${data['uniqueId'] ?? 'N/A'} • ${data['role'].toString().toUpperCase()}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12)
                      ),
                      const SizedBox(height: 4),
                      Text(
                          "${data['phone']} • ${data['city']}",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)
                      ),
                      if (isLawyer && !isSuspended) ...[
                        const SizedBox(height: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: data['isVerified'] == true ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(
                                data['isVerified'] == true ? 'VERIFIED ADVOCATE' : 'PENDING APPROVAL',
                                style: TextStyle(
                                    color: data['isVerified'] == true ? Colors.green.shade700 : Colors.orange.shade700,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.5
                                )
                            )
                        )
                      ],
                      if (isSuspended) ...[
                        const SizedBox(height: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(
                                "ACCOUNT SUSPENDED",
                                style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.5
                                )
                            )
                        )
                      ]
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch(
                      value: !isSuspended,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(doc.id).update({'isSuspended': !val}),
                    ),
                  ],
                ),
                onLongPress: () => _showEditUserDialog(context, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSystemConfigTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
            "Master Control",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))
        ),
        const SizedBox(height: 24),
        _buildConfigTile(
            "Allow New Registrations",
            "Temporarily freeze the platform from accepting new users.",
            true,
            const Color(0xFF4A3AFF)
        ),
        _buildConfigTile(
            "AI Paralegal Engine",
            "Toggle the AI document scanner and chat summarizer.",
            true,
            const Color(0xFF4A3AFF)
        ),
        _buildConfigTile(
            "Global SOS Radar",
            "Master kill-switch for the emergency broadcast system.",
            true,
            Colors.red.shade600
        ),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Divider(height: 1, thickness: 1)
        ),
        const Text(
            "Platform Rules",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Platform Commission",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))
                  ),
                  const SizedBox(height: 4),
                  Text(
                      "Current Cut: 10%",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {},
                child: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTile(String title, String subtitle, bool value, Color activeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ]
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B))
        ),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)
            )
        ),
        value: value,
        activeColor: activeColor,
        onChanged: (val) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Text(
              "Admin Command Center",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)
          ),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          actions: [
            Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    onPressed: () => _logout(context)
                )
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            physics: const BouncingScrollPhysics(),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicator: BoxDecoration(
                color: const Color(0xFF4A3AFF),
                borderRadius: BorderRadius.circular(30)
            ),
            indicatorPadding: const EdgeInsets.only(top: 8, bottom: 8),
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            tabs: const [
              Tab(child: Row(children: [Icon(Icons.dashboard_rounded, size: 18), SizedBox(width: 8), Text("Overview")])),
              Tab(child: Row(children: [Icon(Icons.verified_user_rounded, size: 18), SizedBox(width: 8), Text("Pending")])),
              Tab(child: Row(children: [Icon(Icons.radar_rounded, size: 18), SizedBox(width: 8), Text("SOS Logs")])),
              Tab(child: Row(children: [Icon(Icons.support_agent_rounded, size: 18), SizedBox(width: 8), Text("Support Tickets")])),
              Tab(child: Row(children: [Icon(Icons.handshake_rounded, size: 18), SizedBox(width: 8), Text("Connections")])),
              Tab(child: Row(children: [Icon(Icons.people_alt_rounded, size: 18), SizedBox(width: 8), Text("Directory")])),
              Tab(child: Row(children: [Icon(Icons.settings_suggest_rounded, size: 18), SizedBox(width: 8), Text("Config")])),
            ],
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildOverviewTab(),
            _buildPendingTab(),
            _buildSosLogsTab(),
            _buildSupportTab(),
            _buildConnectionsTab(),
            _buildUserDirectoryTab(),
            _buildSystemConfigTab(),
          ],
        ),
      ),
    );
  }
}
