import 'package:flutter/material.dart';
import 'application_legal_bundle.dart';
import 'application_legal_service.dart';

class ApplicationLegalScreen extends StatefulWidget {
  final String? documentId;
  final ApplicationLegalBundle? bundle;
  final ApplicationLegalService? service;
  const ApplicationLegalScreen({
    super.key,
    this.documentId,
    this.bundle,
    this.service,
  });
  @override
  State<ApplicationLegalScreen> createState() => _ApplicationLegalScreenState();
}

class _ApplicationLegalScreenState extends State<ApplicationLegalScreen> {
  late Future<ApplicationLegalBundle> _load;
  @override
  void initState() {
    super.initState();
    _load = widget.bundle != null
        ? Future.value(widget.bundle!)
        : (widget.service ?? ApplicationLegalService.instance).load(
            refresh: true,
          );
  }

  void retry() => setState(
        () => _load = (widget.service ?? ApplicationLegalService.instance).load(
          refresh: true,
        ),
      );
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF00296B),
            title: FutureBuilder<ApplicationLegalBundle>(
              future: _load,
              builder: (context, state) => Text(
                widget.documentId != null && state.hasData
                    ? state.data!.document(widget.documentId!)['title']
                    : 'السياسات والشروط',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          body: FutureBuilder<ApplicationLegalBundle>(
            future: _load,
            builder: (context, state) {
              if (state.connectionState != ConnectionState.done)
                return const Center(
                  child:
                      CircularProgressIndicator(color: const Color(0xFF00296B)),
                );
              if (!state.hasData)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.article_outlined,
                          color: const Color(0xFF00296B),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تعذر تحميل السياسات المنشورة. تحقق من الاتصال ثم أعد المحاولة.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: retry,
                          child: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(color: const Color(0xFF00296B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              final b = state.data!;
              if (widget.documentId == null)
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'يمكنك الرجوع إلى هذه الصفحات في أي وقت.',
                      style: TextStyle(color: Color(0xFF53627B), height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    for (final d in b.documents)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE4EAF2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          leading: const Icon(
                            Icons.description_outlined,
                            color: const Color(0xFF00296B),
                          ),
                          title: Text(
                            d['title'],
                            style: const TextStyle(
                              color: const Color(0xFF00296B),
                              fontSize: 16,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_left,
                            color: const Color(0xFF00296B),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApplicationLegalScreen(
                                documentId: d['id'],
                                bundle: b,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _footer(b),
                  ],
                );
              final doc = b.document(widget.documentId!);
              final date = DateTime.parse(
                b.publishedAt,
              ).toUtc().add(const Duration(hours: 3));
              return ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    doc['title'],
                    style: const TextStyle(
                      color: const Color(0xFF00296B),
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الإصدار ${b.revision} · آخر تحديث: ${date.year}/${date.month}/${date.day}',
                    style:
                        const TextStyle(color: Color(0xFF65728A), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  for (final s in doc['sections'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            s['heading'],
                            style: const TextStyle(
                              color: const Color(0xFF00296B),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s['body'],
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 16,
                              height: 1.85,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _footer(b),
                ],
              );
            },
          ),
        ),
      );
  Widget _footer(ApplicationLegalBundle b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 24),
            Image.asset(
              b.brand['logoKey'] == 'WIZZ_PRIMARY'
                  ? 'assets/images/wizz-company-primary.png'
                  : 'assets/images/wizz-wordmark-blue.png',
              width: 120,
              height: 65,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              b.brand['companyName'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: const Color(0xFF00296B),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              b.brand['appName'],
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Text(
              b.brand['supportPhone'],
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Color(0xFF53627B)),
            ),
            if ((b.brand['supportEmail'] as String).isNotEmpty)
              Text(
                b.brand['supportEmail'],
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Color(0xFF53627B)),
              ),
          ],
        ),
      );
}
