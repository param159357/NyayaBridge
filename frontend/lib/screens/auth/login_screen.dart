import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/auth/otp_screen.dart';
import 'package:frontend/utils/responsive_layout.dart'; // 🚀 ADDED RESPONSIVE WRAPPER

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 10-digit mobile number."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (rarely happens on testing, but good to have)
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification Failed: ${e.message}"), backgroundColor: Colors.red),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(verificationId: verificationId, phoneNumber: '+91$phone'),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium color palette
    const Color primaryText = Color(0xFF2D3142);
    const Color brandBlue = Color(0xFF4A3AFF);
    const Color backgroundOffWhite = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundOffWhite,
      body: SafeArea(
        child: Center( // 🚀 KEEPS EVERYTHING CENTERED ON WIDE SCREENS
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // 🚀 LIMITS WIDTH FOR WEB
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                margin: const EdgeInsets.all(16),
                // 🚀 ADDS A FLOATING CARD EFFECT ONLY ON DESKTOP
                decoration: ResponsiveLayout.isDesktop(context)
                    ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // 🚀 HUGS CONTENT
                  children: [
                    // --- BRANDING HEADER ---
                    Center(
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: brandBlue.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.balance_rounded,
                          size: 50,
                          color: brandBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- WELCOME TEXT ---
                    const Text(
                      "NyayaBridge",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Enter your mobile number to securely access your legal portal and get immediate assistance.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey.shade400,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // --- PHONE INPUT FIELD ---
                    const Text(
                      "Mobile Number",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        // Slightly darker grey on web to pop out from the white card
                        color: ResponsiveLayout.isDesktop(context) ? Colors.grey.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "98765 43210",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 20, right: 12, top: 15, bottom: 15),
                            child: Text(
                              "+91",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- SUBMIT BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandBlue,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: brandBlue.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : const Text(
                          "Send Verification Code",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- FOOTER ---
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: "By continuing, you agree to our\n",
                          style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, height: 1.5),
                          children: const [
                            TextSpan(
                              text: "Terms of Service",
                              style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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