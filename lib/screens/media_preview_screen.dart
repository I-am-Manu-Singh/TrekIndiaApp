import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:webview_flutter/webview_flutter.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const MediaPreviewScreen({super.key, required this.url, this.title});

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  WebViewController? _webViewController;
  bool _isVideo = false;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType();
  }

  void _checkMediaType() {
    final lowerUrl = widget.url.toLowerCase();
    if (lowerUrl.contains('.mp4') || lowerUrl.contains('.mov') || lowerUrl.contains('.avi')) {
      _isVideo = true;
      _initVideo();
    } else if (lowerUrl.contains('.pdf')) {
      _isPdf = true;
      _initPdf();
    }
  }

  void _initVideo() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      aspectRatio: 16 / 9,
      errorBuilder: (context, errorMessage) {
        return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
      },
    );
  }

  void _initPdf() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://docs.google.com/viewer?url=${widget.url}&embedded=true'));
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Preview', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: _isVideo
            ? (_chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator())
            : _isPdf
                ? (_webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : const CircularProgressIndicator())
                : InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: widget.url,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                      fit: BoxFit.contain,
                    ),
                  ),
      ),
    );
  }
}
