import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../design_system/app_colors.dart';
import '../../../models/driver_profile.dart';
import '../../../services/driver_service.dart';
import '../../../widgets/gradient_border_container.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  DriverProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await DriverService.getDriverProfile();
      if (profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.name;
          _emailController.text = profile.email;
          _phoneController.text = profile.phone;
          _cityController.text = profile.city;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load profile');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    try {
      String? profilePhotoData;

      // Handle profile photo upload
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        profilePhotoData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final updatedProfile = _profile!.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        profilePhoto: profilePhotoData ?? _profile!.profilePhoto,
      );

      final success = await DriverService.updateDriverProfile(updatedProfile);

      if (success) {
        setState(() {
          _profile = updatedProfile;
          _isEditing = false;
          _selectedImage = null; // Clear selected image after successful upload
        });
        _showSuccessSnackBar('Profile updated successfully');
      } else {
        _showErrorSnackBar('Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: $e');
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableProfileAvatar() {
    Widget avatarWidget;

    if (_selectedImage != null) {
      avatarWidget = ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    } else if (_profile?.profilePhoto != null &&
        _profile!.profilePhoto!.isNotEmpty) {
      avatarWidget = ClipOval(
        child: _profile!.profilePhoto!.startsWith('data:')
            ? Image.memory(
                _getImageBytesFromDataUrl(_profile!.profilePhoto!),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatarIcon();
                },
              )
            : Image.network(
                _profile!.profilePhoto!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatarIcon();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultAvatarIcon();
                },
              ),
      );
    } else {
      avatarWidget = _buildDefaultAvatarIcon();
    }

    return GestureDetector(
      onTap: _isEditing ? _showImagePickerDialog : null,
      child: Stack(
        children: [
          GradientBorderContainer.circular(
            borderWidth: 3,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(shape: BoxShape.circle,
              ),
              child: avatarWidget,
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatarIcon() {
    return ClipOval(
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 30, color: AppColors.white),
      ),
    );
  }

  Uint8List _getImageBytesFromDataUrl(String dataUrl) {
    // Extract base64 part from data URL (data:image/jpeg;base64,...)
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset controllers to original values
                  if (_profile != null) {
                    _nameController.text = _profile!.name;
                    _emailController.text = _profile!.email;
                    _phoneController.text = _profile!.phone;
                    _cityController.text = _profile!.city;
                  }
                });
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _profile == null
          ? const Center(
              child: Text(
                'No profile data available',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Profile Header
                  _buildCompactProfileHeader(),

                  const SizedBox(height: 16),

                  // Personal Information Section
                  _buildPersonalInfoSection(),

                  const SizedBox(height: 16),

                  // Combined Status and Statistics Section
                  _buildCombinedStatsSection(),

                  const SizedBox(height: 16),

                  // Quick Actions Section
                  _buildQuickActionsSection(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCompactProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          _buildEditableProfileAvatar(),
          const SizedBox(width: 16),
          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _profile!.isVerified
                          ? Icons.verified_user
                          : Icons.pending,
                      size: 16,
                      color: _profile!.isVerified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _profile!.isVerified
                          ? 'Verified Driver'
                          : 'Pending Verification',
                      style: TextStyle(
                        fontSize: 14,
                        color: _profile!.isVerified
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _profile!.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Quick Stats
          Column(
            children: [
              Text(
                _profile!.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const Text(
                'Rating',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                _profile!.totalDeliveries.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'Deliveries',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildCompactEditableField(
            label: 'Full Name',
            controller: _nameController,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildCompactEditableField(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildCompactEditableField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildCompactEditableField(
            label: 'City',
            controller: _cityController,
            icon: Icons.location_city_outlined,
          ),
          
          // Enhanced DynamoDB fields
          if (_profile!.district != null && _profile!.district!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'District',
              value: _profile!.district!,
              icon: Icons.location_on_outlined,
            ),
          ],
          if (_profile!.address != null && _profile!.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'Address',
              value: _profile!.address!,
              icon: Icons.home_outlined,
            ),
          ],
          if (_profile!.dateOfBirth != null) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'Date of Birth',
              value: _profile!.dateOfBirth!,
              icon: Icons.cake_outlined,
            ),
          ],
          if (_profile!.gender != null) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'Gender',
              value: _profile!.gender!,
              icon: Icons.person_outline,
            ),
          ],
          if (_profile!.nationality != null) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'Nationality',
              value: _profile!.nationality!,
              icon: Icons.flag_outlined,
            ),
          ],
          
          const SizedBox(height: 12),
          _buildCompactStaticField(
            label: 'National ID',
            value: _profile!.nationalId,
            icon: Icons.credit_card_outlined,
          ),
          
          // License information
          const SizedBox(height: 12),
          _buildCompactStaticField(
            label: 'License Number',
            value: _profile!.licenseNumber,
            icon: Icons.badge_outlined,
          ),
          if (_profile!.licenseExpiry != null) ...[
            const SizedBox(height: 12),
            _buildCompactStaticField(
              label: 'License Expiry',
              value: _profile!.licenseExpiry!,
              icon: Icons.event_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCombinedStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account & Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Account Status Row
          Row(
            children: [
              Expanded(
                child: _buildCompactStatusCard(
                  title: 'Status',
                  value: _profile!.status.toUpperCase(),
                  icon: Icons.account_circle,
                  color: _profile!.status == 'active'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatusCard(
                  title: 'Verified',
                  value: _profile!.isVerified ? 'YES' : 'NO',
                  icon: Icons.verified_user,
                  color: _profile!.isVerified
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Join Date Field
          _buildCompactInfoRow(
            label: 'Member Since',
            value:
                '${_profile!.joinDate.day}/${_profile!.joinDate.month}/${_profile!.joinDate.year}',
            icon: Icons.calendar_today_outlined,
          ),
          
          // Enhanced statistics from DynamoDB
          if (_profile!.totalTrips != null && _profile!.totalTrips! > 0) ...[
            const SizedBox(height: 8),
            _buildCompactInfoRow(
              label: 'Total Trips',
              value: _profile!.totalTrips.toString(),
              icon: Icons.drive_eta_outlined,
            ),
          ],
          if (_profile!.totalEarnings != null &&
              _profile!.totalEarnings! > 0) ...[
            const SizedBox(height: 8),
            _buildCompactInfoRow(
              label: 'Total Earnings',
              value: 'IQD ${_profile!.totalEarnings!.toStringAsFixed(0)}',
              icon: Icons.attach_money_outlined,
            ),
          ],
          if (_profile!.completionRate != null) ...[
            const SizedBox(height: 8),
            _buildCompactInfoRow(
              label: 'Completion Rate',
              value: '${(_profile!.completionRate! * 100).toStringAsFixed(1)}%',
              icon: Icons.check_circle_outline,
            ),
          ],
          if (_profile!.availabilityStatus != null) ...[
            const SizedBox(height: 8),
            _buildCompactInfoRow(
              label: 'Availability',
              value: _profile!.availabilityStatus!,
              icon: Icons.schedule_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return GradientBorderContainer(
      borderWidth: 2,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactActionButton(
                  title: 'Change Password',
                  icon: Icons.lock_outline,
                  onTap: () => _showChangePasswordDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactActionButton(
                  title: 'Delete Account',
                  icon: Icons.delete_outline,
                  color: AppColors.error,
                  onTap: () => _showDeleteAccountDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: buttonColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: buttonColor, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: buttonColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isEditing ? AppColors.background : AppColors.grey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isEditing
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: _isEditing,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          labelStyle: const TextStyle(fontSize: 14),
        ),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildCompactStaticField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Change Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: isObscured,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => isObscured = !isObscured),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  _showErrorSnackBar('Passwords do not match');
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  _showErrorSnackBar('Password must be at least 6 characters');
                  return;
                }

                Navigator.pop(context);

                final success = await DriverService.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                if (success) {
                  _showSuccessSnackBar('Password changed successfully');
                } else {
                  _showErrorSnackBar('Failed to change password');
                }
              },
              child: const Text(
                'Change Password',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    String? selectedReason;
    final reasons = [
      'Found a better opportunity',
      'App is difficult to use',
      'Low earnings',
      'Safety concerns',
      'Moving to different city',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete your account? This action cannot be undone.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please tell us why you\'re leaving:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  hint: const Text('Select a reason'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: reasons
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedReason = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Enter your password to confirm',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.error,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (selectedReason == null) {
                  _showErrorSnackBar('Please select a reason');
                  return;
                }

                if (passwordController.text.isEmpty) {
                  _showErrorSnackBar('Please enter your password');
                  return;
                }

                // Use local variable for context safety
                final parentContext = context;
                Navigator.pop(parentContext);

                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: parentContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text(
                      'Final Confirmation',
                      style: TextStyle(color: AppColors.error),
                    ),
                    content: const Text(
                      'This will permanently delete your account and all associated data. Are you absolutely sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('No, Keep Account'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Yes, Delete Account'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await DriverService.deleteAccount(
                    password: passwordController.text,
                    reason: selectedReason!,
                  );

                  if (!parentContext.mounted) return;
                  if (success) {
                    _showSuccessSnackBar('Account deleted successfully');
                    // Navigate to login screen or exit app
                    Navigator.of(parentContext)
                        .popUntil((route) => route.isFirst);
                  } else {
                    _showErrorSnackBar(
                      'Failed to delete account. Please check your password.',
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
