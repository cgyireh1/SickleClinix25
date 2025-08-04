class UserProfile {
  final String email;
  final String passwordHash;
  final String fullName;
  final String facilityName;
  final String? phoneNumber;
  final String? specialty;
  final String? profileImageUrl;
  final String? firebaseUid;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final bool isSynced;

  UserProfile({
    required this.email,
    required this.passwordHash,
    required this.fullName,
    required this.facilityName,
    this.phoneNumber,
    this.specialty,
    this.profileImageUrl,
    this.firebaseUid,
    required this.createdAt,
    required this.lastUpdated,
    required this.isSynced,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'],
      passwordHash: json['passwordHash'],
      fullName: json['fullName'],
      facilityName: json['facilityName'],
      phoneNumber: json['phoneNumber'],
      specialty: json['specialty'],
      profileImageUrl: json['profileImageUrl'],
      firebaseUid: json['firebaseUid'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isSynced: json['isSynced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'passwordHash': passwordHash,
      'fullName': fullName,
      'facilityName': facilityName,
      'phoneNumber': phoneNumber,
      'specialty': specialty,
      'profileImageUrl': profileImageUrl,
      'firebaseUid': firebaseUid,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  UserProfile copyWith({
    String? email,
    String? passwordHash,
    String? fullName,
    String? facilityName,
    String? phoneNumber,
    String? specialty,
    String? profileImageUrl,
    String? firebaseUid,
    DateTime? createdAt,
    DateTime? lastUpdated,
    bool? isSynced,
  }) {
    return UserProfile(
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      fullName: fullName ?? this.fullName,
      facilityName: facilityName ?? this.facilityName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      specialty: specialty ?? this.specialty,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
