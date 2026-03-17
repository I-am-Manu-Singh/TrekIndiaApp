import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewFlyoverScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewFlyoverScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewFlyoverScreen> createState() => _WebViewFlyoverScreenState();
}

class _WebViewFlyoverScreenState extends State<WebViewFlyoverScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Prevent opening external apps via common schemes
            if (url.startsWith('intent:') || 
                url.startsWith('tel:') || 
                url.startsWith('mailto:') || 
                url.startsWith('sms:') ||
                url.startsWith('market:')) {
              return NavigationDecision.prevent;
            }
            
            // Force google maps links to stay in webview by appending specific params if needed is hard, 
            // but we can try to block the app-switch by ensuring navigate instead of launch
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
        ],
      ),
    );
  }
}
