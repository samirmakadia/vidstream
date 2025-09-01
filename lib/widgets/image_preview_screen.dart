import 'dart:io';
import 'package:flutter/material.dart';

class ImagePreviewScreen extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final bool showUploadButton;
  final bool isAvatar;

  const ImagePreviewScreen({
    Key? key,
    this.imageFile,
    this.imageUrl,
    this.showUploadButton = false,
    this.isAvatar = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 4.0,
              child: _buildPreviewContent(context),
            ),
          ),
          // Close button
          Positioned(
            top: padding.top + 30,
            right: 20,
            child: _buildRoundButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          if (showUploadButton)
            Positioned(
              bottom: padding.bottom + 30,
              right: 20,
              child: _buildRoundButton(
                icon: Icons.send,
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
        ],
      ),
    );
  }

  /// Decides what to show based on imageFile, imageUrl or fallback
  Widget _buildPreviewContent(BuildContext context) {
    if (imageFile != null) {
      return Image.file(
        imageFile!,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        fit: BoxFit.contain,
      );
    } else if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        fit: BoxFit.contain,
      );
    } else {
      // fallback when no image
      if (isAvatar) {
        return Icon(
          Icons.person,
          size: 120,
          color: Theme.of(context).colorScheme.primary,
        );
      } else {
        return Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      }
    }
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
