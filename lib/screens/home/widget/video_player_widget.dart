import 'dart:io';
import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isActive;
  final VoidCallback? onVideoCompleted;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.isActive, this.onVideoCompleted,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  BetterPlayerController? controller;
  bool _showPlayPauseIcon = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp,]);
  }

  @override
  void dispose() {
    controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }


  void _initializePlayer() {
    if (!widget.isActive) return;

    controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: false,
        handleLifecycle: true,
        expandToFill: true,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
      betterPlayerDataSource: _ds(widget.videoUrl),
    );

    controller!.setupDataSource(controller!.betterPlayerDataSource!).then((_) {
      final aspect = controller!.videoPlayerController!.value.aspectRatio;
      controller!.setOverriddenAspectRatio(aspect);

      if (widget.isActive) {
        controller!.play();
      }

      controller!.addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
          widget.onVideoCompleted?.call();
        }
      });

      setState(() {});
    });
  }


  BetterPlayerDataSource _ds(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        //useCache: Platform.isAndroid, // disable cache on iOS
        preCacheSize: 2 * 1024 * 1024,
        maxCacheSize: 500 * 1024 * 1024,
        maxCacheFileSize: 20 * 1024 * 1024,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializePlayer();
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Stop old controller if video became inactive
    if (oldWidget.isActive && !widget.isActive) {
      controller?.pause();
      controller?.dispose();
      controller = null;
    }

    // Initialize controller if this video became active
    if (!oldWidget.isActive && widget.isActive) {
      _initializePlayer();
    }

    // Replace video source if URL changed
    if (oldWidget.videoUrl != widget.videoUrl && widget.isActive) {
      controller?.dispose();
      _initializePlayer();
    }
  }


  void playVideo() {
    if (controller != null && !(controller!.isPlaying() ?? false)) {
      controller!.play();
    }
  }

  void pauseVideo() {
    if (controller != null && (controller!.isPlaying() ?? false)) {
      controller!.pause();
    }
  }

  void _togglePlayPause() {
    if (controller == null) return;

    if (controller!.isPlaying() ?? false) {
      controller!.pause();
    } else {
      controller!.play();
    }

    setState(() {
      _showPlayPauseIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final videoController = controller?.videoPlayerController;
    final videoValue = videoController?.value;

    final isBuffering = videoValue?.isBuffering ?? false;
    final isInitialized = controller!.isVideoInitialized() ?? false;


    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: BetterPlayer(controller: controller!),
        ),

        if (!isInitialized || isBuffering)
          const Center(
            child: CircularProgressIndicator(
            ),
          ),

        if (_showPlayPauseIcon)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              controller!.isPlaying() ?? false
                  ? Icons.pause
                  : Icons.play_arrow,
              size: 48,
              color: Colors.white,
            ),
          ),

        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayPause,
          ),
        ),
      ],
    );
  }
}
