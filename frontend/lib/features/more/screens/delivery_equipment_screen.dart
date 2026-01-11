import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../models/delivery_equipment.dart';
import '../../../services/delivery_equipment_service.dart';
import '../../../widgets/gradient_border_container.dart';

class DeliveryEquipmentScreen extends StatefulWidget {
  const DeliveryEquipmentScreen({super.key});

  @override
  State<DeliveryEquipmentScreen> createState() =>
      _DeliveryEquipmentScreenState();
}

class _DeliveryEquipmentScreenState extends State<DeliveryEquipmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DeliveryEquipment> _driverEquipment = [];
  List<EquipmentType> _equipmentTypes = [];
  bool _isLoading = true;
  double _completionPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final equipment = await DeliveryEquipmentService.getDriverEquipment();
      final types = await DeliveryEquipmentService.getEquipmentTypes();

      setState(() {
        _driverEquipment = equipment;
        _equipmentTypes = types;
        _completionPercentage =
            DeliveryEquipmentService.getCompletionPercentage(equipment, types);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading equipment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Completion Progress
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Equipment Completion',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: _completionPercentage / 100,
                                  backgroundColor: AppColors.white.withValues(
                                    alpha: 0.3,
                                  ),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_completionPercentage.toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'My Equipment'),
                    Tab(text: 'Available'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMyEquipmentTab(), _buildAvailableEquipmentTab()],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEquipmentDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Add Equipment',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildMyEquipmentTab() {
    if (_driverEquipment.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No Equipment Added',
        subtitle: 'Add your delivery equipment to get started',
        actionText: 'Add Equipment',
        onAction: () => _showAddEquipmentDialog(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _driverEquipment.length,
      itemBuilder: (context, index) {
        final equipment = _driverEquipment[index];
        final type = _equipmentTypes.firstWhere(
          (t) => t.id == equipment.type,
          orElse: () => EquipmentType(
            id: equipment.type,
            name: equipment.name,
            nameArabic: equipment.name,
            description: '',
            isRequired: false,
            iconName: 'category',
            recommendedBrands: [],
          ),
        );

        return _buildEquipmentCard(equipment, type, true);
      },
    );
  }

  Widget _buildAvailableEquipmentTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipmentTypes.length,
      itemBuilder: (context, index) {
        final type = _equipmentTypes[index];
        final hasEquipment = _driverEquipment.any((eq) => eq.type == type.id);

        return _buildEquipmentTypeCard(type, hasEquipment);
      },
    );
  }

  Widget _buildEquipmentCard(
    DeliveryEquipment equipment,
    EquipmentType type,
    bool isOwned,
  ) {
    Color statusColor = AppColors.success;
    String statusText = 'Owned';
    IconData statusIcon = Icons.check_circle;

    switch (equipment.status) {
      case 'rented':
        statusColor = AppColors.warning;
        statusText = 'Rented';
        statusIcon = Icons.schedule;
        break;
      case 'needed':
        statusColor = AppColors.error;
        statusText = 'Needed';
        statusIcon = Icons.error_outline;
        break;
      case 'owned':
      default:
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconData(type.iconName),
            color: AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          equipment.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (equipment.brand != null) ...[
              const SizedBox(height: 4),
              Text(
                '${equipment.brand} ${equipment.model ?? ''}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (type.isRequired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () => _showEditEquipmentDialog(equipment),
            ),
            PopupMenuItem(
              child: const ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete', style: TextStyle(color: AppColors.error)),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () => _deleteEquipment(equipment),
            ),
          ],
        ),
        onTap: () => _showEquipmentDetails(equipment, type),
      ),
    );
  }

  Widget _buildEquipmentTypeCard(EquipmentType type, bool hasEquipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GradientBorderContainer(
        borderWidth: 1.5,
        borderRadius: 12,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconData(type.iconName),
            color: AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          type.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.nameArabic,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (type.isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                if (type.estimatedPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '~${type.estimatedPrice!.toInt()} IQD',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: hasEquipment
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : const Icon(Icons.add_circle_outline, color: AppColors.primary),
        onTap: hasEquipment
            ? null
            : () => _showAddEquipmentFromTypeDialog(type),
      ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.grey400),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work_outline':
        return Icons.work_outline;
      case 'phone_android':
        return Icons.phone_android;
      case 'battery_charging_full':
        return Icons.battery_charging_full;
      case 'sports_motorsports':
        return Icons.sports_motorsports;
      case 'safety_check':
        return Icons.safety_check;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'back_hand':
        return Icons.back_hand;
      case 'flashlight_on':
        return Icons.flashlight_on;
      default:
        return Icons.category;
    }
  }

  void _showAddEquipmentDialog() {
    _showEquipmentFormDialog();
  }

  void _showAddEquipmentFromTypeDialog(EquipmentType type) {
    _showEquipmentFormDialog(equipmentType: type);
  }

  void _showEditEquipmentDialog(DeliveryEquipment equipment) {
    _showEquipmentFormDialog(equipment: equipment);
  }

  void _showEquipmentFormDialog({
    DeliveryEquipment? equipment,
    EquipmentType? equipmentType,
  }) {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => _EquipmentFormDialog(
        equipment: equipment,
        equipmentType: equipmentType,
        equipmentTypes: _equipmentTypes,
        onSave: (updatedEquipment) async {
          final success = equipment != null
              ? await DeliveryEquipmentService.updateEquipment(updatedEquipment)
              : await DeliveryEquipmentService.addEquipment(updatedEquipment);

          if (success) {
            _loadData();
            if (!parentContext.mounted) return;
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text(
                  equipment != null
                      ? 'Equipment updated successfully'
                      : 'Equipment added successfully',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            if (!parentContext.mounted) return;
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to ${equipment != null ? 'update' : 'add'} equipment',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  void _showEquipmentDetails(DeliveryEquipment equipment, EquipmentType type) {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) =>
          _EquipmentDetailsDialog(equipment: equipment, equipmentType: type),
    );
  }

  void _deleteEquipment(DeliveryEquipment equipment) {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text('Are you sure you want to delete ${equipment.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await DeliveryEquipmentService.deleteEquipment(
                equipment.id,
              );

              if (success) {
                _loadData();
                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Equipment deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete equipment'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// Equipment Form Dialog
class _EquipmentFormDialog extends StatefulWidget {
  final DeliveryEquipment? equipment;
  final EquipmentType? equipmentType;
  final List<EquipmentType> equipmentTypes;
  final Function(DeliveryEquipment) onSave;

  const _EquipmentFormDialog({
    this.equipment,
    this.equipmentType,
    required this.equipmentTypes,
    required this.onSave,
  });

  @override
  State<_EquipmentFormDialog> createState() => _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends State<_EquipmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  String _selectedType = '';
  String _selectedStatus = 'owned';
  DateTime? _purchaseDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();

    final equipment = widget.equipment;
    final type = widget.equipmentType;

    _nameController = TextEditingController(
      text: equipment?.name ?? type?.name ?? '',
    );
    _brandController = TextEditingController(text: equipment?.brand ?? '');
    _modelController = TextEditingController(text: equipment?.model ?? '');
    _serialController = TextEditingController(
      text: equipment?.serialNumber ?? '',
    );
    _priceController = TextEditingController(
      text:
          equipment?.purchasePrice?.toString() ??
          type?.estimatedPrice?.toString() ??
          '',
    );
    _notesController = TextEditingController(text: equipment?.notes ?? '');

    _selectedType =
        equipment?.type ?? type?.id ?? widget.equipmentTypes.first.id;
    _selectedStatus = equipment?.status ?? 'owned';
    _purchaseDate = equipment?.purchaseDate;
    _expiryDate = equipment?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.equipment != null ? 'Edit Equipment' : 'Add Equipment',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equipment Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Equipment Type',
                  border: OutlineInputBorder(),
                ),
                items: widget.equipmentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type.id,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                    if (widget.equipment == null) {
                      final type = widget.equipmentTypes.firstWhere(
                        (t) => t.id == value,
                      );
                      _nameController.text = type.name;
                      _priceController.text =
                          type.estimatedPrice?.toString() ?? '';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Equipment Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'owned', child: Text('Owned')),
                  DropdownMenuItem(value: 'rented', child: Text('Rented')),
                  DropdownMenuItem(value: 'needed', child: Text('Needed')),
                ],
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              const SizedBox(height: 16),

              // Brand and Model
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Serial Number and Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Serial Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (IQD)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveEquipment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: Text(widget.equipment != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  void _saveEquipment() {
    if (_formKey.currentState!.validate()) {
      final equipment = DeliveryEquipment(
        id:
            widget.equipment?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: _selectedType,
        status: _selectedStatus,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        purchasePrice: double.tryParse(_priceController.text),
        brand: _brandController.text.isEmpty ? null : _brandController.text,
        model: _modelController.text.isEmpty ? null : _modelController.text,
        serialNumber: _serialController.text.isEmpty
            ? null
            : _serialController.text,
        isRequired: widget.equipmentTypes
            .firstWhere((t) => t.id == _selectedType)
            .isRequired,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      widget.onSave(equipment);
      Navigator.of(context).pop();
    }
  }
}

// Equipment Details Dialog
class _EquipmentDetailsDialog extends StatelessWidget {
  final DeliveryEquipment equipment;
  final EquipmentType equipmentType;

  const _EquipmentDetailsDialog({
    required this.equipment,
    required this.equipmentType,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(equipment.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Type', equipmentType.name),
            _buildDetailRow('Arabic Name', equipmentType.nameArabic),
            _buildDetailRow('Status', equipment.status.toUpperCase()),
            if (equipment.brand != null)
              _buildDetailRow('Brand', equipment.brand!),
            if (equipment.model != null)
              _buildDetailRow('Model', equipment.model!),
            if (equipment.serialNumber != null)
              _buildDetailRow('Serial Number', equipment.serialNumber!),
            if (equipment.purchasePrice != null)
              _buildDetailRow(
                'Price',
                '${equipment.purchasePrice!.toInt()} IQD',
              ),
            if (equipment.purchaseDate != null)
              _buildDetailRow(
                'Purchase Date',
                '${equipment.purchaseDate!.day}/${equipment.purchaseDate!.month}/${equipment.purchaseDate!.year}',
              ),
            if (equipment.expiryDate != null)
              _buildDetailRow(
                'Expiry Date',
                '${equipment.expiryDate!.day}/${equipment.expiryDate!.month}/${equipment.expiryDate!.year}',
              ),
            if (equipment.notes != null)
              _buildDetailRow('Notes', equipment.notes!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
