import 'package:flutter/material.dart';

// Web implementation: no-op since we use url_launcher to open forms in new tab
void registerIframe(String viewId, String url) {
  // No-op: iframe embedding replaced with url_launcher for web compatibility
}

Widget buildIframeView(String viewId) {
  return const Center(child: CircularProgressIndicator());
}
