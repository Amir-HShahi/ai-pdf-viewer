import 'dart:async';

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
  bool _isNavigating = false;

  bool _isDraggingScrollHandle = false;
  double _scrollHandlePosition = 0.0; // Tracks visual position (0.0 to 1.0)
  Timer? _scrollDebounceTimer;
  int _lastDragTargetPage = -1;

  bool get isDraggingScrollHandle => _isDraggingScrollHandle;
  double get scrollHandlePosition => _scrollHandlePosition;

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
  }) : _pdfFileService = pdfFileService,
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
    _scrollDebounceTimer?.cancel();
    _pdfDocument?.dispose();
    appBarAnimationController.dispose();
    super.dispose();
  }

  void onScrollHandleDrag(
    DragUpdateDetails details,
    double scrollAreaHeight,
    BuildContext context,
  ) {
    if (_pdfDocument == null || _totalPages <= 1) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final scrollableHeight =
        scrollAreaHeight -
        AppConstants.topMargin -
        AppConstants.bottomMargin -
        AppConstants.handleHeight;

    final relativeY = (localPosition.dy -
            AppConstants.topMargin -
            (AppConstants.handleHeight / 2))
        .clamp(0.0, scrollableHeight);

    // Update visual position immediately for smooth animation
    final newProgress = relativeY / scrollableHeight;
    _scrollHandlePosition = newProgress.clamp(0.0, 1.0);
    _isDraggingScrollHandle = true;

    // Calculate target page
    final targetPage = (1 + (newProgress * (_totalPages - 1))).round().clamp(
      1,
      _totalPages,
    );

    // Only navigate if target page changed and debounce rapid changes
    if (targetPage != _lastDragTargetPage) {
      _lastDragTargetPage = targetPage;

      // Cancel previous timer
      _scrollDebounceTimer?.cancel();

      // Set a short debounce to prevent too many navigation calls
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 50), () {
        if (_isDraggingScrollHandle && targetPage != _currentPage) {
          _navigateToPageSmooth(targetPage);
        }
      });
    }

    notifyListeners();
  }

  void onScrollHandleDragStart(DragStartDetails details) {
    _isDraggingScrollHandle = true;
    _scrollDebounceTimer?.cancel();
    notifyListeners();
  }

  void onScrollHandleDragEnd(DragEndDetails details) {
    _isDraggingScrollHandle = false;
    _scrollDebounceTimer?.cancel();

    // Snap to the current page position
    if (_totalPages > 1) {
      _scrollHandlePosition = (_currentPage - 1) / (_totalPages - 1);
    } else {
      _scrollHandlePosition = 0.0;
    }

    _lastDragTargetPage = -1;
    notifyListeners();
  }

  Future<void> _navigateToPageSmooth(int targetPage) async {
    if (_isNavigating || targetPage == _currentPage) return;

    _isNavigating = true;

    try {
      await pdfViewerController.goToPage(pageNumber: targetPage);
      // Don't update _currentPage here - let onPageChanged handle it
    } catch (e) {
      debugPrint('Error navigating to page $targetPage: $e');
    } finally {
      _isNavigating = false;
    }
  }

  // Update the onPageChanged method to sync scroll handle position
  void onPageChanged(int? pageNumber) async {
    if (pageNumber != null && pageNumber != _currentPage && !_isNavigating) {
      _currentPage = pageNumber;

      // Update scroll handle position if not dragging
      if (!_isDraggingScrollHandle) {
        if (_totalPages > 1) {
          _scrollHandlePosition = (_currentPage - 1) / (_totalPages - 1);
        } else {
          _scrollHandlePosition = 0.0;
        }
      }

      showAppBar();
      Future.delayed(const Duration(milliseconds: 2000), () {
        hideAppBar();
      });

      if (!_isLoadingLastPdf && _pdfPath != null) {
        try {
          await _pdfStatePersistenceService.savePdfState(
            _pdfPath!,
            _currentPage,
          );
        } catch (e) {
          debugPrint('Error saving PDF state: $e');
        }
      }

      notifyListeners();
    }
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

  Future<void> goToPage(int pageNumber, Function(String) onError) async {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    if (_isNavigating) {
      debugPrint('Navigation already in progress, skipping...');
      return;
    }

    _isNavigating = true;

    try {
      // Use a more reliable method to navigate to the page
      await pdfViewerController.goToPage(pageNumber: pageNumber);

      // Add a small delay to ensure the navigation completes
      await Future.delayed(const Duration(milliseconds: 200));

      // Force update the current page if it hasn't been updated by onPageChanged
      if (_currentPage != pageNumber) {
        _currentPage = pageNumber;

        // Save the page state immediately
        if (_pdfPath != null) {
          await _pdfStatePersistenceService.savePdfState(_pdfPath!, pageNumber);
        }

        // Notify listeners after state is saved
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error going to page $pageNumber: $e');
      onError('Error going to page: $e');
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> goToPagePrecise(int pageNumber, Function(String) onError) async {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Try multiple approaches for better reliability
      bool navigationSuccessful = false;

      //  Direct navigation
      try {
        await pdfViewerController.goToPage(pageNumber: pageNumber);
        await Future.delayed(const Duration(milliseconds: 200));

        if (_currentPage == pageNumber) {
          navigationSuccessful = true;
        }
      } catch (e) {
        debugPrint('Method 1 failed: $e');
      }

      //  If direct navigation didn't work, try with retry
      if (!navigationSuccessful) {
        for (int attempt = 0; attempt < 3 && !navigationSuccessful; attempt++) {
          try {
            await pdfViewerController.goToPage(pageNumber: pageNumber);
            await Future.delayed(Duration(milliseconds: 300 + (attempt * 100)));

            if (_currentPage == pageNumber) {
              navigationSuccessful = true;
              break;
            }
          } catch (e) {
            debugPrint('Retry attempt $attempt failed: $e');
          }
        }
      }

      // Force update if navigation was successful but page wasn't updated
      if (!navigationSuccessful) {
        // Last resort: force update the page number
        _currentPage = pageNumber;
        notifyListeners();

        // Save the state
        if (_pdfPath != null) {
          await _pdfStatePersistenceService.savePdfState(_pdfPath!, pageNumber);
        }
      }
    } catch (e) {
      debugPrint('Error in precise navigation to page $pageNumber: $e');
      onError('Error going to page: $e');
    } finally {
      _isNavigating = false;
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
        // Wait a bit longer for the navigation to complete
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify the navigation was successful
        if (_currentPage != _targetPage!) {
          // Try once more if it didn't work
          await controller.goToPage(pageNumber: _targetPage!);
        }
      } catch (e) {
        debugPrint('Error navigating to saved page: $e');
      }
      Future.delayed(const Duration(milliseconds: 500), _resetLoadingState);
    });
  }
}
