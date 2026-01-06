import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/common_blood_group_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  late Future<Employee> _profileFuture;

  final _formKey = GlobalKey<FormState>();

  Employee? _initialProfile;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subOrganisationController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  File? _selectedImage;

  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _profileFuture = _fetchProfileAndSetupControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _subOrganisationController.dispose();
    _employeeIdController.dispose();
    _jobTitleController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  Future<Employee> _fetchProfileAndSetupControllers({
    bool forceRefresh = false,
  }) async {
    final profile = await _fetchProfile(forceRefresh: forceRefresh);
    _initialProfile = profile;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _subOrganisationController.text = profile.subOrganisation;
    _employeeIdController.text = profile.employeeId;
    _jobTitleController.text = profile.jobTitle;
    _bloodGroupController.text = profile.bloodGroup ?? '';

    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
    _subOrganisationController.addListener(_checkForChanges);
    _employeeIdController.addListener(_checkForChanges);
    _jobTitleController.addListener(_checkForChanges);
    _bloodGroupController.addListener(_checkForChanges);
    return profile;
  }

  Future<Employee> _fetchProfile({bool forceRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      try {
        await employeeProvider.loadEmployeeProfile(
          authProvider.token!,
          forceRefresh: forceRefresh,
        );
        if (employeeProvider.employeeProfile != null) {
          return employeeProvider.employeeProfile!;
        }
      } catch (e) {}
    }

    throw Exception('Failed to load employee profile');
  }

  void _checkForChanges() {
    if (_initialProfile == null) return;

    final hasChanges =
        _nameController.text != _initialProfile!.name ||
        _phoneController.text != _initialProfile!.phone ||
        _subOrganisationController.text != _initialProfile!.subOrganisation ||
        _employeeIdController.text != _initialProfile!.employeeId ||
        _jobTitleController.text != _initialProfile!.jobTitle ||
        _bloodGroupController.text != (_initialProfile!.bloodGroup ?? '') ||
        _selectedImage != null;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final bool hasPermission = await _checkAndRequestPermission(source);
      if (!hasPermission) {
        _showPermissionDeniedDialog();
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasChanges = true;
        });
        _checkForChanges();
        _showSnackBar(
          'Profile image selected. Click "Save Changes" to update.',
          isError: false,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _handleSaveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );

      if (authProvider.token == null) {
        throw Exception('No authentication token found');
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'subOrganisation': _subOrganisationController.text.trim(),
        'employeeId': _employeeIdController.text.trim(),
        'jobTitle': _jobTitleController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
      };

      if (_selectedImage != null) {
        await _uploadProfilePicture(authProvider.token!);
      }

      await employeeProvider.updateEmployeeProfile(
        updatedData,
        authProvider.token!,
      );

      _initialProfile = Employee(
        id: _initialProfile!.id,
        name: _nameController.text.trim(),
        email: _initialProfile!.email,
        phone: _phoneController.text.trim(),
        profilePic: _selectedImage != null
            ? 'updated'
            : _initialProfile!.profilePic,
        jobTitle: _jobTitleController.text.trim(),
        subOrganisation: _subOrganisationController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        bloodGroup: _bloodGroupController.text.trim(),
        user: _initialProfile!.user,
      );

      setState(() {
        _hasChanges = false;
        _selectedImage = null;
      });

      _showSuccessSnackBar('Profile updated successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _uploadProfilePicture(String token) async {
    if (_selectedImage == null) return;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/api/employee/upload-profile-image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      final String fileExtension = _selectedImage!.path
          .split('.')
          .last
          .toLowerCase();

      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          _selectedImage!.path,
          contentType: MediaType(
            'image',
            fileExtension == 'jpg' ? 'jpeg' : fileExtension,
          ),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['imageUrl'];

        final employeeProvider = Provider.of<EmployeeProvider>(
          context,
          listen: false,
        );
        employeeProvider.updateEmployeeProfilePic(imageUrl);

        await employeeProvider.loadEmployeeProfile(token, forceRefresh: true);

        final updatedProfile = await _fetchProfile(forceRefresh: true);
        if (mounted) {
          setState(() {
            _initialProfile = updatedProfile;
            _selectedImage = null;
            _hasChanges = false;
          });
          _showSnackBar('Profile image updated successfully!', isError: false);
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          if (response.body.startsWith('<!DOCTYPE html>') ||
              response.body.startsWith('<html')) {
            errorMessage =
                'Server returned HTML instead of JSON. Check if server is running correctly.';
          } else {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? 'Unknown error';
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response';
        }
        _showSnackBar('Failed to upload image: $errorMessage', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to upload image: ${e.toString()}', isError: true);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.edgeError : AppColors.edgeAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isDenied) {
          final result = await Permission.camera.request();
          return result.isGranted;
        }
        return cameraStatus.isGranted;
      } else {
        final photosStatus = await Permission.photos.status;
        final storageStatus = await Permission.storage.status;

        if (photosStatus.isGranted || storageStatus.isGranted) {
          return true;
        }

        if (photosStatus.isDenied) {
          final result = await Permission.photos.request();
          if (result.isGranted) return true;
        }

        if (storageStatus.isDenied) {
          final result = await Permission.storage.request();
          if (result.isGranted) return true;
        }

        return false;
      }
    } catch (e) {
      return true;
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.edgeSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.edgeBorder, width: 1),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildImageSourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                const SizedBox(height: 8),
                _buildImageSourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.edgeBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.edgeTextSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.edgeSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.edgeBorder, width: 1),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app needs camera and storage permissions to select profile images. Please enable these permissions in your device settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.edgeTextSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.edgePrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading.rectangular(width: 150, height: 24),
                  SizedBox(height: 8),
                  ShimmerLoading.rectangular(width: 200, height: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Avatar Skeleton
          const Center(child: ShimmerLoading.circular(width: 160)),
          const SizedBox(height: 30),

          // Form Sections Skeleton
          _buildShimmerFormSection(),
          const SizedBox(height: 20),
          _buildShimmerFormSection(),
          const SizedBox(height: 20),
          _buildShimmerFormSection(),
        ],
      ),
    );
  }

  Widget _buildShimmerFormSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading.circular(width: 32),
              SizedBox(width: 12),
              ShimmerLoading.rectangular(width: 120, height: 18),
            ],
          ),
          SizedBox(height: 20),
          ShimmerLoading.rectangular(width: double.infinity, height: 48),
          SizedBox(height: 16),
          ShimmerLoading.rectangular(width: double.infinity, height: 48),
        ],
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.edgeSurface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.edgePrimary.withValues(alpha: 0.1),
                              AppColors.edgePrimary.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: ShimmerLoading.circular(width: 24),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Saving changes...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.edgeError.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.edgeTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _profileFuture = _fetchProfileAndSetupControllers();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgePrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: FutureBuilder<Employee>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _initialProfile == null) {
            return _buildLoadingState();
          } else if (snapshot.hasError && _initialProfile == null) {
            return _buildErrorState(snapshot.error.toString());
          } else if (snapshot.hasData || _initialProfile != null) {
            return Consumer<EmployeeProvider>(
              builder: (context, employeeProvider, child) {
                final profile =
                    employeeProvider.employeeProfile ??
                    (snapshot.data ?? _initialProfile!);

                return Stack(
                  children: [
                    _buildProfileContent(profile),
                    if (_isSaving) _buildSavingOverlay(),
                  ],
                );
              },
            );
          }
          return const Center(child: Text('No profile data found.'));
        },
      ),
    );
  }

  Widget _buildProfileContent(Employee profile) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildModernHeader(profile)),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildModernFormSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  children: [
                    _buildModernNameField(),
                    const SizedBox(height: 20),
                    _buildModernEmployeeIdField(),
                    const SizedBox(height: 20),
                    _buildModernJobTitleField(),
                    const SizedBox(height: 20),
                    _buildModernBloodGroupField(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildModernFormSection(
                  title: 'Contact Information',
                  icon: Icons.mail_outline,
                  children: [
                    _buildModernEmailField(profile),
                    const SizedBox(height: 20),
                    _buildModernPhoneField(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildModernFormSection(
                  title: 'Organization Details',
                  icon: Icons.business_center_outlined,
                  children: [
                    _buildModernSubOrganisationField(),
                    const SizedBox(height: 20),
                    _buildModernRoleField(),
                  ],
                ),
                const SizedBox(height: 20),
                if (_hasChanges) ...[
                  _buildModernSaveButton(),
                  const SizedBox(height: 16),
                ],
                _buildLogoutButton(),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(Employee profile) {
    // Dashboard-style header + Centered Profile Image

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 20),
      child: Column(
        children: [
          // 1. Dashboard-style Header (No Notification Icon)
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Edit & manage your Account',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // No Notification Icon here as per request
            ],
          ),

          const SizedBox(height: 30),

          // 2. Profile Image (Centered & Animated)

          // 2. Profile Image (Centered)
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 160, // Increased from 120
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _getProfileImage(profile) != null
                        ? Image(
                            image: _getProfileImage(profile)!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(profile);
                            },
                          )
                        : _buildDefaultAvatar(profile),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () async {
        // Show confirmation dialog? Or just logout.
        // Usually good practice to confirm.
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        );

        if (shouldLogout == true && mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final employeeProvider = Provider.of<EmployeeProvider>(
            context,
            listen: false,
          );

          employeeProvider.clearData();
          await authProvider.logout(context);

          if (mounted) {
            await Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(
            0xFF00C853,
          ), // Green "Log out" button as in commonly seen designs
          borderRadius: BorderRadius.circular(30), // Pill shape
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Log out',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(Employee profile) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.edgePrimary.withValues(alpha: 0.8),
            AppColors.edgePrimary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'E',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildModernFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.edgePrimary.withValues(alpha: 0.1),
                  AppColors.edgePrimary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.edgePrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNameField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _nameController,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Full Name',
          icon: Icons.person_outline_rounded,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your full name';
          }
          if (value.trim().length < 2) {
            return 'Name must be at least 2 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernEmployeeIdField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _employeeIdController,
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Employee ID',
          icon: Icons.badge_outlined,
        ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
      ),
    );
  }

  Widget _buildModernJobTitleField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _jobTitleController,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Job Title',
          icon: Icons.work_outline_rounded,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your job title';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernBloodGroupField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CommonBloodGroupDropdown(
        controller: _bloodGroupController,
        decoration: _modernInputDecoration(
          labelText: 'Blood Group',
          icon: Icons.bloodtype_outlined,
        ),
      ),
    );
  }

  Widget _buildModernSubOrganisationField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _subOrganisationController,
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Department',
          icon: Icons.business_center_outlined,
        ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
      ),
    );
  }

  Widget _buildModernRoleField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: 'Employee',
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Role',
          icon: Icons.badge_outlined,
        ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
      ),
    );
  }

  Widget _buildModernEmailField(Employee profile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: profile.email,
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        decoration:
            _modernInputDecoration(
              labelText: 'Email Address',
              icon: Icons.mail_outline_rounded,
            ).copyWith(
              filled: true,
              fillColor: AppColors.edgeBackground,
              suffixIcon: const Icon(
                Icons.verified_rounded,
                color: AppColors.edgeAccent,
                size: 20,
              ),
            ),
      ),
    );
  }

  Widget _buildModernPhoneField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _phoneController,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Phone Number',
          icon: Icons.phone_outlined,
        ),
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your mobile number';
          }
          if (value.length != 10) {
            return 'Mobile number must be 10 digits';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernSaveButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF00C853),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _handleSaveChanges,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isSaving ? 'Saving Changes...' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _modernInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.edgeTextSecondary,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.edgePrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: AppColors.edgePrimary, size: 18),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeDivider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeDivider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgePrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: AppColors.edgeSurface,
    );
  }

  ImageProvider? _getProfileImage(Employee profile) {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (profile.profilePic.isNotEmpty) {
      String imageUrl;
      if (profile.profilePic.startsWith('http')) {
        imageUrl = profile.profilePic;
      } else {
        imageUrl = '${ApiConstants.baseUrl}${profile.profilePic}';
      }

      return NetworkImage(imageUrl);
    }

    return null;
  }
}
