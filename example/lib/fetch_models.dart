import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class FetchModelsPage extends StatefulWidget {
  const FetchModelsPage({super.key});

  @override
  State<FetchModelsPage> createState() => _FetchModelsPageState();
}

class _FetchModelsPageState extends State<FetchModelsPage> {
  final lm = CactusLM();
  List<CactusModel> availableModels = [];
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
    fetchModels();
  }

  Future<void> fetchModels() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final models = await lm.getModels();
      setState(() {
        availableModels = models;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching models: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Fetch Models'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: fetchModels,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.builder(
                  itemCount: availableModels.length,
                  itemBuilder: (context, index) {
                    final model = availableModels[index];
                    return Card(
                      color: Colors.white,
                      elevation: 1,
                      margin: const EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey, width: 0.5),
                      ),
                      child: ListTile(
                        title: Text(
                          model.name,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Slug: ${model.slug}', style: const TextStyle(color: Colors.black)),
                            Text('Size: ${model.sizeMb} MB', style: const TextStyle(color: Colors.black)),
                            Text('Downloaded: ${model.isDownloaded ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.black)),
                            Text('Supports Tool Calling: ${model.supportsToolCalling ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.black)),
                            Text('Supports Vision: ${model.supportsVision ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}