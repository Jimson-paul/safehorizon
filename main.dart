import 'package:flutter/material.dart';

void main() {
  runApp(const SafeHorizonApp());
}

class SafeHorizonApp extends StatelessWidget {
  const SafeHorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(
          0xFFF4F7FC,
        ), // Soft background color
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // State variable to handle password visibility toggle
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. App Logo Icon
                const Icon(
                  Icons.shield_outlined, // Safety themed icon
                  size: 100,
                  color: Color(0xFF1E88E5), // Vivid Blue
                ),
                const SizedBox(height: 24),

                // 2. App Title
                const Text(
                  "Safe Horizon",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A43), // Dark Navy
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Subtitle Text
                const Text(
                  "Safe Navigation. Safer Roads.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF627D98), // Slate Gray
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // 4. Email Input Field
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Email address",
                    hintStyle: const TextStyle(color: Color(0xFF9FB3C8)),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF627D98),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Password Input Field
                TextField(
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: const TextStyle(color: Color(0xFF9FB3C8)),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF627D98),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF627D98),
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
                  ),
                ),
                const SizedBox(height: 32),

                // 6. Rounded Login Button with Blue Gradient
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Add frontend validation or navigation here
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.transparent, // Transparent to show gradient
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 7. Register Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "New user? ",
                      style: TextStyle(color: Color(0xFF627D98), fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () {
                        // TODO: Navigate to Registration Page
                      },
                      child: const Text(
                        "Register here",
                        style: TextStyle(
                          color: Color(0xFF1E88E5),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
