import 'agreement.dart';

class Company {
  final int? id;
  final String nif;
  final String legalName;
  final String activity;
  final String street;
  final String postalCode;
  final String city;
  final String phone;
  final Agreement? agreement;

  Company({
    this.id,
    required this.nif,
    required this.legalName,
    required this.activity,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.phone,
    this.agreement,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      nif: json['nif'] ?? '',
      legalName: json['legalName'] ?? '',
      activity: json['activity'] ?? '',
      street: json['street'] ?? '',
      postalCode: json['postalCode'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone'] ?? '',
      agreement: json['agreement'] != null
          ? Agreement.fromJson(json['agreement'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nif': nif,
      'legalName': legalName,
      'activity': activity,
      'street': street,
      'postalCode': postalCode,
      'city': city,
      'phone': phone,
    };
  }
}