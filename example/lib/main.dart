
import 'package:flutter/material.dart';
import 'basic_completion.dart';
import 'streaming_completion.dart';
import 'function_calling.dart';
import 'hybrid_completion.dart';
import 'fetch_models.dart';
import 'embedding.dart';
import 'rag.dart';

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

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

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
        ],
      ),
    );
  }
}
