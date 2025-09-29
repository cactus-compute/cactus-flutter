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
      appBar: AppBar(
        title: const Text('Fetch Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchModels,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : ListView.builder(
                  itemCount: availableModels.length,
                  itemBuilder: (context, index) {
                    final model = availableModels[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(model.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Slug: ${model.slug}'),
                            Text('Size: ${model.sizeMb} MB'),
                            Text('Downloaded: ${model.isDownloaded ? 'Yes' : 'No'}'),
                            Text('Supports Tool Calling: ${model.supportsToolCalling ? 'Yes' : 'No'}'),
                            Text('Supports Vision: ${model.supportsVision ? 'Yes' : 'No'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}