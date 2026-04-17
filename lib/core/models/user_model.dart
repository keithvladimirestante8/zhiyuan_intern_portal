import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String username;
  final String email;
  final String address;
  final String birthdate;
  final String course;
  final String gender;
  final String phone;
  final String photoUrl;
  final String resumeUrl;
  final String role;
  final String school;
  final String targetCompletionDate;
  final double requiredHours;
  final bool isVerified;
  final bool profileSetupCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.username,
    required this.email,
    required this.address,
    required this.birthdate,
    required this.course,
    required this.gender,
    required this.phone,
    required this.photoUrl,
    required this.resumeUrl,
    required this.role,
    required this.school,
    required this.targetCompletionDate,
    required this.requiredHours,
    required this.isVerified,
    required this.profileSetupCompleted,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      birthdate: map['birthdate'] ?? '',
      course: map['course'] ?? '',
      gender: map['gender'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photo_url'] ?? '',
      resumeUrl: map['resume_url'] ?? '',
      role: map['role'] ?? 'intern',
      school: map['school'] ?? '',
      targetCompletionDate: map['target_completion_date'] ?? '',
      requiredHours: (map['required_hours'] ?? 0).toDouble(),
      isVerified: map['is_verified'] ?? false,
      profileSetupCompleted: map['profile_setup_completed'] ?? false,
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] as Timestamp).toDate()
          : null,
    );
  }
}
