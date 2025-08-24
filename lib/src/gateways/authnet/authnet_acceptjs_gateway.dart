import 'package:flutter/material.dart';
import '../../core/payment_gateway.dart';
import '../../core/payment_result.dart';
import 'authnet_acceptjs_webview.dart';

/// Client-only gateway that opens Accept.js to tokenize card data and
/// returns the opaque token to Flutter. No secrets, no backend calls.
class AuthNetAcceptJsGateway implements PaymentGateway {
  AuthNetAcceptJsGateway({
    required this.apiLoginId,
    required this.clientKey,
    this.sandbox = true,
  });

  final String apiLoginId; // safe to embed
  final String clientKey;  // safe to embed
  final bool sandbox;

  @override
  String get name => 'Authorize.Net (Accept.js)';

  @override
  Future<PaymentResult> pay({
    required BuildContext context,
    required int amountSmallestUnit, // not used by Accept.js tokenization
    required String currency,        // not used in tokenization
    required String email,           // not used in tokenization
    String? reference,
  }) async {
    try {
      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthNetAcceptJsWebView(
            apiLoginId: apiLoginId,
            clientKey: clientKey,
            sandbox: sandbox,
          ),
        ),
      );

      if (result == null) {
        return PaymentFailure(name, 'Cancelled by user.');
      }

      if (result['status'] == 'success') {
        return PaymentSuccess(name, data: {
          // <-- This is the "token you asked for":
          'dataDescriptor': result['dataDescriptor'],
          'dataValue': result['dataValue'],
          // Include your own metadata if desired:
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
