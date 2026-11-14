import 'package:flutter/material.dart';
import '../../../models/driver_profile.dart';

const _navy = Color(0xFF00296B);

String registrationValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ||
          ['pending', 'null', 'undefined', 'n/a'].contains(text.toLowerCase())
      ? 'غير مسجل'
      : text;
}

String registrationVehicleName(String type) => switch (type.toLowerCase()) {
      'car' => 'سيارة',
      'motorcycle' => 'دراجة نارية',
      'bicycle' => 'دراجة هوائية',
      _ => registrationValue(type),
    };

String registrationDocumentState(String? url, String? status) {
  if (registrationValue(url) == 'غير مسجل') return 'لم تُرفع الوثيقة';
  return switch (status?.toUpperCase()) {
    'VERIFIED' || 'APPROVED' => 'مرفوعة · معتمدة',
    'REJECTED' => 'مرفوعة · تحتاج إلى تصحيح',
    'EXPIRED' => 'مرفوعة · منتهية الصلاحية',
    'PENDING' || 'PENDING_REVIEW' => 'مرفوعة · قيد المراجعة',
    _ => 'مرفوعة · لم تُسجّل نتيجة المراجعة',
  };
}

class RegistrationCard extends StatelessWidget {
  const RegistrationCard(
      {super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

class RegistrationField extends StatelessWidget {
  const RegistrationField(this.label, this.value, this.icon, {super.key});
  final String label;
  final String? value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: _navy),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF667085))),
                const SizedBox(height: 5),
                Text(registrationValue(value),
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFF182230))),
              ])),
        ]),
      );
}

class RegistrationAreaCard extends StatelessWidget {
  const RegistrationAreaCard({super.key, required this.profile});
  final DriverProfile profile;
  @override
  Widget build(BuildContext context) =>
      RegistrationCard(title: 'منطقة العمل المسجلة', children: [
        if (profile.countryName?.isNotEmpty == true)
          RegistrationField(
              'البلد', profile.countryName, Icons.public_outlined),
        RegistrationField(
            'المحافظة', profile.governorateName, Icons.location_city_outlined),
        RegistrationField(
            'منطقة العمل', profile.workRegionName, Icons.map_outlined),
        RegistrationField(
            'أقرب نقطة دالة', profile.landmark, Icons.location_on_outlined),
        const SizedBox(height: 6),
        const Text(
            'لتغيير منطقة العمل أو نوع المركبة، تواصل مع الدعم لمراجعة البيانات.',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF667085), height: 1.6)),
      ]);
}

class RegistrationDocumentsCard extends StatelessWidget {
  const RegistrationDocumentsCard(
      {super.key, required this.profile, this.vehicleOnly = false});
  final DriverProfile profile;
  final bool vehicleOnly;
  @override
  Widget build(BuildContext context) =>
      RegistrationCard(title: 'الوثائق المطلوبة', children: [
        RegistrationField(
            'سنوية المركبة',
            registrationDocumentState(profile.vehicleRegistrationUrl,
                profile.vehicleRegistrationStatus),
            Icons.description_outlined),
        RegistrationField(
            'إجازة السوق / رخصة القيادة',
            registrationDocumentState(
                profile.drivingLicenseUrl, profile.drivingLicenseStatus),
            Icons.credit_card_outlined),
        if (!vehicleOnly)
          RegistrationField(
              'البطاقة الوطنية',
              registrationDocumentState(
                  profile.nationalIdUrl, profile.nationalIdStatus),
              Icons.badge_outlined),
        const SizedBox(height: 6),
        const Text(
            'حالة الرفع مستقلة عن مراجعة الوثيقة وصلاحيتها. اعتماد الحساب لا يثبت اعتماد كل وثيقة.',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF667085), height: 1.6)),
      ]);
}
