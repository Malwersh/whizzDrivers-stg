import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/map_data.dart';

const mapInk = Color(0xFF00296B);

class DriverMapButton extends StatelessWidget {
  const DriverMapButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  Color get _iconColor {
    if (icon == Icons.local_fire_department_outlined) {
      return selected ? const Color(0xFFBF4820) : const Color(0xFFD26827);
    }
    if (icon == Icons.bar_chart_rounded) return const Color(0xFF5854A8);
    if (icon == Icons.support_agent_outlined) return const Color(0xFF087F83);
    if (icon == Icons.my_location) return const Color(0xFF2473AB);
    if (icon == Icons.search) return const Color(0xFF285FA5);
    return mapInk;
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      child: DecoratedBox(
          decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(
                color: Color(0x1F24354D),
                blurRadius: 12,
                spreadRadius: 1,
                offset: Offset(0, 2))
          ]),
          child: Material(
              shape: CircleBorder(
                  side: BorderSide(
                      color: selected
                          ? _iconColor.withValues(alpha: .65)
                          : Colors.white,
                      width: selected ? 1.5 : 1)),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                      dimension: 52,
                      child: Icon(icon,
                          color: onPressed == null ? Colors.grey : _iconColor,
                          size: 30))))));
}

String storeSearchKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[ًٌٍَُِّْـ]'), '');
List<NearbyStore> matchingMapStores(List<NearbyStore> stores, String query) =>
    stores
        .where((s) =>
            s.lat.isFinite &&
            s.lng.isFinite &&
            s.lat.abs() <= 90 &&
            s.lng.abs() <= 180 &&
            (s.lat != 0 || s.lng != 0) &&
            storeSearchKey(s.name).contains(storeSearchKey(query)))
        .toList();

class MapStoreSearchSheet extends StatefulWidget {
  const MapStoreSearchSheet(
      {super.key, required this.stores, this.initialQuery = ''});
  final List<NearbyStore> stores;
  final String initialQuery;
  @override
  State<MapStoreSearchSheet> createState() => _MapStoreSearchSheetState();
}

class _MapStoreSearchSheetState extends State<MapStoreSearchSheet> {
  late final TextEditingController text;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stores = matchingMapStores(widget.stores, text.text);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 12),
                child: SizedBox(
                    height: math.max(
                        0,
                        math.min(
                            MediaQuery.sizeOf(context).height * .55,
                            MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom -
                                MediaQuery.paddingOf(context).top -
                                80)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Expanded(
                                child: Text('ابحث على الخريطة',
                                    style: TextStyle(
                                        color: mapInk,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600))),
                            IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: mapInk))
                          ]),
                          TextField(
                              controller: text,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                  hintText: 'اسم المطعم أو المتجر',
                                  prefixIcon:
                                      const Icon(Icons.search, color: mapInk),
                                  suffixIcon: text.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'مسح البحث',
                                          onPressed: () {
                                            text.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close)),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)))),
                          const SizedBox(height: 8),
                          Text(
                              '${stores.length} من المتاجر الظاهرة على الخريطة',
                              style: const TextStyle(
                                  color: Color(0xFF53627B), fontSize: 12)),
                          Expanded(
                              child: stores.isEmpty
                                  ? const Center(
                                      child: Text('لا توجد نتائج مطابقة.'))
                                  : ListView.builder(
                                      itemCount: stores.length,
                                      itemBuilder: (c, i) {
                                        final s = stores[i];
                                        return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                                Icons.storefront_outlined,
                                                color: mapInk),
                                            title: Text(s.name),
                                            subtitle: Text(s.address,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            trailing: const Icon(
                                                Icons.chevron_left,
                                                color: mapInk),
                                            onTap: () =>
                                                Navigator.pop(context, s));
                                      }))
                        ])))));
  }
}
