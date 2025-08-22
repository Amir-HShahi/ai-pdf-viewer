import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_file_service.dart';
import '../services/pdf_state_persistence.dart';
import '../services/ui_interaction_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/ui_helpers.dart';
import '../view_model/home_view_model.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late final HomeViewModel _viewModel;
  final UiInteractionService _uiService = UiInteractionService();

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(
      vsync: this,
      pdfFileService: PdfFileService(),
      pdfStatePersistenceService: PdfStatePersistenceService(),
    );
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showErrorSnackBar(String message) {
    UIHelpers.showSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _viewModel.pdfDocument == null
              ? _buildEmptyState()
              : _buildPdfViewer(),
          if (_viewModel.pdfDocument != null) _buildPageIndicator(),
          if (_viewModel.pdfDocument != null) _buildScrollHandle(),
          _buildAnimatedAppBar(appBarHeight),
        ],
      ),
    );
  }

  // Widget Builders

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: AppColors.whiteTransparent07,
          ),
          SizedBox(height: 16),
          Text(
            'Pick a PDF file to view',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.whiteTransparent08,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _viewModel.handleScroll(notification.metrics.pixels);
        } else if (notification is ScrollEndNotification) {
          Future.delayed(
            const Duration(milliseconds: 1000),
            _viewModel.showAppBar,
          );
        }
        return false;
      },
      child: PdfViewer.file(
        _viewModel.pdfPath!,
        controller: _viewModel.pdfViewerController,
        params: PdfViewerParams(
          enableTextSelection: true,
          onViewerReady: _viewModel.onViewerReady,
          onPageChanged: _viewModel.onPageChanged,
          onTextSelectionChange: _viewModel.onTextSelectionChange,
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return AnimatedBuilder(
      animation: _viewModel.appBarAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _viewModel.pdfDocument != null ? _jumpToPage : null,
              child: UIHelpers.buildGlassmorphicContainer(
                backgroundColor: AppColors.blackTransparent02,
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_viewModel.currentPage} / ${_viewModel.totalPages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollHandle() {
    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollAreaHeight =
              constraints.maxHeight -
              AppConstants.topMargin -
              AppConstants.bottomMargin;
          final scrollableHeight = scrollAreaHeight - AppConstants.handleHeight;

          final progress =
              _viewModel.isDraggingScrollHandle
                  ? _viewModel.scrollHandlePosition
                  : (_viewModel.totalPages > 1
                      ? (_viewModel.currentPage - 1) /
                          (_viewModel.totalPages - 1)
                      : 0.0);

          final handleTop =
              AppConstants.topMargin + (progress * scrollableHeight);

          return GestureDetector(
            onVerticalDragStart: _viewModel.onScrollHandleDragStart,
            onVerticalDragUpdate:
                (details) => _viewModel.onScrollHandleDrag(
                  details,
                  constraints.maxHeight,
                  context,
                ),
            onVerticalDragEnd: _viewModel.onScrollHandleDragEnd,
            child: SizedBox(
              width: AppConstants.handleWidth,
              height: constraints.maxHeight,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  // Track
                  Positioned(
                    right:
                        (AppConstants.handleWidth - AppConstants.trackWidth) /
                        2,
                    top: AppConstants.topMargin,
                    bottom: AppConstants.bottomMargin,
                    child: UIHelpers.buildGlassmorphicContainer(
                      backgroundColor: AppColors.blackTransparent01,
                      borderRadius: AppConstants.trackWidth / 2,
                      child: const SizedBox(width: AppConstants.trackWidth),
                    ),
                  ),
                  // Handle with smooth animation
                  AnimatedPositioned(
                    duration:
                        _viewModel.isDraggingScrollHandle
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    top: handleTop,
                    child: UIHelpers.buildGlassmorphicContainer(
                      backgroundColor:
                          _viewModel.isDraggingScrollHandle
                              ? AppColors
                                  .blackTransparent03 // Slightly more opaque when dragging
                              : AppColors.blackTransparent02,
                      borderRadius: AppConstants.handleWidth / 2,
                      child: Container(
                        width: AppConstants.handleWidth,
                        height: AppConstants.handleHeight,
                        decoration:
                            _viewModel.isDraggingScrollHandle
                                ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.handleWidth / 2,
                                  ),
                                  border: Border.all(
                                    color: AppColors.whiteTransparent02,
                                    width: 1,
                                  ),
                                )
                                : null,
                        child: const Center(
                          child: Icon(
                            Icons.drag_handle,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Optional: Add page indicator next to handle when dragging
                  if (_viewModel.isDraggingScrollHandle)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 100),
                      top: handleTop - 4,
                      right: AppConstants.handleWidth + 8,
                      child: UIHelpers.buildGlassmorphicContainer(
                        backgroundColor: AppColors.blackTransparent02,
                        borderRadius: 12,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            '${(1 + (_viewModel.scrollHandlePosition * (_viewModel.totalPages - 1))).round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedAppBar(double appBarHeight) {
    return AnimatedBuilder(
      animation: _viewModel.appBarAnimation,
      builder: (context, child) {
        return Positioned(
          top: _viewModel.appBarAnimation.value * appBarHeight,
          left: 0,
          right: 0,
          child: UIHelpers.buildGlassmorphicContainer(
            borderRadius: 0,
            backgroundColor: AppColors.blackTransparent02,
            child: Container(
              height: appBarHeight,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.whiteTransparent02),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _viewModel.pdfName ?? 'PDF Viewer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._buildAppBarActions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (_viewModel.selectedText.isNotEmpty) ...[
        IconButton(
          onPressed: () {
            _uiService.copyToClipboard(context, _viewModel.selectedText);
            _viewModel.onTextSelectionChange(null); // Clear selection
            _viewModel.showAppBar();
          },
          tooltip: 'Copy text',
          icon: const Icon(Icons.copy, color: Colors.white, size: 24),
        ),
        IconButton(
          onPressed:
              () => _uiService.showSummaryScreen(
                context,
                _viewModel.selectedText,
              ),
          tooltip: 'Summarize',
          icon: const Icon(Icons.summarize, color: Colors.white, size: 24),
        ),
      ],
      if (_viewModel.pdfDocument != null)
        IconButton(
          onPressed: _jumpToPage,
          tooltip: 'Go to page',
          icon: const Icon(Icons.numbers, color: Colors.white, size: 24),
        ),
      IconButton(
        onPressed: () => _viewModel.pickPdf(_showErrorSnackBar),
        tooltip: 'Open PDF',
        icon: const Icon(Icons.file_open, color: Colors.white, size: 24),
      ),
    ];
  }

  // UI Action Handlers

  Future<void> _jumpToPage() async {
    _viewModel.showAppBar();
    // The context is captured before the 'await'
    final currentContext = context;
    final pageNumber = await _uiService.showPageJumpDialog(
      currentContext,
      _viewModel.totalPages,
    );

    if (!mounted) return;

    if (pageNumber != null) {
      await _viewModel.goToPage(pageNumber, _showErrorSnackBar);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    }
  }
}
