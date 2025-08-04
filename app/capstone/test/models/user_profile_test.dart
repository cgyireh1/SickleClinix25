import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/models/user_profile.dart';

void main() {
  test('UserProfile serializes and deserializes correctly', () {
    final now = DateTime.now();
    final profile = UserProfile(
      email: 'caroline@gmail.com',
      passwordHash: 'hashedpassword',
      fullName: 'Caroline Gyireh',
      facilityName: 'St. Joseph Clinic',
      createdAt: now,
      lastUpdated: now,
      isSynced: false,
      phoneNumber: '+1234567890',
      specialty: 'General Practitioner',
      profileImageUrl: null,
      firebaseUid: null,
    );
    final map = profile.toJson();
    final fromMap = UserProfile.fromJson(map);
    expect(fromMap.email, 'caroline@gmail.com');
    expect(fromMap.fullName, 'Caroline Gyireh');
    expect(fromMap.facilityName, 'St. Joseph Clinic');
    expect(fromMap.specialty, 'General Practitioner');
    expect(fromMap.passwordHash, 'hashedpassword');
    expect(fromMap.createdAt, now);
    expect(fromMap.lastUpdated, now);
    expect(fromMap.isSynced, false);
  });

  test('UserProfile copyWith updates fields', () {
    final now = DateTime.now();
    final profile = UserProfile(
      email: 'caroline@gmail.com',
      passwordHash: 'hash',
      fullName: 'Caroline Gyireh',
      facilityName: 'St. Joseph Clinic',
      createdAt: now,
      lastUpdated: now,
      isSynced: false,
    );
    final updated = profile.copyWith(fullName: 'Azaamaale Gy', isSynced: true);
    expect(updated.fullName, 'Azaamaale Gy');
    expect(updated.isSynced, true);
    expect(updated.email, 'caroline@gmail.com');
  });

  test('UserProfile handles optional fields', () {
    final now = DateTime.now();
    final profile = UserProfile(
      email: 'caroline@gmail.com',
      passwordHash: 'hash',
      fullName: 'Caroline Gyireh',
      facilityName: 'St. Joseph Clinic',
      createdAt: now,
      lastUpdated: now,
      isSynced: false,
    );
    final map = profile.toJson();
    final fromMap = UserProfile.fromJson(map);
    expect(fromMap.phoneNumber, isNull);
    expect(fromMap.specialty, isNull);
    expect(fromMap.profileImageUrl, isNull);
    expect(fromMap.firebaseUid, isNull);
  });
}
