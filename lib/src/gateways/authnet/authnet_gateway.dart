import 'package:flutter/material.dart';
import '../../core/payment_gateway.dart';
import '../../core/payment_result.dart';
import 'authnet_webview.dart';

/// A client-only gateway that *displays* Accept Hosted when you provide a token.
/// It does not fetch/create tokens (no http).
///
/// Usage pattern:
///   - Provide a `hostedPaymentPageToken` via `tokenProvider` (likely from your backend).
///   - This gateway opens the hosted payment UI and returns a result map with status and url.
class AuthNetGateway implements PaymentGateway {
  AuthNetGateway({
    required this.tokenProvider,
    this.sandbox = true,
  });

  /// Provide a token on demand. You decide how to get it (env var, callback, etc).
  /// For real payments, this must call your server to create the token.
  final Future<String?> Function({
  required int amountCents,
  required String currency, // 'USD'
  required String email,
  String? reference,
  }) tokenProvider;

  final bool sandbox;

  @override
  String get name => 'Authorize.Net';

  @override
  Future<PaymentResult> pay({
    required BuildContext context,
    required int amountSmallestUnit, // cents
    required String currency,
    required String email,
    String? reference,
  }) async {
    // Get the hostedPaymentPageToken from your provider (caller-supplied).
    final token = await tokenProvider(
      amountCents: amountSmallestUnit,
      currency: currency,
      email: email,
      reference: reference,
    );

    if (token == null || token.isEmpty) {
      return PaymentFailure(name, 'Missing hostedPaymentPageToken (client-only).');
    }

    try {
      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthNetWebView(
            hostedPaymentPageToken: token,
            sandbox: sandbox,
          ),
        ),
      );

      if (result == null) {
        return PaymentFailure(name, 'Payment cancelled.');
      }

      final status = (result['status'] ?? '').toString();
      if (status == 'success') {
        return PaymentSuccess(name, data: {
          'currency': currency,
          'amount_cents': amountSmallestUnit,
          'email': email,
          'return_url': result['url'],
        });
      } else if (status == 'cancelled') {
        return PaymentFailure(name, 'Closed by user.', cause: result);
      } else {
        return PaymentFailure(name, 'Payment failed.', cause: result);
      }
    } catch (e) {
      return PaymentFailure(name, 'Exception', cause: e);
    }
  }
}
