import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Displays the Authorize.Net Accept Hosted page using a pre-created token.
/// You must generate `hostedPaymentPageToken` on your server (sandbox or live).
///
/// Sandbox pay page base: https://test.authorize.net/payment/payment
/// Live    pay page base: https://accept.authorize.net/payment/payment
class AuthNetWebView extends StatefulWidget {
  const AuthNetWebView({
    super.key,
    required this.hostedPaymentPageToken,
    this.sandbox = true,
    this.title = 'Pay with Authorize.Net',
  });

  final String hostedPaymentPageToken;
  final bool sandbox;
  final String title;

  @override
  State<AuthNetWebView> createState() => _AuthNetWebViewState();
}

class _AuthNetWebViewState extends State<AuthNetWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _payUrlBase =>
      widget.sandbox
          ? 'https://test.authorize.net/payment/payment'
          : 'https://accept.authorize.net/payment/payment';

  /// Minimal HTML wrapper that posts the token into the Authorize.Net pay page.
  /// Accept Hosted uses a token in either a POST or as a URL param (?token=...).
  /// We use an HTML auto-submitting form to POST the token (recommended).
  String _html(String token) {
    final action = _payUrlBase;
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Authorize.Net</title>
  <style>
    body { font-family: -apple-system, Segoe UI, Roboto, system-ui, sans-serif; margin: 0; }
    .bar { height: 3px; width: 100%; background: #0a7; animation: load 1s infinite; }
    @keyframes load { 0%{opacity:.2} 50%{opacity:1} 100%{opacity:.2} }
  </style>
</head>
<body>
  <div class="bar"></div>
  <form id="payForm" method="post" action="$action">
    <input type="hidden" name="token" value="$token"/>
  </form>
  <script>
    // Auto-submit to open the hosted checkout
    document.getElementById('payForm').submit();

    // The hosted page can redirect back to your return/cancel URLs configured
    // when you requested the token on your server. Those URLs are not handled
    // here; we only observe navigation changes from WebView in Flutter.
  </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (m) {
        // Reserved for future custom messaging if you embed your own wrapper.
        // Accept Hosted itself does not post messages to our JS channel.
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (nav) {
            // Heuristics: infer status by return URL patterns you configured server-side.
            final url = nav.url.toLowerCase();

            // Common patterns you might set as return/cancel endpoints:
            // e.g., https://yourapp/return/success, /return/cancel, /return/error
            if (url.contains('success') || url.contains('approved')) {
              Navigator.pop(context, {'status': 'success', 'url': nav.url});
              return NavigationDecision.prevent;
            }
            if (url.contains('cancel') || url.contains('declined')) {
              Navigator.pop(context, {'status': 'cancelled', 'url': nav.url});
              return NavigationDecision.prevent;
            }
            if (url.contains('error') || url.contains('failure')) {
              Navigator.pop(context, {'status': 'failure', 'url': nav.url});
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_html(widget.hostedPaymentPageToken));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
