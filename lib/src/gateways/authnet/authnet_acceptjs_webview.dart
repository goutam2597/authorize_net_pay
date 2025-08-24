import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A minimal Accept.js form inside a WebView that tokenizes card data on the client
/// and returns `opaqueData` (dataDescriptor, dataValue) back to Flutter.
/// REQUIREMENTS (no secrets needed in app):
///   - apiLoginId (public)
///   - clientKey (public)
///
/// NOTE: You CANNOT charge with this token on the client; you'll need a server
/// to submit the transaction using the opaqueData returned here.
class AuthNetAcceptJsWebView extends StatefulWidget {
  const AuthNetAcceptJsWebView({
    super.key,
    required this.apiLoginId,
    required this.clientKey,
    this.sandbox = true,
    this.title = 'Authorize.Net (Accept.js)',
  });

  final String apiLoginId; // from your sandbox acct (safe to embed)
  final String clientKey;  // generated client key (safe to embed)
  final bool sandbox;      // true => test
  final String title;

  @override
  State<AuthNetAcceptJsWebView> createState() => _AuthNetAcceptJsWebViewState();
}

class _AuthNetAcceptJsWebViewState extends State<AuthNetAcceptJsWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;

  String _html() {
    final acceptJsUrl = widget.sandbox
        ? 'https://jstest.authorize.net/v1/Accept.js'
        : 'https://js.authorize.net/v1/Accept.js';

    final loginId = widget.apiLoginId;
    final clientKey = widget.clientKey;

    // This demo collects card details in the WebView just to get a token.
    // In production, use your own hosted fields/UI and pass them to Accept.js.
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
  <title>Accept.js</title>
  <script type="text/javascript" src="$acceptJsUrl"></script>
  <style>
    body { font-family: -apple-system, Segoe UI, Roboto, system-ui, sans-serif; padding: 16px; }
    input, button { display:block; width:100%; padding:12px; margin:10px 0; border-radius:10px; border:1px solid #ccc; }
    button { background:#0a7; color:#fff; border:0; box-shadow: 0 6px 18px rgba(0,0,0,.1); }
    .small { font-size: 12px; color: #555; }
  </style>
</head>
<body>
  <h3>Get Accept.js Token</h3>
  <label>Card Number</label>
  <input id="cardNumber" placeholder="4111111111111111" value="4111111111111111" />
  <div style="display:flex;gap:10px">
    <div style="flex:1">
      <label>MM</label>
      <input id="expMonth" placeholder="12" value="12" />
    </div>
    <div style="flex:1">
      <label>YYYY</label>
      <input id="expYear" placeholder="2030" value="2030" />
    </div>
  </div>
  <label>CVV</label>
  <input id="cvv" placeholder="123" value="123" />
  <label>ZIP (optional)</label>
  <input id="zip" placeholder="94107" />

  <button id="tokenize">Tokenize (Accept.js)</button>
  <p class="small">This creates an opaque token only. You still need a server to charge.</p>

  <script>
    const FlutterChannel = window.FlutterChannel;

    function send(obj) {
      if (FlutterChannel) FlutterChannel.postMessage(JSON.stringify(obj));
    }

    function handleResponse(response) {
      if (response.messages.resultCode === "Error") {
        send({ event: "error", errors: response.messages.message });
      } else {
        const opaqueData = response.opaqueData || {};
        send({
          event: "success",
          dataDescriptor: opaqueData.dataDescriptor,
          dataValue: opaqueData.dataValue
        });
      }
    }

    function tokenize() {
      const cardData = {
        cardNumber: document.getElementById('cardNumber').value,
        month: document.getElementById('expMonth').value,
        year: document.getElementById('expYear').value,
        cardCode: document.getElementById('cvv').value,
        zip: document.getElementById('zip').value
      };

      const authData = {
        clientKey: "$clientKey",
        apiLoginID: "$loginId"
      };

      Accept.dispatchData({ cardData, authData }, handleResponse);
    }

    document.getElementById('tokenize').addEventListener('click', tokenize);
  </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          if (data['event'] == 'success') {
            Navigator.pop(context, {
              'status': 'success',
              'dataDescriptor': data['dataDescriptor'],
              'dataValue': data['dataValue'],
            });
          } else if (data['event'] == 'error') {
            Navigator.pop(context, { 'status': 'failure', 'errors': data['errors'] });
          }
        } catch (e) {
          Navigator.pop(context, { 'status': 'failure', 'error': e.toString() });
        }
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadHtmlString(_html());
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
