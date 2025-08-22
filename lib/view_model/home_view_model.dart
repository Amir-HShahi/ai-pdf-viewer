import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_file_service.dart';
import '../services/pdf_state_persistence.dart';
import '../utils/app_constants.dart';

class HomeViewModel with ChangeNotifier {
  // Services
  final PdfFileService _pdfFileService;
  final PdfStatePersistenceService _pdfStatePersistenceService;

  // Controllers
  late final PdfViewerController pdfViewerController;
  late final AnimationController appBarAnimationController;
  late final Animation<double> appBarAnimation;
  final TickerProvider vsync;

  // State
  String _selectedText = '';
  String? _pdfPath;
  String? _pdfName;
  PdfDocument? _pdfDocument;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoadingLastPdf = false;
  int? _targetPage;
  bool _isAppBarVisible = true;
  double _lastScrollOffset = 0;

  // Getters for UI
  String get selectedText => _selectedText;
  String? get pdfPath => _pdfPath;
  String? get pdfName => _pdfName;
  PdfDocument? get pdfDocument => _pdfDocument;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isAppBarVisible => _isAppBarVisible;

  HomeViewModel({
    required this.vsync,
    required PdfFileService pdfFileService,
    required PdfStatePersistenceService pdfStatePersistenceService,
  })  : _pdfFileService = pdfFileService,
        _pdfStatePersistenceService = pdfStatePersistenceService {
    _initializeControllers();
  }

  // Initialization & Disposal
  void _initializeControllers() {
    pdfViewerController = PdfViewerController();
    appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );
    appBarAnimation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: appBarAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> initialize() async {
    await _loadLastPdf();
  }

  @override
  void dispose() {
    _pdfDocument?.dispose();
    appBarAnimationController.dispose();
    super.dispose();
  }

  // App Bar Animation Logic
  void handleScroll(double scrollOffset) {
    final scrollDelta = scrollOffset - _lastScrollOffset;
    if (scrollDelta.abs() > 10) {
      if (scrollDelta > 0 && _isAppBarVisible) {
        hideAppBar();
      } else if (scrollDelta < 0 && !_isAppBarVisible) {
        showAppBar();
      }
      _lastScrollOffset = scrollOffset;
    }
  }

  void showAppBar() {
    if (!_isAppBarVisible) {
      _isAppBarVisible = true;
      appBarAnimationController.reverse();
      notifyListeners();
    }
  }

  void hideAppBar() {
    if (_isAppBarVisible) {
      _isAppBarVisible = false;
      appBarAnimationController.forward();
      notifyListeners();
    }
  }

  // PDF Loading Logic
  Future<void> _loadLastPdf() async {
    try {
      final pdfState = await _pdfStatePersistenceService.getLastPdfState();
      if (pdfState == null) return;

      _isLoadingLastPdf = true;
      final document = await PdfDocument.openFile(pdfState['path']);
      final targetPage = (pdfState['page'] as int).clamp(
        1,
        document.pages.length,
      );
      final fileName = (pdfState['path'] as String).split('/').last;

      _pdfPath = pdfState['path'];
      _pdfName = fileName;
      _pdfDocument = document;
      _selectedText = '';
      _totalPages = document.pages.length;
      _currentPage = 1;
      _targetPage = targetPage;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading last PDF: $e');
      await _pdfStatePersistenceService.clearSavedPdf();
      _isLoadingLastPdf = false;
    }
  }

  Future<void> pickPdf(Function(String) onError) async {
    try {
      final result = await _pdfFileService.pickAndLoadPdf();
      if (result != null) {
        final (path, document) = result;
        _resetLoadingState();
        _pdfPath = path;
        _pdfName = path.split('/').last;
        _pdfDocument = document;
        _selectedText = '';
        _totalPages = document.pages.length;
        _currentPage = 1;

        await _pdfStatePersistenceService.savePdfState(path, _currentPage);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      onError('Error loading PDF: $e');
    }
  }

  void _resetLoadingState() {
    _isLoadingLastPdf = false;
    _targetPage = null;
  }

  // Page Navigation Logic
  Future<void> goToPage(int pageNumber, Function(String) onError) async {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    try {
      await pdfViewerController.goToPage(pageNumber: pageNumber);
    } catch (e) {
      onError('Error going to page: $e');
    }
  }

  // Scroll Handle Logic
  void onScrollHandleDrag(
      DragUpdateDetails details,
      double scrollAreaHeight,
      BuildContext context,
      ) {
    if (_pdfDocument == null || _totalPages <= 1) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final scrollableHeight = scrollAreaHeight -
        AppConstants.topMargin -
        AppConstants.bottomMargin -
        AppConstants.handleHeight;
    final relativeY = (localPosition.dy -
        AppConstants.topMargin -
        (AppConstants.handleHeight / 2))
        .clamp(0.0, scrollableHeight);

    final progress = relativeY / scrollableHeight;
    final targetPage = (1 + (progress * (_totalPages - 1))).round().clamp(
      1,
      _totalPages,
    );

    if (targetPage != _currentPage) {
      pdfViewerController.goToPage(pageNumber: targetPage).catchError((e) {
        debugPrint('Error navigating to page $targetPage: $e');
      });
    }
  }

  // PDF Viewer Event Handlers
  void onPageChanged(int? pageNumber) async {
    if (pageNumber != null) {
      _currentPage = pageNumber;
      notifyListeners();

      showAppBar();
      Future.delayed(const Duration(milliseconds: 2000), () => hideAppBar());

      if (!_isLoadingLastPdf && _pdfPath != null) {
        await _pdfStatePersistenceService.savePdfState(_pdfPath!, _currentPage);
      }
    }
  }

  void onTextSelectionChange(selections) {
    _selectedText = selections?.map((s) => s.text).join(' ') ?? '';
    if (_selectedText.isNotEmpty) {
      showAppBar();
    }
    notifyListeners();
  }

  void onViewerReady(PdfDocument document, PdfViewerController controller) {
    _totalPages = document.pages.length;
    notifyListeners();

    if (_isLoadingLastPdf && _targetPage != null && _targetPage! > 1) {
      _navigateToSavedPage(controller);
    } else {
      _resetLoadingState();
    }
  }

  void _navigateToSavedPage(PdfViewerController controller) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await controller.goToPage(pageNumber: _targetPage!);
      } catch (e) {
        debugPrint('Error navigating to saved page: $e');
      }
      Future.delayed(const Duration(milliseconds: 500), _resetLoadingState);
    });
  }
}