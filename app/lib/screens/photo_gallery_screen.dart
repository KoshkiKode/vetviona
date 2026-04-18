import 'dart:io';

import 'package:flutter/material.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const PhotoGalleryScreen({
    super.key,
    required this.photoPaths,
    required this.initialIndex,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.photoPaths.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.photoPaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoPaths.length;
    final indicator = '${_currentIndex + 1} / $total';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(indicator, style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: total,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final path = widget.photoPaths[i];
          final file = File(path);
          final exists = file.existsSync();
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: exists
                  ? Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _BrokenImage(),
                    )
                  : const _BrokenImage(),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          indicator,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
        SizedBox(height: 8),
        Text('Image not available',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    );
  }
}
