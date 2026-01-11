import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import '../../../app_colors.dart';
import '../../../widgets/file_upload_widget.dart';
import '../../../services/logging/auth_logger.dart';
import '../../../services/document_upload_service.dart';
import '../../../services/aws_dynamodb_service.dart';
import '../../../config/environment.dart';
import '../../../core/models/region_models.dart';
import '../../../core/services/regions_api_service.dart';

class DriverProfileSetupScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const DriverProfileSetupScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState
    extends ConsumerState<DriverProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  final String _selectedCity = 'Baghdad';
  String _selectedVehicleType = 'motorcycle';

  // ✨ Regions API integration
  final _regionsApiService = RegionsApiService();
  List<Country> _countries = [];
  List<Governorate> _governorates = [];
  List<ResidentialArea> _residentialAreas = [];
  String? _selectedCountry;
  String? _selectedGovernorate;
  String? _selectedResidentialArea;
  bool _loadingCountries = false;
  bool _loadingGovernorates = false;
  bool _loadingResidentialAreas = false;

  // File upload data
  Map<String, dynamic>? _drivingLicenseFile;
  Map<String, dynamic>? _registrationPaperFile;
  String? _drivingLicenseError;
  String? _registrationPaperError;

  final List<Map<String, String>> _vehicleTypes = [
    {'value': 'motorcycle', 'label': 'دراجة نارية'},
    {'value': 'car', 'label': 'سيارة'},
    {'value': 'bicycle', 'label': 'دراجة هوائية'},
  ];

  AuthLogger get _logger => AuthLogger();
  final DocumentUploadService documentUploadService = DocumentUploadService();

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ✨ Load countries from API
  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final countries = await _regionsApiService.getCountries();
      if (mounted) {
        setState(() {
          _countries = countries;
          _loadingCountries = false;
          // Auto-select Iraq if it's the only country
          if (_countries.length == 1) {
            _selectedCountry = _countries.first.regionId;
            _loadGovernorates(_selectedCountry!);
          }
        });
      }
      debugPrint('✅ Loaded ${_countries.length} countries');
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
      if (mounted) {
        setState(() => _loadingCountries = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل البلدان. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✨ Load governorates for selected country
  Future<void> _loadGovernorates(String countryId) async {
    setState(() => _loadingGovernorates = true);
    try {
      final governorates = await _regionsApiService.getGovernorates(countryId);
      if (mounted) {
        setState(() {
          _governorates = governorates;
          _loadingGovernorates = false;
        });
      }
      debugPrint('✅ Loaded ${_governorates.length} governorates');
    } catch (e) {
      debugPrint('❌ Error loading governorates: $e');
      if (mounted) {
        setState(() => _loadingGovernorates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل المحافظات. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✨ Load residential areas for selected governorate
  Future<void> _loadResidentialAreas(String governorateId) async {
    setState(() => _loadingResidentialAreas = true);
    try {
      final areas = await _regionsApiService.getResidentialAreas(governorateId);
      if (mounted) {
        setState(() {
          _residentialAreas = areas;
          _loadingResidentialAreas = false;
        });
      }
      debugPrint('✅ Loaded ${_residentialAreas.length} residential areas');
    } catch (e) {
      debugPrint('❌ Error loading residential areas: $e');
      if (mounted) {
        setState(() => _loadingResidentialAreas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل مناطق السكن. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVehicleTypeChanged(String? value) {
    setState(() {
      _selectedVehicleType = value!;
      // Clear file errors when vehicle type changes
      _drivingLicenseError = null;
      _registrationPaperError = null;
    });
  }

  void _onDrivingLicenseSelected(Map<String, dynamic> fileData) {
    setState(() {
      _drivingLicenseFile = fileData;
      _drivingLicenseError = null;
    });
  }

  void _onDrivingLicenseRemoved() {
    setState(() {
      _drivingLicenseFile = null;
      _drivingLicenseError = null;
    });
  }

  void _onRegistrationPaperSelected(Map<String, dynamic> fileData) {
    setState(() {
      _registrationPaperFile = fileData;
      _registrationPaperError = null;
    });
  }

  void _onRegistrationPaperRemoved() {
    setState(() {
      _registrationPaperFile = null;
      _registrationPaperError = null;
    });
  }

  bool _validateFiles() {
    debugPrint('🔍 Validating files...');
    debugPrint(
      '   Driving license file: ${_drivingLicenseFile != null ? "✅ Selected" : "❌ Missing"}',
    );
    debugPrint(
      '   Registration paper file: ${_registrationPaperFile != null ? "✅ Selected" : "❌ Missing"}',
    );
    debugPrint('   Vehicle type: $_selectedVehicleType');
    
    bool isValid = true;

    // Temporarily using placeholders, but still require file selection
    // Always require driving license
    if (_drivingLicenseFile == null) {
      debugPrint('❌ Validation FAILED: Driving license is required');
      setState(() {
        _drivingLicenseError = 'رخصة القيادة مطلوبة';
      });
      isValid = false;
    }

    // Require registration paper only for car and motorcycle
    if ((_selectedVehicleType == 'car' ||
            _selectedVehicleType == 'motorcycle') &&
        _registrationPaperFile == null) {
      debugPrint(
        '❌ Validation FAILED: Registration paper is required for $_selectedVehicleType',
      );
      setState(() {
        _registrationPaperError = 'إستمارة المركبة مطلوبة';
      });
      isValid = false;
    }

    debugPrint('   Validation result: ${isValid ? "✅ PASSED" : "❌ FAILED"}');
    return isValid;
  }

  Future<void> _submitProfile() async {
    debugPrint('🚀 Submit profile called');

    // ✨ Validate form first (only once!)
    final formValid = _formKey.currentState?.validate() ?? false;
    debugPrint('   Form validation: $formValid');

    // ✨ Validate regions
    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار البلد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedGovernorate == null || _selectedGovernorate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المحافظة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedResidentialArea == null || _selectedResidentialArea!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار منطقة السكن'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final filesValid = _validateFiles();
    if (!formValid || !filesValid) {
      debugPrint('⛔ Submission blocked: Form validation=$formValid, Files validation=$filesValid');
      return;
    }

    debugPrint('✅ All validations passed, proceeding with save...');
    setState(() {
      _isLoading = true;
    });

    try {
      // final documentUploadService = DocumentUploadService(); // Unused for now
      String? drivingLicenseUrl;
      String? registrationPaperUrl;

      // Step 1: Upload driving license
      debugPrint('📄 Starting document upload...');
      if (_drivingLicenseFile != null) {
        debugPrint('📤 Uploading driving license...');
        final uploadResult = await documentUploadService.uploadDocumentFromData(
          fileName: _drivingLicenseFile!['name'] as String,
          contentType: _drivingLicenseFile!['type'] as String,
          base64Content: _drivingLicenseFile!['content'] as String,
          documentType: 'driving_license',
          phoneNumber: widget.phoneNumber,
        );

        if (uploadResult['success'] == true) {
          final urlValue = uploadResult['documentUrl'];
          if (urlValue != null && urlValue is String) {
            drivingLicenseUrl = urlValue;
          } else {
            drivingLicenseUrl = null;
          }
          debugPrint('✅ Driving license uploaded: $drivingLicenseUrl');
        } else {
          throw Exception('فشل رفع رخصة القيادة: ${uploadResult['message']}');
        }
      } else {
        throw Exception('رخصة القيادة مطلوبة');
      }

      // Step 2: Upload registration paper (if applicable)
      if (_registrationPaperFile != null) {
        debugPrint('📤 Uploading registration paper...');
        final uploadResult = await documentUploadService.uploadDocumentFromData(
          fileName: _registrationPaperFile!['name'] as String,
          contentType: _registrationPaperFile!['type'] as String,
          base64Content: _registrationPaperFile!['content'] as String,
          documentType: 'registration_paper',
          phoneNumber: widget.phoneNumber,
        );

        if (uploadResult['success'] == true) {
          final urlValue = uploadResult['documentUrl'];
          if (urlValue != null && urlValue is String) {
            registrationPaperUrl = urlValue;
          } else {
            registrationPaperUrl = null;
          }
          debugPrint('✅ Registration paper uploaded: $registrationPaperUrl');
        } else {
          throw Exception(
            'فشل رفع إستمارة المركبة: ${uploadResult['message']}',
          );
        }
      } else if (_selectedVehicleType == 'car' ||
          _selectedVehicleType == 'motorcycle') {
        throw Exception('إستمارة المركبة مطلوبة');
      }

      // Step 3: Configure DynamoDB service with auth token
      debugPrint('🔧 Configuring DynamoDB service...');
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        throw Exception('المستخدم غير مسجل دخول');
      }
      
      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;
      
      AWSDynamoDBService.configure(
        baseUrl: Environment.apiBaseUrl,
        authToken: accessToken,
      );
      debugPrint('✅ DynamoDB service configured');

      // Step 4: Save driver profile to DynamoDB
      debugPrint('📝 Form controller values:');
      debugPrint('   Name: ${_nameController.text.trim()}');
      debugPrint('   License: ${_licenseController.text.trim()}');
      debugPrint('   National ID: ${_nationalIdController.text.trim()}');
      debugPrint('   Country: $_selectedCountry');
      debugPrint('   Governorate: $_selectedGovernorate');
      debugPrint('   Residential Area: $_selectedResidentialArea');
      debugPrint('   Address: ${_addressController.text.trim()}');
      debugPrint('   Vehicle Type: $_selectedVehicleType');
      
      // Get selected governorate and residential area details
      final selectedGov = _governorates.firstWhere(
        (g) => g.regionId == _selectedGovernorate,
        orElse: () => Governorate(regionId: '', name: '', nameAr: '', level: 0, parentId: ''),
      );
      
      final selectedArea = _residentialAreas.firstWhere(
        (a) => a.regionId == _selectedResidentialArea,
        orElse: () => ResidentialArea(regionId: '', name: '', nameAr: '', level: 0, parentId: ''),
      );
      
      final profileData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'vehicleType': _selectedVehicleType,
        'licenseNumber': _licenseController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        
        // ✨ New region and address fields
        'home_region_id': _selectedResidentialArea!,
        'home_region_name': selectedArea.nameAr,
        'home_address_text': _addressController.text.trim(),
        
        // ✨ Governorate data
        'governorate_id': _selectedGovernorate!,
        'governorate_name': selectedGov.nameAr,
        
        // ✨ Parent district data (Level 2 parent for Level 3 areas, or governorate for Level 2 areas)
        'parent_district_id': selectedArea.parentId,
        'parent_district_name': selectedArea.level == 3 
            ? (selectedArea.parentDistrictName ?? '')
            : selectedGov.nameAr,
        
        // Legacy city field (for backward compatibility)
        'city': selectedGov.nameAr,
        
        'status': 'ACTIVE', // Profile is now complete
      };

      // Only add document URLs if they exist
      debugPrint('🔍 Checking document URLs before adding to profile:');
      debugPrint('   drivingLicenseUrl: $drivingLicenseUrl');
      debugPrint('   registrationPaperUrl: $registrationPaperUrl');
      
      if (drivingLicenseUrl != null && drivingLicenseUrl.isNotEmpty) {
        profileData['drivingLicenseUrl'] = drivingLicenseUrl;
        debugPrint('✅ Added drivingLicenseUrl to profileData');
      } else {
        debugPrint('⚠️ drivingLicenseUrl NOT added (null or empty)');
      }
      
      if (registrationPaperUrl != null && registrationPaperUrl.isNotEmpty) {
        profileData['registrationPaperUrl'] = registrationPaperUrl;
        debugPrint('✅ Added registrationPaperUrl to profileData');
      } else {
        debugPrint('⚠️ registrationPaperUrl NOT added (null or empty)');
      }

      debugPrint('💾 Saving driver profile...');
      debugPrint('   Profile data keys: ${profileData.keys.toList()}');
      debugPrint('   Full profile data: $profileData');

      final saveSuccess = await AWSDynamoDBService().updateDriverProfile(
        profileData,
      );

      if (!saveSuccess) {
        throw Exception('فشل حفظ بيانات الملف الشخصي');
      }

      debugPrint('✅ Driver profile saved successfully');

      _logger.logProfileSetup(
        phoneNumber: widget.phoneNumber,
        name: _nameController.text,
        city: selectedGov.nameAr,
        vehicleType: _selectedVehicleType,
        success: true,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إكمال تسجيل البيانات بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Wait a moment then navigate to home
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      debugPrint('❌ Profile setup error: $e');

      _logger.logProfileSetup(
        phoneNumber: widget.phoneNumber,
        name: _nameController.text,
        city: _selectedCity,
        vehicleType: _selectedVehicleType,
        success: false,
        error: e.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ البيانات: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'إكمال بيانات السائق',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 60,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'مرحباً بك في ويز درايفرز!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'يرجى إكمال بياناتك الشخصية لبدء العمل',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الاسم الكامل مطلوب';
                  }
                  if (value.trim().length < 3) {
                    return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // License number field
              TextFormField(
                controller: _licenseController,
                decoration: InputDecoration(
                  labelText: 'رقم رخصة القيادة *',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'رقم رخصة القيادة مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // National ID field
              TextFormField(
                controller: _nationalIdController,
                decoration: InputDecoration(
                  labelText: 'رقم الهوية الوطنية *',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'رقم الهوية الوطنية مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✨ Country dropdown (NEW)
              _loadingCountries
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      decoration: InputDecoration(
                        labelText: 'البلد *',
                        prefixIcon: const Icon(Icons.flag),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      hint: const Text('اختر البلد'),
                      items: _countries.map((country) {
                        return DropdownMenuItem<String>(
                          value: country.regionId,
                          child: Text(country.nameAr),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() {
                          _selectedCountry = value;
                          _selectedGovernorate = null;
                          _selectedResidentialArea = null;
                          _governorates = [];
                          _residentialAreas = [];
                        });
                        if (value != null) {
                          await _loadGovernorates(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار البلد';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 16),

              // ✨ Governorate dropdown (NEW)
              _loadingGovernorates
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedGovernorate,
                      decoration: InputDecoration(
                        labelText: 'المحافظة *',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      hint: Text(_selectedCountry == null
                          ? 'اختر البلد أولاً'
                          : 'اختر المحافظة'),
                      items: _governorates.map((governorate) {
                        return DropdownMenuItem<String>(
                          value: governorate.regionId,
                          child: Text(governorate.nameAr),
                        );
                      }).toList(),
                      onChanged: _selectedCountry == null
                          ? null
                          : (value) async {
                        setState(() {
                          _selectedGovernorate = value;
                          _selectedResidentialArea = null;
                          _residentialAreas = [];
                        });
                        if (value != null) {
                          await _loadResidentialAreas(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار المحافظة';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 16),

              // ✨ Residential Area dropdown (NEW)
              _loadingResidentialAreas
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedResidentialArea,
                      decoration: InputDecoration(
                        labelText: 'منطقة السكن *',
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      hint: Text(_selectedGovernorate == null
                          ? 'اختر المحافظة أولاً'
                          : 'اختر منطقة السكن'),
                      items: _residentialAreas.map((area) {
                        return DropdownMenuItem<String>(
                          value: area.regionId,
                          child: Text(area.displayName),
                        );
                      }).toList(),
                      onChanged: _selectedGovernorate == null
                          ? null
                          : (value) {
                              setState(() {
                                _selectedResidentialArea = value;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار منطقة السكن';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 16),

              // ✨ Address field (NEW)
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'العنوان التفصيلي *',
                  hintText: 'مثال: حي السعد، شارع الكوفة، بناية رقم 15',
                  prefixIcon: const Icon(Icons.home),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'العنوان التفصيلي مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vehicle type dropdown
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: InputDecoration(
                  labelText: 'نوع المركبة *',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                items: _vehicleTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: _onVehicleTypeChanged,
              ),
              const SizedBox(height: 24),

              // File uploads section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المستندات المطلوبة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Driving license upload
                    FileUploadWidget(
                      label: 'رخصة القيادة *',
                      hint: 'اختر صورة رخصة القيادة',
                      onFileSelected: _onDrivingLicenseSelected,
                      onFileRemoved: _onDrivingLicenseRemoved,
                      errorText: _drivingLicenseError,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle registration upload (conditional)
                    if (_selectedVehicleType == 'car' ||
                        _selectedVehicleType == 'motorcycle')
                      FileUploadWidget(
                        label: 'استمارة المركبة *',
                        hint: 'اختر صورة استمارة المركبة',
                        onFileSelected: _onRegistrationPaperSelected,
                        onFileRemoved: _onRegistrationPaperRemoved,
                        errorText: _registrationPaperError,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.secondary,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'إكمال التسجيل',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'سيتم مراجعة مستنداتك وتفعيل حسابك خلال 24 ساعة',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
