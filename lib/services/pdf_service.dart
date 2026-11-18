import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';
import '../utils/app_utils.dart';

class PdfService {
  static const _htmlPdfChannel = MethodChannel('efatura_app/html_pdf');

  static final _currency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );
  static final _number = NumberFormat('#,##0.##', 'tr_TR');

  static String _fmt(double v) => _currency.format(v);
  static String _num(double v) => _number.format(v);

  static Future<Uint8List> generatePdfFromHtml(String htmlContent) async {
    if (Platform.isAndroid) {
      final bytes = await _htmlPdfChannel
          .invokeMethod<Uint8List>('renderHtmlToPdf', {'html': htmlContent})
          .timeout(const Duration(seconds: 20));
      if (bytes == null || bytes.isEmpty) {
        throw Exception('PDF oluşturuldu ama içerik boş geldi.');
      }
      return bytes;
    }

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 5 * PdfPageFormat.mm,
      marginTop: 5 * PdfPageFormat.mm,
      marginRight: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
    );
    // ignore: deprecated_member_use
    return Printing.convertHtml(html: htmlContent, format: pageFormat)
        .timeout(const Duration(seconds: 20));
  }

  /// GİB'den gelen orijinal HTML içeriğini PDF'e dönüştürür ve sistem paylaşım diyaloğunu açar
  static Future<void> shareHtmlPdf(String htmlContent, String targetName) async {
    final bytes = await generatePdfFromHtml(htmlContent);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safePdfName(targetName)}.pdf',
    );
  }

  static Future<void> printHtmlPdf(String htmlContent, String targetName) async {
    await Printing.layoutPdf(
      name: _safePdfName(targetName),
      format: PdfPageFormat.a4,
      onLayout: (_) => generatePdfFromHtml(htmlContent),
    );
  }

  static Future<void> printOrShareHtml(String htmlContent, String targetName) {
    return shareHtmlPdf(htmlContent, targetName);
  }

  static String _safePdfName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return cleaned.isEmpty ? 'fatura' : cleaned;
  }
  /// Faturadan PDF byte'ları üretir (Yerel/Şablon Tasarım)
  static Future<Uint8List> generateInvoicePdf(InvoiceModel invoice) async {
    final doc = pw.Document(
      title: 'Fatura ${invoice.faturaNo ?? invoice.uuid.substring(0, 8)}',
      author: 'eArşiv Fatura',
    );

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    final baseStyle = pw.TextStyle(font: regular, fontSize: 9);
    final boldStyle = pw.TextStyle(font: bold, fontSize: 9);
    final titleStyle = pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.white);
    final headerStyle = pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white);
    final subStyle = pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey700);

    const primaryColor = PdfColor.fromInt(0xFF1A3A5C);
    const accentColor = PdfColor.fromInt(0xFF2E7D52);
    const lightBg = PdfColor.fromInt(0xFFF8F9FA);
    const borderColor = PdfColor.fromInt(0xFFE0E0E0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const pw.BoxDecoration(color: primaryColor),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FATURA', style: titleStyle),
                        pw.SizedBox(height: 4),
                        if (invoice.faturaNo != null)
                          pw.Text(invoice.faturaNo!, style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Tarih', style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white)),
                        pw.Text(AppUtils.gibDateToDisplay(invoice.tarih),
                            style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text('Saat', style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white)),
                        pw.Text(invoice.saat,
                            style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Alıcı Bilgileri
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(color: primaryColor),
                      child: pw.Text('ALICI BİLGİLERİ', style: headerStyle),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (invoice.customer.unvan?.isNotEmpty ?? false)
                                _infoRow('Ünvan', invoice.customer.unvan!, bold, regular),
                              if (invoice.customer.ad?.isNotEmpty ?? false)
                                _infoRow('Ad Soyad',
                                    '${invoice.customer.ad ?? ''} ${invoice.customer.soyad ?? ''}'.trim(),
                                    bold, regular),
                              _infoRow('VKN / TCKN', invoice.customer.vknTckn, bold, regular),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (invoice.customer.vergiDairesi?.isNotEmpty ?? false)
                                _infoRow('Vergi Dairesi', invoice.customer.vergiDairesi!, bold, regular),
                              if (invoice.customer.adres?.isNotEmpty ?? false)
                                _infoRow('Adres', invoice.customer.adres!, bold, regular),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Kalemler Tablosu
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      _th('Mal / Hizmet', headerStyle),
                      _th('Miktar', headerStyle, align: pw.TextAlign.center),
                      _th('Birim Fiyat', headerStyle, align: pw.TextAlign.right),
                      _th('Tutar', headerStyle, align: pw.TextAlign.right),
                      _th('KDV %20', headerStyle, align: pw.TextAlign.right),
                      _th('Toplam', headerStyle, align: pw.TextAlign.right),
                    ],
                  ),
                  ...invoice.items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final bg = i.isEven ? PdfColors.white : lightBg;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bg),
                      children: [
                        _td(item.malHizmet, baseStyle),
                        _td('${_num(item.miktar)} ${item.birim}', baseStyle, align: pw.TextAlign.center),
                        _td(_fmt(item.birimFiyat), baseStyle, align: pw.TextAlign.right),
                        _td(_fmt(item.fiyat), baseStyle, align: pw.TextAlign.right),
                        _td(_fmt(item.kdvTutar), baseStyle, align: pw.TextAlign.right),
                        _td(_fmt(item.fiyat + item.kdvTutar), boldStyle, align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Toplamlar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      children: [
                        _totalRow('Ara Toplam', _fmt(invoice.toplamTutar), regular, bold),
                        pw.Divider(color: borderColor, height: 1),
                        _totalRow('KDV (%20)', _fmt(invoice.kdvTutar), regular, bold),
                        pw.Divider(color: borderColor, height: 1),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const pw.BoxDecoration(color: primaryColor),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('GENEL TOPLAM',
                                  style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white)),
                              pw.Text(_fmt(invoice.genelToplam),
                                  style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (invoice.notlar?.isNotEmpty ?? false) ...[
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    border: pw.Border.all(color: borderColor),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NOT', style: boldStyle),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.notlar!, style: baseStyle),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(color: borderColor),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('eArşiv Fatura Uygulaması', style: subStyle),
                  pw.Text(
                    'Durum: ${AppUtils.statusLabel(invoice.onayDurumu)}',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 8,
                      color: invoice.onayDurumu == 'Onaylandı'
                          ? accentColor
                          : PdfColors.orange,
                    ),
                  ),
                  pw.Text(
                    'UUID: ${invoice.uuid.substring(0, 18)}...',
                    style: subStyle,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printOrShare(InvoiceModel invoice) async {
    final bytes = await generateInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'fatura_${invoice.faturaNo ?? invoice.uuid.substring(0, 8)}.pdf',
    );
  }

  static Future<void> printInvoice(InvoiceModel invoice) async {
    await Printing.layoutPdf(
      onLayout: (_) async => generateInvoicePdf(invoice),
      name: 'fatura_${invoice.faturaNo ?? invoice.uuid.substring(0, 8)}',
    );
  }

  static pw.Widget _th(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _td(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.Font bold, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey600)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9)),
        ],
      ),
    );
  }
}


