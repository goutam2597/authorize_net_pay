import 'package:flutter/material.dart';
import '../../core/payment_gateway.dart';
import '../../core/payment_result.dart';
import 'authnet_acceptjs_webview.dart';

/// Opens your HTTPS Accept.js page in a WebView and returns the opaque token.
/// No secrets in client. You still need a server later to charge with this token.
class AuthNetAcceptJsGateway implements PaymentGateway {
  AuthNetAcceptJsGateway({
    required this.hostedHtmlUrl,
    required this.apiLoginId,
    required this.clientKey,
  });

  final String hostedHtmlUrl; // e.g. https://yourdomain.com/acceptjs.html
  final String apiLoginId;
  final String clientKey;

  @override
  String get name => 'Authorize.Net (Accept.js)';

  @override
  Future<PaymentResult> pay({
    required BuildContext context,
    required int amountSmallestUnit, // metadata only
    required String currency,        // metadata only
    required String email,           // metadata only
    String? reference,
  }) async {
    try {
      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthNetAcceptJsWebView(
            hostedHtmlUrl: hostedHtmlUrl,
            apiLoginId: apiLoginId,
            clientKey: clientKey,
          ),
        ),
      );

      if (result == null) {
        return PaymentFailure(name, 'Cancelled by user.');
      }

      if (result['status'] == 'success') {
        return PaymentSuccess(name, data: {
          'dataDescriptor': result['dataDescriptor'],
          'dataValue': result['dataValue'],
          'amount_cents': amountSmallestUnit,
          'currency': currency,
          'email': email,
          'reference': reference,
        });
      }
      return PaymentFailure(name, 'Tokenization failed.', cause: result);
    } catch (e) {
      return PaymentFailure(name, 'Exception', cause: e);
    }
  }
}
