class Student {
  final int? id;
  final String name;
  final String lrn;
  final String grade;
  final String createdAt;

  Student({
    this.id,
    required this.name,
    required this.lrn,
    required this.grade,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lrn': lrn,
        'grade': grade,
        'created_at': createdAt,
      };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['id'] as int?,
        name: map['name'] as String,
        lrn: map['lrn'] as String,
        grade: map['grade'] as String? ?? '',
        createdAt: map['created_at'] as String,
      );
}