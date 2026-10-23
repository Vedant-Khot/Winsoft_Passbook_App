import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:passbook/l10n/app_localizations.dart';
import 'package:passbook/model/daily_report_row.dart';
import 'package:passbook/model/data_parser.dart';
import '../model/bill_period.dart';
import '../model/bill_transaction_model.dart';
import '../model/deduction_model.dart';
import '../model/passbook_model.dart';
import '../model/report_item.dart';
import '../service/api_service.dart';
import '../widget/dynamic_text.dart';
import '../widget/company_logo.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';

enum CattleTypeFilter { cow, buffalo }

class _GroupedDeduction {
  const _GroupedDeduction({
    required this.dedcode,
    required this.dedName,
    required this.deductionAmount,
    required this.earningAmount,
    required this.actdedAmount,
  });

  final int? dedcode;
  final String? dedName;
  final double deductionAmount;
  final double earningAmount;
  final double actdedAmount;
}

class CombinedReportScreen extends StatefulWidget {
  final int socCode;
  final int memCode;
  final int langCode;
  final int cobfType; // Controls filter visibility
  final int? rptType;

  const CombinedReportScreen({
    super.key,
    required this.socCode,
    required this.memCode,
    required this.langCode,
    required this.cobfType,
    this.rptType,
  });

  @override
  State<CombinedReportScreen> createState() => _CombinedReportScreenState();
}

class _CombinedReportScreenState extends State<CombinedReportScreen> {
  late Future<List<BillPeriod>> _billPeriodsFuture;
  BillPeriod? _selectedPeriod;
  int _reportGeneration = 0;
  bool _isReportLoading = false;

  List<DailyMilkRecord> _allDailyMilkRecords = [];
  List<DeductionModel> _allReportDeductions = [];

  CattleTypeFilter _activeCattleFilter = CattleTypeFilter.cow;

  List<DailyMilkRecord> _filteredDailyMilkRecords = [];
  List<_GroupedDeduction> _groupedDeductions = [];
  CalculatedSummaryItem? _summary;
  CalculatedSummaryItem? _billSummary;

  final TextStyle _poppinsStyle = AppTextStyles.poppins();
  Color? _cachedGridColor;

  // State variables for column totals
  double _totalMorningLiters = 0.0;
  double _totalMorningAmount = 0.0;
  double _totalEveningLiters = 0.0;
  double _totalEveningAmount = 0.0;

  // --- NEW: State variables for Average FAT and SNF ---
  double _avgMorningFat = 0.0;
  double _avgEveningFat = 0.0;
  double _avgMorningSnf = 0.0;
  double _avgEveningSnf = 0.0;
  // --- END ---

