import 'dart:convert';

import 'package:cactus/utils.dart';
import 'package:cactus_example/device_info_helper.dart';
import 'package:cactus_example/log_entry.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _telemetryTokenController = TextEditingController();
  final _enterpriseKeyController = TextEditingController();
  final _deviceMetadataController = TextEditingController();

  List<LogEntry> _logEntries = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceMetadata = await DeviceInfoHelper.getDeviceMetadataJson();
      setState(() {
        _deviceMetadataController.text = deviceMetadata;
      });
    } catch (e) {
      print('Error loading device info: $e');
    }
  }

  Future<void> _registerApp() async {
    if (_formKey.currentState!.validate()) {
      final success = await registerApp(
        encString: "22cf52364d87b3761a7fb15b7ed0ac83b765e4ca08e0a4a7503dca158f30d26bb259876f0fa63006d6b8973054c308522892154a4920cfb71f3a66af143f5c0f20664a7dd5ef7d69bfbb76d35c1144c92116c5d7b5c72569c3de5a7de392"
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App registered successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to register app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cactus Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _telemetryTokenController,
                    decoration: const InputDecoration(labelText: 'Telemetry Token'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a telemetry token';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _enterpriseKeyController,
                    decoration: const InputDecoration(labelText: 'Enterprise Key (Optional)'),
                  ),
                  TextFormField(
                    controller: _deviceMetadataController,
                    decoration: InputDecoration(
                      labelText: 'Device Metadata',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDeviceInfo,
                        tooltip: 'Refresh device info',
                      ),
                    ),
                    maxLines: 5,
                    minLines: 1,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter device metadata';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _registerApp,
                    child: const Text('Register App'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Log Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: _logEntries.isEmpty
                  ? const Center(child: Text('No entries found.'))
                  : ListView.builder(
                      itemCount: _logEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _logEntries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text('ID: ${entry.id}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Token: ${entry.telemetryToken}'),
                                if (entry.enterpriseKey != null) Text('Key: ${entry.enterpriseKey}'),
                                Text('Metadata: ${entry.deviceMetadata}'),
                                Text('Created At: ${entry.createdAt}'),
                                Text('Updated At: ${entry.updatedAt}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
