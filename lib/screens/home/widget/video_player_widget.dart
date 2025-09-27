import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isActive;
  final bool shouldPreload;
  final bool isAuto;
  final BetterPlayerController? externalController;
  final VoidCallback? onVideoCompleted;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.isActive,
    required this.isAuto,
    required this.shouldPreload, this.externalController, this.onVideoCompleted,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  BetterPlayerController? controller;
  bool _showPlayPauseIcon = false;
  bool _initialized = false;
  bool _ownsController = true;
  bool _listenersAttached = false;
  double _visibleFraction = 0.0;

  BetterPlayerController? _activeController() {
    return _ownsController ? controller : (widget.externalController ?? controller);
  }

  @override
  void initState() {
    super.initState();
    // Use external prebuilt controller if provided
    if (widget.externalController != null) {
      controller = widget.externalController;
      _ownsController = false;
      _attachListenersOnce();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp,]);
  }

  @override
  void dispose() {
    if (_ownsController) {
      controller?.dispose();
    }else{
      controller?.pause();
    }
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
    if (!(widget.isActive || widget.shouldPreload)) return;
    if (controller != null) return;

    controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: !widget.isAuto,
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

      _attachListenersOnce();
      _updatePlayback();

      setState(() {});
    });
  }

  void _updatePlayback() {
    final ctrl = _activeController();
    if (ctrl == null) return;

    final shouldPlay = widget.isActive && _visibleFraction > 0.5;
    try {
      if (shouldPlay) {
        if (!(ctrl.isPlaying() ?? false)) ctrl.play();
      } else {
        if (ctrl.isPlaying() ?? false) ctrl.pause();
      }
    } catch (_) {}
  }


  BetterPlayerDataSource _ds(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(
        minBufferMs: 2000,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 500,
        bufferForPlaybackAfterRebufferMs: 1000,
      ),
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        //useCache: Platform.isAndroid,
        preCacheSize: 5 * 1024 * 1024,
        maxCacheSize: 500 * 1024 * 1024,
        maxCacheFileSize: 50 * 1024 * 1024,
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

    // Adopt or release external controller if it changed
    if (oldWidget.externalController != widget.externalController) {
      if (widget.externalController != null) {
        // Prefer to use external controller only if we don't already have one
        if (controller == null) {
          controller = widget.externalController;
          _ownsController = false;
          _listenersAttached = false;
          _attachListenersOnce();
          setState(() {});
        }
      } else {
        // External removed; if we didn't own the previous controller, just drop reference
        if (!_ownsController) {
          controller?.pause();
          controller = null;
          _ownsController = true;
          _listenersAttached = false;
          setState(() {});
        }
      }
    }
    if (oldWidget.videoUrl != widget.videoUrl && widget.isActive) {
      _initializePlayer();
    }
    // Stop or keep controller based on preload/active state
    if (oldWidget.isActive && !widget.isActive) {
      if (widget.shouldPreload) {
        try { controller?.pause(); } catch (_) {}
        // keep controller initialized for instant resume
      } else {
        try { controller?.pause(); } catch (_) {}
        if (_ownsController) {
          controller?.dispose();
        }
        controller = null;
      }
    }

    // Initialize controller if this video became active
    if (!oldWidget.isActive && widget.isActive) {
      if (controller == null) {
        _initializePlayer();
      } else {
        _updatePlayback();
      }
    }

    // Begin preloading if it entered the preload window
    if (!oldWidget.shouldPreload && widget.shouldPreload && !widget.isActive) {
      _initializePlayer();
    }

    // Dispose if it left the preload window and is not active
    if (oldWidget.shouldPreload && !widget.shouldPreload && !widget.isActive) {
      try { controller?.pause(); } catch (_) {}
      if (_ownsController) {
        controller?.dispose();
      }
      controller = null;
      setState(() {});
    }

    // Replace video source if URL changed
    if (oldWidget.videoUrl != widget.videoUrl) {
      if (_ownsController) {
        if (widget.isActive || widget.shouldPreload) {
          controller?.dispose();
          controller = null;
          _initializePlayer();
        } else {
          controller?.dispose();
          controller = null;
        }
      } else {
        // External controller is managed by parent; detach reference without invoking methods
        controller = widget.externalController;
        _listenersAttached = false;
        if (controller != null) {
          _attachListenersOnce();
        }
      }
    }
  }


  void playVideo() {
    final ctrl = _activeController();
    if (ctrl == null) return;
    try {
      if (!(ctrl.isPlaying() ?? false)) {
        ctrl.play();
      }
    } catch (_) {}
  }

  void pauseVideo() {
    final ctrl = _activeController();
    if (ctrl == null) return;
    try {
      if (ctrl.isPlaying() ?? false) {
        ctrl.pause();
      }
    } catch (_) {}
  }

  void _togglePlayPause() {
    final ctrl = _activeController();
    if (ctrl == null) return;
    try {
      final playing = ctrl.isPlaying() ?? false;
      if (playing) {
        ctrl.pause();
      } else {
        ctrl.play();
      }
    } catch (_) {
      return;
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
    final renderController = _ownsController ? controller : (widget.externalController ?? controller);
    if (renderController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    bool isInitialized = false;
    try {
      isInitialized = renderController.isVideoInitialized() ?? false;
    } catch (_) {
      isInitialized = false;
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        _visibleFraction = info.visibleFraction;
        _updatePlayback();

      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isInitialized)
            SizedBox.expand(
              child: BetterPlayer(controller: renderController),
            ),

          if (!isInitialized)
            const Center(
              child: CircularProgressIndicator(),
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
      ),
    );
  }

  void _attachListenersOnce() {
    if (controller == null || _listenersAttached) return;
    controller!.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
        widget.onVideoCompleted?.call();
      }
    });
    _listenersAttached = true;
  }
}
