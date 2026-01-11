import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/earnings.dart';
import '../../../services/driver_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      // In a real app, this would come from DriverService.getPaymentMethods()
      // For now, we'll create some dummy data
      setState(() {
        _paymentMethods = [
          PaymentMethod(
            id: '1',
            type: 'zain_cash',
            displayName: 'Zain Cash',
            phoneNumber: '+964 7XX XXX XXXX',
            isDefault: true,
            isActive: true,
          ),
          PaymentMethod(
            id: '2',
            type: 'bank_account',
            displayName: 'Bank of Baghdad',
            accountNumber: '**** **** **** 1234',
            isDefault: false,
            isActive: true,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading payment methods: $e');
    }
  }

  Future<void> _addPaymentMethod() async {
    final result = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddPaymentMethodSheet(),
    );

    if (result != null) {
      final success = await DriverService.addPaymentMethod(result);
      if (success) {
        setState(() {
          _paymentMethods.add(result);
        });
        _showSuccessSnackBar('Payment method added successfully');
      } else {
        _showErrorSnackBar('Failed to add payment method');
      }
    }
  }

  Future<void> _removePaymentMethod(PaymentMethod method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Method'),
        content: Text('Are you sure you want to remove ${method.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await DriverService.removePaymentMethod(method.id);
      if (success) {
        setState(() {
          _paymentMethods.removeWhere((m) => m.id == method.id);
        });
        _showSuccessSnackBar('Payment method removed');
      } else {
        _showErrorSnackBar('Failed to remove payment method');
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paymentMethods.length,
                    itemBuilder: (context, index) {
                      final method = _paymentMethods[index];
                      return _buildPaymentMethodCard(method);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _addPaymentMethod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: AppColors.white),
                      label: const Text(
                        'Add Payment Method',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    IconData icon;
    Color color;

    switch (method.type) {
      case 'zain_cash':
        icon = Icons.phone_android;
        color = AppColors.primary;
        break;
      case 'asia_cell_pay':
        icon = Icons.phone_android;
        color = Colors.blue;
        break;
      case 'ki_card':
        icon = Icons.credit_card;
        color = Colors.green;
        break;
      case 'bank_account':
        icon = Icons.account_balance;
        color = Colors.orange;
        break;
      default:
        icon = Icons.payment;
        color = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: method.isDefault
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (method.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  method.accountNumber ?? method.phoneNumber ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') {
                _removePaymentMethod(method);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Remove'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddPaymentMethodSheet extends StatefulWidget {
  const AddPaymentMethodSheet({super.key});

  @override
  State<AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  String? _selectedType;
  final _phoneController = TextEditingController();
  final _accountController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _paymentTypes = [
    {
      'type': 'zain_cash',
      'name': 'Zain Cash',
      'icon': Icons.phone_android,
      'color': AppColors.primary,
      'requiresPhone': true,
    },
    {
      'type': 'asia_cell_pay',
      'name': 'Asia Cell Pay',
      'icon': Icons.phone_android,
      'color': Colors.blue,
      'requiresPhone': true,
    },
    {
      'type': 'ki_card',
      'name': 'Ki Card',
      'icon': Icons.credit_card,
      'color': Colors.green,
      'requiresPhone': true,
    },
    {
      'type': 'bank_account',
      'name': 'Bank Account',
      'icon': Icons.account_balance,
      'color': Colors.orange,
      'requiresPhone': false,
    },
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _addPaymentMethod() async {
    if (_selectedType == null) return;

    final typeData = _paymentTypes.firstWhere(
      (t) => t['type'] == _selectedType,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final paymentMethod = PaymentMethod(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedType!,
        displayName: typeData['name'],
        phoneNumber: typeData['requiresPhone'] ? _phoneController.text : null,
        accountNumber: !typeData['requiresPhone']
            ? _accountController.text
            : null,
        isDefault: false,
        isActive: true,
      );

      Navigator.pop(context, paymentMethod);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Payment Method',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          ...List.generate(_paymentTypes.length, (index) {
            final type = _paymentTypes[index];
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type['type']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedType == type['type']
                        ? AppColors.primary
                        : AppColors.grey300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(type['icon'], color: type['color'], size: 24),
                    const SizedBox(width: 16),
                    Text(
                      type['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedType == type['type'])
                      const Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),

          if (_selectedType != null) ...[
            const SizedBox(height: 20),
            if (_paymentTypes.firstWhere(
              (t) => t['type'] == _selectedType,
            )['requiresPhone'])
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+964 7XX XXX XXXX',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  hintText: 'Enter account number',
                  border: OutlineInputBorder(),
                ),
              ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedType != null && !_isLoading
                  ? _addPaymentMethod
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : const Text(
                      'Add Payment Method',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
