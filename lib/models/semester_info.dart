import 'package:uuid/uuid.dart';

import 'schedule_utils.dart';

const Uuid _uuidSemester = Uuid();

class SemesterInfo {
  SemesterInfo({String? id, required this.name, DateTime? termStartMonday})
    : id = id ?? _uuidSemester.v4(),
      termStartMonday = mondayOf(termStartMonday ?? DateTime.now());

  final String id;
  final String name;
  final DateTime termStartMonday;

  SemesterInfo copyWith({String? id, String? name, DateTime? termStartMonday}) {
    return SemesterInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      termStartMonday: termStartMonday ?? this.termStartMonday,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'termStartMonday': termStartMonday.toIso8601String(),
  };

  factory SemesterInfo.fromJson(Map<String, dynamic> json) {
    final DateTime parsedTermStart =
        DateTime.tryParse(json['termStartMonday'] as String? ?? '') ??
        mondayOf(DateTime.now());
    return SemesterInfo(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : '未命名学期',
      termStartMonday: parsedTermStart,
    );
  }
}
