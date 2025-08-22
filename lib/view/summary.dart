import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../services/summarizer.dart';

class Summary extends StatelessWidget {
  final String text;

  const Summary({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    final shimmerBaseColor = isDarkMode ? Colors.grey[850]! : Colors.grey[300]!;
    final shimmerHighlightColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Summary"),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: Summarizer.getSummary(text),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading(
              context,
              baseColor: shimmerBaseColor,
              highlightColor: shimmerHighlightColor,
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error generating summary.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  snapshot.data ?? "No summary available",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildShimmerLoading(
    BuildContext context, {
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            10,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                // This color is just a placeholder for the shimmer effect
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
