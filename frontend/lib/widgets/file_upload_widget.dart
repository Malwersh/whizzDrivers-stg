import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design_system/app_colors.dart';

class FileUploadWidget extends StatefulWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final Function(Map<String, dynamic>)? onFileSelected;
  final Function()? onFileRemoved;
  final bool isRequired;
  final List<String> allowedExtensions;
  final int maxSizeMB;

  const FileUploadWidget({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.onFileSelected,
    this.onFileRemoved,
    this.isRequired = false,
    this.allowedExtensions = const ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
    this.maxSizeMB = 10,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  Map<String, dynamic>? _selectedFile;
  bool _isLoading = false;

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _processFile(image.path, image.name);
      }
    } catch (e) {
      _showError('خطأ في اختيار الصورة: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDocument() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          await _processFile(file.path!, file.name);
        }
      }
    } catch (e) {
      _showError('خطأ في اختيار الملف: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);

      // Check file size
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      if (fileSizeMB > widget.maxSizeMB) {
        _showError('حجم الملف يتجاوز ${widget.maxSizeMB} ميجابايت');
        return;
      }

      // Check file extension
      final extension = fileName.split('.').last.toLowerCase();
      if (!widget.allowedExtensions.contains(extension)) {
        _showError(
          'نوع الملف غير مسموح به. الأنواع المسموحة: ${widget.allowedExtensions.join(', ')}',
        );
        return;
      }

      // Read file content
      final bytes = await file.readAsBytes();
      final base64Content = base64Encode(bytes);

      // Determine content type
      String contentType = 'application/octet-stream';
      switch (extension) {
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'heic':
          contentType = 'image/heic';
          break;
      }

      final fileData = {
        'name': fileName,
        'type': contentType,
        'content': base64Content,
        'size': fileSize,
      };

      setState(() {
        _selectedFile = fileData;
      });

      widget.onFileSelected?.call(fileData);
    } catch (e) {
      _showError('خطأ في معالجة الملف: ${e.toString()}');
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
    });
    widget.onFileRemoved?.call();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showFilePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر طريقة رفع الملف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // First row - Camera and Gallery
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickImage(source: ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('الكاميرا'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickImage(source: ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('معرض الصور'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Second row - Document picker
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                  icon: const Icon(Icons.description),
                  label: const Text('اختيار ملف PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // File upload area
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.errorText != null
                  ? AppColors.error
                  : AppColors.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _selectedFile == null
              ? _buildUploadButton()
              : _buildSelectedFile(),
        ),

        // Error text
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],

        // Hint text
        if (widget.hint != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.hint!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadButton() {
    return InkWell(
      onTap: _isLoading ? null : _showFilePickerDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.primary)
            else ...[
              const Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'اضغط لرفع الملف',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الأنواع المسموحة: ${widget.allowedExtensions.join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'الحد الأقصى: ${widget.maxSizeMB} ميجابايت',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFile() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _getFileIcon(_selectedFile!['name']),
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFile!['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_selectedFile!['size'] / (1024 * 1024)).toStringAsFixed(2)} ميجابايت',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _removeFile,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'إزالة الملف',
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'heic':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
