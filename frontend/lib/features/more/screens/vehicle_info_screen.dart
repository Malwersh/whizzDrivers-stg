import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/colors.dart';
import '../../../design_system/design_tokens.dart';
import '../../../models/driver_profile.dart';
import '../../../services/driver_service.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  VehicleInfo? _vehicleInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicleInfo();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadVehicleInfo() async {
    try {
      final profile = await DriverService.getDriverProfile();
      if (profile?.vehicle != null) {
        setState(() {
          _vehicleInfo = profile!.vehicle!;
          _isLoading = false;
        });
      } else if (profile?.vehicleType.isNotEmpty == true) {
        // Profile exists but no detailed vehicle info, show vehicleType from profile
        setState(() {
          _vehicleInfo = VehicleInfo(
            type: profile!.vehicleType,
            make: '',
            model: '',
            year: 0,
            licensePlate: '',
            color: '',
            hasInsurance: false,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading vehicle info: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
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
          'معلومات المركبة',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HadhirColors.arcticCyan),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Vehicle Image/Icon Section
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusLarge,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HadhirColors.obsidianCore.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: HadhirColors.arcticCyan.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getVehicleIcon(_vehicleInfo?.type),
                            size: 40,
                            color: HadhirColors.arcticCyan,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _vehicleInfo != null && _vehicleInfo!.type.isNotEmpty
                              ? _vehicleInfo!.type[0].toUpperCase() +
                                    _vehicleInfo!.type.substring(1)
                              : _vehicleInfo != null &&
                                    (_vehicleInfo!.make.isNotEmpty ||
                                        _vehicleInfo!.model.isNotEmpty)
                              ? '${_vehicleInfo!.year > 0 ? _vehicleInfo!.year : ''} ${_vehicleInfo!.make} ${_vehicleInfo!.model}'
                                    .trim()
                              : 'Vehicle Information',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HadhirColors.obsidianCore,
                          ),
                        ),
                        if (_vehicleInfo != null &&
                            _vehicleInfo!.licensePlate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _vehicleInfo!.licensePlate,
                            style: TextStyle(
                              fontSize: 16,
                              color: HadhirColors.obsidianCore.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Vehicle Details Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusLarge,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HadhirColors.obsidianCore.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HadhirColors.obsidianCore,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Vehicle Information Display
                        if (_vehicleInfo != null) ...[
                          _buildStaticInfoField(
                            label: 'Vehicle Type',
                            value: _vehicleInfo!.type.isNotEmpty
                                ? _vehicleInfo!.type[0].toUpperCase() +
                                      _vehicleInfo!.type.substring(1)
                                : 'Not specified',
                            icon: _getVehicleIcon(_vehicleInfo!.type),
                          ),
                          const SizedBox(height: 16),
                          
                          if (_vehicleInfo!.make.isNotEmpty) ...[
                            _buildStaticInfoField(
                              label: 'Make',
                              value: _vehicleInfo!.make,
                              icon: Icons.business,
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          if (_vehicleInfo!.model.isNotEmpty) ...[
                            _buildStaticInfoField(
                              label: 'Model',
                              value: _vehicleInfo!.model,
                              icon: Icons.directions_car,
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          if (_vehicleInfo!.year > 0) ...[
                            _buildStaticInfoField(
                              label: 'Year',
                              value: _vehicleInfo!.year.toString(),
                              icon: Icons.calendar_today,
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          if (_vehicleInfo!.licensePlate.isNotEmpty) ...[
                            _buildStaticInfoField(
                              label: 'License Plate',
                              value: _vehicleInfo!.licensePlate,
                              icon: Icons.confirmation_number,
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          if (_vehicleInfo!.color.isNotEmpty) ...[
                            _buildStaticInfoField(
                              label: 'Color',
                              value: _vehicleInfo!.color,
                              icon: Icons.palette,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_vehicleInfo!.capacity != null &&
                              _vehicleInfo!.capacity! > 0) ...[
                            _buildStaticInfoField(
                              label: 'Capacity',
                              value: '${_vehicleInfo!.capacity} passengers',
                              icon: Icons.people_outline,
                            ),
                          ],
                        ] else ...[
                          const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_car_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No vehicle information available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_vehicleInfo != null) ...[
                    const SizedBox(height: 20),

                    // Insurance Status
                    Container(
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
                            'Insurance Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                _vehicleInfo!.hasInsurance
                                    ? Icons.verified_user
                                    : Icons.warning,
                                color: _vehicleInfo!.hasInsurance
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _vehicleInfo!.hasInsurance
                                          ? 'Insured'
                                          : 'Not Insured',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _vehicleInfo!.hasInsurance
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                    if (_vehicleInfo!.hasInsurance &&
                                        _vehicleInfo!.insuranceExpiry != null)
                                      Text(
                                        'Expires: ${_vehicleInfo!.insuranceExpiry!.day}/${_vehicleInfo!.insuranceExpiry!.month}/${_vehicleInfo!.insuranceExpiry!.year}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  IconData _getVehicleIcon(String? type) {
    switch (type) {
      case 'motorcycle':
        return Icons.motorcycle;
      case 'car':
        return Icons.directions_car;
      case 'bicycle':
        return Icons.pedal_bike;
      default:
        return Icons.directions_car;
    }
  }

  Widget _buildStaticInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HadhirColors.obsidianCore.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: HadhirColors.moonstoneMist,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(
              color: HadhirColors.arcticCyan.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: HadhirColors.arcticCyan),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: HadhirColors.obsidianCore,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
