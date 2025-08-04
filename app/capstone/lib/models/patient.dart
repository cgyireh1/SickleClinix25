import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'patient.g.dart';

@HiveType(typeId: 1)
class Patient extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final int age;
  @HiveField(3)
  final String gender;
  @HiveField(4)
  final String? contact;
  @HiveField(5)
  final bool hasSickleCell;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final DateTime lastUpdated;
  @HiveField(8)
  final String healthworkerId;
  @HiveField(9)
  final bool isSynced;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.contact,
    this.hasSickleCell = false,
    required this.createdAt,
    required this.lastUpdated,
    this.healthworkerId = '',
    this.isSynced = false,
  });

  // Firestore serialization
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'contact': contact,
    'hasSickleCell': hasSickleCell,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'healthworkerId': healthworkerId,
    'isSynced': isSynced,
  };

  factory Patient.fromMap(Map<String, dynamic> map) => Patient(
    id: map['id'] as String,
    name: map['name'] as String,
    age: map['age'] as int,
    gender: map['gender'] as String,
    contact: map['contact'] as String?,
    hasSickleCell: map['hasSickleCell'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
    lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    healthworkerId: map['healthworkerId'] as String? ?? '',
    isSynced: map['isSynced'] as bool? ?? false,
  );

  // Firestore sync methods
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'contact': contact,
      'hasSickleCell': hasSickleCell,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'healthworkerId': healthworkerId,
    };
  }

  factory Patient.fromFirestore(Map<String, dynamic> data) {
    return Patient(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      contact: data['contact'],
      hasSickleCell: data['hasSickleCell'] ?? false,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      healthworkerId: data['healthworkerId'] ?? '',
    );
  }

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    String? contact,
    bool? hasSickleCell,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? healthworkerId,
    bool? isSynced,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      contact: contact ?? this.contact,
      hasSickleCell: hasSickleCell ?? this.hasSickleCell,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      healthworkerId: healthworkerId ?? this.healthworkerId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  static Future<void> syncToCloud(Patient patient) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // Only sync if patient belongs to current user
      if (patient.healthworkerId.isNotEmpty &&
          patient.healthworkerId != user.uid) {
        print(
          'Patient ${patient.id} does not belong to current user, skipping sync',
        );
        return;
      }

      await firestore
          .collection('patients')
          .doc(patient.id)
          .set(patient.toFirestore(), SetOptions(merge: true));

      final updatedPatient = patient.copyWith(isSynced: true);
      try {
        await updatedPatient.save();
      } catch (hiveError) {
        print('Warning: Could not update local sync status: $hiveError');
      }

      print('Synced patient to cloud: ${patient.id}');
    } catch (e) {
      print('Failed to sync patient to cloud: $e');
      rethrow;
    }
  }

  static Future<List<Patient>> loadFromCloud() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return [];

      // Load patients belonging to current user
      final snapshot = await firestore
          .collection('patients')
          .where('healthworkerId', isEqualTo: user.uid)
          .get();

      return snapshot.docs
          .map((doc) => Patient.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Failed to load patients from cloud: $e');
      return [];
    }
  }

  static Future<void> deleteFromCloud(String patientId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await firestore.collection('patients').doc(patientId).delete();

      print('Deleted patient from cloud: $patientId');
    } catch (e) {
      print('Failed to delete patient from cloud: $e');
      rethrow;
    }
  }

  bool get needsSync => healthworkerId.isNotEmpty && !isSynced;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'contact': contact,
    'hasSickleCell': hasSickleCell,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'healthworkerId': healthworkerId,
    'isSynced': isSynced,
  };

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    age: json['age'] ?? 0,
    gender: json['gender'] ?? '',
    contact: json['contact'],
    hasSickleCell: json['hasSickleCell'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
    healthworkerId: json['healthworkerId'] ?? '',
    isSynced: json['isSynced'] ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          age == other.age &&
          gender == other.gender &&
          contact == other.contact &&
          hasSickleCell == other.hasSickleCell &&
          createdAt == other.createdAt &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      age.hashCode ^
      gender.hashCode ^
      (contact?.hashCode ?? 0) ^
      hasSickleCell.hashCode ^
      createdAt.hashCode ^
      lastUpdated.hashCode;
}
