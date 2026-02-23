import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'reset_password_screen.dart';

class VerifyResetScreen extends StatefulWidget {
  final String email;

  const VerifyResetScreen({super.key, required this.email});

  @override
  State<VerifyResetScreen> createState() => _VerifyResetScreenState();
}

class _VerifyResetScreenState extends State<VerifyResetScreen> {
  final TextEditingController codeController = TextEditingController();

  bool loading = false;

  // =====================================================
  // VERIFY RESET CODE
  // =====================================================
  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter verification code")));
      return;
    }

    setState(() => loading = true);

    bool success = await ApiService.verifyResetCode(widget.email, code);

    if (!mounted) return;

    setState(() => loading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Code verified ✅")));

      // Navigate to reset password screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid or expired code ❌")),
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
        title: const Text("Verify Code"),
        backgroundColor: const Color(0xFF64B5F6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Color(0xFF64B5F6),
              ),

              const SizedBox(height: 25),

              Text(
                "Enter the verification code sent to\n${widget.email}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Verification Code",
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
                  onPressed: loading ? null : verifyCode,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Verify Code"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
