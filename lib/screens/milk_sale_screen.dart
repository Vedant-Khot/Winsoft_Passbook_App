import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:passbook/l10n/app_localizations.dart';
import '../model/milk_sales_model.dart';
import '../service/api_service.dart';
import '../widget/company_logo.dart';
import '../widget/dynamic_text.dart';

class MilkSalePage extends StatefulWidget {
  final int socCode;
  final int memCode;
  final int langCode;

  const MilkSalePage({
    super.key,
    required this.socCode,
    required this.memCode,
    required this.langCode,
  });

  @override
  State<MilkSalePage> createState() => _MilkSalePageState();
}

class _MilkSalePageState extends State<MilkSalePage> {
  late Future<List<MilkSaleModel>> _milkSalesFuture;
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _milkSalesFuture = ApiService().fetchMilkSales(
      widget.socCode,
      widget.memCode,
    );
  }

  String _sessionLabel(int me) {
    final isMorning = me == 1;
    switch (widget.langCode) {
      case 2:
      case 4:
        return isMorning ? 'स' : 'सं';
      case 3:
        return isMorning ? 'ಬೆ' : 'ಸ';
      default:
        return isMorning ? 'M' : 'E';
    }
  }

  String _cobfLabel(String? cobfCode) {
    if (cobfCode == null) return '';
    final code = cobfCode.trim().toUpperCase();
    switch (widget.langCode) {
      case 2:
      case 4:
        if (code == 'C') return 'गा';
        if (code == 'B') return 'म्है';
        break;
      case 3:
        if (code == 'C') return 'ಹ';
        if (code == 'B') return 'ಎ';
        break;
      default:
        if (code == 'C') return 'C';
        if (code == 'B') return 'B';
        break;
    }
    return cobfCode;
  }

  String _formatAmount(double value) =>
      value > 0 ? value.toStringAsFixed(2) : '';

  String _summaryLabel(String key) {
    switch (widget.langCode) {
      case 2:
      case 4:
        switch (key) {
          case 'cow_milk':
            return 'गाय दूध';
          case 'cow_amt':
            return 'गाय दूध रक्कम';
          case 'buffalo_milk':
            return 'म्हैस दूध';
          case 'buffalo_amt':
            return 'म्हैस दूध रक्कम';
          case 'total_milk':
            return 'एकूण दूध';
          case 'total_amt':
            return 'एकूण दूध रक्कम';
        }
        break;
      case 3:
        switch (key) {
          case 'cow_milk':
            return 'ಹಸುವಿನ ಹಾಲು';
          case 'cow_amt':
            return 'ಹಸುವಿನ ಹಾಲಿನ ಮೊತ್ತ';
          case 'buffalo_milk':
            return 'ಎಮ್ಮೆ ಹಾಲು';
          case 'buffalo_amt':
            return 'ಎಮ್ಮೆ ಹಾಲಿನ ಮೊತ್ತ';
          case 'total_milk':
            return 'ಒಟ್ಟು ಹಾಲು';
          case 'total_amt':
            return 'ಒಟ್ಟು ಹಾಲಿನ ಮೊತ್ತ';
        }
        break;
    }
    switch (key) {
      case 'cow_milk':
        return 'Cow Milk';
      case 'cow_amt':
        return 'Milk Amt';
      case 'buffalo_milk':
        return 'Buffalo Milk';
      case 'buffalo_amt':
        return 'B Milk Amt';
      case 'total_milk':
        return 'Total Milk';
      case 'total_amt':
        return 'Total Amt';
      default:
        return key;
    }
  }

  Widget _labelText(String text, {TextStyle? style}) {
    return DynamicText(
      text: text,
      langCode: widget.langCode,
      style: style ?? const TextStyle(fontSize: 14),
    );
  }

  Widget _numberText(String text, {FontWeight fontWeight = FontWeight.normal}) {
    return DynamicText(
      text: text,
      langCode: widget.langCode,
      forceKiran: true,
      style: TextStyle(fontSize: 14, fontWeight: fontWeight),
      textAlign: TextAlign.right,
    );
  }

  Widget _summaryCell(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  }) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }

  TableRow _summaryTableRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue, {
    bool isTotal = false,
  }) {
    final labelStyle = TextStyle(
      fontSize: isTotal ? 15 : 14,
      fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
    );
    final valueWeight = isTotal ? FontWeight.w700 : FontWeight.w600;

    return TableRow(
      children: [
        _summaryCell(
          DynamicText(
            text: leftLabel,
            langCode: widget.langCode,
            style: labelStyle,
            textAlign: TextAlign.right,
          ),
        ),
        _summaryCell(
          DynamicText(
            text: leftValue,
            langCode: widget.langCode,
            forceKiran: true,
            style: TextStyle(fontSize: 14, fontWeight: valueWeight),
            textAlign: TextAlign.right,
          ),
        ),
        _summaryCell(
          DynamicText(
            text: rightLabel,
            langCode: widget.langCode,
            style: labelStyle,
            textAlign: TextAlign.right,
          ),
        ),
        _summaryCell(
          DynamicText(
            text: rightValue,
            langCode: widget.langCode,
            forceKiran: true,
            style: TextStyle(fontSize: 14, fontWeight: valueWeight),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  static const _summaryColumnWidths = {
    0: FlexColumnWidth(2.2),
    1: FixedColumnWidth(72),
    2: FlexColumnWidth(2.5),
    3: FixedColumnWidth(88),
  };

  Widget _buildSummaryCard({
    required double cowMilkTotal,
    required double cowMilkAmount,
    required double buffaloMilkTotal,
    required double buffaloMilkAmount,
    required double totalMilk,
    required double totalAmount,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Table(
              columnWidths: _summaryColumnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _summaryTableRow(
                  _summaryLabel('cow_milk'),
                  cowMilkTotal.toStringAsFixed(2),
                  _summaryLabel('cow_amt'),
                  cowMilkAmount.toStringAsFixed(2),
                ),
                _summaryTableRow(
                  _summaryLabel('buffalo_milk'),
                  buffaloMilkTotal.toStringAsFixed(2),
                  _summaryLabel('buffalo_amt'),
                  buffaloMilkAmount.toStringAsFixed(2),
                ),
              ],
            ),
            Divider(
              height: 16,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Table(
              columnWidths: _summaryColumnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _summaryTableRow(
                  _summaryLabel('total_milk'),
                  totalMilk.toStringAsFixed(2),
                  _summaryLabel('total_amt'),
                  totalAmount.toStringAsFixed(2),
                  isTotal: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        title: DynamicText(
          text: l10n.milk_sale,
          langCode: widget.langCode,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: const CompanyLogo(size: 32),
          ),
        ],
      ),
      body: FutureBuilder<List<MilkSaleModel>>(
        future: _milkSalesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No sale data found.'));
          }

          final sales = snapshot.data!
              .where((sale) => sale.paid == 0)
              .toList()
            ..sort((a, b) {
              final dateComparison = b.trDate.compareTo(a.trDate);
              if (dateComparison != 0) return dateComparison;
              return a.me.compareTo(b.me);
            });

          if (sales.isEmpty) {
            return const Center(child: Text('No sale data found.'));
          }

          double cowMilkTotal = 0.0;
          double buffaloMilkTotal = 0.0;
          double cowMilkAmount = 0.0;
          double buffaloMilkAmount = 0.0;

          for (final sale in sales) {
            final code = sale.cobf?.trim().toUpperCase();
            if (code == 'C') {
              cowMilkTotal += sale.liters;
              cowMilkAmount += sale.tot;
            } else if (code == 'B') {
              buffaloMilkTotal += sale.liters;
              buffaloMilkAmount += sale.tot;
            }
          }

          final totalMilk = cowMilkTotal + buffaloMilkTotal;
          final totalAmount = cowMilkAmount + buffaloMilkAmount;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      headingRowHeight: 40,
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 38,
                      border: TableBorder.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                      columns: [
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_date,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_session,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_cobf,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_liters,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_fat,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_rate,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: _labelText(
                            l10n.passbook_amount,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      rows: sales.map((sale) {
                        return DataRow(
                          cells: [
                            DataCell(
                              _numberText(_dateFormat.format(sale.trDate.toLocal())),
                            ),
                            DataCell(
                              DynamicText(
                                text: _sessionLabel(sale.me),
                                langCode: widget.langCode,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            DataCell(
                              DynamicText(
                                text: _cobfLabel(sale.cobf),
                                langCode: widget.langCode,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            DataCell(
                              _numberText(_formatAmount(sale.liters)),
                            ),
                            DataCell(
                              _numberText(_formatAmount(sale.fat)),
                            ),
                            DataCell(
                              _numberText(_formatAmount(sale.rate)),
                            ),
                            DataCell(
                              _numberText(_formatAmount(sale.tot)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              _buildSummaryCard(
                cowMilkTotal: cowMilkTotal,
                cowMilkAmount: cowMilkAmount,
                buffaloMilkTotal: buffaloMilkTotal,
                buffaloMilkAmount: buffaloMilkAmount,
                totalMilk: totalMilk,
                totalAmount: totalAmount,
              ),
            ],
          );
        },
      ),
    );
  }
}
