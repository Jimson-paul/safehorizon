import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool codeSent = false;
  bool emailVerified = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ================= STEP 1 =================
  Future<void> generateCode() async {
    if (!_formKey.currentState!.validate()) return;

    String name = nameController.text.trim();
    String email = emailController.text.trim();

    String? phone = phoneController.text.trim().isEmpty
        ? null
        : phoneController.text.trim();

    setState(() => isLoading = true);

    String result = await ApiService.register(name, email, phone);

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result == "success") {
      setState(() => codeSent = true);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("OTP sent to email 📧")));
    } else if (result == "exists") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email already registered. Please login."),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to send OTP ❌")));
    }
  }

  // ================= STEP 2 =================
  Future<void> verifyCode() async {
    String email = emailController.text.trim();
    String code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter verification code")));
      return;
    }

    setState(() => isLoading = true);

    bool success = await ApiService.verifyEmail(email, code);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      emailVerified = success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? "Email verified ✅" : "Invalid code ❌")),
    );
  }

  // ================= STEP 3 =================
  Future<void> createPassword() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be 6+ characters")),
      );
      return;
    }

    setState(() => isLoading = true);

    bool success = await ApiService.setPassword(email, password);

    if (!mounted) return;

    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully ✅")),
      );

      await Future.delayed(const Duration(milliseconds: 600));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create account ❌")),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    /// ✅ PERFECT CIRCULAR LOGO
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage('assets/images/logo.png'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D47A1),
                      ),
                    ),

                    const SizedBox(height: 40),

                    _inputField(
                      controller: nameController,
                      hint: "Full Name",
                      icon: Icons.person_outline,
                      enabled: !codeSent,
                    ),

                    const SizedBox(height: 20),

                    _inputField(
                      controller: phoneController,
                      hint: "Phone Number (Optional)",
                      icon: Icons.phone_outlined,
                      enabled: !codeSent,
                    ),

                    const SizedBox(height: 20),

                    _inputField(
                      controller: emailController,
                      hint: "Email",
                      icon: Icons.email_outlined,
                      enabled: !codeSent,
                    ),

                    const SizedBox(height: 20),

                    if (!codeSent) _mainButton("Generate Code", generateCode),

                    if (codeSent && !emailVerified) ...[
                      _inputField(
                        controller: codeController,
                        hint: "Verification Code",
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 20),
                      _mainButton("Verify Code", verifyCode),
                    ],

                    if (emailVerified) ...[
                      _inputField(
                        controller: passwordController,
                        hint: "Create Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 20),
                      _mainButton("Create Account", createPassword),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= INPUT =================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  // ================= BUTTON =================
  Widget _mainButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const CircularProgressIndicator() : Text(text),
      ),
    );
  }
}
