class Payroll {
  final String? id;
  final double totalPay;
  final double bonus;
  final DateTime payPeriod;

  Payroll({
    this.id,
    required this.totalPay,
    required this.bonus,
    required this.payPeriod,
  });

  factory Payroll.fromJson(Map<String, dynamic> json) {
    return Payroll(
      id: json['_id'],
      totalPay: (json['totalPay'] as num).toDouble(),
      bonus: (json['bonus'] as num).toDouble(),
      payPeriod: DateTime.parse(json['payPeriod']),
    );
  }
}
