import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class BenchmarksPage extends StatefulWidget {
  const BenchmarksPage({super.key});

  @override
  State<BenchmarksPage> createState() => _BenchmarksPageState();
}

class _BenchmarksPageState extends State<BenchmarksPage> {
  final lm = CactusLM();

  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isDownloading = false;
  bool isInitializing = false;
  bool isRunningBenchmark = false;
  String outputText = 'Select a model and download it to begin benchmarking.';
  String? selectedModel;
  double downloadProgress = 0.0;

  // Benchmark results
  List<BenchmarkResult> results = [];
  Map<String, double> accuracyByTool = {};
  double overallAccuracy = 0.0;

  @override
  void dispose() {
    lm.unload();
    super.dispose();
  }

  // Tool definitions matching the Python notebook
  List<CactusTool> getTools() {
    return [
      CactusTool(
        name: 'create_note',
        description: 'Creates a new note with the given text. Call this tool if asked to be reminded or to take a note.',
        parameters: ToolParametersSchema(
          properties: {
            'text': ToolParameter(
              type: 'string',
              description: 'The text of the note, usually a direct quote from the user',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'set_alarm',
        description: 'Sets an alarm for a specific time.',
        parameters: ToolParametersSchema(
          properties: {
            'time_hours': ToolParameter(
              type: 'integer',
              description: 'The hour component of the alarm time (24 hour time)',
              required: true,
            ),
            'time_minutes': ToolParameter(
              type: 'integer',
              description: 'The minute component of the alarm time (0-59)',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'set_timer_absolute',
        description: 'Sets a timer to go off at an absolute day and time.',
        parameters: ToolParametersSchema(
          properties: {
            'day_offset': ToolParameter(
              type: 'string',
              description: 'The offset of the day to remind the user at e.g. \'tomorrow\', \'today\', \'thursday\' (will be the next thursday), \'3\' (will be in 3 days)',
            ),
            'time_hours': ToolParameter(
              type: 'integer',
              description: 'The hour component of the desired end time (24 hour time)',
              required: true,
            ),
            'time_minutes': ToolParameter(
              type: 'integer',
              description: 'The minute component of the desired end time (0-59)',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'set_timer',
        description: 'Sets a timer for a relative duration (hours, minutes, seconds).',
        parameters: ToolParametersSchema(
          properties: {
            'time_hours': ToolParameter(
              type: 'integer',
              description: 'The number of hours on the timer',
            ),
            'time_minutes': ToolParameter(
              type: 'integer',
              description: 'The number of minutes on the timer',
            ),
            'time_seconds': ToolParameter(
              type: 'integer',
              description: 'The number of seconds on the timer',
            ),
          },
        ),
      ),
      CactusTool(
        name: 'reminder_absolute',
        description: 'Creates a reminder for a specific absolute date and time.',
        parameters: ToolParametersSchema(
          properties: {
            'day_offset': ToolParameter(
              type: 'string',
              description: 'The offset of the day to remind the user at e.g. \'tomorrow\', \'today\', \'thursday\' (will be the next thursday), \'3\' (will be in 3 days)',
            ),
            'absolute_time_hour': ToolParameter(
              type: 'integer',
              description: 'The absolute time to remind the user at as a 24 hour hour part e.g. \'17\'',
              required: true,
            ),
            'absolute_time_minute': ToolParameter(
              type: 'integer',
              description: 'The absolute time to remind the user at as a minute part e.g. \'30\', or \'00\' for the top of the hour',
              required: true,
            ),
            'date_month_day': ToolParameter(
              type: 'string',
              description: 'The date to remind the user at if specified by the user as a date part (month-day) e.g. \'12-31\'',
            ),
            'date_year': ToolParameter(
              type: 'integer',
              description: 'The year to remind the user at if specified by the user as a year part e.g. \'2022\'',
            ),
            'message': ToolParameter(
              type: 'string',
              description: 'The message to remind the user e.g. \'Buy more milk\'',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'create_reminder_relative',
        description: 'When the user requires a reminder at a relative time e.g. \'in 5 minutes\' use the create_reminder_relative tool.',
        parameters: ToolParametersSchema(
          properties: {
            'relative_time': ToolParameter(
              type: 'integer',
              description: 'The relative time to remind the user at as n \'time_unit\'s in the future',
              required: true,
            ),
            'time_unit': ToolParameter(
              type: 'string',
              description: 'The unit of time for the relative time. Must be one of: ["seconds", "minutes", "hours", "days", "weeks", "months", "years"]',
              required: true,
            ),
            'message': ToolParameter(
              type: 'string',
              description: 'The message to remind the user e.g. \'Buy more milk\'',
              required: true,
            ),
          },
        ),
      ),
    ];
  }

  // Evaluation dataset matching the Python notebook
  List<EvalSample> getEvalData() {
    return [
      EvalSample("Wake me up at 5 am tomorrow please.", "set_alarm"),
      EvalSample("Write down that i need to go buy groceries for the house tomorrow", "create_note"),
      EvalSample("Hey how are you!", null),
      EvalSample("Set an alarm for 7:30 PM.", "set_alarm"),
      EvalSample("I need an alarm for 6:15 tomorrow morning.", "set_alarm"),
      EvalSample("Remind me to buy milk and eggs.", "create_note"),
      EvalSample("Make a note: pick up dry cleaning on Tuesday.", "create_note"),
      EvalSample("Save this thought: on-device inference is key for privacy.", "create_note"),
      EvalSample("That's great, thanks!", null),
      EvalSample("What is the capital of France?", null),
      EvalSample("Who won the game last night?", null),
      EvalSample("Make a note of the weather in Berlin.", "create_note"),
      EvalSample("I need an alarm for 8:45 in the morning.", "set_alarm"),
      EvalSample("Set an alarm for 11:30 PM tonight.", "set_alarm"),
      EvalSample("Alarm for 6am.", "set_alarm"),
      EvalSample("Can you wake me up at 7:15 am?", "set_alarm"),
      EvalSample("Note to self: buy milk.", "create_note"),
      EvalSample("Remember this: the new inference engine for the react-native app is a priority.", "create_note"),
      EvalSample("I need to make a note about the meeting... just write down 'Follow up with marketing'.", "create_note"),
      EvalSample("Jot this down: need to research more apps for the Cactus library.", "create_note"),
      EvalSample("Create a new note titled 'Gift Ideas' with 'book for mom' in it.", "create_note"),
      EvalSample("What time is it?", null),
      EvalSample("Thanks, that's perfect.", null),
      EvalSample("How do I set an alarm?", null),
      EvalSample("Who was the first person on the moon?", null),
      EvalSample("How old is the Eiffel Tower?", null),
      EvalSample("What's the alarm for?", null),
      EvalSample("Tell me a joke.", null),
    ];
  }

  Future<void> downloadModel() async {
    if (selectedModel == null) return;

    setState(() {
      isDownloading = true;
      outputText = 'Downloading model...';
      downloadProgress = 0.0;
    });

    try {
      await lm.downloadModel(
        model: selectedModel!,
        downloadProcessCallback: (double? progress, String statusMessage, bool isError) {
          setState(() {
            if (isError) {
              outputText = 'Error: $statusMessage';
            } else {
              downloadProgress = progress ?? 0.0;
              outputText = statusMessage;
              if (progress != null) {
                outputText += ' (${(progress * 100).toStringAsFixed(0)}%)';
              }
            }
          });
        },
      );

      setState(() {
        isModelDownloaded = true;
        outputText = 'Model downloaded successfully! Now initialize it.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error downloading model: $e';
      });
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> initializeModel() async {
    if (selectedModel == null) return;

    setState(() {
      isInitializing = true;
      outputText = 'Initializing model...';
    });

    try {
      // Unload any previously loaded model first
      try {
        lm.unload();
      } catch (e) {
        // Ignore errors if no model was loaded
      }

      await lm.initializeModel(
        params: CactusInitParams(
          model: selectedModel!,
        ),
      );

      setState(() {
        isModelLoaded = true;
        outputText = 'Model initialized! Ready to run benchmarks.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error initializing model: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> runBenchmarks() async {
    setState(() {
      isRunningBenchmark = true;
      outputText = 'Running benchmarks...';
      results = [];
    });

    final tools = getTools();
    final evalData = getEvalData();
    int completed = 0;
    int totalTests = evalData.length;

    try {
      for (final sample in evalData) {
        final result = await runSingleEval(sample, tools);
        setState(() {
          results.add(result);
          completed++;
          outputText = 'Running benchmarks... ($completed/$totalTests)';
        });
      }

      // Calculate accuracy metrics
      calculateAccuracy();

      setState(() {
        outputText = 'Benchmarks completed!\nOverall Accuracy: ${(overallAccuracy * 100).toStringAsFixed(1)}%';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error running benchmarks: $e';
      });
    } finally {
      setState(() {
        isRunningBenchmark = false;
      });
    }
  }

  Future<BenchmarkResult> runSingleEval(EvalSample sample, List<CactusTool> tools) async {
    try {
      final messages = [
        ChatMessage(
          role: 'system',
          content: 'You are a helpful assistant. You have access to a list of tools. You are communicating via one-shot interactions. If using a tool/function, just call it without asking follow-up questions.',
        ),
        ChatMessage(
          role: 'user',
          content: sample.query,
        ),
      ];

      final result = await lm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 512,
          tools: tools,
        ),
      );

      final toolsCalled = result.toolCalls.map((fc) => fc.name).toList();
      final correctToolCalled = (sample.correctTool == null && toolsCalled.isEmpty) ||
          (sample.correctTool != null && toolsCalled.contains(sample.correctTool));

      return BenchmarkResult(
        query: sample.query,
        correctTool: sample.correctTool,
        toolsCalled: toolsCalled,
        correctToolCalled: correctToolCalled,
        response: result.response,
      );
    } catch (e) {
      return BenchmarkResult(
        query: sample.query,
        correctTool: sample.correctTool,
        toolsCalled: [],
        correctToolCalled: false,
        response: 'Error: $e',
      );
    }
  }

  void calculateAccuracy() {
    if (results.isEmpty) return;

    // Overall accuracy
    final correctCount = results.where((r) => r.correctToolCalled).length;
    overallAccuracy = correctCount / results.length;

    // Accuracy by tool
    final toolGroups = <String, List<BenchmarkResult>>{};
    for (final result in results) {
      final tool = result.correctTool ?? 'none';
      toolGroups.putIfAbsent(tool, () => []).add(result);
    }

    accuracyByTool = {};
    toolGroups.forEach((tool, results) {
      final correct = results.where((r) => r.correctToolCalled).length;
      accuracyByTool[tool] = correct / results.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noah Benchmarks'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Model Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Model',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: selectedModel,
                          hint: const Text('Choose a model'),
                          isExpanded: true,
                          items: [
                            'qwen3-0.6',
                            'lfm2-350m',
                            'lfm2-1.2B',
                          ].map((String model) {
                            return DropdownMenuItem<String>(
                              value: model,
                              child: Text(model),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedModel = newValue;
                              isModelDownloaded = false;
                              isModelLoaded = false;
                              results = [];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedModel != null && !isDownloading && !isModelDownloaded)
                            ? downloadModel
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isDownloading
                              ? 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%'
                              : 'Download Model',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isModelDownloaded && !isInitializing && !isModelLoaded)
                            ? initializeModel
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isInitializing ? 'Initializing...' : 'Initialize'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isModelLoaded && !isRunningBenchmark)
                            ? runBenchmarks
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isRunningBenchmark ? 'Running...' : 'Run Benchmarks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    outputText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Results Display
                if (results.isNotEmpty) ...[
                  const Text(
                    'Results:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Accuracy Summary
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Accuracy: ${(overallAccuracy * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Accuracy by Tool:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...accuracyByTool.entries.map((entry) =>
                            Text('  ${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%')
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Detailed Results
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return Card(
                          color: result.correctToolCalled ? Colors.green[50] : Colors.red[50],
                          child: ExpansionTile(
                            title: Text(
                              result.query,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              result.correctToolCalled ? '✓ Correct' : '✗ Incorrect',
                              style: TextStyle(
                                color: result.correctToolCalled ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Expected: ${result.correctTool ?? "none"}'),
                                    Text('Called: ${result.toolsCalled.isEmpty ? "none" : result.toolsCalled.join(", ")}'),
                                    if (result.response != null) ...[
                                      const SizedBox(height: 8),
                                      Text('Response: ${result.response}'),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EvalSample {
  final String query;
  final String? correctTool;

  EvalSample(this.query, this.correctTool);
}

class BenchmarkResult {
  final String query;
  final String? correctTool;
  final List<String> toolsCalled;
  final bool correctToolCalled;
  final String? response;

  BenchmarkResult({
    required this.query,
    required this.correctTool,
    required this.toolsCalled,
    required this.correctToolCalled,
    this.response,
  });
}
