import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/common_blood_group_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/data/models/hr_model.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_loading_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';

class HRProfileScreen extends StatefulWidget {
  const HRProfileScreen({super.key});

  @override
  State<HRProfileScreen> createState() => _HRProfileScreenState();
}

class _HRProfileScreenState extends State<HRProfileScreen>
    with TickerProviderStateMixin {
  late Future<HR> _profileFuture;
  final _formKey = GlobalKey<FormState>();

  late AnimationController _mainController;
  late AnimationController _formController;
  late AnimationController _imageController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  HR? _initialProfile;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subOrganisationController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  File? _selectedImage;

  bool _hasChanges = false;
  bool _isSaving = false;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Duration _fastAnimDuration = Duration(milliseconds: 200);
  static const Duration _slowAnimDuration = Duration(milliseconds: 500);
  static const Curve _animCurve = Curves.easeInOutCubic;
  static const Curve _bounceCurve = Curves.elasticOut;
  static const Curve _slideCurve = Curves.easeOutBack;

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
    ).animate(CurvedAnimation(parent: _imageController, curve: _bounceCurve));

    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
    _subOrganisationController.addListener(_checkForChanges);
    _bloodGroupController.addListener(_checkForChanges);

    _mainController.forward();
    _formController.forward();
    _imageController.forward();

    _profileFuture = _fetchProfileAndSetupControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _subOrganisationController.dispose();
    _bloodGroupController.dispose();
    _mainController.dispose();
    _formController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<HR> _fetchProfileAndSetupControllers({
    bool forceRefresh = false,
  }) async {
    final profile = await _fetchProfile(forceRefresh: forceRefresh);
    _initialProfile = profile;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _subOrganisationController.text = profile.subOrganisation;
    _bloodGroupController.text = profile.bloodGroup ?? '';

    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
    _subOrganisationController.addListener(_checkForChanges);
    _bloodGroupController.addListener(_checkForChanges);
    return profile;
  }

  Future<HR> _fetchProfile({bool forceRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    await hrProvider.loadHRProfile(token, forceRefresh: forceRefresh);

    if (hrProvider.hrProfile == null) {
      throw Exception('Failed to load HR profile');
    }
    return hrProvider.hrProfile!;
  }

  void _checkForChanges() {
    if (_initialProfile == null) return;

    final hasChanged =
        _nameController.text != _initialProfile!.name ||
        _phoneController.text != _initialProfile!.phone ||
        _bloodGroupController.text != (_initialProfile!.bloodGroup ?? '') ||
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
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      if (_selectedImage != null) {
        await hrProvider.uploadProfileImage(_selectedImage!, token);
        // Image upload updates the profile in provider, but we need to update our local state to clear selected image
        if (mounted) {
          setState(() {
            _selectedImage = null;
            _hasChanges = false;
            _initialProfile = hrProvider.hrProfile;
          });
        }
      }

      final dataToUpdate = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
      };

      await hrProvider.updateHRProfile(dataToUpdate, token);

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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _refreshProfile() {
    setState(() {
      _hasChanges = false;
      _selectedImage = null;

      _profileFuture = _fetchProfileAndSetupControllers(forceRefresh: true);
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
        _checkForChanges();
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

  ImageProvider? _getProfileImage(HR profile) {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (profile.profilePicture.isNotEmpty) {
      String imageUrl;
      if (profile.profilePicture.startsWith('http')) {
        imageUrl = profile.profilePicture;
      } else {
        imageUrl = '${ApiConstants.baseUrl}${profile.profilePicture}';
      }

      return NetworkImage(imageUrl);
    }

    return null;
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
              child: FutureBuilder<HR>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _initialProfile == null) {
                    return const CustomLoadingState(
                      message: 'Loading profile...',
                    );
                  } else if (snapshot.hasError && _initialProfile == null) {
                    return CustomErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refreshProfile,
                    );
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

  Widget _buildSavingOverlay() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: AppColors.edgePrimary,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving changes...',
                      style: TextStyle(
                        color: AppColors.edgeText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
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

  Widget _buildProfileContent(HR profile) {
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
                      _buildModernSubOrganisationField(),
                      const SizedBox(height: 12),
                      _buildModernBloodGroupField(),
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

  Widget _buildModernHeader(HR profile) {
    return AnimatedBuilder(
      animation: _imageController,
      builder: (context, child) {
        return Container(
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
                    color: Colors.white.withOpacity(0.1),
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
                    color: Colors.white.withOpacity(0.05),
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
                                      if (loadingProgress == null) return child;
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
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.1),
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
                                color: Colors.black.withOpacity(0.3),
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
        );
      },
    );
  }

  Widget _buildDefaultAvatar(HR profile) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.edgePrimary.withOpacity(0.8),
            AppColors.edgePrimary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          profile.email.isNotEmpty ? profile.email[0].toUpperCase() : 'H',
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
        border: Border.all(color: AppColors.edgeBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.edgePrimary, size: 20),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileCard(HR profile) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeBorder, width: 1),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    border: Border.all(color: AppColors.edgeBorder, width: 2),
                  ),
                  child: ClipOval(
                    child: _getProfileImage(profile) != null
                        ? Image(
                            image: _getProfileImage(profile)!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildDefaultAvatar(profile);
                            },
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.edgeSurface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name.isNotEmpty ? profile.name : 'HR User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.edgePrimary.withOpacity(0.3)),
            ),
            child: const Text(
              'HR Manager',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.edgePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.edgePrimary, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
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
            color: Colors.black.withOpacity(0.05),
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
            return 'Please enter your name';
          }
          if (value.trim().length < 2) {
            return 'Name must be at least 2 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernSubOrganisationField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _subOrganisationController,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: _modernInputDecoration(
          labelText: 'Organisation',
          icon: Icons.business_outlined,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter organisation';
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
            color: Colors.black.withOpacity(0.05),
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

  Widget _buildModernRoleField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: 'HR',
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
                  'HR',
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

  Widget _buildModernEmailField(HR profile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            color: Colors.black.withOpacity(0.05),
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your phone number';
          }
          if (value.length < 10) {
            return 'Phone number must be at least 10 digits';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgePrimary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSaveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.edgePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_outlined, size: 20),
            SizedBox(width: 12),
            Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
          color: AppColors.edgePrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: AppColors.edgePrimary, size: 18),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeBorder, width: 1),
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
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
      decoration: _inputDecoration(
        labelText: 'Full Name',
        icon: Icons.person_outline,
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
    );
  }

  Widget _buildSubOrganisationField() {
    return TextFormField(
      controller: _subOrganisationController,
      readOnly: true,
      style: const TextStyle(fontSize: 14, color: AppColors.edgeTextSecondary),
      decoration: _inputDecoration(
        labelText: 'Organisation',
        icon: Icons.business_center_outlined,
      ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
    );
  }

  Widget _buildRoleField() {
    return TextFormField(
      initialValue: 'HR',
      readOnly: true,
      style: const TextStyle(fontSize: 14, color: AppColors.edgeTextSecondary),
      decoration: _inputDecoration(
        labelText: 'Role',
        icon: Icons.badge_outlined,
      ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
    );
  }

  Widget _buildEmailField(HR profile) {
    return TextFormField(
      initialValue: profile.email,
      readOnly: true,
      style: const TextStyle(fontSize: 14, color: AppColors.edgeTextSecondary),
      decoration: _inputDecoration(
        labelText: 'Email Address',
        icon: Icons.mail_outline,
      ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
      decoration: _inputDecoration(
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
    );
  }

  Widget _buildSaveChangesButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSaveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.edgePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          disabledBackgroundColor: AppColors.edgePrimary.withOpacity(0.5),
        ),
        child: Text(
          _isSaving ? 'Saving...' : 'Save Changes',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.edgeTextSecondary,
      ),
      prefixIcon: Icon(icon, color: AppColors.edgeTextSecondary, size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgePrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
