class Agreement {
  final int? id;
  final String? number;
  final String? signDate;

  Agreement({
    this.id,
    this.number,
    this.signDate,
  });

  factory Agreement.fromJson(Map<String, dynamic> json) {
    return Agreement(
      id: json['id'],
      number: json['number'],
      signDate: json['signDate'],
    );
  }
}