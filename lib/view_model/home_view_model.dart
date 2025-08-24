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

    final relativeY =
    (localPosition.dy -
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

  void onPageChanged(int? pageNumber) async {
    debugPrint(
      '📄 onPageChanged called: pageNumber=$pageNumber, _currentPage=$_currentPage, _isNavigating=$_isNavigating',
    );

    if (pageNumber != null && pageNumber != _currentPage) {
      final previousPage = _currentPage;
      _currentPage = pageNumber;

      debugPrint('✅ Page updated: $previousPage → $_currentPage');

      // Update scroll handle position if not dragging
      if (!_isDraggingScrollHandle) {
        if (_totalPages > 1) {
          _scrollHandlePosition = (_currentPage - 1) / (_totalPages - 1);
        } else {
          _scrollHandlePosition = 0.0;
        }
      }

      // Show app bar briefly on page change, then hide
      showAppBar();
      Future.delayed(const Duration(milliseconds: 2000), () {
        hideAppBar();
      });

      // Save PDF state (but don't save during initial loading)
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
      // Only hide app bar on scroll, don't auto-show
      if (scrollDelta > 0 && _isAppBarVisible) {
        hideAppBar();
      }
      // Removed the auto-show on scroll up
      _lastScrollOffset = scrollOffset;
    }
  }

  // New method: Toggle app bar visibility
  void toggleAppBar() {
    if (_isAppBarVisible) {
      hideAppBar();
    } else {
      showAppBar();
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

  Future<void> goToPageRobust(int pageNumber, Function(String) onError) async {
    debugPrint(
      '🎯 goToPageRobust called: target=$pageNumber, current=$_currentPage',
    );
    debugPrint(
      '📊 Jump details: ${(pageNumber - _currentPage).abs()} pages, direction: ${pageNumber > _currentPage ? "forward" : "backward"}',
    );

    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    if (pageNumber == _currentPage) {
      debugPrint('📍 Already on target page $pageNumber');
      return;
    }

    if (_isNavigating) {
      debugPrint('🚫 Navigation in progress, queuing...');
      // Wait for current navigation to finish
      while (_isNavigating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isNavigating = true;

    try {
      bool success = false;
      final jumpSize = (pageNumber - _currentPage).abs();
      final isBackward = pageNumber < _currentPage;

      // Strategy selection based on jump characteristics
      if (isBackward && jumpSize > 10) {
        debugPrint(
          '📋 Large backward jump detected, using reset strategy first',
        );
        success = await _attemptResetNavigation(pageNumber);
        if (success) return;

        debugPrint('📋 Reset failed, trying step navigation');
        success = await _attemptStepNavigation(pageNumber);
        if (success) return;
      } else if (jumpSize > 20) {
        debugPrint('📋 Very large jump detected, using step navigation');
        success = await _attemptStepNavigation(pageNumber);
        if (success) return;
      }

      // Strategy 1: Direct navigation
      debugPrint('📋 Strategy 1: Direct navigation');
      success = await _attemptNavigation(pageNumber, 'Direct');
      if (success) return;

      // Strategy 2: Reset and navigate (especially for backward jumps)
      if (isBackward) {
        debugPrint('📋 Strategy 2: Reset approach for backward navigation');
        success = await _attemptResetNavigation(pageNumber);
        if (success) return;
      }

      // Strategy 3: Step-by-step navigation
      debugPrint('📋 Strategy 3: Step-by-step navigation');
      success = await _attemptStepNavigation(pageNumber);
      if (success) return;

      // Strategy 4: Force navigation with state sync
      debugPrint('📋 Strategy 4: Force navigation');
      success = await _attemptForceNavigation(pageNumber);
      if (success) return;

      // All strategies failed
      debugPrint('💥 All navigation strategies failed');
      onError('Unable to navigate to page $pageNumber. All methods failed.');
    } catch (e) {
      debugPrint('❌ Critical error in robust navigation: $e');
      onError('Navigation error: $e');
    } finally {
      _isNavigating = false;
    }
  }

  Future<bool> _attemptNavigation(int pageNumber, String method) async {
    try {
      debugPrint('🚀 $method: Navigating to page $pageNumber');
      debugPrint('🎮 Using controller: ${pdfViewerController.hashCode}');

      await pdfViewerController.goToPage(pageNumber: pageNumber);

      // Check multiple times with increasing delays
      for (int i = 0; i < 8; i++) {
        await Future.delayed(Duration(milliseconds: 50 + (i * 50)));
        debugPrint(
          '🔍 $method check $i: current=$_currentPage, target=$pageNumber',
        );

        if (_currentPage == pageNumber) {
          debugPrint('✅ $method: Success!');
          return true;
        }

        // Try to trigger a controller state check
        try {
          final currentPageFromController =
          await _getCurrentPageFromController();
          debugPrint(
            '📄 Controller says current page: $currentPageFromController',
          );

          if (currentPageFromController == pageNumber &&
              _currentPage != pageNumber) {
            debugPrint(
              '🔄 Controller is at target but state not synced, updating...',
            );
            _currentPage = pageNumber;
            notifyListeners();
            return true;
          }
        } catch (e) {
          debugPrint('⚠️ Could not get page from controller: $e');
        }
      }

      debugPrint('❌ $method: Failed to reach target');
      return false;
    } catch (e) {
      debugPrint('❌ $method: Exception - $e');
      return false;
    }
  }

  Future<int?> _getCurrentPageFromController() async {
    try {
      // Try to get current page from controller if possible
      // Note: This might not be available in all PDF viewer implementations
      return null; // Placeholder - implement if your PDF controller supports it
    } catch (e) {
      return null;
    }
  }

  Future<bool> _attemptStepNavigation(int pageNumber) async {
    try {
      debugPrint('👣 Step navigation: $_currentPage → $pageNumber');

      final direction = pageNumber > _currentPage ? 1 : -1;
      final totalSteps = (pageNumber - _currentPage).abs();

      // For large jumps, use smaller steps
      if (totalSteps > 10) {
        debugPrint(
          '👣 Large jump detected ($totalSteps pages), using careful navigation',
        );

        // For backward navigation, try going to page 1 first, then target
        if (direction < 0) {
          debugPrint('👣 Backward jump: Going to page 1 first');
          if (await _attemptNavigation(1, 'Step-Reset')) {
            await Future.delayed(const Duration(milliseconds: 300));
            return await _attemptNavigation(pageNumber, 'Step-Final');
          }
          return false;
        }

        // For forward navigation, break into smaller chunks
        final stepSize = (totalSteps / 4).ceil(); // Use 4 steps max
        int currentTarget = _currentPage;

        for (int step = 0; step < 4; step++) {
          final nextTarget = currentTarget + (stepSize * direction);
          final actualTarget = direction > 0
              ? nextTarget.clamp(currentTarget, pageNumber)
              : nextTarget.clamp(pageNumber, currentTarget);

          debugPrint('👣 Step ${step + 1}/4: Moving to page $actualTarget');

          if (await _attemptNavigation(actualTarget, 'Step')) {
            currentTarget = actualTarget;
            if (actualTarget == pageNumber) {
              debugPrint('✅ Step navigation: Reached target!');
              return true;
            }
            // Small delay between steps
            await Future.delayed(const Duration(milliseconds: 200));
          } else {
            debugPrint('❌ Step navigation: Step failed at page $actualTarget');
            break;
          }
        }
      } else {
        // For smaller jumps, try direct navigation with extra attempts
        debugPrint(
          '👣 Small jump ($totalSteps pages), using direct navigation',
        );
        return await _attemptNavigation(pageNumber, 'Step-Direct');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Step navigation: Exception - $e');
      return false;
    }
  }

  Future<bool> _attemptResetNavigation(int pageNumber) async {
    try {
      debugPrint('🔄 Reset navigation: Going to page 1 first');

      // Go to page 1 first
      if (_currentPage != 1) {
        await pdfViewerController.goToPage(pageNumber: 1);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Now try to go to target page
      return await _attemptNavigation(pageNumber, 'Reset');
    } catch (e) {
      debugPrint('❌ Reset navigation: Exception - $e');
      return false;
    }
  }

  Future<bool> _attemptForceNavigation(int pageNumber) async {
    try {
      debugPrint('⚡ Force navigation: Direct state update + controller call');

      // Update our internal state first
      _currentPage = pageNumber;

      // Update scroll handle position
      if (_totalPages > 1) {
        _scrollHandlePosition = (_currentPage - 1) / (_totalPages - 1);
      }

      // Notify listeners to update UI
      notifyListeners();

      // Try controller navigation
      try {
        await pdfViewerController.goToPage(pageNumber: pageNumber);
        await Future.delayed(const Duration(milliseconds: 500));

        // If the controller worked, great!
        if (_currentPage == pageNumber) {
          debugPrint('✅ Force navigation: Controller sync successful');
          return true;
        }
      } catch (e) {
        debugPrint(
          '⚠️ Force navigation: Controller failed but state updated - $e',
        );
      }

      // Even if controller failed, we've updated our state
      debugPrint('⚡ Force navigation: State forced to page $pageNumber');
      return true;
    } catch (e) {
      debugPrint('❌ Force navigation: Exception - $e');
      return false;
    }
  }

  // SIMPLE: Direct navigation approach (try this first)
  Future<void> goToPageSimple(int pageNumber, Function(String) onError) async {
    debugPrint('🎯 SIMPLE goToPage: $pageNumber (from $_currentPage)');

    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    if (pageNumber == _currentPage) {
      debugPrint('📍 Already on target page $pageNumber');
      return;
    }

    if (_isNavigating) {
      debugPrint('🚫 Navigation in progress, waiting...');
      return;
    }

    _isNavigating = true;

    try {
      // Clear any pending page change callbacks
      debugPrint('🚀 Attempting direct navigation to page $pageNumber');

      // Single, clean call to the controller
      await pdfViewerController.goToPage(pageNumber: pageNumber);

      // Wait for the navigation to complete
      int attempts = 0;
      while (_currentPage != pageNumber && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        debugPrint(
          '⏳ Waiting for page change: current=$_currentPage, target=$pageNumber, attempt=$attempts',
        );
      }

      if (_currentPage == pageNumber) {
        debugPrint('✅ Simple navigation successful!');
      } else {
        debugPrint(
          '⚠️ Simple navigation incomplete. Final page: $_currentPage, Target: $pageNumber',
        );
        // Try one more time
        await pdfViewerController.goToPage(pageNumber: pageNumber);
        await Future.delayed(const Duration(milliseconds: 500));

        if (_currentPage != pageNumber) {
          onError('Navigation failed: Could not reach page $pageNumber');
        }
      }
    } catch (e) {
      debugPrint('❌ Simple navigation error: $e');
      onError('Navigation error: $e');
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> goToPage(int pageNumber, Function(String) onError) async {
    // Try simple approach first
    await goToPageSimple(pageNumber, onError);

    // If it failed, don't try robust - let user try again
    // This prevents multiple navigation attempts from interfering
  }

  // FIXED: Simplified goToPagePrecise method
  Future<void> goToPagePrecise(int pageNumber, Function(String) onError) async {
    if (pageNumber < 1 || pageNumber > _totalPages) {
      onError('Page number must be between 1 and $_totalPages');
      return;
    }

    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Try navigation with retries if needed
      int maxRetries = 3;
      bool success = false;

      for (int attempt = 0; attempt < maxRetries && !success; attempt++) {
        try {
          await pdfViewerController.goToPage(pageNumber: pageNumber);

          // Wait progressively longer for each attempt
          await Future.delayed(Duration(milliseconds: 200 + (attempt * 100)));

          // Check if we reached the target page
          if (_currentPage == pageNumber) {
            success = true;
            break;
          }
        } catch (e) {
          debugPrint('Navigation attempt ${attempt + 1} failed: $e');
          if (attempt == maxRetries - 1) {
            rethrow; // Rethrow on final attempt
          }
        }
      }

      if (!success) {
        onError(
          'Failed to navigate to page $pageNumber after $maxRetries attempts',
        );
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
    debugPrint('📱 PDF Viewer Ready: totalPages=${document.pages.length}');
    debugPrint(
      '🎮 Controller instances: passed=${controller.hashCode}, stored=${pdfViewerController.hashCode}',
    );
    debugPrint('🔄 Controllers match: ${controller == pdfViewerController}');

    _totalPages = document.pages.length;

    // Ensure we're using the same controller instance
    if (controller != pdfViewerController) {
      debugPrint(
        '⚠️ WARNING: Controller mismatch detected! Updating stored controller.',
      );
      // Don't dispose the old one as it might be in use
      pdfViewerController = controller;
    }

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
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (e) {
        debugPrint('Error navigating to saved page: $e');
      }
      Future.delayed(const Duration(milliseconds: 500), _resetLoadingState);
    });
  }
}