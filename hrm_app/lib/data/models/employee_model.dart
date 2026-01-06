import 'package:hrm_app/data/models/user_model.dart';

class Employee {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profilePic;
  final String jobTitle;
  final String subOrganisation;
  final String employeeId;
  final String? bloodGroup;
  final UserModel? user;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profilePic,
    required this.jobTitle,
    required this.subOrganisation,
    required this.employeeId,
    this.bloodGroup,
    this.user,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] as String,
      name: json['name'] as String? ?? 'No Name',
      email: json['email'] as String? ?? 'No Email',
      phone: json['phone'] as String? ?? '',
      profilePic: json['profilePic'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      subOrganisation: json['subOrganisation'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
