import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mechlink/services/profile_service.dart';
import 'package:mechlink/screens/login_screen.dart';
import 'package:mechlink/screens/change_password_screen.dart';
import 'package:mechlink/screens/notifications_screen.dart';
import 'package:mechlink/models/mechanic.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;
  Mechanic? _mechanic;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Edit mode controllers
  bool _isEditingPersonal = false;
  bool _isEditingMechanic = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _specializationController = TextEditingController();
  final _employeeIdController = TextEditingController();

  // Validation
  final _formKey = GlobalKey<FormState>();
  String? _selectedCountryCode = '+1';
  String? _selectedDepartment;
  String? _selectedSpecialization;
  MechanicRole? _selectedRole;

  // Bio character count
  int _bioCharCount = 0;

  // Predefined options
  final List<String> _countryCodes = ['+60', '+65', '+66', '+86'];
  final List<String> _departments = [
    'Engine',
    'Transmission',
    'Electrical',
    'Brake System',
    'Suspension',
    'Body Work',
    'Diagnostics',
    'General Maintenance',
  ];
  final List<String> _specializations = [
    'Engine Repair',
    'Transmission Specialist',
    'Electrical Systems',
    'Brake Specialist',
    'Suspension Expert',
    'Body Work',
    'Diagnostic Technician',
    'General Mechanic',
    'Hybrid/Electric Vehicles',
    'Heavy Machinery',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadProfile();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _countryCodeController.dispose();
    _departmentController.dispose();
    _specializationController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      await _profileService.reloadProfile();
      setState(() {
        _mechanic = _profileService.currentMechanic;
        if (_mechanic != null) {
          _nameController.text = _mechanic!.name;
          _phoneController.text = _mechanic!.phone ?? '';
          _bioController.text = _mechanic!.bio ?? '';
          _emailController.text = _mechanic!.email ?? '';
          _departmentController.text = _mechanic!.department ?? '';
          _specializationController.text = _mechanic!.specialization;
          _employeeIdController.text = _mechanic!.employeeId ?? '';
          _selectedDepartment = _mechanic!.department;
          _selectedSpecialization = _mechanic!.specialization;
          _selectedRole = _mechanic!.role;
          _bioCharCount = _bioController.text.length;

          // Extract country code from phone number if exists
          if (_mechanic!.phone != null && _mechanic!.phone!.isNotEmpty) {
            for (String code in _countryCodes) {
              if (_mechanic!.phone!.startsWith(code)) {
                _selectedCountryCode = code;
                _phoneController.text = _mechanic!.phone!.substring(
                  code.length,
                );
                break;
              }
            }
          }
        }
      });
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_mechanic == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            'No profile data available',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                        bottom: 125,
                      ),
                      child: Column(
                        children: [
                          _buildPersonalInfoCard(),
                          const SizedBox(height: 20),
                          _buildProfessionalInfoCard(),
                          const SizedBox(height: 20),
                          _buildActionsCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build Sliver App Bar with gradient background
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF667eea),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Colorful gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                    Color(0xFFf093fb),
                    Color(0xFFf5576c),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            // Floating decorative elements
            Positioned(
              top: 30,
              right: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: 15,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 40,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            // Content - keeping same layout
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      _mechanic!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mechanic!.role.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 1.2,
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
  }

  // Build Profile Avatar with edit functionality
  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(),
            child: ClipOval(
              child: _mechanic!.avatar != null && _mechanic!.avatar!.isNotEmpty
                  ? _buildAvatarImage()
                  : _buildDefaultAvatar(),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _showImagePickerDialog,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (_mechanic!.avatar!.startsWith('data:image')) {
      // Base64 image
      final base64String = _mechanic!.avatar!.split(',')[1];
      final bytes = base64Decode(base64String);
      return Image.memory(bytes, fit: BoxFit.cover, width: 100, height: 100);
    } else {
      // Network image
      return Image.network(
        _mechanic!.avatar!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }
  }

  // Build Card Container
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool isEditable = false,
    bool isEditing = false,
    VoidCallback? onEditPressed,
    VoidCallback? onSave,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (isEditable)
                IconButton(
                  onPressed: isEditing ? onSave : onEditPressed,
                  icon: Icon(
                    isEditing ? Icons.save : Icons.edit,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Save Personal Info
  Future<void> _savePersonalInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fullPhone = _selectedCountryCode! + _phoneController.text.trim();

    final success = await _profileService.updatePersonalInfo(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: fullPhone,
      bio: _bioController.text.trim(),
    );

    if (success) {
      // Update the local mechanic object immediately to reflect changes in UI
      if (_mechanic != null) {
        setState(() {
          _mechanic = Mechanic(
            id: _mechanic!.id,
            name: _nameController.text.trim(),
            avatar: _mechanic!.avatar,
            phone: fullPhone,
            email: _emailController.text.trim(),
            bio: _bioController.text.trim(),
            status: _mechanic!.status,
            role: _mechanic!.role,
            employeeId: _mechanic!.employeeId,
            department: _mechanic!.department,
            specialization: _mechanic!.specialization,
            passwordHash: _mechanic!.passwordHash,
            createdAt: _mechanic!.createdAt,
            updatedAt: DateTime.now(),
            lastLoginAt: _mechanic!.lastLoginAt,
            monthlySalary: _mechanic!.monthlySalary,
          );
          _isEditingPersonal = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    }
  }

  // Save Mechanic Info
  Future<void> _saveMechanicInfo() async {
    final success = await _profileService.updateMechanicInfo(
      department: _selectedDepartment,
      specialization: _selectedSpecialization,
      employeeId: _employeeIdController.text.trim().isEmpty
          ? null
          : _employeeIdController.text.trim(),
      role: _selectedRole,
    );

    if (success) {
      // Update the local mechanic object immediately to reflect changes in UI
      if (_mechanic != null) {
        setState(() {
          _mechanic = Mechanic(
            id: _mechanic!.id,
            name: _mechanic!.name,
            avatar: _mechanic!.avatar,
            phone: _mechanic!.phone,
            email: _mechanic!.email,
            bio: _mechanic!.bio,
            status: _mechanic!.status,
            role: _selectedRole ?? _mechanic!.role,
            employeeId: _employeeIdController.text.trim().isEmpty
                ? _mechanic!.employeeId
                : _employeeIdController.text.trim(),
            department: _selectedDepartment ?? _mechanic!.department,
            specialization:
                _selectedSpecialization ?? _mechanic!.specialization,
            passwordHash: _mechanic!.passwordHash,
            createdAt: _mechanic!.createdAt,
            updatedAt: DateTime.now(),
            lastLoginAt: _mechanic!.lastLoginAt,
            monthlySalary: _mechanic!.monthlySalary,
          );
          _isEditingMechanic = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mechanic information updated successfully'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update mechanic information'),
          ),
        );
      }
    }
  }

  // Build Switch Row
  Widget _buildSwitchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF3B82F6),
        ),
      ],
    );
  }

  // Build Action Button
  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.2)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red[600] : const Color(0xFF3B82F6),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive
                      ? Colors.red[600]
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  // Show image picker dialog
  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromCamera();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromGallery();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF3B82F6)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    final imageBase64 = await _profileService.pickImageFromCamera();
    if (imageBase64 != null) {
      final success = await _profileService.updateAvatar(imageBase64);
      if (success) {
        // Update the local mechanic object immediately to reflect avatar changes
        if (_mechanic != null) {
          setState(() {
            _mechanic = Mechanic(
              id: _mechanic!.id,
              name: _mechanic!.name,
              avatar: imageBase64,
              phone: _mechanic!.phone,
              email: _mechanic!.email,
              bio: _mechanic!.bio,
              status: _mechanic!.status,
              role: _mechanic!.role,
              employeeId: _mechanic!.employeeId,
              department: _mechanic!.department,
              specialization: _mechanic!.specialization,
              passwordHash: _mechanic!.passwordHash,
              createdAt: _mechanic!.createdAt,
              updatedAt: DateTime.now(),
              lastLoginAt: _mechanic!.lastLoginAt,
              monthlySalary: _mechanic!.monthlySalary,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile picture')),
          );
        }
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final imageBase64 = await _profileService.pickImageFromGallery();
    if (imageBase64 != null) {
      final success = await _profileService.updateAvatar(imageBase64);
      if (success) {
        // Update the local mechanic object immediately to reflect avatar changes
        if (_mechanic != null) {
          setState(() {
            _mechanic = Mechanic(
              id: _mechanic!.id,
              name: _mechanic!.name,
              avatar: imageBase64,
              phone: _mechanic!.phone,
              email: _mechanic!.email,
              bio: _mechanic!.bio,
              status: _mechanic!.status,
              role: _mechanic!.role,
              employeeId: _mechanic!.employeeId,
              department: _mechanic!.department,
              specialization: _mechanic!.specialization,
              passwordHash: _mechanic!.passwordHash,
              createdAt: _mechanic!.createdAt,
              updatedAt: DateTime.now(),
              lastLoginAt: _mechanic!.lastLoginAt,
              monthlySalary: _mechanic!.monthlySalary,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile picture')),
          );
        }
      }
    }
  }

  // Show full screen image
  void _showFullScreenImage() {
    if (_mechanic?.avatar == null || _mechanic!.avatar!.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black87,
                child: Center(
                  child: InteractiveViewer(
                    child: _mechanic!.avatar!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(_mechanic!.avatar!.split(',')[1]),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            _mechanic!.avatar!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Validation methods
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (value.length > 100) {
      return 'Email must be less than 100 characters';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 7) {
      return 'Phone number must be at least 7 digits';
    }
    if (digitsOnly.length > 15) {
      return 'Phone number must be less than 15 digits';
    }
    return null;
  }

  String? _validateBio(String? value) {
    if (value != null && value.length > 500) {
      return 'Bio must be less than 500 characters';
    }
    return null;
  }

  String? _validateEmployeeId(String? value) {
    if (value != null && value.isNotEmpty && value.length > 20) {
      return 'Employee ID must be less than 20 characters';
    }
    return null;
  }

  // Build validated text field
  Widget _buildValidatedTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: isMultiline ? 3 : 1,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  // Build phone field with country code
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.phone, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text(
              'Phone',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedCountryCode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                items: _countryCodes.map((code) {
                  return DropdownMenuItem(value: code, child: Text(code));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCountryCode = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextFormField(
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Enter phone number',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build bio field with character count
  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text(
              'Bio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
            Text(
              '$_bioCharCount/500',
              style: TextStyle(
                fontSize: 12,
                color: _bioCharCount > 500
                    ? Colors.red
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _bioController,
            validator: _validateBio,
            maxLines: 3,
            onChanged: (value) {
              setState(() {
                _bioCharCount = value.length;
              });
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintText: 'Tell us about yourself...',
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  // Build Personal Information Card
  Widget _buildPersonalInfoCard() {
    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      child: _isEditingPersonal
          ? _buildEditablePersonalInfo()
          : _buildDisplayPersonalInfo(),
      isEditable: true,
      isEditing: _isEditingPersonal,
      onEditPressed: () {
        setState(() {
          _isEditingPersonal = !_isEditingPersonal;
        });
      },
      onSave: _savePersonalInfo,
    );
  }

  Widget _buildEditablePersonalInfo() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildValidatedTextField(
            'Name',
            _nameController,
            Icons.person,
            validator: _validateName,
          ),
          const SizedBox(height: 16),
          _buildValidatedTextField(
            'Email',
            _emailController,
            Icons.email,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildPhoneField(),
          const SizedBox(height: 16),
          _buildBioField(),
        ],
      ),
    );
  }

  Widget _buildDisplayPersonalInfo() {
    return Column(
      children: [
        _buildInfoRow('Name', _mechanic!.name),
        _buildInfoRow('Email', _mechanic!.email ?? 'Not provided'),
        _buildInfoRow('Phone', _mechanic!.phone ?? 'Not provided'),
        _buildInfoRow('Bio', _mechanic!.bio ?? 'No bio available'),
      ],
    );
  }

  // Build Mechanic Information Card
  Widget _buildProfessionalInfoCard() {
    return _buildCard(
      title: 'Mechanic Information',
      icon: Icons.build_outlined,
      child: _isEditingMechanic
          ? _buildEditableMechanicInfo()
          : _buildDisplayMechanicInfo(),
      isEditable: true,
      isEditing: _isEditingMechanic,
      onEditPressed: () {
        setState(() {
          _isEditingMechanic = !_isEditingMechanic;
        });
      },
      onSave: _saveMechanicInfo,
    );
  }

  Widget _buildEditableMechanicInfo() {
    return Column(
      children: [
        _buildDropdownField(
          'Department',
          _selectedDepartment,
          _departments,
          Icons.business,
          (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          'Specialization',
          _selectedSpecialization,
          _specializations,
          Icons.engineering,
          (value) {
            setState(() {
              _selectedSpecialization = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          'Role',
          _selectedRole?.toString().split('.').last,
          ['manager', 'mechanic'],
          Icons.person_outline,
          (value) {
            setState(() {
              _selectedRole = value == 'manager'
                  ? MechanicRole.manager
                  : MechanicRole.mechanic;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildValidatedTextField(
          'Employee ID',
          _employeeIdController,
          Icons.badge,
          validator: _validateEmployeeId,
        ),
      ],
    );
  }

  Widget _buildDisplayMechanicInfo() {
    return Column(
      children: [
        _buildInfoRow('Department', _mechanic!.department ?? 'Not specified'),
        _buildInfoRow('Specialization', _mechanic!.specialization),
        _buildInfoRow(
          'Role',
          _mechanic!.role.toString().split('.').last.toUpperCase(),
        ),
        _buildInfoRow('Employee ID', _mechanic!.employeeId ?? 'Not provided'),
      ],
    );
  }

  // Build dropdown field
  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    IconData icon,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            hint: Text('Select $label'),
          ),
        ),
      ],
    );
  }

  // Build Actions Card
  Widget _buildActionsCard() {
    return _buildCard(
      title: 'Account Actions',
      icon: Icons.admin_panel_settings_outlined,
      child: Column(
        children: [
          _buildActionButton(
            'Notifications',
            Icons.notifications_outlined,
            () => _showNotifications(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Change Password',
            Icons.lock_outline,
            () => _showChangePasswordDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Account Information',
            Icons.info_outline,
            () => _showAccountInfo(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Logout',
            Icons.logout,
            () => _showLogoutDialog(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _showChangePasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
    );
  }

  void _showAccountInfo() {
    final stats = _profileService.getProfileStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Employee ID', _mechanic!.employeeId ?? 'N/A'),
              _buildInfoRow('Department', _mechanic!.department ?? 'N/A'),
              _buildInfoRow('Specialization', _mechanic!.specialization),
              _buildInfoRow('Member Since', _formatDate(stats['memberSince'])),
              if (stats['lastLogin'] != null)
                _buildInfoRow('Last Login', _formatDate(stats['lastLogin'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _profileService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
