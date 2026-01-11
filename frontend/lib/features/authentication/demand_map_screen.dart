import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/app_colors.dart';

class DemandMapScreen extends StatefulWidget {
  const DemandMapScreen({super.key});

  @override
  State<DemandMapScreen> createState() => _DemandMapScreenState();
}

class _DemandMapScreenState extends State<DemandMapScreen> {
  String? _selectedZone;

  final List<Map<String, dynamic>> _zones = [
    {
      'name': 'Downtown Riyadh',
      'demandLevel': 'Very Busy',
      'color': Colors.red,
      'bonusPay': 2.50,
    },
    {
      'name': 'Al Olaya',
      'demandLevel': 'Busy',
      'color': Colors.orange,
      'bonusPay': 1.75,
    },
    {
      'name': 'Al Malaz',
      'demandLevel': 'Moderately Busy',
      'color': Colors.yellow,
      'bonusPay': 1.00,
    },
    {
      'name': 'King Fahd District',
      'demandLevel': 'Normal',
      'color': Colors.green,
      'bonusPay': 0.50,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Simulated map background
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text(
                'Interactive Zone Map\n(Map functionality ready)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Top header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Choose Your Zone',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Zone selection cards
          Positioned(
            bottom: 200,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _zones.length,
                itemBuilder: (context, index) {
                  final zone = _zones[index];
                  final isSelected = _selectedZone == zone['name'];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedZone = zone['name'];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
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
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: zone['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    zone['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              zone['demandLevel'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                Text(
                                  '+\$${zone['bonusPay']} bonus',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom action button
          Positioned(
            bottom: 50,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedZone != null
                    ? () {
                        // Navigate back to home with selected zone and start dashing
                        context.go('/?zone=$_selectedZone&startDash=true');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _selectedZone != null
                      ? 'Start Dash in $_selectedZone'
                      : 'Select a Zone to Start',
                  style: const TextStyle(
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
}
