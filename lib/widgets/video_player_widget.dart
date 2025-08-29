import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

class VideoPlayerWidgetState extends State<VideoPlayerWidget> with WidgetsBindingObserver {
  VideoPlayerController? controller;
  bool _isInitialized = false;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _wasPlayingBeforeBackground = false;
  bool _isManuallyPaused = false;
  bool _showPlayPauseIcon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo(); 
  }


  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializeVideo();
    }
    
    if (oldWidget.isActive != widget.isActive) {
      _handleActiveStateChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    if (controller != null) {
      controller!.removeListener(_videoListener);
      controller!.dispose();
      controller = null;
    }
    _isInitialized = false;
    _hasError = false;
    _retryCount = 0;
  }

  Future<void> _initializeVideo() async {
    try {
      // Use the actual video URL from widget
      if (widget.videoUrl.isEmpty) {
        throw Exception('Video URL is empty');
      }

      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      
      await controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        
        // Set looping and handle active state
        controller!.setLooping(true);
        _handleActiveStateChange();
        
        // Add listener for when video ends
        controller!.addListener(_videoListener);
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
        
        // Auto-retry with exponential backoff
        if (_retryCount < _maxRetries) {
          _retryCount++;
          final retryDelay = Duration(seconds: _retryCount * 2);
          Future.delayed(retryDelay, () {
            if (mounted && _hasError) {
              _initializeVideo();
            }
          });
        }
      }
    }
  }

  void _videoListener() {
    if (controller != null && mounted) {
      final position = controller!.value.position;
      final duration = controller!.value.duration;
      
      // Only handle completion if we're near the end and video is actually playing
      if (position.inMilliseconds > 0 && 
          duration.inMilliseconds > 0 && 
          position.inMilliseconds >= duration.inMilliseconds - 100) {
        // Video completed - just restart without triggering listener again
        controller!.removeListener(_videoListener);
        controller!.seekTo(Duration.zero).then((_) {
          if (mounted && widget.isActive) {
            controller!.play();
          }
          // Re-add listener after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && controller != null) {
              controller!.addListener(_videoListener);
            }
          });
        });
      }
    }
  }

  void _handleActiveStateChange() {
    if (controller != null && _isInitialized) {
      if (widget.isActive && !_isManuallyPaused) {
        controller!.play();
      } else {
        controller!.pause();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (controller == null || !_isInitialized) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background or being inactive
        _wasPlayingBeforeBackground = controller!.value.isPlaying;
        controller!.pause();
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        if (_wasPlayingBeforeBackground && widget.isActive && !_isManuallyPaused) {
          controller!.play();
        }
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state (platform specific)
        _wasPlayingBeforeBackground = controller!.value.isPlaying;
        controller!.pause();
        break;
    }
  }

  void _togglePlayPause() {
    if (controller != null && _isInitialized) {
      if (controller!.value.isPlaying) {
        controller!.pause();
        _isManuallyPaused = true;
      } else {
        controller!.play();
        _isManuallyPaused = false;
      }
      
      // Show play/pause icon briefly
      setState(() {
        _showPlayPauseIcon = true;
      });
      
      // Hide the icon after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showPlayPauseIcon = false;
          });
        }
      });
      
      // Provide haptic feedback for better user experience
      HapticFeedback.selectionClick();
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!_isInitialized || controller == null) return;

    if (info.visibleFraction == 0) {
      // Fully invisible → force pause
      if (controller!.value.isPlaying) {
        controller!.pause();
      }
    } else {
      // Visible → only play if active & not manually paused
      if (widget.isActive && !_isManuallyPaused) {
        controller!.play();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: VisibilityDetector(
                  key: Key('video_${widget.videoUrl}'),
                  onVisibilityChanged: _handleVisibilityChanged,
                  child: VideoPlayer(controller!),
                ),
              ),
            ),

            // Play/Pause icon overlay
            if (_showPlayPauseIcon)
              Center(
                child: AnimatedOpacity(
                  opacity: _showPlayPauseIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _retryCount >= _maxRetries 
                ? 'Max retries reached' 
                : 'Retrying... (${_retryCount}/$_maxRetries)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _retryCount = 0;
                });
                _initializeVideo();
              },
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}