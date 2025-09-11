# Cactus Flutter Plugin

![Cactus Logo](https://github.com/cactus-compute/cactus-flutter/blob/main/assets/logo.png)

Official Flutter plugin for Cactus, a framework for deploying LLM models locally in your app. Currently supports text generation and embeddings. Requires iOS 12.0+, Android API 24+.

## Resources
[![cactus](https://img.shields.io/badge/cactus-000000?logo=github&logoColor=white)](https://github.com/cactus-compute/cactus) [![HuggingFace](https://img.shields.io/badge/HuggingFace-FFD21E?logo=huggingface&logoColor=black)](https://huggingface.co/Cactus-Compute/models?sort=downloads) [![Discord](https://img.shields.io/badge/Discord-5865F2?logo=discord&logoColor=white)](https://discord.gg/bNurx3AXTJ) [![Documentation](https://img.shields.io/badge/Documentation-4285F4?logo=googledocs&logoColor=white)](https://cactuscompute.com/docs)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  cactus:
    git:
      url: https://github.com/cactus-compute/cactus-flutter.git
      ref: v1
```

Then run:

```bash
flutter pub get
```

### iOS Setup

No additional permissions are required for the current version of the Cactus Flutter plugin, which focuses on text-based language model functionality.

### Android Setup

For Android, add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

These permissions are needed for downloading models from the internet.

## Hello World

Here's a simple example to get started with text generation:

```dart
import 'package:cactus/cactus.dart';

void main() async {
  final lm = CactusLM();

  // Download and initialize the default model
  await lm.downloadModel();
  await lm.initializeModel(CactusInitParams());

  // Generate a response
  final result = await lm.generateCompletion(
    messages: [ChatMessage(content: "Hello, world!", role: "user")],
    params: CactusCompletionParams(),
  );

  if (result != null && result.success) {
    print(result.response);
  }

  // Clean up
  lm.unload();
}
```

That's it! For more advanced usage, check the [documentation](https://cactuscompute.com/docs).

## Support

- 📖 [Documentation](https://cactuscompute.com/docs)
- 💬 [Discord Community](https://discord.gg/bNurx3AXTJ)
- 🐛 [Issues](https://github.com/cactus-compute/cactus-flutter/issues)
- 🤗 [Models on Hugging Face](https://huggingface.co/Cactus-Compute/models)