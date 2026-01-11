import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../widgets/support_chat_widgets.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Daily', 'Weekly'];

  // Hadhir driver earnings data
  final List<Map<String, dynamic>> _dailyEarnings = [
    {
      'date': 'Today',
      'fullDate': 'Sunday, Dec 15',
      'totalEarnings': 89.75,
      'deliveries': 6,
      'hours': 4.5,
      'tips': 32.50,
      'dasherPay': 57.25,
      'trips': [
        {
          'time': '2:30 PM',
          'amount': 18.50,
          'tip': 5.00,
          'restaurant': 'Al-Baghdadia Restaurant',
          'distance': 2.1,
        },
        {
          'time': '1:45 PM',
          'amount': 15.25,
          'tip': 8.00,
          'restaurant': 'Fast Food Palace',
          'distance': 1.8,
        },
        {
          'time': '1:15 PM',
          'amount': 12.75,
          'tip': 3.50,
          'restaurant': 'Coffee Corner',
          'distance': 0.9,
        },
      ],
    },
    {
      'date': 'Yesterday',
      'fullDate': 'Saturday, Dec 14',
      'totalEarnings': 125.30,
      'deliveries': 8,
      'hours': 6.0,
      'tips': 48.75,
      'dasherPay': 76.55,
      'trips': [],
    },
    {
      'date': 'Friday',
      'fullDate': 'Friday, Dec 13',
      'totalEarnings': 98.40,
      'deliveries': 5,
      'hours': 5.5,
      'tips': 38.90,
      'dasherPay': 59.50,
      'trips': [],
    },
  ];

  final List<Map<String, dynamic>> _weeklyEarnings = [
    {
      'week': 'This Week',
      'period': 'Dec 9 - Dec 15',
      'totalEarnings': 487.25,
      'tripCount': 32,
      'hours': 28.5,
      'tips': 185.50,
      'dasherPay': 301.75,
      'deliveries': [
        {'day': 'Sunday', 'earnings': 89.75, 'trips': 6},
        {'day': 'Saturday', 'earnings': 125.30, 'trips': 8},
        {'day': 'Friday', 'earnings': 98.40, 'trips': 5},
        {'day': 'Thursday', 'earnings': 76.80, 'trips': 4},
        {'day': 'Wednesday', 'earnings': 97.00, 'trips': 9},
        {'day': 'Tuesday', 'earnings': 0.00, 'trips': 0},
        {'day': 'Monday', 'earnings': 0.00, 'trips': 0},
      ],
    },
    {
      'week': 'Last Week',
      'period': 'Dec 2 - Dec 8',
      'totalEarnings': 542.15,
      'tripCount': 38,
      'hours': 32.0,
      'tips': 198.25,
      'dasherPay': 343.90,
      'deliveries': [
        {'day': 'Sunday', 'earnings': 112.35, 'trips': 7},
        {'day': 'Saturday', 'earnings': 145.80, 'trips': 9},
        {'day': 'Friday', 'earnings': 98.75, 'trips': 6},
        {'day': 'Thursday', 'earnings': 89.45, 'trips': 5},
        {'day': 'Wednesday', 'earnings': 95.80, 'trips': 8},
        {'day': 'Tuesday', 'earnings': 0.00, 'trips': 0},
        {'day': 'Monday', 'earnings': 0.00, 'trips': 3},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundGrey,
      child: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.grey200, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),

          // Summary Card (Hadhir style)
          _summaryCard(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_dailyEarningsView(), _weeklyEarningsView()],
            ),
          ),

          // Support Card for Earnings Issues
          _buildEarningsSupportCard(),

          // Payout Info (Hadhir style)
          _payoutInfo(),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final isDaily = _tabController.index == 0;
    final data = isDaily ? _dailyEarnings.first : _weeklyEarnings.first;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.secondary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total earnings
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: AppColors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                '\$${data['totalEarnings'].toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDaily ? 'Today\'s Earnings' : 'This Week\'s Earnings',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                'Deliveries',
                isDaily
                    ? data['deliveries'].toString()
                    : data['tripCount'].toString(),
                Icons.receipt_long,
              ),
              _statItem(
                'Hours',
                data['hours'].toStringAsFixed(1),
                Icons.access_time,
              ),
              _statItem(
                'Tips',
                '\$${data['tips'].toStringAsFixed(2)}',
                Icons.thumb_up,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _dailyEarningsView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _dailyEarnings.length,
      itemBuilder: (context, index) {
        final day = _dailyEarnings[index];
        return _dailyEarningsCard(day);
      },
    );
  }

  Widget _weeklyEarningsView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _weeklyEarnings.length,
      itemBuilder: (context, index) {
        final week = _weeklyEarnings[index];
        return _weeklyEarningsCard(week);
      },
    );
  }

  Widget _dailyEarningsCard(Map<String, dynamic> day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day['date'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      day['fullDate'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${day['totalEarnings'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Breakdown
            Row(
              children: [
                Expanded(
                  child: _breakdownItem(
                    'Base Pay',
                    '\$${day['dasherPay'].toStringAsFixed(2)}',
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _breakdownItem(
                    'Tips',
                    '\$${day['tips'].toStringAsFixed(2)}',
                    AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _breakdownItem(
                    'Deliveries',
                    day['deliveries'].toString(),
                    AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _breakdownItem(
                    'Hours',
                    '${day['hours']} hrs',
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // Trip details (if available)
            if (day['trips'] != null && (day['trips'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Recent Deliveries',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...((day['trips'] as List)
                  .take(3)
                  .map((trip) => _tripItem(trip))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weeklyEarningsCard(Map<String, dynamic> week) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week['week'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      week['period'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${week['totalEarnings'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _weeklyStatItem(
                      'Total Trips',
                      week['tripCount'].toString(),
                    ),
                  ),
                  Expanded(
                    child: _weeklyStatItem('Hours', '${week['hours']} hrs'),
                  ),
                  Expanded(
                    child: _weeklyStatItem(
                      'Tips',
                      '\$${week['tips'].toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily breakdown
            const Text(
              'Daily Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...((week['deliveries'] as List).map((day) => _dayItem(day))),
          ],
        ),
      ),
    );
  }

  Widget _breakdownItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _weeklyStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _tripItem(Map<String, dynamic> trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip['restaurant'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${trip['distance']} mi • ${trip['time']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${trip['amount'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '+\$${trip['tip'].toStringAsFixed(2)} tip',
                style: const TextStyle(fontSize: 12, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayItem(Map<String, dynamic> day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day['day'],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              Text(
                '${day['trips']} trips',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '\$${day['earnings'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payoutInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey200, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Weekly payouts are deposited every Monday',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  SupportChatBottomSheet.show(
                    context,
                    driverId:
                        'current_driver_id', // TODO: Get from auth provider
                    driverName:
                        'Current Driver', // TODO: Get from auth provider
                  );
                },
                child: const Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSupportCard() {
    return const SupportChatCard(
      driverId: 'current_driver_id', // TODO: Get from auth provider
      driverName: 'Current Driver', // TODO: Get from auth provider
      quickTopics: [
        'Payment Issue',
        'Missing Earnings',
        'Payout Question',
        'Tax Information',
      ],
    );
  }
}
