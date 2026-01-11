import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/colors.dart';
import '../../../models/driver_profile.dart';
import '../../../services/driver_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  DriverProfile? _driverProfile;
  bool _isLoading = true;
  File? _nationalIdFront;
  File? _nationalIdBack;
  File? _drivingLicense;
  File? _selfiePhoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    try {
      final profile = await DriverService.getDriverProfile();
      setState(() {
        _driverProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HadhirColors.moonstoneMist,
      appBar: AppBar(
        backgroundColor: HadhirColors.primary,
        elevation: 0,
        shadowColor: HadhirColors.primary.withOpacity(0.3),
        surfaceTintColor: HadhirColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'التحقق من الهوية',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  HadhirColors.arcticCyan,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Status Header
                  _buildStatusHeader(),

                  // Verification Steps
                  _buildVerificationSteps(),

                  // Required Documents
                  _buildRequiredDocuments(),

                  // Submit Button
                  if (_driverProfile?.isVerified != true) _buildSubmitButton(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader() {
    final isVerified = _driverProfile?.isVerified ?? false;
    final status = (_driverProfile?.status ?? '').toString();

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    final normalized = status.toUpperCase();

    if (isVerified || normalized == 'VERIFIED') {
      statusColor = HadhirColors.acidKiwi;
      statusIcon = Icons.verified_user;
      statusText = 'Verified';
      statusDescription = 'Your identity has been successfully verified.';
    } else if (normalized == 'PENDING_REVIEW' || normalized == 'UNDER_REVIEW') {
      statusColor = HadhirColors.arcticCyan;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Under Review';
      statusDescription =
          'Your documents are being reviewed. This may take 1-3 business days.';
    } else if (normalized == 'REJECTED') {
      statusColor = HadhirColors.ultravioletPulse;
      statusIcon = Icons.error;
      statusText = 'Verification Failed';
      statusDescription = 'Please review and resubmit your documents.';
    } else {
      // Default includes PENDING_PROFILE or unknown
      statusColor = AppColors.grey400;
      statusIcon = Icons.pending;
      statusText = 'Pending';
      statusDescription =
          'Please submit your identity documents to start driving.';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 40, color: statusColor),
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSteps() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
            'Verification Process',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            number: '1',
            title: 'Submit Documents',
            description: 'Upload clear photos of your identity documents',
            isCompleted: _driverProfile?.status != 'pending',
          ),
          _buildStep(
            number: '2',
            title: 'Review Process',
            description:
                'Our team will review your documents (1-3 business days)',
            isCompleted: _driverProfile?.isVerified == true,
          ),
          _buildStep(
            number: '3',
            title: 'Start Driving',
            description:
                'Once verified, you can start accepting delivery orders',
            isCompleted: _driverProfile?.isVerified == true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.grey300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: AppColors.white, size: 18)
                  : Text(
                      number,
                      style: TextStyle(
                        color: isCompleted
                            ? AppColors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredDocuments() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
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
            'Required Documents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Show existing documents from profile
          _buildExistingDocument(
            title: 'البطاقة الوطنية',
            titleEn: 'National ID',
            status: _driverProfile?.nationalIdStatus,
            hasDocument: _driverProfile?.nationalIdUrl != null,
          ),
          _buildExistingDocument(
            title: 'رخصة القيادة',
            titleEn: 'Driving License',
            status: _driverProfile?.drivingLicenseStatus,
            hasDocument: _driverProfile?.drivingLicenseUrl != null,
          ),
          _buildExistingDocument(
            title: 'استمارة المركبة',
            titleEn: 'Vehicle Registration',
            status: _driverProfile?.vehicleRegistrationStatus,
            hasDocument: _driverProfile?.vehicleRegistrationUrl != null,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Upload new documents section
          const Text(
            'Upload New Documents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildDocumentUpload(
            title: 'National ID (Front)',
            description:
                'Clear photo of the front side of your Iraqi National ID',
            file: _nationalIdFront,
            onTap: () => _pickDocument('national_id_front'),
          ),
          _buildDocumentUpload(
            title: 'National ID (Back)',
            description:
                'Clear photo of the back side of your Iraqi National ID',
            file: _nationalIdBack,
            onTap: () => _pickDocument('national_id_back'),
          ),
          _buildDocumentUpload(
            title: 'Driving License',
            description: 'Clear photo of your valid Iraqi driving license',
            file: _drivingLicense,
            onTap: () => _pickDocument('driving_license'),
          ),
          _buildDocumentUpload(
            title: 'Selfie Photo',
            description: 'Recent selfie photo for identity verification',
            file: _selfiePhoto,
            onTap: () => _pickDocument('selfie'),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingDocument({
    required String title,
    required String titleEn,
    String? status,
    required bool hasDocument,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!hasDocument) {
      statusColor = AppColors.grey400;
      statusIcon = Icons.cloud_upload_outlined;
      statusText = 'Not uploaded';
    } else if (status?.toLowerCase() == 'verified') {
      statusColor = AppColors.success;
      statusIcon = Icons.verified;
      statusText = 'Verified ✓';
    } else if (status?.toLowerCase() == 'pending') {
      statusColor = HadhirColors.arcticCyan;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Under Review';
    } else if (status?.toLowerCase() == 'rejected') {
      statusColor = HadhirColors.ultravioletPulse;
      statusIcon = Icons.error_outline;
      statusText = 'Rejected';
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titleEn,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUpload({
    required String title,
    required String description,
    required File? file,
    required VoidCallback onTap,
  }) {
    final bool hasFile = file != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasFile ? AppColors.success : AppColors.grey300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (hasFile ? AppColors.success : AppColors.grey300)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasFile ? Icons.check_circle : Icons.upload_file,
                  color: hasFile ? AppColors.success : AppColors.grey400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: hasFile
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile ? 'Document uploaded' : description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasFile ? Icons.edit : Icons.add_photo_alternate,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit =
        _nationalIdFront != null &&
        _nationalIdBack != null &&
        _drivingLicense != null &&
        _selfiePhoto != null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canSubmit ? _submitVerification : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? AppColors.primary : AppColors.grey300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            'Submit for Verification',
            style: TextStyle(
              color: canSubmit ? AppColors.white : AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _pickDocument(String documentType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _capturePhoto(documentType);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery(documentType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(String documentType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _setDocumentFile(documentType, File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(String documentType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _setDocumentFile(documentType, File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _setDocumentFile(String documentType, File file) {
    setState(() {
      switch (documentType) {
        case 'national_id_front':
          _nationalIdFront = file;
          break;
        case 'national_id_back':
          _nationalIdBack = file;
          break;
        case 'driving_license':
          _drivingLicense = file;
          break;
        case 'selfie':
          _selfiePhoto = file;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document uploaded successfully'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _submitVerification() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );

      final success = await DriverService.submitIdentityVerification(
        nationalIdFront: _nationalIdFront!,
        nationalIdBack: _nationalIdBack!,
        drivingLicense: _drivingLicense!,
        selfiePhoto: _selfiePhoto!,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (success) {
        await _loadDriverProfile(); // Refresh profile to get updated status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Documents submitted successfully! Review may take 1-3 business days.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit documents. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
