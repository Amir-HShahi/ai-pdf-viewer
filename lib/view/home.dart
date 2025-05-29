import 'package:ai_pdf_viewer/services/summarizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final PdfViewerController _pdfViewerController;

  String selectedText = '';
  String? pdfPath;
  PdfDocument? pdfDocument;
  int currentPage = 1;
  int totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    pdfDocument?.dispose();
    super.dispose();
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result?.files.single.path case final String path) {
        final document = await PdfDocument.openFile(path);
        setState(() {
          pdfPath = path;
          pdfDocument = document;
          selectedText = '';
          totalPages = document.pages.length;
          currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading PDF: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSummaryDialog(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Summary'),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<String>(
                future: Summarizer.getSummary(text),
                builder: (context, snapshot) {
                  return switch (snapshot.connectionState) {
                    ConnectionState.waiting => const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    _ when snapshot.hasError => Text(
                      'Error: ${snapshot.error}',
                    ),
                    _ => SingleChildScrollView(
                      child: Text(snapshot.data ?? 'No summary available'),
                    ),
                  };
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _copySelectedText() {
    Clipboard.setData(ClipboardData(text: selectedText));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Text copied to clipboard')));
    setState(() {
      selectedText = '';
    });
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber != null) {
      setState(() {
        currentPage = pageNumber;
      });
    }
  }

  void _onTextSelectionChange(selections) {
    if (selections.isNotEmpty) {
      final selectedTextContent = selections
          .map((selection) => selection.text)
          .join(' ');
      setState(() {
        selectedText = selectedTextContent;
      });
    } else {
      setState(() {
        selectedText = '';
      });
    }
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    setState(() {
      totalPages = document.pages.length;
    });
  }

  Widget _buildEmptyState() {
    return const Center(
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
    );
  }

  Widget _buildPdfViewer() {
    return PdfViewer.file(
      pdfPath!,
      controller: _pdfViewerController,
      params: PdfViewerParams(
        enableTextSelection: true,
        onViewerReady: _onViewerReady,
        onPageChanged: _onPageChanged,
        onTextSelectionChange: _onTextSelectionChange,
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
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
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (selectedText.isNotEmpty) ...[
        IconButton(icon: const Icon(Icons.copy), onPressed: _copySelectedText),
        IconButton(
          icon: const Icon(Icons.summarize),
          onPressed: () => _showSummaryDialog(selectedText),
        ),
      ],
      IconButton(icon: const Icon(Icons.file_open), onPressed: _pickPDF),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: _buildAppBarActions(),
      ),
      body: Stack(
        children: [
          pdfDocument == null ? _buildEmptyState() : _buildPdfViewer(),
          if (pdfDocument != null) _buildPageIndicator(),
        ],
      ),
    );
  }
}
