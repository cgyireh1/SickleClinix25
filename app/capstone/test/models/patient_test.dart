import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/models/patient.dart';

void main() {
  test('Patient model serializes and deserializes', () {
    final now = DateTime.now();
    final patient = Patient(
      id: '1',
      name: 'Caroline Gyireh',
      age: 30,
      gender: 'Female',
      createdAt: now,
      lastUpdated: now,
    );
    final map = patient.toMap();
    final fromMap = Patient.fromMap(map);
    expect(fromMap.name, 'Caroline Gyireh');
    expect(fromMap.age, 30);
    expect(fromMap.gender, 'Female');
    expect(fromMap.id, '1');
    expect(fromMap.createdAt, now);
    expect(fromMap.lastUpdated, now);
  });

  test('Patient model handles optional fields', () {
    final now = DateTime.now();
    final patient = Patient(
      id: '2',
      name: 'Caroline Gyireh',
      age: 25,
      gender: 'Female',
      contact: 'carolinegy@gmail.com',
      hasSickleCell: true,
      createdAt: now,
      lastUpdated: now,
    );
    final map = patient.toMap();
    final fromMap = Patient.fromMap(map);
    expect(fromMap.contact, 'carolinegy@gmail.com');
    expect(fromMap.hasSickleCell, true);
  });

  test('Patient equality and hashCode', () {
    final now = DateTime.now();
    final patient1 = Patient(
      id: '3',
      name: 'Caroline Gyireh',
      age: 25,
      gender: 'Female',
      contact: 'carolinegy@gmail.com',
      hasSickleCell: true,
      createdAt: now,
      lastUpdated: now,
    );
    final patient2 = Patient(
      id: '3',
      name: 'Caroline Gyireh',
      age: 25,
      gender: 'Female',
      contact: 'carolinegy@gmail.com',
      hasSickleCell: true,
      createdAt: now,
      lastUpdated: now,
    );
    expect(patient1, equals(patient2));
    expect(patient1.hashCode, equals(patient2.hashCode));
  });
} 