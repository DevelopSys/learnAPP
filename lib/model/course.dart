class Course {
  final int id;
  final String name;
  final String acronym;
  final String code;

  Course({
    required this.id,
    required this.name,
    required this.acronym,
    required this.code,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      name: json['name'],
      acronym: json['acronym'],
      code: json['code'],
    );
  }
}