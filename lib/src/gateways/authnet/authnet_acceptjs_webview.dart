import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AuthNetAcceptJsWebView extends StatefulWidget {
  const AuthNetAcceptJsWebView({
    super.key,
    required this.hostedHtmlUrl, // e.g. https://yourdomain.com/acceptjs.html
    required this.apiLoginId,
    required this.clientKey,
    this.title = 'Authorize.Net (Accept.js)',
  });

  final String hostedHtmlUrl;
  final String apiLoginId; // public identifier
  final String clientKey;  // client key (public)
  final String title;

  @override
  State<AuthNetAcceptJsWebView> createState() => _AuthNetAcceptJsWebViewState();
}

class _AuthNetAcceptJsWebViewState extends State<AuthNetAcceptJsWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;

  Uri get _url => Uri.parse(widget.hostedHtmlUrl).replace(queryParameters: {
    'apiLoginId': widget.apiLoginId,
    'clientKey': widget.clientKey,
  });

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          final event = data['event'];
          if (event == 'success') {
            Navigator.pop(context, {
              'status': 'success',
              'dataDescriptor': data['dataDescriptor'],
              'dataValue': data['dataValue'],
            });
          } else if (event == 'error') {
            Navigator.pop(context, {'status': 'failure', 'errors': data['errors']});
          }
        } catch (e) {
          Navigator.pop(context, {'status': 'failure', 'error': e.toString()});
        }
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(_url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
