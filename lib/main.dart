import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.black,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.black),
        ),
      ),
      home: const PDF(),
    );
  }
}

class PDF extends StatefulWidget {
  const PDF({super.key});

  @override
  State<PDF> createState() => _PDFState();
}

class _PDFState extends State<PDF> {
  late PdfViewerController _pdfViewerController;
  String selectedText = '';
  bool isLoading = false;
  String? pdfPath;
  PdfDocument? pdfDocument;
  int currentPage = 1;
  int totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  Future<void> pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path != null) {
          final document = await PdfDocument.openFile(path);
          setState(() {
            pdfPath = path;
            pdfDocument = document;
            selectedText = ''; // Clear any previous selection
            totalPages = document.pages.length;
            currentPage = 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
      }
    }
  }

  Future<String> getSummary(String text) async {
    try {
      if (text.isEmpty) {
        return 'Error: Text is not provided';
      }

      final response = await http.post(
        Uri.parse('https://ai-pdf-summarizer-api.vercel.app/ai/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'token':
          '',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['ok'] == true && data['message'] == "Text is not provided") {
          return 'Error: Text is not provided';
        }

        if (data.containsKey('data')) {
          return data['data'] ?? 'No summary available';
        }

        return data['summary'] ?? 'No summary available';
      } else {
        return 'Error: Unable to generate summary';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  void showSummaryDialog(String text) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Summary'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<String>(
              future: getSummary(text),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return SingleChildScrollView(
                    child: Text(snapshot.data ?? 'No summary available'),
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: [
          if (selectedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: selectedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text copied to clipboard')),
                );
                setState(() {
                  selectedText = '';
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: () {
                showSummaryDialog(selectedText);
              },
            ),
          ],
          IconButton(icon: const Icon(Icons.file_open), onPressed: pickPDF),
        ],
      ),
      body: Stack(
        children: [
          pdfDocument == null
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Pick a PDF file to view',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
              : PdfViewer.file(
            pdfPath!,
            controller: _pdfViewerController,
            params: PdfViewerParams(
              enableTextSelection: true,
              onViewerReady: (document, controller) {
                // Update total pages when viewer is ready
                setState(() {
                  totalPages = document.pages.length;
                });
              },
              onPageChanged: (pageNumber) {
                setState(() {
                  currentPage = pageNumber!;
                });
              },
              onTextSelectionChange: (selections) {
                if (selections.isNotEmpty) {
                  final selectedTextContent = selections
                      .map((selection) => selection.text)
                      .join(' ');
                  setState(() {
                    selectedText = selectedTextContent;
                  });
                  // Show selection options immediately
                  WidgetsBinding.instance.addPostFrameCallback((_) {});
                } else {
                  setState(() {
                    selectedText = '';
                  });
                }
              },
            ),
          ),
          // Page indicator
          if (pdfDocument != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentPage / $totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    pdfDocument?.dispose();
    super.dispose();
  }
}