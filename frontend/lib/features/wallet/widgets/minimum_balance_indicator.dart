import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';

/// The bar reflects the wallet's actual available/locked split, not eligibility.
class MinimumBalanceIndicator extends StatelessWidget {
  const MinimumBalanceIndicator({super.key, required this.balance});
  final WalletBalance balance;
  String _money(int n) =>
      '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} د.ع';
  @override
  Widget build(BuildContext context) {
    final share = balance.totalBalance > 0
        ? (balance.availableBalance / balance.totalBalance).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.shield_outlined, color: AppColors.secondary),
          SizedBox(width: 8),
          Expanded(
              child: Text('ضمان الطلبات',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)))
        ]),
        const SizedBox(height: 14),
        Text(
            balance.totalBalance > 0
                ? '${(share * 100).round()}٪ من رصيدك متاح'
                : 'لا يوجد رصيد حاليًا',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                color: AppColors.secondary,
                backgroundColor: balance.totalBalance > 0
                    ? const Color(0xFFB7C8DA)
                    : AppColors.grey200,
                semanticsLabel: 'نسبة الرصيد المتاح من إجمالي المحفظة',
                semanticsValue: '${(share * 100).round()} بالمئة')),
        const SizedBox(height: 10),
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('متاح: ${_money(balance.availableBalance)}',
                  style: const TextStyle(
                      color: AppColors.secondary, fontWeight: FontWeight.w600)),
              Text('محجوز: ${_money(balance.lockedBalance)}',
                  style: const TextStyle(color: AppColors.textSecondary))
            ]),
        Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 14),
                iconColor: AppColors.secondary,
                collapsedIconColor: AppColors.secondary,
                title: const Text('كيف يعمل الضمان؟',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary)),
                children: const [
                  Text(
                      'عند قبول طلب، يُحجز ضمان من رصيدك المتاح حسب مبلغ التحصيل ومستحقاتك. يظهر المبلغ المطلوب في تفاصيل العرض، ويُتحقق من كفاية الرصيد عند القبول.',
                      style:
                          TextStyle(height: 1.7, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                      'الحجز ليس خصمًا نهائيًا؛ تُسوّى قيمته عند التسليم أو الإلغاء وفق نتيجة الطلب. الرصيد المحجوز لا يُستخدم لقبول طلب آخر.',
                      style: TextStyle(
                          height: 1.7, color: AppColors.textSecondary)),
                ])),
        if (!balance.isActive)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('المحفظة غير نشطة؛ راجع الدعم لمعرفة سبب الحالة.',
                  style: TextStyle(color: AppColors.textPrimary))),
      ]),
    );
  }
}
