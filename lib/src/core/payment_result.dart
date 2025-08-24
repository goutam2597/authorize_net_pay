abstract class PaymentResult {
  const PaymentResult(this.gatewayName);
  final String gatewayName;
  bool get isSuccess;
}

class PaymentSuccess extends PaymentResult {
  const PaymentSuccess(String gatewayName, {this.data}) : super(gatewayName);
  final Map<String, dynamic>? data;
  @override
  bool get isSuccess => true;
}

class PaymentFailure extends PaymentResult {
  const PaymentFailure(String gatewayName, this.message, {this.cause})
      : super(gatewayName);
  final String message;
  final Object? cause;
  @override
  bool get isSuccess => false;
}
