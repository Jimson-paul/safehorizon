import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator localhost
  static const String baseUrl = "http://127.0.0.1:8000";
  // =====================================================
  // REGISTER
  // =====================================================
  static Future<String> register(
    String name,
    String email,
    String? phone,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "phone": phone}),
    );

    if (response.statusCode == 200) {
      return "success";
    } else if (response.statusCode == 409) {
      return "exists";
    } else {
      return "error";
    }
  }

  // =====================================================
  // VERIFY EMAIL
  // =====================================================
  static Future<bool> verifyEmail(String email, String code) async {
    final response = await http.post(
      Uri.parse("$baseUrl/verify-email"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "code": code}),
    );

    return response.statusCode == 200;
  }

  // =====================================================
  // SET PASSWORD
  // =====================================================
  static Future<bool> setPassword(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/set-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    return response.statusCode == 200;
  }

  // =====================================================
  // LOGIN
  // =====================================================
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 403) {
      return {"error": "not_verified"};
    } else {
      return {"error": "invalid"};
    }
  }

  // =====================================================
  // ✅ GET USER PROFILE (NEW)
  // =====================================================
  static Future<Map<String, dynamic>?> getUserProfile(String email) async {
    final response = await http.get(Uri.parse("$baseUrl/user/$email"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }

  // =====================================================
  // ✅ UPLOAD PROFILE IMAGE (NEW)
  // =====================================================
  static Future<bool> uploadProfileImage(String email, File imageFile) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/upload-profile-image"),
    );

    request.fields["email"] = email;

    request.files.add(
      await http.MultipartFile.fromPath("image", imageFile.path),
    );

    var response = await request.send();

    return response.statusCode == 200;
  }

  // =====================================================
  // FORGOT PASSWORD
  // =====================================================
  static Future<bool> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/forgot-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    return response.statusCode == 200;
  }

  // =====================================================
  // VERIFY RESET OTP
  // =====================================================
  static Future<bool> verifyResetCode(String email, String code) async {
    final response = await http.post(
      Uri.parse("$baseUrl/verify-reset-code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "code": code}),
    );

    return response.statusCode == 200;
  }

  // =====================================================
  // RESET PASSWORD
  // =====================================================
  static Future<bool> resetPassword(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    return response.statusCode == 200;
  }

  // =====================================================
  // USER REPORT STATUS
  // =====================================================
  static Future<List<dynamic>> getUserReports(String email) async {
    final response = await http.get(Uri.parse("$baseUrl/user/reports/$email"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load user reports");
    }
  }

  // =====================================================
  // DELETE ACCOUNT
  // =====================================================
  static Future<bool> deleteAccount(String email) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/delete-account/$email"),
    );

    return response.statusCode == 200;
  }

  // ================= ADMIN APIs =================

  static Future<List<dynamic>> getPendingReports() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin/pending-reports"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load pending reports");
    }
  }

  static Future<bool> approveReport(int reportId) async {
    final response = await http.put(
      Uri.parse("$baseUrl/admin/approve/$reportId"),
    );

    return response.statusCode == 200;
  }

  static Future<bool> rejectReport(int reportId) async {
    final response = await http.put(
      Uri.parse("$baseUrl/admin/reject/$reportId"),
    );

    return response.statusCode == 200;
  }
}
