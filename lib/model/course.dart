class Course {
  final int id;
  final String name;
  final String acronym;
  final String code;
  final int? level;
  final int? coordinatorUserId;

  Course({
    required this.id,
    required this.name,
    required this.acronym,
    required this.code,
    this.level,
    this.coordinatorUserId,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      acronym: (json['acronym'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      level: json['level'] is int
          ? json['level'] as int
          : int.tryParse(json['level']?.toString() ?? ''),
      coordinatorUserId: json['coordinatorUserId'] is int
          ? json['coordinatorUserId'] as int
          : int.tryParse(json['coordinatorUserId']?.toString() ?? ''),
    );
  }
}