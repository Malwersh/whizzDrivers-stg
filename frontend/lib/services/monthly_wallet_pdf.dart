import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/monthly_wallet_statement.dart';

class MonthlyWalletPdf {
  static Future<Uint8List> generate(MonthlyWalletStatement statement) async {
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    final doc = pw.Document(
        title: 'كشف محفظة السائق ${statement.month}', author: 'Wizzer');
    final navy = PdfColor.fromHex('#0B2F67');
    String money(int n) =>
        '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} د.ع';
    String date(DateTime d) =>
        MonthlyWalletStatement.baghdad(d).toString().substring(0, 16);
    pw.Widget summary(String label, int value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label),
              pw.Text(money(value), style: pw.TextStyle(color: navy))
            ]));
    String title(String text) => String.fromCharCodes(text.runes
            .where((r) =>
                r <= 0xFFFF &&
                r != 0xFE0F &&
                r != 0x200D &&
                !(r >= 0x2600 && r <= 0x27BF))
            .take(200))
        .trim();
    final rows = statement.visible;
    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 10000,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (c) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الكشف الشهري لمحفظة السائق',
                      style: pw.TextStyle(fontSize: 18, color: navy)),
                  pw.Text(statement.month)
                ])),
        footer: (c) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text('صفحة ${c.pageNumber} / ${c.pagesCount}',
                style: const pw.TextStyle(fontSize: 9))),
        build: (c) => [
              pw.Text('حتى ${date(statement.asOf)} — بتوقيت بغداد',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              summary('الإضافات الفعلية', statement.credits),
              summary('الخصومات الفعلية', statement.debits),
              summary('صافي تغيّر المحفظة', statement.net),
              pw.Divider(),
              summary('حُجز مؤقتًا خلال الشهر', statement.holds),
              summary('فُك حجزه خلال الشهر', statement.releases),
              pw.SizedBox(height: 8),
              pw.Text(
                  'الحجز وفكّه حركات داخلية؛ صافي التغير ليس الرصيد الحالي. أجور التوصيل التي يحتفظ بها السائق نقدًا لا تدخل في هذا الكشف.',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 18),
              pw.Text('الحركات (${rows.length})',
                  style: pw.TextStyle(fontSize: 14, color: navy)),
              pw.SizedBox(height: 8),
              if (rows.isEmpty) pw.Text('لا توجد حركات في هذا الشهر'),
              for (final t in rows)
                pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey300))),
                    child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                              child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                pw.Text(title(t.displayTitle),
                                    style: const pw.TextStyle(fontSize: 11)),
                                pw.SizedBox(height: 3),
                                pw.Text(date(t.createdAt),
                                    style: const pw.TextStyle(fontSize: 9)),
                                pw.Text(
                                    t.isReversed
                                        ? 'ملغاة'
                                        : MonthlyWalletStatement.isInternal(t)
                                            ? 'حركة حجز داخلية'
                                            : t.isCredit
                                                ? 'إضافة'
                                                : 'خصم',
                                    style: const pw.TextStyle(fontSize: 9))
                              ])),
                          pw.Text('${t.amountSign}${money(t.amount)}',
                              style: pw.TextStyle(fontSize: 11, color: navy))
                        ])),
            ]));
    return doc.save();
  }
}
