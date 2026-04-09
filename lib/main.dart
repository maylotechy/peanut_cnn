import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_cropper/image_cropper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Peanut Doctor',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.green,
        fontFamily: 'Outfit',
      ),
      home: const WelcomeScreen(),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  bool _loading = false;
  bool _showResult = false;
  bool _isModelLoaded = false;
  String _prediction = "";
  String _confidenceStr = "";

  // Define custom colors
  final Color _greenColor = const Color(0xFF2EAA78);
  final Color _yellowColor = const Color(0xFFFBC02D);
  final Color _textColor = const Color(0xFF004D40);

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // 1. Load the TFLite Model
  Future<void> _loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/peanut_model_cnn.tflite", // Ensure this matches your asset filename
        labels: "assets/labels.txt",
      );
      print("Model loaded: $res");
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  // 2. Pick an image (Camera or Gallery)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: const Color(0xFF2EAA78),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _image = File(croppedFile.path);
        // Reset results when a new image is picked
        _showResult = false;
        _prediction = "";
        _confidenceStr = "";
      });
      Navigator.pop(context); // Close the modal
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // 3. Reset the App State (Clear screen for new scan)
  void _resetApp() {
    setState(() {
      _image = null;
      _showResult = false;
      _prediction = "";
      _confidenceStr = "";
    });
  }

  // 4. Run AI Classification
  Future<void> _classifyImage() async {
    if (_image == null || !_isModelLoaded) return;

    setState(() {
      _loading = true;
    });

    // Optional: Small delay so the "Analyzing..." animation is visible to the user
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      var output = await Tflite.runModelOnImage(
        path: _image!.path,
        numResults: 1,
        threshold: 0.05,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      setState(() {
        _loading = false;
        _showResult = true;

        if (output != null && output.isNotEmpty) {
          double confidence = output[0]['confidence'];
          String label = output[0]['label'];

          // "Not a Leaf" Logic (Threshold < 70%)
          if (confidence < 0.70) {
            _prediction = "Not a Peanut Leaf";
            _confidenceStr = "Accuracy: ${(confidence * 100).toStringAsFixed(1)}%";
          } else {
            // Remove index numbers (e.g., "0 Early" -> "Early")
            _prediction = label.replaceAll(RegExp(r'[0-9]'), '').trim();
            _confidenceStr = "Accuracy: ${(confidence * 100).toStringAsFixed(1)}%";
          }
        } else {
          _prediction = "Could not identify";
          _confidenceStr = "Try another image";
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      print("Error during classification: $e");
    }
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // --- UI WIDGETS ---

  void _showPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black54),
                title: const Text('Take a Photo'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black54),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Text(
                'Peanut Leaf Disease Detection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a leaf image for disease detection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              // Image Card
              Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: 300,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _image == null
                      ? Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Tap "Select Image" below to begin.',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _image!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Buttons
              Column(
                children: [
                  // Button 1: Select Image (Hide this if results are shown to reduce clutter)
                  if (!_showResult)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _showPickerModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _yellowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Select Image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Button 2: Main Action (Analyzing / Detect / Scan New)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_image == null && !_showResult) || _loading || !_isModelLoaded
                          ? null
                          : () {
                        if (_showResult) {
                          _resetApp(); // Action: Clear Screen
                        } else {
                          _classifyImage(); // Action: Run AI
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _greenColor,
                        disabledBackgroundColor: _greenColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Analyzing...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        _showResult ? 'Scan New Image' : 'Detect Disease',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Results Section
              if (_showResult) ...[
                Text(
                  _prediction == "Not a Peanut Leaf" || _prediction == "Could not identify"
                      ? _prediction
                      : _prediction == 'Healthy'
                          ? 'Status: Healthy plant!'
                          : 'Disease Detected: $_prediction',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _prediction == 'Healthy' ? Colors.green : Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_confidenceStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _confidenceStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _greenColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // App Logo placeholder (using local asset if configured)
              Image.asset(
                'assets/logo.png',
                height: 150,
                width: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.medical_services,
                    size: 150,
                    color: Color(0xFF2EAA78),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Peanut Doctor',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Detect peanut leaf diseases like Rust and Leaf Spot instantly using AI. Keep your crops healthy with professional analysis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EAA78),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}