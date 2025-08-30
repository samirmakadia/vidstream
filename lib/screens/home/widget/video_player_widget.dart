import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isActive;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.isActive,
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
    controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: true,
        handleLifecycle: true,
        expandToFill: true,
        fit: BoxFit.cover,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
      betterPlayerDataSource: _ds(widget.videoUrl),
    );

    controller!.setupDataSource(controller!.betterPlayerDataSource!).then((_) {
      final aspect = controller!.videoPlayerController!.value.aspectRatio;
      debugPrint("Video aspect ratio: $aspect");
      controller!.setOverriddenAspectRatio(aspect);

      if (widget.isActive) {
        controller!.play();
      }
      setState(() {});
    });
  }



  BetterPlayerDataSource _ds(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: 5 * 1024 * 1024,
        maxCacheSize: 500 * 1024 * 1024,
        maxCacheFileSize: 60 * 1024 * 1024,
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

    if (oldWidget.videoUrl != widget.videoUrl) {
      controller?.dispose();
      _initializePlayer();
    }

    if (widget.isActive) {
      controller?.play();
    } else {
      controller?.pause();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: BetterPlayer(controller: controller!),
            ),
            if (_showPlayPauseIcon)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  controller!.isPlaying() ?? false ? Icons.pause : Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
