import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'map_picker_screen.dart';

class ReportAccidentScreen extends StatefulWidget {
  final String userEmail;

  const ReportAccidentScreen({super.key, required this.userEmail});

  @override
  State<ReportAccidentScreen> createState() => _ReportAccidentScreenState();
}

class _ReportAccidentScreenState extends State<ReportAccidentScreen> {
  String severity = "Minor";
  final TextEditingController descriptionController = TextEditingController();

  bool usingManualLocation = false;
  bool isSubmitting = false;

  /// DATE & TIME
  DateTime selectedDateTime = DateTime.now();
  String get formattedDateTime =>
      DateFormat('MMM dd, yyyy, hh:mm a').format(selectedDateTime);

  /// LOCATION
  String gpsLocation = "Detecting location...";
  double? latitude;
  double? longitude;

  /// IMAGE
  File? incidentImage;
  final ImagePicker picker = ImagePicker();

  // ================= LOCATION =================
  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      usingManualLocation = false;

      gpsLocation =
          "Auto-detected: ${latitude!.toStringAsFixed(5)}, "
          "${longitude!.toStringAsFixed(5)}";
    });
  }

  Future<void> selectFromMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null) {
      setState(() {
        latitude = result.latitude;
        longitude = result.longitude;
        usingManualLocation = true;

        gpsLocation =
            "Selected from map: ${latitude!.toStringAsFixed(5)}, "
            "${longitude!.toStringAsFixed(5)}";
      });
    }
  }

  // ================= DATE TIME =================
  Future<void> pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
    );

    if (time == null) return;

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ================= IMAGE =================
  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() => incidentImage = File(image.path));
    }
  }

  // ================= SUBMIT =================
  Future<void> submitReport() async {
    if (isSubmitting) return;

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Location not available")));
      return;
    }

    setState(() => isSubmitting = true);

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("http://10.0.2.2:8000/report-accident"),
    );

    /// ✅ REAL USER EMAIL (THE IMPORTANT FIX)
    request.fields["user_email"] = widget.userEmail;
    request.fields["latitude"] = latitude.toString();
    request.fields["longitude"] = longitude.toString();
    request.fields["severity"] = severity;
    request.fields["description"] = descriptionController.text;
    request.fields["accident_datetime"] = formattedDateTime;

    if (incidentImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath("image", incidentImage!.path),
      );
    }

    final response = await request.send();

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report Submitted ✅")));

      Navigator.pop(context, true); // ✅ notify previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to submit report ❌")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safe Horizon"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "Accident Reporting",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            /// LOCATION
            const Text("Location (GPS)"),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(gpsLocation)),
                ],
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: usingManualLocation
                  ? getCurrentLocation
                  : selectFromMap,
              icon: Icon(
                usingManualLocation ? Icons.my_location : Icons.map_outlined,
              ),
              label: Text(
                usingManualLocation ? "Use Auto Location" : "Select From Map",
              ),
            ),

            const SizedBox(height: 16),

            /// DATE TIME
            const Text("Date & Time"),
            const SizedBox(height: 6),

            GestureDetector(
              onTap: pickDateTime,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined),
                    const SizedBox(width: 10),
                    Text(formattedDateTime),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// SEVERITY
            const Text("Severity"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ["Minor", "Major", "Critical"]
                  .map(
                    (level) => ChoiceChip(
                      label: Text(level),
                      selected: severity == level,
                      onSelected: (_) => setState(() => severity = level),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 20),

            /// IMAGE
            const Text("Incident Image (Optional)"),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey.shade100,
                ),
                child: incidentImage == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 40),
                            Text("Add photo of the incident"),
                          ],
                        ),
                      )
                    : Image.file(incidentImage!, fit: BoxFit.cover),
              ),
            ),

            const SizedBox(height: 20),

            /// DESCRIPTION
            const Text("Description (Optional)"),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Brief accident details...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// SUBMIT
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : submitReport,
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Report"),
              ),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Center(child: Text("Cancel")),
            ),
          ],
        ),
      ),
    );
  }
}
