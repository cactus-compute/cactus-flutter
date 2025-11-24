# Cactus Flutter SDK Examples

This directory contains comprehensive examples demonstrating all the features of the Cactus Flutter SDK. Each example is implemented as a separate page with a clean, consistent UI and complete functionality.

## 📱 Example Structure

The examples are organized as a single Flutter app with navigation to different feature demonstrations:

### Main Navigation (`main.dart`)
- **HomePage**: Central navigation hub with links to all examples
- Clean Material Design interface
- Easy access to all SDK features

### Feature Examples

#### 1. **Basic Completion** (`basic_completion.dart`)
- **What it demonstrates**: Simple, straightforward text completion
- **Features**:
  - Model downloading with progress tracking
  - Model initialization
  - Single-turn text completion
  - Performance metrics (TTFT, TPS)
- **UI**: Clean interface focused on basic completion workflow

#### 2. **Streaming Completion** (`streaming_completion.dart`)  
- **What it demonstrates**: Real-time streaming text generation
- **Features**:
  - Model setup (download + initialization)
  - Live streaming text generation
  - Real-time UI updates as tokens arrive
  - Performance metrics
- **UI**: Focused on streaming experience with live text updates

#### 3. **Function Calling** (`function_calling.dart`)
- **What it demonstrates**: Tool/function calling capabilities
- **Features**:
  - Model setup
  - Structured function definitions
  - Tool call execution
  - Function response handling
- **UI**: Demonstrates weather function calling example

#### 4. **Hybrid Completion** (`hybrid_completion.dart`)
- **What it demonstrates**: Cloud fallback functionality
- **Features**:
  - Cloud-based completion without local model
  - Cactus token authentication
  - Seamless local/cloud switching
- **UI**: Token input field and cloud completion testing

#### 5. **Fetch Models** (`fetch_models.dart`)
- **What it demonstrates**: Model discovery and management
- **Features**:
  - Available models listing
  - Model metadata (size, capabilities, download status)
  - Model filtering and search
  - Refresh functionality
- **UI**: Card-based model listing with detailed information

#### 6. **Embedding Generation** (`embedding.dart`)
- **What it demonstrates**: Text embedding generation
- **Features**:
  - Model setup
  - Text-to-vector conversion
  - Embedding dimensions and vector inspection
- **UI**: Simple embedding generation with vector preview

#### 7. **RAG (Retrieval-Augmented Generation)** (`rag.dart`)
- **What it demonstrates**: Complete RAG implementation
- **Features**:
  - Local vector database setup (ObjectBox)
  - Document storage with embeddings
  - Similarity search
  - Sample document population
  - Interactive query interface
  - Database statistics
- **UI**: Full RAG workflow with search interface and results display

#### 8. **Vision** (`vision.dart`)
- **What it demonstrates**: Image analysis using vision-capable models
- **Features**:
  - Vision model discovery and selection
  - Model downloading with progress tracking
  - Model initialization
  - Image picking from gallery
  - Real-time streaming image analysis
  - Performance metrics (TTFT, TPS)
  - Image preview
- **UI**: Complete vision workflow with image selection, model management, and analysis results

## 🚀 How to Run

1. **Setup Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the App**:
   ```bash
   flutter run
   ```

3. **Navigate Examples**:
   - Start from the main page
   - Tap any example to explore
   - Follow the step-by-step UI prompts

## 📋 Example Flow

### Typical Usage Pattern:
1. **Download Model** → Download required AI model
2. **Initialize Model** → Load model into memory  
3. **Use Features** → Generate text, embeddings, search, etc.
4. **View Results** → See outputs, metrics, and data

### RAG Workflow:
1. **Setup** → Download model, initialize model, initialize RAG
2. **Populate** → Add sample documents to vector database
3. **Search** → Enter queries and find relevant documents
4. **Results** → View similarity-ranked document results

### Vision Workflow:
1. **Select Model** → Choose a vision-capable model from dropdown
2. **Download** → Download the selected vision model
3. **Initialize** → Load model into memory
4. **Pick Image** → Select an image from gallery
5. **Analyze** → Generate streaming description of the image
6. **Results** → View analysis, metrics, and image preview

## 🔧 Configuration

- **Telemetry Token**: Set in each example for analytics
- **Model Selection**: Default to `qwen3-0.6` (customizable)
- **RAG Database**: Stored locally using ObjectBox
- **Sample Data**: Landmark information for RAG demonstration

This example app serves as both a demonstration and a learning resource for integrating the Cactus SDK into Flutter applications.
