import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'verify_reset_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();

  bool loading = false;

  // =====================================================
  // SEND RESET CODE
  // =====================================================
  Future<void> sendResetCode() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter your email")));
      return;
    }

    setState(() => loading = true);

    bool success = await ApiService.forgotPassword(email);

    if (!mounted) return;

    setState(() => loading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reset code sent 📧")));

      // Navigate to OTP verification screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyResetScreen(email: email)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send reset code ❌")),
      );
    }
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: const Color(0xFF64B5F6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Color(0xFF64B5F6)),

              const SizedBox(height: 25),

              const Text(
                "Enter your registered email.\nWe will send a reset code.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64B5F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: loading ? null : sendResetCode,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Send Code"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
