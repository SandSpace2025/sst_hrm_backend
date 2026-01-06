import 'package:hrm_app/data/models/user_model.dart';

class HR {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profilePicture;
  final String? employeeId;
  final String jobTitle;
  final String subOrganisation;
  final String? bloodGroup;
  final UserModel? user;

  HR({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profilePicture,
    this.employeeId,
    required this.jobTitle,
    required this.subOrganisation,
    this.bloodGroup,
    this.user,
  });

  factory HR.fromJson(Map<String, dynamic> json) {
    return HR(
      id: json['_id'] as String,
      name: json['name'] as String? ?? 'No Name',
      email: json['email'] as String? ?? 'No Email',
      phone: json['phone'] as String? ?? '',
      profilePicture: json['profilePic'] as String? ?? '',
      employeeId: json['employeeId'] as String?,
      jobTitle: json['jobTitle'] as String? ?? '',
      subOrganisation: json['subOrganisation'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  String get profilePic => profilePicture;
}
