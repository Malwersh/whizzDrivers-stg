import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/environment.dart';

/// Service for handling document uploads for driver registration
class DocumentUploadService {
  static const String _baseUrl = Environment.documentUploadApiBaseUrl;
  
  /// Upload a single document file
  Future<Map<String, dynamic>> uploadDocument({
    required File file,
    required String documentType,
    String? userId,
  }) async {
    try {
      debugPrint('📤 DocumentUploadService: Uploading $documentType');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'));
      
      // Add file to request
      final fileBytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);
      
      // Add metadata
      request.fields['documentType'] = documentType;
      if (userId != null) {
        request.fields['userId'] = userId;
      }
      
      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = jsonDecode(responseData);
        debugPrint('✅ Document upload successful: $documentType');
        return {
          'success': true,
          'url': result['url'],
          'documentId': result['id'],
        };
      } else {
        debugPrint('❌ Document upload failed: ${response.statusCode}');
        return {
          'success': false,
          'error': 'فشل في رفع المستند',
        };
      }
    } catch (e) {
      debugPrint('❌ Document upload error: $e');
      return {
        'success': false,
        'error': 'حدث خطأ أثناء رفع المستند',
      };
    }
  }
  
  /// Upload multiple documents at once
  Future<Map<String, dynamic>> uploadMultipleDocuments({
    required Map<String, File> documents,
    String? userId,
  }) async {
    try {
      debugPrint('📤 DocumentUploadService: Uploading ${documents.length} documents');
      
      final results = <String, dynamic>{};
      bool allSuccessful = true;
      
      for (final entry in documents.entries) {
        final documentType = entry.key;
        final file = entry.value;
        
        final result = await uploadDocument(
          file: file,
          documentType: documentType,
          userId: userId,
        );
        
        results[documentType] = result;
        
        if (result['success'] != true) {
          allSuccessful = false;
        }
      }
      
      return {
        'success': allSuccessful,
        'results': results,
        'message': allSuccessful 
          ? 'تم رفع جميع المستندات بنجاح'
          : 'فشل في رفع بعض المستندات',
      };
      
    } catch (e) {
      debugPrint('❌ Multiple documents upload error: $e');
      return {
        'success': false,
        'error': 'حدث خطأ أثناء رفع المستندات',
      };
    }
  }
  
  /// Convert Uint8List to temporary file for upload (web support)
  Future<Map<String, dynamic>> uploadFromBytes({
    required Uint8List bytes,
    required String documentType,
    required String fileName,
    String? userId,
  }) async {
    try {
      debugPrint('📤 DocumentUploadService: Uploading $documentType from bytes');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'));
      
      // Add file from bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      );
      request.files.add(multipartFile);
      
      // Add metadata
      request.fields['documentType'] = documentType;
      if (userId != null) {
        request.fields['userId'] = userId;
      }
      
      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = jsonDecode(responseData);
        debugPrint('✅ Document upload from bytes successful: $documentType');
        return {
          'success': true,
          'url': result['url'],
          'documentId': result['id'],
        };
      } else {
        debugPrint('❌ Document upload from bytes failed: ${response.statusCode}');
        return {
          'success': false,
          'error': 'فشل في رفع المستند',
        };
      }
    } catch (e) {
      debugPrint('❌ Document upload from bytes error: $e');
      return {
        'success': false,
        'error': 'حدث خطأ أثناء رفع المستند',
      };
    }
  }
  
  /// Mock upload for testing (when backend is not available)
  Future<Map<String, dynamic>> mockUploadDocument({
    required String documentType,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay
    
    debugPrint('🧪 Mock upload: $documentType');
    
    return {
      'success': true,
      'url': 'https://mock-storage.example.com/${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'documentId': 'mock_${documentType}_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Mock upload for testing - replace with actual implementation
  Future<Map<String, dynamic>> mockUpload({
    required String documentType,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay
    
    debugPrint('🧪 Mock upload: $documentType');
    
    return {
      'success': true,
      'url': 'https://mock-storage.example.com/${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'documentId': 'mock_${documentType}_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Upload a document from base64 data
  Future<Map<String, dynamic>> uploadDocumentFromData({
    required String fileName,
    required String contentType,
    required String base64Content,
    required String documentType, // 'driving_license' or 'registration_paper'
    required String phoneNumber,
  }) async {
    try {
      // Get the auth token
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
      }

      final cognitoSession = session as CognitoAuthSession;
      final tokens = cognitoSession.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      debugPrint('📤 Uploading $documentType from data...');
      debugPrint('   File: $fileName');
      debugPrint('   Type: $contentType');

      // Call the upload API
      final response = await http
          .post(
            Uri.parse('$_baseUrl/driver/documents/upload'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'documentType': documentType,
              'phoneNumber': phoneNumber,
              'fileName': fileName,
              'contentType': contentType,
              'fileData': base64Content,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📥 Upload response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ Document uploaded successfully');
          debugPrint('   URL: ${data['documentUrl']}');

          return {
            'success': true,
            'documentUrl': data['documentUrl'],
            'message': 'تم رفع المستند بنجاح',
          };
        }
      }

      // Handle error response
      String errorMessage = 'فشل رفع المستند';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (_) {}

      debugPrint('❌ Upload failed: $errorMessage');

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      debugPrint('❌ Document upload error: $e');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء رفع المستند: ${e.toString()}',
      };
    }
  }
}
