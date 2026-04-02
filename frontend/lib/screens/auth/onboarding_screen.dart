import 'package:flutter/material.dart';
import 'package:frontend/screens/client/client_dashboard.dart';
import 'package:frontend/screens/lawyer/lawyer_dashboard.dart';

class OnboardingScreen extends StatefulWidget {
  final String role; // We pass 'client' or 'lawyer' into this screen

  const OnboardingScreen({super.key, required this.role});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 🚀 The swipeable cards for the Citizen
  final List<Map<String, dynamic>> _clientPages = [
    {
      "icon": Icons.chat,
      "title": "Smart AI Legal Intake",
      "description": "Describe your legal issue and our AI will instantly categorize it and provide preliminary guidance."
    },
    {
      "icon": Icons.document_scanner,
      "title": "AI Document Scanner",
      "description": "Snap a photo of any confusing legal document and get a simple 4-point breakdown in plain English."
    },
    {
      "icon": Icons.radar,
      "title": "Emergency SOS Radar",
      "description": "In immediate danger? Alert nearby verified lawyers instantly with your location and a high-priority distress signal."
    }
  ];

  // 🚀 The swipeable cards for the Lawyer
  final List<Map<String, dynamic>> _lawyerPages = [
    {
      "icon": Icons.radar,
      "title": "Live Case Radar",
      "description": "Toggle your status to online and receive real-time SOS distress signals from citizens in your radius."
    },
    {
      "icon": Icons.auto_awesome,
      "title": "AI Case Summaries",
      "description": "Review AI-generated summaries of client issues instantly before you decide to accept a case."
    },
    {
      "icon": Icons.forum,
      "title": "Instant Client Chat",
      "description": "Accept an emergency case and instantly connect with the client via a secure, real-time chat room."
    }
  ];

  void _completeOnboarding() {
    // When they finish the tutorial, send them to their actual home screen
    if (widget.role == 'lawyer') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LawyerDashboard()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ClientDashboard()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Choose which list to show based on their role
    final pages = widget.role == 'lawyer' ? _lawyerPages : _clientPages;
    final themeColor = widget.role == 'lawyer' ? Colors.deepPurple : Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // The Swipeable Area
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(pages[index]["icon"], size: 120, color: themeColor),
                        const SizedBox(height: 48),
                        Text(
                          pages[index]["title"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          pages[index]["description"],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Area (Dots and Button)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The DOT Indicators
                  Row(
                    children: List.generate(
                      pages.length,
                          (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 10,
                        width: _currentPage == index ? 24 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? themeColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),

                  // The Next / Get Started Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      if (_currentPage == pages.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      }
                    },
                    child: Text(_currentPage == pages.length - 1 ? "Get Started" : "Next", style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}