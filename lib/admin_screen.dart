import 'package:flutter/material.dart';
import 'services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<dynamic>> reportsFuture;

  @override
  void initState() {
    super.initState();
    reportsFuture = ApiService.getPendingReports();
  }

  void refresh() {
    setState(() {
      reportsFuture = ApiService.getPendingReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Verification"),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Failed to load reports"));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text("No pending reports"));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];

              return Card(
                margin: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// IMAGE
                    if (report["image_url"] != null)
                      Image.network(
                        report["image_url"],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Severity: ${report["severity"]}"),
                          Text(
                            "Location: ${report["latitude"]}, ${report["longitude"]}",
                          ),
                          Text("Date: ${report["accident_datetime"]}"),
                          Text("Description: ${report["description"] ?? ""}"),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              /// APPROVE
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () async {
                                  await ApiService.approveReport(report["id"]);
                                  refresh();
                                },
                                child: const Text("Approve"),
                              ),

                              /// REJECT
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  await ApiService.rejectReport(report["id"]);
                                  refresh();
                                },
                                child: const Text("Reject"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
