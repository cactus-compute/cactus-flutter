import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class CactusModelOpaque extends Opaque {}
typedef CactusModel = Pointer<CactusModelOpaque>;

typedef CactusTokenCallbackNative = Void Function(Pointer<Utf8> token, Uint32 tokenId, Pointer<Void> userData);
typedef CactusTokenCallbackDart = void Function(Pointer<Utf8> token, int tokenId, Pointer<Void> userData);

typedef CactusInitNative = CactusModel Function(Pointer<Utf8> modelPath, Size contextSize, Pointer<Utf8> corpusDir);
typedef CactusInitDart = CactusModel Function(Pointer<Utf8> modelPath, int contextSize, Pointer<Utf8> corpusDir);

typedef CactusCompleteNative = Int32 Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    Size bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<Utf8> toolsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);
typedef CactusCompleteDart = int Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    int bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<Utf8> toolsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);

typedef CactusDestroyNative = Void Function(CactusModel model);
typedef CactusDestroyDart = void Function(CactusModel model);

typedef CactusEmbedNative = Int32 Function(
    CactusModel model,
    Pointer<Utf8> text,
    Pointer<Float> embeddingsBuffer,
    Size bufferSize,
    Pointer<Size> embeddingDim);
typedef CactusEmbedDart = int Function(
    CactusModel model,
    Pointer<Utf8> text,
    Pointer<Float> embeddingsBuffer,
    int bufferSize,
    Pointer<Size> embeddingDim);

typedef CactusTranscribeNative = Int32 Function(
    CactusModel model,
    Pointer<Utf8> audioFilePath,
    Pointer<Utf8> prompt,
    Pointer<Utf8> responseBuffer,
    Size bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);
typedef CactusTranscribeDart = int Function(
    CactusModel model,
    Pointer<Utf8> audioFilePath,
    Pointer<Utf8> prompt,
    Pointer<Utf8> responseBuffer,
    int bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);

typedef RegisterAppNative = Pointer<Utf8> Function(
    Pointer<Utf8> encData);
typedef RegisterAppDart = Pointer<Utf8> Function(
    Pointer<Utf8> encData);

typedef GetAllEntriesNative = Pointer<Utf8> Function();
typedef GetAllEntriesDart = Pointer<Utf8> Function();

typedef GetDeviceIdNative = Pointer<Utf8> Function();
typedef GetDeviceIdDart = Pointer<Utf8> Function();