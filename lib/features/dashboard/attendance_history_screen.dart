import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/utils/battery_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_switcher.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_button.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  String _displayName = "INTERN";
  String _school = "NOT SET";
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    _fetchAttendanceData();
    _fetchProfileInfo();
  }

  @override
  void dispose() {
    UltraBatterySaver.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileInfo() async {
    if (user == null) return;
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('intern_profiles')
          .doc(user!.uid)
          .get();
      if (profileDoc.exists) {
        setState(() {
          _displayName = profileDoc.data()?['username'] ?? "INTERN";
          _school = profileDoc.data()?['school'] ?? "NOT SET";
        });
      }
    } catch (e) {
      // Silently handle profile fetch error
    }
  }

  Future<void> _fetchAttendanceData() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final allAttendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('email', isEqualTo: user!.email)
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> records = [];
      for (var doc in allAttendance.docs) {
        records.add({'id': doc.id, ...doc.data()});
      }

      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editAttendance(Map<String, dynamic> record) async {
    if (user == null) return;
    HapticFeedback.mediumImpact();

    TimeOfDay? selectedTimeIn;
    TimeOfDay? selectedTimeOut;
    DateTime? selectedDate;
    bool isWFH = record['location'] == 'WFH';

    if (record['timeIn'] != null) {
      Timestamp timeInTs = record['timeIn'];
      DateTime timeInDt = timeInTs.toDate();
      selectedTimeIn = TimeOfDay(hour: timeInDt.hour, minute: timeInDt.minute);
      selectedDate = timeInDt;
    }

    if (record['timeOut'] != null) {
      Timestamp timeOutTs = record['timeOut'];
      DateTime timeOutDt = timeOutTs.toDate();
      selectedTimeOut = TimeOfDay(hour: timeOutDt.hour, minute: timeOutDt.minute);
    }

    if (!mounted) return;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A232E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGold.withOpacity(0.2),
                            AppTheme.primaryDark.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: AppTheme.primaryGold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Attendance',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A232E),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayName,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _buildEditTimePicker('Time In', selectedTimeIn, (t) => setDialogState(() => selectedTimeIn = t), isDark),
                const SizedBox(height: 16),
                _buildEditTimePicker('Time Out', selectedTimeOut, (t) => setDialogState(() => selectedTimeOut = t), isDark),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A232E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryGold,
                              AppTheme.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && selectedDate != null) {
      await _updateAttendance(record['id'], selectedTimeIn, selectedTimeOut, selectedDate, isWFH);
    }
  }

  Future<void> _updateAttendance(String docId, TimeOfDay? timeIn, TimeOfDay? timeOut, DateTime? date, bool isWFH) async {
    if (date == null) return;
    setState(() => _isLoading = true);

    Map<String, dynamic> updateData = {'location': isWFH ? 'WFH' : 'Office'};
    if (timeIn != null) updateData['timeIn'] = Timestamp.fromDate(DateTime(date.year, date.month, date.day, timeIn.hour, timeIn.minute));
    if (timeOut != null) updateData['timeOut'] = Timestamp.fromDate(DateTime(date.year, date.month, date.day, timeOut.hour, timeOut.minute));

    try {
      await FirebaseFirestore.instance.collection('attendance').doc(docId).update(updateData);
      AppSnackbar.show(context: context, message: 'Attendance updated successfully', type: SnackbarType.success);
      _fetchAttendanceData();
    } catch (e) {
      AppSnackbar.error(context, 'Failed to update attendance');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();
    try {
      final pdf = pw.Document();
      double totalHours = _calculateTotalHours();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(
            children: [
              pw.Center(
                child: pw.Text('ZHIYUAN ENTERPRISE GROUP INC',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1A232E))),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          ),
          build: (pw.Context context) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Intern Name: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: _displayName),
                    ])),
                pw.SizedBox(height: 4),
                pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'School: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: _school),
                    ])),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFC2A984)),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.5),
              },
              headers: ['Date', 'Time In', 'Time Out', 'Duration (hrs)', 'Break (hrs)', 'Net Hours (hrs)'],
              data: _attendanceRecords.map((record) {
                final timeIn = record['timeIn'] as Timestamp?;
                final timeOut = record['timeOut'] as Timestamp?;
                String sIn = timeIn != null ? _formatTime(timeIn.toDate()) : '--:--';
                String sOut = timeOut != null ? _formatTime(timeOut.toDate()) : '--:--';
                double dur = 0.0;
                if (timeIn != null && timeOut != null) dur = timeOut.toDate().difference(timeIn.toDate()).inMinutes / 60.0;
                double brk = dur >= 5.0 ? 1.0 : 0.0;
                return [record['date'], sIn, sOut, dur.toStringAsFixed(2), brk.toStringAsFixed(2), (dur - brk).toStringAsFixed(2)];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('GRAND TOTAL HOURS: ${totalHours.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromInt(0xFFC2A984))),
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
        ),
      );

      final bytes = await pdf.save();
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)..setAttribute("download", "DTR_${_displayName.replaceAll(' ', '_')}.pdf")..click();
      } else {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: 'DTR_${_displayName.replaceAll(' ', '_')}');
      }
    } catch (e) {
      AppSnackbar.error(context, 'Failed to generate PDF');
    }
  }

  Future<void> _exportToExcel() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['DTR'];

      sheet.cell(excel_lib.CellIndex.indexByString('A1')).value = excel_lib.TextCellValue('ZHIYUAN ENTERPRISE GROUP INC');
      sheet.cell(excel_lib.CellIndex.indexByString('A1')).cellStyle = excel_lib.CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: excel_lib.ExcelColor.fromHexString('#FF1A232E'),
        horizontalAlign: excel_lib.HorizontalAlign.Center,
      );
      sheet.merge(excel_lib.CellIndex.indexByString('A1'), excel_lib.CellIndex.indexByString('F1'));
      sheet.setRowHeight(0, 30);

      sheet.cell(excel_lib.CellIndex.indexByString('A3')).value = excel_lib.TextCellValue('Intern Name:');
      sheet.cell(excel_lib.CellIndex.indexByString('B3')).value = excel_lib.TextCellValue(_displayName);
      sheet.merge(excel_lib.CellIndex.indexByString('B3'), excel_lib.CellIndex.indexByString('F3'));

      sheet.cell(excel_lib.CellIndex.indexByString('A4')).value = excel_lib.TextCellValue('School:');
      sheet.cell(excel_lib.CellIndex.indexByString('B4')).value = excel_lib.TextCellValue(_school);
      sheet.merge(excel_lib.CellIndex.indexByString('B4'), excel_lib.CellIndex.indexByString('F4'));

      final headers = ['Date', 'Time In', 'Time Out', 'Duration (hrs)', 'Break (hrs)', 'Net Hours (hrs)'];
      final columns = ['A', 'B', 'C', 'D', 'E', 'F'];
      final columnWidths = [18.0, 12.0, 12.0, 16.0, 14.0, 18.0];

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, columnWidths[i]);
        final cell = sheet.cell(excel_lib.CellIndex.indexByString('${columns[i]}6'));
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = excel_lib.CellStyle(
          bold: true,
          fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFFFF'),
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#FFC2A984'),
          horizontalAlign: excel_lib.HorizontalAlign.Center,
        );
      }

      int rowIndex = 7;
      for (var record in _attendanceRecords) {
        final timeIn = record['timeIn'] as Timestamp?;
        final timeOut = record['timeOut'] as Timestamp?;
        double dur = 0.0;
        if (timeIn != null && timeOut != null) dur = timeOut.toDate().difference(timeIn.toDate()).inMinutes / 60.0;
        double brk = dur >= 5.0 ? 1.0 : 0.0;

        sheet.cell(excel_lib.CellIndex.indexByString('A$rowIndex')).value = excel_lib.TextCellValue(record['date'] ?? '');
        sheet.cell(excel_lib.CellIndex.indexByString('B$rowIndex')).value = excel_lib.TextCellValue(timeIn != null ? _formatTime(timeIn.toDate()) : '--:--');
        sheet.cell(excel_lib.CellIndex.indexByString('C$rowIndex')).value = excel_lib.TextCellValue(timeOut != null ? _formatTime(timeOut.toDate()) : '--:--');
        sheet.cell(excel_lib.CellIndex.indexByString('D$rowIndex')).value = excel_lib.DoubleCellValue(double.parse(dur.toStringAsFixed(2)));
        sheet.cell(excel_lib.CellIndex.indexByString('E$rowIndex')).value = excel_lib.DoubleCellValue(double.parse(brk.toStringAsFixed(2)));
        sheet.cell(excel_lib.CellIndex.indexByString('F$rowIndex')).value = excel_lib.DoubleCellValue(double.parse((dur - brk).toStringAsFixed(2)));
        rowIndex++;
      }

      sheet.cell(excel_lib.CellIndex.indexByString('A$rowIndex')).value = excel_lib.TextCellValue('TOTAL');
      sheet.cell(excel_lib.CellIndex.indexByString('A$rowIndex')).cellStyle = excel_lib.CellStyle(bold: true, fontColorHex: excel_lib.ExcelColor.fromHexString('#FFC2A984'));
      sheet.cell(excel_lib.CellIndex.indexByString('F$rowIndex')).value = excel_lib.FormulaCellValue('SUM(F7:F${rowIndex - 1})');
      sheet.cell(excel_lib.CellIndex.indexByString('F$rowIndex')).cellStyle = excel_lib.CellStyle(bold: true, fontColorHex: excel_lib.ExcelColor.fromHexString('#FFC2A984'));

      final bytes = excel.encode();
      if (kIsWeb) {
        final blob = html.Blob([bytes!]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)..setAttribute("download", "DTR_${_displayName.replaceAll(' ', '_')}.xlsx")..click();
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/DTR.xlsx');
        await file.writeAsBytes(bytes!);
        await OpenFile.open(file.path);
      }
      AppSnackbar.show(context: context, message: 'Excel exported successfully', type: SnackbarType.success);
    } catch (e) {
      AppSnackbar.error(context, 'Excel Export Failed');
    }
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return "$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
  }

  double _calculateTotalHours() {
    double total = 0;
    for (var record in _attendanceRecords) {
      final tIn = record['timeIn'] as Timestamp?;
      final tOut = record['timeOut'] as Timestamp?;
      if (tIn != null && tOut != null) {
        double dur = tOut.toDate().difference(tIn.toDate()).inMinutes / 60.0;
        total += (dur - (dur >= 5.0 ? 1.0 : 0.0));
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A232E);
    final Color cardBg = isDark ? const Color(0x1AFFFFFF) : const Color(0xE6FFFFFF);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
    }

    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records yet',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your attendance',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, textColor),
            const SizedBox(height: 24),
            ..._attendanceRecords.map((r) => _buildAttendanceCard(r, cardBg, isDark, textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATTENDANCE',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'History',
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildExportButton(
              icon: Icons.picture_as_pdf_rounded,
              color: Colors.red,
              onPressed: _exportToPDF,
              tooltip: 'Export PDF',
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildExportButton(
              icon: Icons.table_view_rounded,
              color: Colors.green,
              onPressed: _exportToExcel,
              tooltip: 'Export Excel',
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record, Color cardBg, bool isDark, Color textColor) {
    Timestamp? timeIn = record['timeIn'];
    Timestamp? timeOut = record['timeOut'];
    String date = record['date'] ?? '';
    String location = record['location'] ?? 'Office';
    String status = record['status'] ?? 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.08 : 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGold.withOpacity(0.2),
                            AppTheme.primaryDark.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: AppTheme.primaryGold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      date,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Completed'
                        ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                        : Colors.orange.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: status == 'Completed'
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'Completed' ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 12,
                        color: status == 'Completed' ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'Completed' ? Colors.green : Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeDetail(
                    label: 'TIME IN',
                    value: timeIn != null ? _formatTime(timeIn.toDate()) : '--:--',
                    icon: Icons.login_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeDetail(
                    label: 'TIME OUT',
                    value: timeOut != null ? _formatTime(timeOut.toDate()) : '--:--',
                    icon: Icons.logout_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.05 : 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    location == 'WFH' ? Icons.home_rounded : Icons.business_rounded,
                    color: AppTheme.primaryGold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    location,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Edit Attendance',
              onPressed: () => _editAttendance(record),
              variant: ButtonVariant.secondary,
              size: ButtonSize.small,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDetail({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800.withOpacity(0.6) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.05 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: AppTheme.primaryGold,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A232E),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTimePicker(String label, TimeOfDay? selectedTime, Function(TimeOfDay?) onTimeSelected, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: AppTheme.primaryGold),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onTimeSelected(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.access_time_rounded,
                color: AppTheme.primaryGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A232E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              selectedTime != null
                  ? "${selectedTime.hour > 12 ? selectedTime.hour - 12 : (selectedTime.hour == 0 ? 12 : selectedTime.hour)}:${selectedTime.minute.toString().padLeft(2, '0')} ${selectedTime.period == DayPeriod.am ? 'AM' : 'PM'}"
                  : 'Not set',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}