class AdminProfile {
  final String id;
  final String email;
  final String role;
  final String fullName;
  final String mobileNumber;
  final String designation;
  final String profileImage;

  AdminProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.mobileNumber,
    required this.designation,
    required this.profileImage,
  });

  factory AdminProfile.fromJson(Map<String, dynamic> json) {
    return AdminProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? 'No Email Provided',
      role: json['role']?.toUpperCase() ?? 'USER',
      fullName: json['fullName'] ?? 'No Name Provided',
      mobileNumber: json['mobileNumber'] ?? 'No Number Provided',
      designation: json['designation'] ?? 'Not Specified',
      profileImage: json['profileImage'] ?? '',
    );
  }
}