  static const Color _primaryBlue = AppTheme.primaryBlue;
  static const Color _redLoss = AppTheme.errorRed;
  static const Color _greenProfit = AppTheme.successGreen;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isOnOrBetween(DateTime date, DateTime from, DateTime to) {
    final d = _dateOnly(date);
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  PassbookModel _sumPassbookEntries(
    Iterable<PassbookModel> entries, {
    required int me,
    required String cobf,
  }) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final dateCompare = a.trndate.compareTo(b.trndate);
        if (dateCompare != 0) return dateCompare;
        final rateCompare = a.rate.compareTo(b.rate);
        if (rateCompare != 0) return rateCompare;
        return a.liters.compareTo(b.liters);
      });

    return sorted.reduce((value, element) {
      final totalLiters = value.liters + element.liters;
      final divisor = totalLiters == 0 ? 1.0 : totalLiters;
      return PassbookModel(
        cobf: cobf,
        me: me,
        trndate: element.trndate,
        liters: totalLiters,
        amount: value.amount + element.amount,
        fat: ((value.fat * value.liters) + (element.fat * element.liters)) /
            divisor,
        rate: ((value.rate * value.liters) + (element.rate * element.liters)) /
            divisor,
        degree:
            ((value.degree * value.liters) + (element.degree * element.liters)) /
            divisor,
      );
    });
  }

  List<PassbookModel> _collapsePassbookBySession(List<PassbookModel> entries) {
    final merged = <String, PassbookModel>{};
    for (final entry in entries) {
      final day = _dateOnly(entry.trndate);
      final cobf = entry.cobf?.trim().toUpperCase() ?? '';
      final key = '${day.year}-${day.month}-${day.day}_${entry.me}_$cobf';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = entry;
      } else {
        merged[key] = _sumPassbookEntries(
          [existing, entry],
          me: entry.me,
          cobf: cobf,
        );
      }
    }
    return merged.values.toList();
  }

  String _passbookSessionKey(PassbookModel entry) {
    final day = _dateOnly(entry.trndate);
    final cobf = entry.cobf?.trim().toUpperCase() ?? '';
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')} me=${entry.me} cobf=$cobf';
  }

  String _formatPassbookRow(PassbookModel row) =>
      'L=${row.liters} rate=${row.rate} amt=${row.amount}';

  /// Logs duplicate passbook rows per day/session — proof for rate flips on refresh.
  void _logBillProofPassbookRows({
    required int generation,
    required String phase,
    required List<PassbookModel> entries,
  }) {
    if (!kDebugMode) return;

    final bySession = <String, List<PassbookModel>>{};
    for (final entry in entries) {
      bySession.putIfAbsent(_passbookSessionKey(entry), () => []).add(entry);
    }

    var duplicateSessions = 0;
    var conflictingRateSessions = 0;
    for (final rows in bySession.values) {
      if (rows.length > 1) duplicateSessions++;
      if (rows.map((r) => r.rate).toSet().length > 1) conflictingRateSessions++;
    }

    debugPrint(
      'BillProof [gen=$generation] $phase: ${entries.length} rows, '
      '${bySession.length} sessions, duplicateSessions=$duplicateSessions, '
      'conflictingRates=$conflictingRateSessions',
    );

    for (final key in bySession.keys.toList()..sort()) {
      final rows = bySession[key]!;
      if (rows.length <= 1) continue;

      final parts = rows.map(_formatPassbookRow).join(' | ');
      final rates = rows.map((r) => r.rate).toSet();
      final tag = rates.length > 1 ? 'DUPLICATE-RATES' : 'DUPLICATE-ROWS';
      debugPrint('BillProof [gen=$generation] $phase: $key ($tag) -> $parts');

      if (rates.length > 1 && rows.length >= 2) {
        final liters = rows.map((r) => r.liters).toSet();
        if (liters.length == 1) {
          debugPrint(
            'BillProof [gen=$generation] $phase: $key SAME-LITERS (${rows.first.liters}) '
            'but ${rates.length} rates — would flip between rows if not merged',
          );
        }
      }
    }
  }

  void _logBillProofDisplayRows({
    required int generation,
    required List<DailyMilkRecord> records,
    required String cattleFilter,
  }) {
    if (!kDebugMode) return;

    debugPrint(
      'BillProof [gen=$generation] display ($cattleFilter): ${records.length} bill days',
    );
    for (final record in records) {
      final day = _dateOnly(record.date);
      final dayLabel =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final morning = record.morningEntry;
      final evening = record.eveningEntry;
      if (morning != null) {
        debugPrint(
          'BillProof [gen=$generation] display: $dayLabel morning '
          '${_formatPassbookRow(morning)}',
        );
      }
      if (evening != null) {
        debugPrint(
          'BillProof [gen=$generation] display: $dayLabel evening '
          '${_formatPassbookRow(evening)}',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _activeCattleFilter = widget.cobfType == 2
        ? CattleTypeFilter.buffalo
        : CattleTypeFilter.cow;
    _billPeriodsFuture = _fetchAndProcessBillPeriods();
  }

  Future<List<BillPeriod>> _loadBillPeriods() async {
    final transactions = await ApiService().fetchBillTransactions(
      widget.socCode,
      widget.memCode,
    );
    final validTransactions = transactions.where(
      (t) => t.fromdate != null && t.todate != null,
    );

    final allPeriods = validTransactions
        .map(
          (t) => BillPeriod(
            fromDate: t.fromdate!,
            toDate: t.todate!,
            sourceTransaction: t,
          ),
        )
        .toList();

    final Map<String, BillPeriod> uniquePeriodsMap = {};
    for (final period in allPeriods) {
      final key =
          '${period.fromDate.toIso8601String()}-${period.toDate.toIso8601String()}';
      uniquePeriodsMap.putIfAbsent(key, () => period);
    }
    final periods = uniquePeriodsMap.values.toList();

    periods.sort((a, b) => b.toDate.compareTo(a.toDate));
    return periods;
  }

  Future<List<BillPeriod>> _fetchAndProcessBillPeriods() async {
    final periods = await _loadBillPeriods();

    if (periods.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedPeriod = periods.first;
          });
          _generateReport(periods.first);
        }
      });
    }
    return periods;
  }

  Future<void> _generateReport(BillPeriod period) async {
    final generation = ++_reportGeneration;
    setState(() {
      _isReportLoading = true;
      _allDailyMilkRecords = [];
      _allReportDeductions = [];
      _groupedDeductions = [];
      _summary = null;
      _billSummary = null;
    });

    try {
      final allPassbookEntries = await ApiService().fetchPassbook(
        widget.socCode,
        widget.memCode,
        forceRefresh: false,
      );
      final allDeductions = await ApiService().fetchDeductions(
        widget.socCode,
        widget.memCode,
        forceRefresh: false,
      );

      if (!mounted || generation != _reportGeneration) {
        return;
      }

      final selectedBillNo = period.sourceTransaction.billno;
      final inPeriodPassbook = allPassbookEntries
          .where(
            (p) => _isOnOrBetween(p.trndate, period.fromDate, period.toDate),
          )
          .toList();

      _logBillProofPassbookRows(
        generation: generation,
        phase: 'raw-from-fetch',
        entries: inPeriodPassbook,
      );

      final filteredPassbook = _collapsePassbookBySession(inPeriodPassbook);

      _logBillProofPassbookRows(
        generation: generation,
        phase: 'after-collapse',
        entries: filteredPassbook,
      );
      final filteredDeductions = allDeductions
          .where(
            (d) =>
                d.billno == selectedBillNo &&
                d.dedctnDate != null &&
                _isOnOrBetween(
                  d.dedctnDate!,
                  period.fromDate,
                  period.toDate,
                ),
          )
          .toList();

      final Map<DateTime, DailyMilkRecord> recordsByDate = {};
      for (final entry in filteredPassbook) {
        final dateKey = DateTime(
          entry.trndate.year,
          entry.trndate.month,
          entry.trndate.day,
        );
        recordsByDate.putIfAbsent(
          dateKey,
          () => DailyMilkRecord(date: dateKey),
        );

        if (entry.me == 1) {
          recordsByDate[dateKey]!.morningEntries.add(entry);
        } else if (entry.me == 2) {
          recordsByDate[dateKey]!.eveningEntries.add(entry);
        }
      }

      final processedMilkRecords = recordsByDate.values.toList();
      processedMilkRecords.sort((a, b) => a.date.compareTo(b.date));

      // Single setState for data + loading flag together (avoids extra rebuild)
      if (mounted && generation == _reportGeneration) {
        setState(() {
          _allDailyMilkRecords = processedMilkRecords;
          _allReportDeductions = filteredDeductions;
          _isReportLoading = false;
        });
        _applyFiltersAndRecalculate(generation: generation);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReportLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFiltersAndRecalculate({int? generation}) {
    List<DailyMilkRecord> tempFilteredRecords = [];
    final bool shouldApplyAnimalFilter = widget.rptType != 2;
    final String targetCobfValue = (_activeCattleFilter == CattleTypeFilter.cow)
        ? 'C'
        : 'B';

    // Filter deductions based on cobf
    final List<DeductionModel> tempFilteredDeductions = shouldApplyAnimalFilter
        ? _allReportDeductions.where((d) {
            final code = d.cobf?.trim().toUpperCase();
            return code == targetCobfValue ||
                code == 'O' ||
                code == null ||
                code == '';
          }).toList()
        : _allReportDeductions;

    // Step 1: Create a temporary list of display-ready records
    List<DailyMilkRecord> processedRecords = [];

    for (final record in _allDailyMilkRecords) {
      PassbookModel? summedMorningEntry;
      PassbookModel? summedEveningEntry;

      // Filter the entries for the day based on the dropdown
      var morningSource = shouldApplyAnimalFilter
          ? record.morningEntries.where((e) {
              final code = e.cobf?.trim().toUpperCase();
              return code == targetCobfValue || code == 'O';
            })
          : record.morningEntries;

      var eveningSource = shouldApplyAnimalFilter
          ? record.eveningEntries.where((e) {
              final code = e.cobf?.trim().toUpperCase();
              return code == targetCobfValue || code == 'O';
            })
          : record.eveningEntries;

      // If there are morning entries, sum them up into a single object
      if (morningSource.isNotEmpty) {
        summedMorningEntry = _sumPassbookEntries(
          morningSource,
          me: 1,
          cobf: targetCobfValue,
        );
      }

      if (eveningSource.isNotEmpty) {
        summedEveningEntry = _sumPassbookEntries(
          eveningSource,
          me: 2,
          cobf: targetCobfValue,
        );
      }

      // Only add a record for this day if there was any data after filtering
      if (summedMorningEntry != null || summedEveningEntry != null) {
        // NOTE: We need to modify the DailyMilkRecord constructor to accept single entries again
        // This is a key change. Let's assume you modify it like this:
        // DailyMilkRecord({this.date, this.morningEntry, this.eveningEntry})
        // You may need a separate model for display purposes.
        // Given the original code, you probably need to add the single properties back for the filtered list.

        // Let's assume you have a display model like `DisplayDailyRecord` that has single entries
        // Or you can add them back to `DailyMilkRecord` as nullable.

        // Let's modify the DailyMilkRecord model to support both for simplicity.
        // See Step 1-B below.
        processedRecords.add(
          DailyMilkRecord(
            date: record.date,
            morningEntry: summedMorningEntry,
            eveningEntry: summedEveningEntry,
          ),
        );
      }
    }

    // Now, all the calculation logic below can remain THE SAME, because `processedRecords`
    // has the exact same structure that the UI expects (one entry per session).
    tempFilteredRecords = processedRecords;

    // --- UPDATED: Calculate column totals and weighted FAT/SNF sum simultaneously ---
    double morningLiters = 0.0, morningAmount = 0.0;
    double eveningLiters = 0.0, eveningAmount = 0.0;
    double weightedMorningFatSum = 0.0;
    double weightedEveningFatSum = 0.0;
    double weightedMorningSnfSum = 0.0;
    double weightedEveningSnfSum = 0.0;

    for (final record in tempFilteredRecords) {
      final morningLtr = record.morningEntry?.liters ?? 0.0;
      morningLiters += morningLtr;
      morningAmount += record.morningEntry?.amount ?? 0.0;
      weightedMorningFatSum += morningLtr * (record.morningEntry?.fat ?? 0.0);
      weightedMorningSnfSum +=
          morningLtr * (record.morningEntry?.degree ?? 0.0);

      final eveningLtr = record.eveningEntry?.liters ?? 0.0;
      eveningLiters += eveningLtr;
      eveningAmount += record.eveningEntry?.amount ?? 0.0;
      weightedEveningFatSum += eveningLtr * (record.eveningEntry?.fat ?? 0.0);
      weightedEveningSnfSum +=
          eveningLtr * (record.eveningEntry?.degree ?? 0.0);
    }

    final avgMorningFat = (morningLiters > 0)
        ? weightedMorningFatSum / morningLiters
        : 0.0;
    final avgEveningFat = (eveningLiters > 0)
        ? weightedEveningFatSum / eveningLiters
        : 0.0;
    final avgMorningSnf = (morningLiters > 0)
        ? weightedMorningSnfSum / morningLiters
        : 0.0;
    final avgEveningSnf = (eveningLiters > 0)
        ? weightedEveningSnfSum / eveningLiters
        : 0.0;

    // Calculate overall summary
    final List<PassbookModel> passbookForSummary = [];
    for (var rec in tempFilteredRecords) {
      if (rec.morningEntry != null) passbookForSummary.add(rec.morningEntry!);
      if (rec.eveningEntry != null) passbookForSummary.add(rec.eveningEntry!);
    }

    final double totalLiters = passbookForSummary.fold(
      0.0,
      (sum, item) => sum + item.liters,
    );
    final double totalMilkAmount = passbookForSummary.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final totalDeductions = tempFilteredDeductions
        .where((item) => item.dedearn == 0)
        .fold<double>(0.0, (sum, item) => sum + (item.dedctnAmt1 ?? 0.0));

    final totalEarnings = tempFilteredDeductions
        .where((item) => item.dedearn == 1)
        .fold<double>(0.0, (sum, item) => sum + (item.dedctnAmt1 ?? 0.0));

    final double netAmount = totalMilkAmount + totalEarnings - totalDeductions;

    final summary = CalculatedSummaryItem(
      totalLiters: totalLiters,
      totalLitersAmount: totalMilkAmount,
      totalEarnings: totalEarnings,
      totalDeductions: totalDeductions,
      netAmount: netAmount,
    );

    CalculatedSummaryItem? billSummary;
    if (_selectedPeriod != null) {
      billSummary = _billSummaryFromTransaction(
        _selectedPeriod!.sourceTransaction,
      );
    }

    if (generation != null) {
      _logBillProofDisplayRows(
        generation: generation,
        records: tempFilteredRecords,
        cattleFilter: targetCobfValue,
      );
    }

    setState(() {
      _filteredDailyMilkRecords = tempFilteredRecords;
      _groupedDeductions = _groupDeductionsByCode(tempFilteredDeductions);
      _summary = summary;
      _billSummary = billSummary;

      // Update state with column totals
      _totalMorningLiters = morningLiters;
      _totalMorningAmount = morningAmount;
      _totalEveningLiters = eveningLiters;
      _totalEveningAmount = eveningAmount;

      // --- NEW: Update state with average FAT/SNF values ---
      _avgMorningFat = avgMorningFat;
      _avgEveningFat = avgEveningFat;
      _avgMorningSnf = avgMorningSnf;
      _avgEveningSnf = avgEveningSnf;
      // --- END ---
    });
  }

  List<_GroupedDeduction> _groupDeductionsByCode(List<DeductionModel> deductions) {
    final Map<String, _GroupedDeduction> grouped = {};

    for (final item in deductions) {
      final key = item.dedcode?.toString() ?? item.dedName ?? '';
      if (key.isEmpty) continue;

      final existing = grouped[key];
      final deductionAmount =
          (existing?.deductionAmount ?? 0) +
          (item.dedearn == 0 ? (item.dedctnAmt1 ?? 0) : 0);
      final earningAmount =
          (existing?.earningAmount ?? 0) +
          (item.dedearn == 1 ? (item.dedctnAmt1 ?? 0) : 0);
      final actdedAmount =
          (existing?.actdedAmount ?? 0) + (item.actdedAmt ?? 0);

      grouped[key] = _GroupedDeduction(
        dedcode: item.dedcode,
        dedName: existing?.dedName ?? item.dedName,
        deductionAmount: deductionAmount,
        earningAmount: earningAmount,
        actdedAmount: actdedAmount,
      );
    }

    final result = grouped.values.toList()
      ..sort((a, b) {
        final codeCompare = (a.dedcode ?? 0).compareTo(b.dedcode ?? 0);
        if (codeCompare != 0) return codeCompare;
        return (a.dedName ?? '').compareTo(b.dedName ?? '');
      });
    return result;
  }

  ({double liters, double amount}) _resolveBillMilkTotals(
    BillTransactionModel bill,
  ) {
    if (widget.rptType == 2) {
      return (liters: bill.liters, amount: bill.amount);
    }

    final isCow = _activeCattleFilter == CattleTypeFilter.cow;
    final cobf = bill.cobf?.trim().toUpperCase();

    if (isCow) {
      if (bill.cliters > 0 || bill.camount > 0) {
        return (liters: bill.cliters, amount: bill.camount);
      }
      if (cobf == 'C') {
        return (liters: bill.liters, amount: bill.amount);
      }
      return (liters: 0, amount: 0);
    }

    if (bill.bliters > 0 || bill.bamount > 0) {
      return (liters: bill.bliters, amount: bill.bamount);
    }
    if (cobf == 'B') {
      return (liters: bill.liters, amount: bill.amount);
    }
    return (liters: 0, amount: 0);
  }

  CalculatedSummaryItem _billSummaryFromTransaction(
    BillTransactionModel bill,
  ) {
    final billMilk = _resolveBillMilkTotals(bill);
    return CalculatedSummaryItem(
      totalLiters: billMilk.liters,
      totalLitersAmount: billMilk.amount,
      totalEarnings: bill.totearn,
      totalDeductions: bill.totded,
      netAmount: bill.netamt,
    );
  }

  @override
  Widget build(BuildContext context) {
    _cachedGridColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.7);
    return Scaffold(
      appBar: _buildEnhancedAppBar(
        AppLocalizations.of(context)!.reports,
        Icons.analytics_outlined,
      ),
      body: Column(
        children: [
          _buildSelectorsRow(),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildReportContent()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar(String title, IconData icon) {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          alignment: Alignment.center,
          child: const CompanyLogo(size: 32),
        ),
      ],
    );
  }

  /// Renders the Bill Period and Milk Type selectors in a single row.
  Widget _buildSelectorsRow() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final showCattleFilter =
        widget.rptType != 2 && !_isReportLoading && _selectedPeriod != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: colorScheme.surface,
      child: FutureBuilder<List<BillPeriod>>(
        future: _billPeriodsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final periods = snapshot.data ?? [];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Bill Period Dropdown ---
              Expanded(
                flex: showCattleFilter ? 6 : 10,
                child: DropdownButtonFormField<BillPeriod>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: l10n.report_selectPeriod,
                    labelStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 17,
                    ),
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: _primaryBlue,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: periods.isEmpty
                      ? null
                      : (BillPeriod? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedPeriod = newValue);
                            _generateReport(newValue);
                          }
                        },
                  items: periods.map((period) {
                    final from = formatLanguageAwareDateShort(
                      period.fromDate,
                      widget.langCode,
                    );
                    final to = formatLanguageAwareDateShort(
                      period.toDate,
                      widget.langCode,
                    );
                    return DropdownMenuItem(
                      value: period,
                      child: DynamicText(
                        text: '$from – $to',
                        langCode: widget.langCode,
                        forceKiran: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // --- Cattle Type Filter (only when cobfType == 3) ---
              if (showCattleFilter) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<CattleTypeFilter>(
                    value: _activeCattleFilter,
                    isExpanded: true,
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Milk Type',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 17,
                      ),
                      prefixIcon: Icon(
                        Icons.water_drop_outlined,
                        color: _primaryBlue,
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryBlue, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (CattleTypeFilter? newValue) {
                      if (newValue != null) {
                        setState(() => _activeCattleFilter = newValue);
                        _applyFiltersAndRecalculate();
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: CattleTypeFilter.cow,
                        child: DynamicText(
                          text: l10n.cow,
                          langCode: widget.langCode,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: CattleTypeFilter.buffalo,
                        child: DynamicText(
                          text: l10n.buffalo,
                          langCode: widget.langCode,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportContent() {
    if (_isReportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredDailyMilkRecords.isEmpty &&
        _groupedDeductions.isEmpty &&
        _selectedPeriod != null) {
      return const Center(
        child: Text(
          'No data found for this period/filter.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }
    if (_selectedPeriod == null) {
      return const Center(
        child: Text(
          'Please select a bill period to generate a report.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final int maxRows = max(
      _filteredDailyMilkRecords.length,
      _groupedDeductions.length,
    );
    final bool hasData = maxRows > 0;

    // Calculate maximum characters to size the date column dynamically
    int maxDateChars = 5;
    for (final record in _filteredDailyMilkRecords) {
      final dateStr = formatLanguageAwareDateNoYear(record.date, widget.langCode);
      if (dateStr.length > maxDateChars) {
        maxDateChars = dateStr.length;
      }
    }
    // 8.5 pixels per char + padding + 2.0 extra, clamped
    final double maxDateWidth = ((maxDateChars * 8.5) + 24.0 + 2.0).clamp(75.0, 150.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth - 16;
        // Total of non-flexible (fixed) columns: m_fat(50) + m_snf(50) + m_rate(70) + e_fat(50) + e_snf(50) + e_rate(70) = 340.0
        // Total coefficients of flexible columns (excluding date): m_liters(70) + m_amount(100) + e_liters(80) + e_amount(100) + d_name(100) + d_ded(100) + d_earn(100) + d_amount(175) = 825.0
        final double minTargetWidth = maxDateWidth + 340.0 + 825.0; 
        final double targetWidth = max(minTargetWidth, availableWidth);
        final double flexScale = (targetWidth - 340.0 - maxDateWidth) / 825.0;

        final Map<String, double> colWidths = {
          'date': maxDateWidth,
          'm_liters': 70.0 * flexScale,
          'm_fat': 50.0,
          'm_snf': 50.0,
          'm_rate': 70.0,
          'm_amount': 100.0 * flexScale,
          'e_liters': 80.0 * flexScale,
          'e_fat': 50.0,
          'e_snf': 50.0,
          'e_rate': 70.0,
          'e_amount': 100.0 * flexScale,
          'd_name': 100.0 * flexScale,
          'd_ded': 100.0 * flexScale,
          'd_earn': 100.0 * flexScale,
          'd_amount': 175.0 * flexScale,
        };

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(11),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: targetWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMergedHeaders(colWidths),
                            _buildSubHeaders(colWidths),
                            Expanded(
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: hasData ? maxRows : 1,
                                itemBuilder: (context, i) {
                                  if (!hasData) {
                                    return _buildDataRow(-1, colWidths);
                                  }
                                  return _buildDataRow(i, colWidths);
                                },
                              ),
                            ),
                            if (hasData) _buildTotalRow(colWidths),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_billSummary != null) _buildSummaryCard(_billSummary!),
          ],
        );
      },
    );
  }

  Widget _buildTotalRow(Map<String, double> colWidths) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final totalStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 17,
      color: colorScheme.onSurface,
    );
    final totalRowColor = isDark
        ? const Color(0xFF2A2A2A)
        : Theme.of(context).highlightColor;

    Widget buildNumberCell(
      double? value,
      int fractionDigits, {
      Color? color,
      String? suffix,
    }) {
      if (value == null || value == 0.0) return const SizedBox.shrink();
      final numberText = value.toStringAsFixed(fractionDigits);
      if (suffix == null) {
        return DynamicText(
          text: numberText,
          langCode: widget.langCode,
          style: totalStyle.copyWith(color: color),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          DynamicText(
            text: numberText,
            langCode: widget.langCode,
            style: totalStyle.copyWith(color: color),
          ),
          const SizedBox(width: 3),
          DynamicText(
            text: suffix,
            langCode: widget.langCode,
            style: totalStyle.copyWith(
              color: (color ?? colorScheme.onSurface).withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      );
    }

    final totalActdedAmount = _groupedDeductions.fold<double>(
      0.0,
      (sum, item) => sum + item.actdedAmount,
    );

    return SizedBox(
      height: 52,
      child: Container(
        color: totalRowColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCell(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.total,
                    style: totalStyle.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.summary_fromPassbook,
                    style: totalStyle.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              width: colWidths['date']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.center,
            ),
            // Morning Totals
            _buildCell(
              child: buildNumberCell(_totalMorningLiters, 2),
              width: colWidths['m_liters']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // --- UPDATED: Show Average FAT and SNF ---
            _buildCell(
              child: buildNumberCell(_avgMorningFat, 1),
              width: colWidths['m_fat']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(_avgMorningSnf, 1),
              width: colWidths['m_snf']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // --- END ---
            _buildCell(
              child: const SizedBox.shrink(),
              width: colWidths['m_rate']!,
              backgroundColor: totalRowColor,
            ), // Empty RATE
            _buildCell(
              child: buildNumberCell(
                _totalMorningAmount,
                2,
                color: _greenProfit,
              ),
              width: colWidths['m_amount']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // Evening Totals
            _buildCell(
              child: buildNumberCell(_totalEveningLiters, 2),
              width: colWidths['e_liters']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // --- UPDATED: Show Average FAT and SNF ---
            _buildCell(
              child: buildNumberCell(_avgEveningFat, 1),
              width: colWidths['e_fat']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(_avgEveningSnf, 1),
              width: colWidths['e_snf']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // --- END ---
            _buildCell(
              child: const SizedBox.shrink(),
              width: colWidths['e_rate']!,
              backgroundColor: totalRowColor,
            ), // Empty RATE
            _buildCell(
              child: buildNumberCell(
                _totalEveningAmount,
                2,
                color: _greenProfit,
              ),
              width: colWidths['e_amount']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            // Deduction/Earning Totals
            _buildCell(
              child: const SizedBox.shrink(),
              width: colWidths['d_name']!,
              backgroundColor: totalRowColor,
            ), // Empty Deduction Name
            _buildCell(
              child: buildNumberCell(
                _summary?.totalDeductions,
                2,
                color: _redLoss,
              ),
              width: colWidths['d_ded']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(
                _summary?.totalEarnings,
                2,
                color: _greenProfit,
              ),
              width: colWidths['d_earn']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(
                totalActdedAmount == 0 ? null : totalActdedAmount.abs(),
                2,
                color: totalActdedAmount > 0 ? _greenProfit : _redLoss,
                suffix: totalActdedAmount == 0
                    ? null
                    : totalActdedAmount > 0
                        ? ' ${l10n.ledger_col_credit}'
                        : ' ${l10n.ledger_col_debit}',
              ),
              width: colWidths['d_amount']!,
              backgroundColor: totalRowColor,
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(int index, Map<String, double> colWidths) {
    final milkRecord = (index >= 0 && index < _filteredDailyMilkRecords.length)
        ? _filteredDailyMilkRecords[index]
        : null;
    final deduction = (index >= 0 && index < _groupedDeductions.length)
        ? _groupedDeductions[index]
        : null;
    // print('Building row $index: MilkRecord=$milkRecord, Deduction=$deduction');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowColor = index.isEven
        ? (isDark ? const Color(0xFF1A1A1A) : Colors.white)
        : (isDark ? const Color(0xFF242424) : const Color(0xFFF9FAFB));

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    Widget buildNumberCell(
      double? value,
      int fractionDigits, {
      Color? color,
      String? suffix,
    }) {
      if (value == null) return const SizedBox.shrink();
      final numberText = value.toStringAsFixed(fractionDigits);

      if (suffix == null) {
        return DynamicText(
          text: numberText,
          langCode: widget.langCode,
          style: _poppinsStyle.copyWith(
            color: color ?? onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          DynamicText(
            text: numberText,
            langCode: widget.langCode,
            style: _poppinsStyle.copyWith(
              color: color ?? onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 3),
          DynamicText(
            text: suffix,
            langCode: widget.langCode,
            style: _poppinsStyle.copyWith(
              color: (color ?? onSurface).withValues(alpha: 0.7),
              fontSize: 17,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      );
    }

    Widget buildDateCell(DateTime? date) {
      if (date == null) return const SizedBox.shrink();
      return DynamicText(
        text: formatLanguageAwareDateNoYear(date, widget.langCode),
        langCode: widget.langCode,
        style: _poppinsStyle.copyWith(
          color: _primaryBlue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Container(
        color: rowColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCell(
              child: buildDateCell(milkRecord?.date),
              width: colWidths['date']!,
            ),
            // Morning Data
            _buildCell(
              child: buildNumberCell(milkRecord?.morningEntry?.liters, 2),
              width: colWidths['m_liters']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.morningEntry?.fat, 1),
              width: colWidths['m_fat']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.morningEntry?.degree, 1),
              width: colWidths['m_snf']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.morningEntry?.rate, 2),
              width: colWidths['m_rate']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(
                milkRecord?.morningEntry?.amount,
                2,
                color: _greenProfit,
              ),
              width: colWidths['m_amount']!,
              alignment: Alignment.centerRight,
            ),
            // Evening Data
            _buildCell(
              child: buildNumberCell(milkRecord?.eveningEntry?.liters, 2),
              width: colWidths['e_liters']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.eveningEntry?.fat, 1),
              width: colWidths['e_fat']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.eveningEntry?.degree, 1),
              width: colWidths['e_snf']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(milkRecord?.eveningEntry?.rate, 2),
              width: colWidths['e_rate']!,
              alignment: Alignment.centerRight,
            ),
            _buildCell(
              child: buildNumberCell(
                milkRecord?.eveningEntry?.amount,
                2,
                color: _greenProfit,
              ),
              width: colWidths['e_amount']!,
              alignment: Alignment.centerRight,
            ),
            // Deduction Data
            deduction != null &&
                    (deduction.dedName?.isNotEmpty ?? false)
                ? _buildCell(
                    child: DynamicText(
                      text: deduction.dedName ?? '',
                      langCode: widget.langCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _poppinsStyle.copyWith(
                        color: onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    width: colWidths['d_name']!,
                  )
                : _buildCell(
                    child: const SizedBox.shrink(),
                    width: colWidths['d_name']!,
                  ),
            deduction != null && deduction.deductionAmount != 0
                ? _buildCell(
                    child: buildNumberCell(
                      deduction.deductionAmount,
                      2,
                      color: _redLoss,
                    ),
                    width: colWidths['d_ded']!,
                    alignment: Alignment.centerRight,
                  )
                : _buildCell(
                    child: const SizedBox.shrink(),
                    width: colWidths['d_ded']!,
                  ),
            deduction != null && deduction.earningAmount != 0
                ? _buildCell(
                    child: buildNumberCell(
                      deduction.earningAmount,
                      2,
                      color: _greenProfit,
                    ),
                    width: colWidths['d_earn']!,
                    alignment: Alignment.centerRight,
                  )
                : _buildCell(
                    child: const SizedBox.shrink(),
                    width: colWidths['d_earn']!,
                  ),
            deduction != null && deduction.actdedAmount != 0
                ? _buildCell(
                    child: buildNumberCell(
                      deduction.actdedAmount.abs(),
                      2,
                      color: deduction.actdedAmount > 0 ? _greenProfit : _redLoss,
                      suffix: deduction.actdedAmount > 0
                          ? ' ${l10n.ledger_col_credit}'
                          : ' ${l10n.ledger_col_debit}',
                    ),
                    width: colWidths['d_amount']!,
                    alignment: Alignment.centerRight,
                  )
                : _buildCell(
                    child: const SizedBox.shrink(),
                    width: colWidths['d_amount']!,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell({
    required Widget child,
    required double width,
    Color? backgroundColor,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final gridColor = _cachedGridColor ?? Colors.grey;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(color: gridColor, width: 1.0),
          bottom: BorderSide(color: gridColor, width: 1.0),
        ),
      ),
      child: Align(alignment: alignment, child: child),
    );
  }

  Widget _buildMergedHeaders(Map<String, double> colWidths) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final morningBgColor = isDark
        ? const Color(0xFF4A3000)
        : Colors.orange.shade100;
    final eveningBgColor = isDark
        ? const Color(0xFF1A2A4A)
        : Colors.indigo.shade100;
    final deductionBgColor = isDark
        ? const Color(0xFF4A1A1A)
        : Colors.red.shade100;

    final morningTextColor = Theme.of(context).colorScheme.onSurface;
    final eveningTextColor = Theme.of(context).colorScheme.onSurface;
    final deductionTextColor = Theme.of(context).colorScheme.onSurface;

    final double morningWidth =
        colWidths['date']! +
        colWidths['m_liters']! +
        colWidths['m_fat']! +
        colWidths['m_snf']! +
        colWidths['m_rate']! +
        colWidths['m_amount']!;
    final double eveningWidth =
        colWidths['e_liters']! +
        colWidths['e_fat']! +
        colWidths['e_snf']! +
        colWidths['e_rate']! +
        colWidths['e_amount']!;
    final double deductionWidth =
        colWidths['d_name']! +
        colWidths['d_ded']! +
        colWidths['d_earn']! +
        colWidths['d_amount']!;

    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCell(
            child: Text(
              l10n.report_morningCollection,
              style: _poppinsStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: morningTextColor,
              ),
            ),
            width: morningWidth,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: Text(
              l10n.report_eveningCollection,
              style: _poppinsStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: eveningTextColor,
              ),
            ),
            width: eveningWidth,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: Text(
              l10n.report_deductions,
              style: _poppinsStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: deductionTextColor,
              ),
            ),
            width: deductionWidth,
            backgroundColor: deductionBgColor,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeaders(Map<String, double> colWidths) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateBgColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;

    final morningBgColor = isDark
        ? const Color(0xFF332000)
        : const Color(0xFFFFF3E0);
    final eveningBgColor = isDark
        ? const Color(0xFF101C36)
        : const Color(0xFFE8EAF6);
    final deductionBgColor = isDark
        ? const Color(0xFF331010)
        : const Color(0xFFFFEBEE);

    final morningTextColor = Theme.of(context).colorScheme.onSurface;
    final eveningTextColor = Theme.of(context).colorScheme.onSurface;
    final deductionTextColor = Theme.of(context).colorScheme.onSurface;

    Widget buildHeader(String text, Color textColor) => Text(
      text,
      style: _poppinsStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      textAlign: TextAlign.center,
    );

    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCell(
            child: buildHeader(
              l10n.passbook_date,
              Theme.of(context).colorScheme.onSurface,
            ),
            width: colWidths['date']!,
            backgroundColor: dateBgColor,
            alignment: Alignment.center,
          ),
          // Morning
          _buildCell(
            child: buildHeader(l10n.passbook_liters, morningTextColor),
            width: colWidths['m_liters']!,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_fat, morningTextColor),
            width: colWidths['m_fat']!,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_snf, morningTextColor),
            width: colWidths['m_snf']!,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_rate, morningTextColor),
            width: colWidths['m_rate']!,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_amount_me, morningTextColor),
            width: colWidths['m_amount']!,
            backgroundColor: morningBgColor,
            alignment: Alignment.center,
          ),
          // Evening
          _buildCell(
            child: buildHeader(l10n.passbook_liters, eveningTextColor),
            width: colWidths['e_liters']!,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_fat, eveningTextColor),
            width: colWidths['e_fat']!,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_snf, eveningTextColor),
            width: colWidths['e_snf']!,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_rate, eveningTextColor),
            width: colWidths['e_rate']!,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_amount_me, eveningTextColor),
            width: colWidths['e_amount']!,
            backgroundColor: eveningBgColor,
            alignment: Alignment.center,
          ),
          // Deductions
          _buildCell(
            child: buildHeader(l10n.report_deductionName, deductionTextColor),
            width: colWidths['d_name']!,
            backgroundColor: deductionBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.report_deduction, deductionTextColor),
            width: colWidths['d_ded']!,
            backgroundColor: deductionBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.report_earning, deductionTextColor),
            width: colWidths['d_earn']!,
            backgroundColor: deductionBgColor,
            alignment: Alignment.center,
          ),
          _buildCell(
            child: buildHeader(l10n.passbook_amount, deductionTextColor),
            width: colWidths['d_amount']!,
            backgroundColor: deductionBgColor,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CalculatedSummaryItem bill) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 6,
      shadowColor: _primaryBlue.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.summary_fromBill,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryRow(
                    l10n.summary_totalMilk,
                    DynamicText(
                      text: '${bill.totalLiters.toStringAsFixed(2)} ',
                      langCode: widget.langCode,
                    ),
                    Icons.opacity,
                    Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryRow(
                    l10n.summary_totalMilkAmount,
                    DynamicText(
                      text: bill.totalLitersAmount.toStringAsFixed(2),
                      langCode: widget.langCode,
                    ),
                    Icons.currency_rupee,
                    Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryRow(
                    l10n.summary_totalEarnings,
                    DynamicText(
                      text: bill.totalEarnings.toStringAsFixed(2),
                      langCode: widget.langCode,
                    ),
                    Icons.add_circle_outline,
                    _greenProfit,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryRow(
                    l10n.report_deductions,
                    DynamicText(
                      text: bill.totalDeductions.abs().toStringAsFixed(2),
                      langCode: widget.langCode,
                    ),
                    Icons.remove_circle_outline,
                    _redLoss,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1, height: 24),
            _summaryRow(
              l10n.summary_netAmount,
              DynamicText(
                text: bill.netAmount.abs().toStringAsFixed(2),
                langCode: widget.langCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Icons.account_balance_wallet,
              Theme.of(context).colorScheme.onSurface,
              isBold: true,
              fontSize: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    Widget valueWidget,
    IconData icon,
    Color? color, {
    bool isBold = false,
    double fontSize = 16,
  }) {
    final textStyle = TextStyle(
      fontSize: isBold ? 22 : fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Row(
      children: [
        Icon(
          icon,
          color:
              color ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: textStyle.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        DefaultTextStyle(style: textStyle, child: valueWidget),
      ],
    );
  }
}
