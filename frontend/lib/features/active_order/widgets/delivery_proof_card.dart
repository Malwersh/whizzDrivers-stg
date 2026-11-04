import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/active_order_model.dart';
import '../services/delivery_proof_service.dart';
import 'active_trip_summary.dart';

Uint8List prepareDeliveryPhoto(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) throw Exception('تعذر قراءة الصورة');
  image = img.bakeOrientation(image);
  if (image.width > 1600 || image.height > 1600)
    image = img.copyResize(image,
        width: image.width >= image.height ? 1600 : null,
        height: image.height > image.width ? 1600 : null);
  image.exif = img.ExifData();
  image.iccProfile = null;
  final output = Uint8List.fromList(img.encodeJpg(image, quality: 80));
  if (output.length > 1500000)
    throw Exception('حجم الصورة كبير؛ التقط صورة أخرى');
  return output;
}

class DeliveryProofCard extends StatefulWidget {
  const DeliveryProofCard(
      {super.key,
      required this.order,
      required this.onBusy,
      this.service,
      this.pick,
      this.readOnly = false});
  final bool readOnly;
  final ActiveOrder order;
  final ValueChanged<bool> onBusy;
  final DeliveryProofService? service;
  final Future<Uint8List?> Function()? pick;
  @override
  State<DeliveryProofCard> createState() => _DeliveryProofCardState();
}

class _DeliveryProofCardState extends State<DeliveryProofCard> {
  late final service = widget.service ?? DeliveryProofService();
  List<Map<String, dynamic>> photos = [];
  Uint8List? pending;
  String? pendingId, error;
  bool busy = false, loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final result = await service.list(widget.order.orderId);
      if (mounted)
        setState(() {
          photos = result;
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل صور التسليم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (busy || loading) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusy(true);
    try {
      if (pending == null) {
        final selected = widget.pick != null
            ? await widget.pick!()
            : await (() async {
                final file = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    requestFullMetadata: false,
                    maxWidth: 1920,
                    maxHeight: 1920,
                    imageQuality: 85);
                return file?.readAsBytes();
              })();
        if (selected == null) return;
        pending = await compute(prepareDeliveryPhoto, selected);
        pendingId = const Uuid().v4();
      }
      final saved = await service.upload(widget.order.orderId, pendingId!,
          pending!, widget.order.financialAssignment);
      if (!mounted) return;
      setState(() {
        if (!photos.any((p) => p['id'] == saved['id'])) photos.add(saved);
        pending = null;
        pendingId = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => error = pending == null
            ? 'تعذر التقاط الصورة؛ حاول مجددًا'
            : 'لم يتأكد حفظ الصورة. اضغط إعادة المحاولة.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusy(false);
      }
    }
  }

  Future<void> preview(String id) async {
    try {
      final bytes = await service.view(widget.order.orderId, id);
      if (!mounted) return;
      await showDialog(
          context: context,
          builder: (ctx) => Dialog(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    child: InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق'))
              ])));
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر عرض الصورة؛ حاول مجددًا');
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E9F1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('توثيق التسليم',
            style: TextStyle(
                color: TripStyle.ink,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            widget.readOnly
                ? 'الصور المحفوظة لتوثيق هذا التسليم.'
                : 'صورة اختيارية للطلب عند التسليم. تجنّب تصوير الأشخاص أو معلوماتهم الخاصة.',
            style: TextStyle(color: TripStyle.muted, height: 1.6)),
        if (loading || busy)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(color: TripStyle.blue)),
        for (final photo in photos)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.verified_outlined, color: TripStyle.blue),
              title: const Text('صورة محفوظة مع الطلب'),
              subtitle: Text(
                  (DateTime.tryParse(photo['uploadedAt'] as String? ?? '')
                              ?.toLocal()
                              .toString() ??
                          '')
                      .split('.')
                      .first),
              trailing: const Icon(Icons.chevron_left),
              onTap: busy ? null : () => preview(photo['id'] as String)),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (!widget.readOnly && !loading && photos.length < 3)
          OutlinedButton.icon(
              onPressed: busy ? null : save,
              icon: Icon(
                  pending == null ? Icons.camera_alt_outlined : Icons.refresh),
              label: Text(pending == null
                  ? 'التقاط وحفظ صورة'
                  : 'إعادة محاولة حفظ الصورة'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: TripStyle.blue,
                  minimumSize: const Size(double.infinity, 48))),
        if (error != null && pending == null)
          TextButton(
              onPressed: busy ? null : load, child: const Text('تحديث الصور')),
      ]));
}
