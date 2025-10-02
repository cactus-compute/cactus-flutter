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
  String outputText = 'Click "Refresh" to load available models.';

  @override
  void initState() {
    super.initState();
    fetchModels();
  }

  Future<void> fetchModels() async {
    setState(() {
      isLoading = true;
      outputText = 'Fetching available models...';
    });

    try {
      final models = await lm.getModels();
      setState(() {
        availableModels = models;
        outputText = 'Found ${models.length} available models. Browse the list below.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error fetching models: $e';
        availableModels = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildModelCard(CactusModel model) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Size: ${model.sizeMb} MB',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slug: ${model.slug}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: model.isDownloaded 
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    model.isDownloaded ? 'Downloaded' : 'Available',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: model.isDownloaded
                          ? Colors.green.shade800
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (model.supportsToolCalling || model.supportsVision) ...[
              const SizedBox(height: 8),
              Text(
                'Features: ${[
                  if (model.supportsToolCalling) 'Tool Calling',
                  if (model.supportsVision) 'Vision'
                ].join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No models available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing to fetch the latest models',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchModels,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
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
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchModels,
          ),
        ],
      ),
      body: Column(
        children: [
          // Information Card
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Model Discovery",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Browse all available AI models. Each model has different capabilities, sizes, and performance characteristics.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // Status Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Status:",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    outputText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Models List
          Expanded(
            child: availableModels.isNotEmpty
                ? ListView.builder(
                    itemCount: availableModels.length,
                    itemBuilder: (context, index) {
                      return _buildModelCard(availableModels[index]);
                    },
                  )
                : !isLoading
                    ? _buildEmptyState()
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
          ),
        ],
      ),
    );
  }
}