import 'package:flutter/widgets.dart';
import 'payment_result.dart';

abstract class PaymentGateway {
  String get name;

  Future<PaymentResult> pay({
    required BuildContext context,
    required int amountSmallestUnit, // cents for USD
    required String currency,        // 'USD'
    required String email,
    String? reference,
  });
}
