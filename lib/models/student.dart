class Student {
  final int? id;
  final String name;
  final String lrn;
  final String grade;
  final String createdAt;
  final bool isTemp;

  Student({
    this.id,
    required this.name,
    required this.lrn,
    required this.grade,
    required this.createdAt,
    this.isTemp = false,
  });

  /// A temp LRN starts with "TEMP-"
  bool get isTempRecord => isTemp || lrn.startsWith('TEMP-');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lrn': lrn,
        'grade': grade,
        'created_at': createdAt,
        'is_temp': isTemp ? 1 : 0,
      };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'] as int?,
        name: map['name'] as String,
        lrn: map['lrn'] as String,
        grade: map['grade'] as String? ?? '',
        createdAt: map['created_at'] as String,
        isTemp: (map['is_temp'] as int? ?? 0) == 1,
      );
}