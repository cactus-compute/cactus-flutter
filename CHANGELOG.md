## 0.2.7

* Agents capable of phone tool use
* Gemma3 270m support
* Separare model download as a separate function

## 0.2.4

* Bugfix
* Openai Compatible Messaging

## 0.2.0

* Changed `visionUrl`/`visionFilename` to `mmprojUrl`/`mmprojFilename` in `CactusVLM.init()`
* Updated to match actual implementation and align with other platforms

## 0.1.4

* added telemetry

## 0.1.3

* bug fix
* simplified APIs

## 0.1.2

* **NEW: Conversation Management API** - Optimized stateful chat with KV cache performance
  * Added `generateResponse()` method for simple text responses
  * Added `continueConversation()` method with detailed performance metrics
  * Added `clearConversation()` method to reset conversation state  
  * Added `isConversationActive()` method to check conversation status
  * Added `ConversationResult` class with timing data (TTFT, total time, tokens/sec)
* **PERFORMANCE: KV Cache Optimization** - Consistent ~70ms TTFT across conversation turns
  * Eliminates conversation length impact on response time
  * 3-6x performance improvement for multi-turn conversations
  * Automatic conversation state management with token appending
* **ENHANCED: Dual-Mode Architecture** in Flutter service
  * Automatic switching between optimized text and multimodal modes
  * Real-time performance tracking with `ValueNotifier`s
  * Enhanced state management and cleanup
* **IMPROVED: FFI Interface** - Complete C FFI bindings for conversation management
  * Added `cactus_generate_response_c`, `cactus_continue_conversation_c`
  * Added `cactus_clear_conversation_c`, `cactus_is_conversation_active_c` 
  * Added `cactus_conversation_result_c_t` struct with performance metrics
  * Proper memory management with `cactus_free_conversation_result_members_c`

## 0.1.0

* Major update with comprehensive API improvements
* Added multimodal completion support with completionSmart method
* Enhanced chat templating with advanced formatting options
* Improved conversation history management and mode switching
* Added tool calling framework for function execution
* Enhanced grammar generation system for structured output
* Added comprehensive error handling and exception types
* Updated example app with modern conversation flow
* Improved memory management and resource cleanup
* Added clear conversation functionality
* Fixed various linter warnings and code quality issues

## 0.0.3

* Fixed an issue with loading the native iOS library when using XCFrameworks.

## 0.0.2

* Fixed an issue with loading the native iOS library when using XCFrameworks.

## 0.0.1

* Initial release