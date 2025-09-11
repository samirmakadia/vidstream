import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isLocal;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.isLocal = true,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();

    // Use file or network controller based on flag
    if (widget.isLocal) {
      _videoController = VideoPlayerController.file(File(widget.videoUrl));
    } else {
      _videoController = VideoPlayerController.network(widget.videoUrl);
    }

    _videoController.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowPlaybackSpeedChanging: true,
        );
      });
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
