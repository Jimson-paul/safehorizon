import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'services/api_service.dart';
import 'utils/app_toast.dart';

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
  bool uploadingImage = false;

  File? _profileImage;
  String? _profileImageUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    reportsFuture = ApiService.getUserReports(widget.email);
    loadProfile();
  }

  // ================= LOAD PROFILE =================
  Future<void> loadProfile() async {
    final data = await ApiService.getUserProfile(widget.email);

    if (data != null && mounted) {
      setState(() {
        _profileImageUrl = data["profile_image"];
      });
    }
  }

  // ================= IMAGE PICK =================
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() {
      _profileImage = File(image.path);
      uploadingImage = true;
    });

    bool success = await ApiService.uploadProfileImage(
      widget.email,
      _profileImage!,
    );

    if (!mounted) return;

    setState(() => uploadingImage = false);

    if (success) {
      await loadProfile();

      AppToast.show(
        context,
        "Profile image updated ✅",
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } else {
      AppToast.show(
        context,
        "Upload failed ❌",
        color: Colors.red,
        icon: Icons.error,
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= CLEAR SESSION =================
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ================= DELETE ACCOUNT =================
  Future<void> deleteAccount() async {
    setState(() => deletingAccount = true);

    bool success = await ApiService.deleteAccount(widget.email);

    if (!mounted) return;

    setState(() => deletingAccount = false);

    if (success) {
      await clearSession();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await clearSession();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ================= STATUS COLOR =================
  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ================= PROFILE IMAGE =================
  ImageProvider? getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage("${ApiService.baseUrl}/$_profileImageUrl");
    }

    return null;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // ===== PROFILE CARD =====
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
                    GestureDetector(
                      onTap: _showImageOptions,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF90CAF9),
                        backgroundImage: getProfileImage(),
                        child: getProfileImage() == null
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),

                    if (uploadingImage)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: CircularProgressIndicator(),
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

                    if (widget.phone != null && widget.phone!.isNotEmpty)
                      Text(
                        widget.phone!,
                        style: const TextStyle(color: Colors.grey),
                      ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: logout,
                        child: const Text("Logout"),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: deletingAccount ? null : deleteAccount,
                      child: deletingAccount
                          ? const CircularProgressIndicator()
                          : const Text(
                              "Delete Account",
                              style: TextStyle(color: Colors.red),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ===== REPORT STATUS =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Reports",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    FutureBuilder<List<dynamic>>(
                      future: reportsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text("No reports submitted");
                        }

                        final reports = snapshot.data!;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F1F1),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.black12,
                                    child: Icon(
                                      Icons.priority_high,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Report #${report["id"]}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Severity: ${report["severity"]}",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    report["status"].toString().toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor(report["status"]),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
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
