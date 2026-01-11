import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/colors.dart';
import '../../providers/simple_notification_provider.dart';
import '../../widgets/gradient_border_container.dart';
import '../../widgets/wizz_logo.dart';

class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update custom toggle appearance
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationsProvider);

    return Theme(
      // Override the entire theme to prevent any Material 3 color interference
      data: Theme.of(context).copyWith(
        primaryColor: Colors.transparent,
        tabBarTheme: const TabBarThemeData(
          indicator: BoxDecoration(color: Colors.transparent),
          indicatorColor: Colors.transparent,
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
        ),
        // Override any seed color that might generate yellow
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Colors.transparent,
          primaryContainer: Colors.transparent,
          secondary: Colors.transparent,
          secondaryContainer: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: HadhirColors.background,
        appBar: AppBar(
          backgroundColor: HadhirColors.primary,
          elevation: 0,
          shadowColor: HadhirColors.primary.withValues(alpha: 0.3),
          surfaceTintColor: HadhirColors.primary,
          scrolledUnderElevation: 1,
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          leading: const Padding(
            padding: EdgeInsets.all(8.0),
            child: WizzLogoCompact(size: 36),
          ),
          title: const Text(
            'الطلبات',
            style: TextStyle(
              color: HadhirColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          flexibleSpace: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 56), // Account for app bar height
                // Modern Toggle Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _buildModernAppBarToggle(),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Theme(
          // Override any theme interference for the TabBarView as well
          data: Theme.of(context).copyWith(
            primaryColor: Colors.transparent,
            tabBarTheme: const TabBarThemeData(indicatorColor: Colors.transparent),
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveOrdersList(notificationState.pendingNotifications),
              SingleChildScrollView(child: _buildOrderHistoryList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBarToggle() {
    return GradientBorderContainer(
      borderWidth: 1.5,
      borderRadius: 12,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white, // Monochrome: pure white background
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          // Override theme to prevent any Material 3 interference
          data: Theme.of(context).copyWith(
            primaryColor: Colors.transparent,
            tabBarTheme: TabBarThemeData(
              indicator: const BoxDecoration(color: Colors.transparent),
              indicatorColor: Colors.transparent,
              labelColor: HadhirColors.textPrimary,
              unselectedLabelColor: HadhirColors.textPrimary.withValues(
                alpha: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCustomToggleTab(
                  text: 'النشطة',
                  icon: Icons.pending_actions_outlined,
                  isActive: _tabController.index == 0,
                  onTap: () => _tabController.animateTo(0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildCustomToggleTab(
                  text: 'التاريخ',
                  icon: Icons.history_outlined,
                  isActive: _tabController.index == 1,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomToggleTab({
    required String text,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.transparent, // Ensure no background color interference
        ),
        child: isActive
            ? GradientBorderContainer(
                borderWidth: 1,
                borderRadius: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent, // Explicitly transparent
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Material(
                    color: Colors
                        .transparent, // Prevent Material widget interference
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: HadhirColors
                              .textPrimary, // Use text color for active state
                        ),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HadhirColors
                                .textPrimary, // Use text color for active state
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Material(
                  color: Colors
                      .transparent, // Prevent Material widget interference
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: HadhirColors.textPrimary.withValues(
                          alpha: 0.6,
                        ), // Use muted primary text color for inactive
                      ),
                      const SizedBox(width: 6),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HadhirColors.textPrimary.withValues(
                            alpha: 0.6,
                          ), // Use muted primary text color for inactive
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActiveOrdersList(List<dynamic> orders) {
    if (orders.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.1),
                    const Color(0xFF6366F1).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.pending_actions_rounded,
                size: 40,
                color: const Color(0xFF6366F1).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد طلبات نشطة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر الطلبات الجديدة هنا عندما تصل إليك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderHistoryList() {
    // Sample history orders data - in a real app, this would come from a provider or API
    final List<Map<String, dynamic>> historyOrders = [
      {
        'id': 'ORD_HIST_001',
        'customerName': 'أحمد محمد',
        'restaurantName': 'مطعم بغداد الأصيل',
        'totalAmount': '25000 د.ع',
        'status': 'delivered',
        'completedAt': '2024-01-15 14:30',
        'items': ['كباب عراقي', 'رز برياني', 'خبز'],
      },
      {
        'id': 'ORD_HIST_002',
        'customerName': 'فاطمة علي',
        'restaurantName': 'مطعم الشام',
        'totalAmount': '18000 د.ع',
        'status': 'delivered',
        'completedAt': '2024-01-14 19:45',
        'items': ['شاورما دجاج', 'بطاطس', 'عصير'],
      },
      {
        'id': 'ORD_HIST_003',
        'customerName': 'حسين كريم',
        'restaurantName': 'مطعم النجف التراثي',
        'totalAmount': '30000 د.ع',
        'status': 'cancelled',
        'completedAt': '2024-01-13 16:20',
        'items': ['مسكوف', 'خبز عراقي'],
      },
    ];

    if (historyOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF64748B).withValues(alpha: 0.1),
                    const Color(0xFF64748B).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF64748B).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 40,
                color: const Color(0xFF64748B).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا يوجد تاريخ طلبات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر الطلبات المكتملة والملغاة هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: historyOrders.length,
      itemBuilder: (context, index) {
        final order = historyOrders[index];
        return _buildHistoryOrderCard(order);
      },
    );
  }

  Widget _buildHistoryOrderCard(Map<String, dynamic> order) {
    final bool isDelivered = order['status'] == 'delivered';
    final Color statusColor = isDelivered
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final IconData statusIcon = isDelivered ? Icons.check_circle : Icons.cancel;
    final String statusText = isDelivered ? 'تم التوصيل' : 'ملغي';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GradientBorderContainer(
        borderWidth: 1.5,
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Monochrome: pure white background
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000), // Subtle monochrome shadow
                blurRadius: 16,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order['restaurantName'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(height: 4),
                          Text(
                            'العميل: ${order['customerName']}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'رقم الطلب: ${order['id']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Order details section
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA), // Light gray background
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الطلبات: ${(order['items'] as List).join(', ')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order['completedAt'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order['totalAmount'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildOrderCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GradientBorderContainer(
        borderWidth: 1.5,
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Monochrome: pure white background
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000), // Subtle monochrome shadow
                blurRadius: 16,
                offset: Offset(0, 2),
              ),
            ],
          ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_outlined,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب توصيل جديد',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'انقر للاطلاع على التفاصيل',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // Handle accept order
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'قبول الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
