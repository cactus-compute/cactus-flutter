
import 'package:cactus/cactus.dart';

import 'package:flutter/material.dart';
import 'pages/basic_completion.dart';
import 'pages/chat.dart';
import 'pages/embedding.dart';
import 'pages/fetch_models.dart';
import 'pages/function_calling.dart';
import 'pages/hybrid_completion.dart';
import 'pages/rag.dart';
import 'pages/streaming_completion.dart';
import 'pages/stt.dart';
import 'pages/vision.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus Examples',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.black,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
        ),
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
  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cactus Examples'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Basic Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BasicCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Streaming Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StreamingCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Function Calling'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FunctionCallingPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Hybrid Completion'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HybridCompletionPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Fetch Models'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FetchModelsPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Embedding'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmbeddingPage()),
              );
            },
          ),
          ListTile(
            title: const Text('RAG'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RAGPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Speech-to-Text'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const STTPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Chat'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Vision'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VisionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
