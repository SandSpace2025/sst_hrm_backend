import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/services/api_service.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/data/models/admin_profile.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with TickerProviderStateMixin {
  late Future<AdminProfile> _profileFuture;
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _mainController;
  late AnimationController _formController;
  late AnimationController _imageController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imageScaleAnimation;

  AdminProfile? _initialProfile;
  final _fullNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  String? _selectedDesignation;
  File? _selectedImage;

  bool _hasChanges = false;
  bool _isSaving = false;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Duration _fastAnimDuration = Duration(milliseconds: 200);
  static const Duration _slowAnimDuration = Duration(milliseconds: 500);
  static const Curve _animCurve = Curves.easeInOutCubic;
  static const Curve _bounceCurve = Curves.elasticOut;
  static const Curve _slideCurve = Curves.easeOutBack;

  final List<String> _designationOptions = [
    'Associate Manager',
    'Manager',
    'Senior Manager',
    'Director',
    'CEO (Chief Executive Officer)',
    'COO (Chief Operating Officer)',
    'CFO (Chief Financial Officer)',
  ];

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(vsync: this, duration: _animDuration);
    _formController = AnimationController(
      vsync: this,
      duration: _slowAnimDuration,
    );
    _imageController = AnimationController(
      vsync: this,
      duration: _fastAnimDuration,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainController, curve: _slideCurve));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: _bounceCurve));

    _imageScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _imageController, curve: _bounceCurve));

    _mainController.forward();
    _formController.forward();
    _imageController.forward();

    _profileFuture = _fetchProfileAndSetupControllers();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileNumberController.dispose();
    _mainController.dispose();
    _formController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<AdminProfile> _fetchProfileAndSetupControllers() async {
    final profile = await _fetchProfile();
    _initialProfile = profile;
    _fullNameController.text = profile.fullName;
    _mobileNumberController.text = profile.mobileNumber;

    if (profile.designation.isNotEmpty &&
        _designationOptions.contains(profile.designation)) {
      _selectedDesignation = profile.designation;
    } else {
      _selectedDesignation = null;
    }

    _fullNameController.addListener(_checkForChanges);
    _mobileNumberController.addListener(_checkForChanges);
    return profile;
  }

  Future<AdminProfile> _fetchProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    await adminProvider.loadAdminProfile(token, forceRefresh: false);

    if (adminProvider.adminProfile != null) {
      return adminProvider.adminProfile!;
    }

    throw Exception('Failed to load profile');
  }

  void _checkForChanges() {
    if (_initialProfile == null) return;

    final hasChanged =
        _fullNameController.text != _initialProfile!.fullName ||
        _mobileNumberController.text != _initialProfile!.mobileNumber ||
        _selectedDesignation !=
            (_initialProfile!.designation.isNotEmpty
                ? _initialProfile!.designation
                : null) ||
        _selectedImage != null;

    if (hasChanged != _hasChanges) {
      setState(() {
        _hasChanges = hasChanged;
      });
    }
  }

  Future<void> _handleSaveChanges() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;

      if (_selectedImage != null) {
        await _uploadImageToBackend(_selectedImage!);
      }

      final dataToUpdate = {
        'fullName': _fullNameController.text.trim(),
        'mobileNumber': _mobileNumberController.text.trim(),
        'designation': _selectedDesignation ?? '',
      };

      await _apiService.updateProfile(dataToUpdate, token);

      if (mounted) {
        _showSnackBar('Profile updated successfully!', isError: false);
      }
      _refreshProfile();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to update profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
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

  void _refreshProfile() {
    setState(() {
      _hasChanges = false;
      _selectedImage = null;
      _profileFuture = _fetchProfileAndSetupControllers();
    });
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
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 95,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasChanges = true;
        });
        _showSnackBar(
          'Profile image selected. Click "Save Changes" to update.',
          isError: false,
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to pick image';
      if (e.toString().contains('Permission denied')) {
        errorMessage =
            'Permission denied. Please enable camera and storage permissions in settings.';
      } else if (e.toString().contains('User cancelled')) {
        return;
      } else {
        errorMessage = 'Failed to pick image: ${e.toString()}';
      }
      _showSnackBar(errorMessage);
    }
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
                          vertical: 10,
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
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Open Settings'),
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

  ImageProvider? _getProfileImage(AdminProfile profile) {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (profile.profileImage.isNotEmpty) {
      final imageUrl = '${ApiConstants.baseUrl}${profile.profileImage}';
      return NetworkImage(imageUrl);
    }

    return null;
  }

  Future<void> _uploadImageToBackend(File imageFile) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/api/user/profile/image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      final String fileExtension = imageFile.path.split('.').last.toLowerCase();

      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          imageFile.path,
          contentType: MediaType(
            'image',
            fileExtension == 'jpg' ? 'jpeg' : fileExtension,
          ),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final adminProvider = Provider.of<AdminProvider>(
          context,
          listen: false,
        );
        await adminProvider.loadAdminProfile(token, forceRefresh: true);

        final updatedProfile = await _fetchProfile();
        if (mounted) {
          setState(() {
            _initialProfile = updatedProfile;
            _selectedImage = null;
          });
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
          errorMessage = 'Failed to parse error response: ${response.body}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: AppColors.edgePrimary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading profile...',
            style: TextStyle(
              color: AppColors.edgeTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.edgePrimary,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving changes...',
                      style: TextStyle(
                        color: AppColors.edgeText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: FutureBuilder<AdminProfile>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _initialProfile == null) {
                    return _buildLoadingState();
                  } else if (snapshot.hasError && _initialProfile == null) {
                    return _buildErrorState(snapshot.error.toString());
                  } else if (snapshot.hasData || _initialProfile != null) {
                    final profile = snapshot.data ?? _initialProfile!;
                    return Stack(
                      children: [
                        _buildProfileContent(profile),
                        if (_isSaving) _buildSavingOverlay(),
                      ],
                    );
                  }
                  return const Center(child: Text('No profile data found.'));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(AdminProfile profile) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildAnimatedWidget(
              delay: 0.1,
              child: _buildModernHeader(profile),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAnimatedWidget(
                  delay: 0.2,
                  child: _buildModernFormSection(
                    title: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _buildModernNameField(),
                      const SizedBox(height: 12),
                      _buildModernDesignationDropdown(),
                      const SizedBox(height: 12),
                      _buildModernRoleField(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnimatedWidget(
                  delay: 0.3,
                  child: _buildModernFormSection(
                    title: 'Contact Details',
                    icon: Icons.contact_mail_outlined,
                    children: [
                      _buildModernEmailField(profile),
                      const SizedBox(height: 12),
                      _buildModernPhoneField(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_hasChanges)
                  _buildAnimatedWidget(
                    delay: 0.4,
                    child: _buildModernSaveButton(),
                  ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) {
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _formController,
            curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _formController,
                    curve: Interval(delay, 1.0, curve: Curves.easeOutBack),
                  ),
                ),
            child: Transform.scale(
              scale: Tween<double>(begin: 0.8, end: 1.0)
                  .animate(
                    CurvedAnimation(
                      parent: _formController,
                      curve: Interval(delay, 1.0, curve: Curves.elasticOut),
                    ),
                  )
                  .value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildModernHeader(AdminProfile profile) {
    return AnimatedBuilder(
      animation: _imageController,
      builder: (context, child) {
        return Transform.scale(
          scale: _imageScaleAnimation.value,
          child: Container(
            height: 200,
            decoration: const BoxDecoration(),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 26),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 13),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: _getProfileImage(profile) != null
                              ? Image(
                                  image: _getProfileImage(profile)!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  filterQuality: FilterQuality.high,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return _buildDefaultAvatar(profile);
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar(profile);
                                  },
                                )
                              : _buildDefaultAvatar(profile),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 76),
                                Colors.black.withValues(alpha: 26),
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.edgePrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 76),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(AdminProfile profile) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.edgePrimary.withValues(alpha: 204),
            AppColors.edgePrimary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          profile.email.isNotEmpty ? profile.email[0].toUpperCase() : 'A',
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
            color: Colors.black.withValues(alpha: 20),
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
                  AppColors.edgePrimary.withValues(alpha: 25),
                  AppColors.edgePrimary.withValues(alpha: 13),
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
                        color: AppColors.edgePrimary.withValues(alpha: 76),
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
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _fullNameController,
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

  Widget _buildModernDesignationDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedDesignation,
        isExpanded: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Designation',
          icon: Icons.business_center_outlined,
        ).copyWith(hintText: 'Select a Designation'),
        dropdownColor: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        items: _designationOptions.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedDesignation = newValue;
            _hasChanges = true;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a designation';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernRoleField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: 'ADMIN',
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        decoration:
            _modernInputDecoration(
              labelText: 'Role',
              icon: Icons.badge_outlined,
            ).copyWith(
              filled: true,
              fillColor: AppColors.edgeBackground,
              suffixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildModernEmailField(AdminProfile profile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
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
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _mobileNumberController,
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
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.edgePrimary,
                  AppColors.edgePrimary.withValues(alpha: 204),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgePrimary.withValues(alpha: 102),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSaveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
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
                    const Icon(Icons.save_rounded, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _isSaving ? 'Saving Changes...' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          color: AppColors.edgePrimary.withValues(alpha: 25),
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

  Widget _buildErrorState(String error) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.edgeError.withValues(alpha: 25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.edgeError.withValues(alpha: 76),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.edgeError.withValues(alpha: 25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.edgeError,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        color: AppColors.edgeText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.edgeTextSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.edgePrimary.withValues(
                                alpha: 51,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: OutlinedButton(
                          onPressed: _refreshProfile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.edgePrimary,
                            side: const BorderSide(
                              color: AppColors.edgePrimary,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Try Again',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
