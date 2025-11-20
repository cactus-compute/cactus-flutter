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

typedef RegisterAppNative = Pointer<Utf8> Function(
    Pointer<Utf8> encData);
typedef RegisterAppDart = Pointer<Utf8> Function(
    Pointer<Utf8> encData);

typedef GetAllEntriesNative = Pointer<Utf8> Function();
typedef GetAllEntriesDart = Pointer<Utf8> Function();

typedef GetDeviceIdNative = Pointer<Utf8> Function();
typedef GetDeviceIdDart = Pointer<Utf8> Function();

// Whisper model types
final class WhisperContextOpaque extends Opaque {}
typedef WhisperContext = Pointer<WhisperContextOpaque>;

final class WhisperStateOpaque extends Opaque {}
typedef WhisperState = Pointer<WhisperStateOpaque>;

final class WhisperFullParamsOpaque extends Opaque {}
typedef WhisperFullParams = Pointer<WhisperFullParamsOpaque>;

// Whisper enums
abstract class WhisperSamplingStrategy {
  static const int whisperSamplingGreedy = 0;
  static const int whisperSamplingBeamSearch = 1;
}

// Whisper function bindings
typedef WhisperInitFromFileNative = WhisperContext Function(Pointer<Utf8> pathModel);
typedef WhisperInitFromFileDart = WhisperContext Function(Pointer<Utf8> pathModel);

typedef WhisperFreeNative = Void Function(WhisperContext ctx);
typedef WhisperFreeDart = void Function(WhisperContext ctx);

typedef WhisperFreeParamsNative = Void Function(WhisperFullParams params);
typedef WhisperFreeParamsDart = void Function(WhisperFullParams params);

typedef WhisperFullDefaultParamsByRefNative = WhisperFullParams Function(Int32 strategy);
typedef WhisperFullDefaultParamsByRefDart = WhisperFullParams Function(int strategy);

typedef WhisperFullNative = Int32 Function(
    WhisperContext ctx,
    WhisperFullParams params,
    Pointer<Float> samples,
    Int32 nSamples);
typedef WhisperFullDart = int Function(
    WhisperContext ctx,
    WhisperFullParams params,
    Pointer<Float> samples,
    int nSamples);

typedef WhisperFullNSegmentsNative = Int32 Function(WhisperContext ctx);
typedef WhisperFullNSegmentsDart = int Function(WhisperContext ctx);

typedef WhisperFullGetSegmentTextNative = Pointer<Utf8> Function(WhisperContext ctx, Int32 iSegment);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(WhisperContext ctx, int iSegment);

typedef WhisperFullGetSegmentT0Native = Int64 Function(WhisperContext ctx, Int32 iSegment);
typedef WhisperFullGetSegmentT0Dart = int Function(WhisperContext ctx, int iSegment);

typedef WhisperFullGetSegmentT1Native = Int64 Function(WhisperContext ctx, Int32 iSegment);
typedef WhisperFullGetSegmentT1Dart = int Function(WhisperContext ctx, int iSegment);