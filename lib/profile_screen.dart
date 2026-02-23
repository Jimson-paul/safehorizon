import 'package:flutter/material.dart';
import 'main.dart';
import 'services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String? phone;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<dynamic>> reportsFuture;
  bool deletingAccount = false;

  @override
  void initState() {
    super.initState();
    reportsFuture = ApiService.getUserReports(widget.email);
  }

  // =====================================================
  // DELETE ACCOUNT
  // =====================================================
  Future<void> deleteAccount() async {
    setState(() => deletingAccount = true);

    bool success = await ApiService.deleteAccount(widget.email);

    if (!mounted) return;

    setState(() => deletingAccount = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully 🗑️")),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete account ❌")),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// ===== TOP BAR =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF64B5F6),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(25),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Profile",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// ===== PROFILE CARD =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF90CAF9),
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      widget.email,
                      style: const TextStyle(color: Colors.grey),
                    ),

                    if (widget.phone != null && widget.phone!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.phone!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],

                    const SizedBox(height: 30),

                    /// ===== LOGOUT =====
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
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text("Logout"),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// ===== DELETE ACCOUNT =====
                    TextButton(
                      onPressed: deletingAccount
                          ? null
                          : () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Account"),
                                  content: const Text(
                                    "This will permanently delete your account and all reports.\n\nContinue?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        deleteAccount();
                                      },
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                      child: deletingAccount
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              "Delete Account",
                              style: TextStyle(color: Colors.red),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// ===== USER REPORT STATUS =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<List<dynamic>>(
                  future: reportsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Text(
                        "Failed to load reports ❌",
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    final reports = snapshot.data ?? [];

                    if (reports.isEmpty) {
                      return const Text(
                        "No accident reports submitted",
                        style: TextStyle(fontSize: 16),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Reports",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...reports.map((report) {
                          Color statusColor;

                          switch (report["status"]) {
                            case "approved":
                              statusColor = Colors.green;
                              break;
                            case "rejected":
                              statusColor = Colors.red;
                              break;
                            default:
                              statusColor = Colors.orange;
                          }

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.report),
                              title: Text("Report #${report["id"]}"),
                              subtitle: Text(
                                "Severity: ${report["severity"] ?? "Unknown"}",
                              ),
                              trailing: Text(
                                (report["status"] ?? "pending").toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
