import 'dart:math';
import 'package:flutter/material.dart';
import 'package:passbook/l10n/app_localizations.dart';
import 'package:passbook/model/data_parser.dart';
import '../model/glms_account_model.dart';
import '../model/ledger_transaction_model.dart';
import '../service/api_service.dart';
import '../widget/dynamic_text.dart';
import '../widget/company_logo.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_styles.dart';

// A helper class to hold the calculated totals for the ledger.
class LedgerSummary {
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

  LedgerSummary({
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });
}

/// A private helper class to hold a transaction and its calculated running balance.
/// This separates data processing from rendering and ensures the balance is always correct.
class _TransactionRowData {
  final LedgerTransactionModel transaction;
  final double runningBalance;

  _TransactionRowData({
    required this.transaction,
    required this.runningBalance,
  });
}

class LedgerScreen extends StatefulWidget {
  final int socCode;
  final int accNo;
  final int langCode;

  const LedgerScreen({
    super.key,
    required this.socCode,
    required this.accNo,
    required this.langCode,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  static final _poppinsStyle = AppTextStyles.poppins(fontSize: 16);

  List<GlmsAccountModel> _accounts = [];
  List<LedgerTransactionModel> _allTransactions = [];
  GlmsAccountModel? _selectedAccount;
  bool _isLoading = true;
  String? _loadError;

  List<_TransactionRowData> _displayRows = [];
  LedgerSummary? _summary;
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData({bool forceNetwork = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final accounts = await _loadGlmsAccounts(forceNetwork: forceNetwork);
      final transactions = await _loadLedgerTransactions(
        forceNetwork: forceNetwork,
      );
      final diskVerify = await ApiService().debugVerifyLedgerDiskCache(
        widget.socCode,
        widget.accNo,
      );

      debugPrint(
        'LedgerScreen: load complete forceNetwork=$forceNetwork '
        'apiRows=${transactions.length} diskVerify=$diskVerify',
      );

      if (!mounted) return;

      GlmsAccountModel? selected;
      if (accounts.isNotEmpty) {
        final matches =
            accounts.where((account) => account.accno == widget.accNo);
        selected = matches.isNotEmpty ? matches.first : accounts.first;
      }

      setState(() {
        _accounts = accounts;
        _allTransactions = transactions;
        _selectedAccount = selected;
        _isLoading = false;
      });

      if (selected != null) {
        _showTransactionsForAccount(selected.accno);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<List<GlmsAccountModel>> _loadGlmsAccounts({
    bool forceNetwork = false,
  }) async {
    if (forceNetwork) {
      return ApiService().fetchGlmsAccounts(
        widget.socCode,
        forceRefresh: true,
      );
    }

    final cached = await ApiService().fetchGlmsAccounts(
      widget.socCode,
      localOnly: true,
    );
    if (cached.isNotEmpty) return cached;

    return ApiService().fetchGlmsAccounts(widget.socCode, forceRefresh: true);
  }

  Future<List<LedgerTransactionModel>> _loadLedgerTransactions({
    bool forceNetwork = false,
  }) async {
    if (forceNetwork) {
      return ApiService().fetchLedgerTransactions(
        widget.socCode,
        widget.accNo,
        forceRefresh: true,
      );
    }

    // Open from local cache only — splash sync already refreshed disk.
    final cached = await ApiService().fetchLedgerTransactions(
      widget.socCode,
      widget.accNo,
      localOnly: true,
    );
    if (cached.isNotEmpty) return cached;

    return ApiService().fetchLedgerTransactions(
      widget.socCode,
      widget.accNo,
      forceRefresh: true,
    );
  }

  Future<void> _handleRefresh() async {
    await _loadInitialData(forceNetwork: true);
  }

  void _onAccountSelected(int? accNo) {
    if (accNo == null || accNo == _selectedAccount?.accno) return;
    final account = _accounts.firstWhere((item) => item.accno == accNo);
    setState(() => _selectedAccount = account);
    _showTransactionsForAccount(accNo);
  }

  void _showTransactionsForAccount(int accNo) {
    _processTransactions(_allTransactions, accNo);
  }

  void _processTransactions(
    List<LedgerTransactionModel> allTransactions,
    int accNo,
  ) {
    if (!mounted) return;

    DateTime latestDate = DateTime(1900);
    for (final txn in allTransactions.where((t) => t.accno == accNo)) {
      if (txn.trDates != null && txn.trDates!.isAfter(latestDate)) {
        latestDate = txn.trDates!;
      }
    }
    final int startYear = latestDate.month >= 4
        ? latestDate.year
        : latestDate.year - 1;
    final DateTime financialYearStart = DateTime(startYear, 4, 1);

    final filteredByAccount = allTransactions
        .where((txn) => txn.accno == accNo)
        .where(
          (txn) =>
              txn.trDates != null && !txn.trDates!.isBefore(financialYearStart),
        )
        .toList();

    filteredByAccount.sort((a, b) {
      final dateA = a.trDates ?? DateTime(1900);
      final dateB = b.trDates ?? DateTime(1900);
      return dateA.compareTo(dateB);
    });

    double runningBalance = 0;
    final List<_TransactionRowData> processedRows = [];
    for (final txn in filteredByAccount) {
      final isCredit = txn.crdb == 'C';
      final double debit = isCredit ? 0.0 : txn.amt;
      final double credit = isCredit ? txn.amt : 0.0;

      if (txn.opInd == 1) {
        runningBalance = isCredit ? credit : -debit;
      } else {
        runningBalance += credit - debit;
      }
      processedRows.add(
        _TransactionRowData(transaction: txn, runningBalance: runningBalance),
      );
    }

    setState(() {
      _displayRows = processedRows;
      _summary = _calculateSummary(filteredByAccount);
    });
    _applyCurrentSort();
  }

  /// Called by the sort button â€” toggles direction then sorts.
  void _sortDisplayRows() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _applySortToRows();
    });
  }

  /// Applies the current sort direction without toggling. Safe to call internally.
  void _applyCurrentSort() {
    setState(() {
      _applySortToRows();
    });
  }

  /// Core sort logic â€” does not change _isSortAscending.
  void _applySortToRows() {
    _displayRows.sort((a, b) {
      final dateA = a.transaction.trDates ?? DateTime(1900);
      final dateB = b.transaction.trDates ?? DateTime(1900);
      return _isSortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  }

  /// Calculates the summary totals for a given list of transactions.
  LedgerSummary _calculateSummary(List<LedgerTransactionModel> transactions) {
    double totalDebit = 0;
    double totalCredit = 0;

    // Use the last transaction's running balance from the processed list if available
    // Note: This requires the list to be chronologically sorted first.
    // final closingBalance = _displayRows.isNotEmpty
    //     ? _displayRows.last.runningBalance
    //     : 0.0;

    for (var txn in transactions) {
      // Opening balance should not be part of the Debit/Credit totals

      if (txn.crdb == 'C') {
        totalCredit += txn.amt;
      } else {
        totalDebit += txn.amt;
      }
    }
    final closingBalance = totalCredit - totalDebit;

    return LedgerSummary(
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      closingBalance: closingBalance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildEnhancedAppBar(
        l10n.ledger_title,
        Icons.account_balance_wallet,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark
                  ? colorScheme.surface
                  : AppTheme.lightBlue.withValues(alpha: 0.3),
              scaffoldBg,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildAccountSelector(l10n, colorScheme),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _loadError!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            const Divider(height: 1),
            Expanded(child: _buildTransactionContent(l10n)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar(String title, IconData icon) {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _handleRefresh,
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          alignment: Alignment.center,
          child: const CompanyLogo(size: 32),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.ledger_loadingAccounts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.ledger_noAccounts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.ledger_selectAccount,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: _selectedAccount?.accno,
            items: _accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.accno,
                    child: DynamicText(
                      text: account.accName.trim().isEmpty
                          ? '${l10n.ledger} ${account.accno}'
                          : account.accName,
                      langCode: widget.langCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _poppinsStyle.copyWith(fontSize: 15),
                    ),
                  ),
                )
                .toList(),
            onChanged: _isLoading
                ? null
                : (accNo) => _onAccountSelected(accNo),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionContent(AppLocalizations l10n) {
    if (_isLoading || _accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_displayRows.isEmpty) {
      return Center(
        child: Text(l10n.ledger_noTransactions, textAlign: TextAlign.center),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _buildTransactionTable(l10n, _displayRows),
        ),
        if (_summary != null) _buildSummaryCard(l10n, _summary!),
      ],
    );
  }

  /// Builds the scrollable DataTable from pre-processed row data.
  Widget _buildTransactionTable(
    AppLocalizations l10n,
    List<_TransactionRowData> rowsData,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBgColor = isDark
        ? const Color(0xFF2A2A2A)
        : Theme.of(context).highlightColor;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;

    // Calculate maximum characters to size the date and particulars columns dynamically
    int maxDateChars = 5;
    int maxChars = 10;
    for (final row in rowsData) {
      final dateStr = row.transaction.trDates != null
          ? formatLanguageAwareDateShort(
              row.transaction.trDates!,
              widget.langCode,
            )
          : 'N/A';
      if (dateStr.length > maxDateChars) {
        maxDateChars = dateStr.length;
      }
      final text = row.transaction.opInd == 1
          ? l10n.ledger_openingBalance
          : row.transaction.part ?? '';
      if (text.length > maxChars) {
        maxChars = text.length;
      }
    }
    // 8.5 pixels per char + padding + 2.0 extra, clamped
    final double maxDateWidth = ((maxDateChars * 8.5) + 24.0 + 2.0).clamp(
      115.0,
      180.0,
    );
    final double maxParticularsWidth = ((maxChars * 8.5) + 24.0).clamp(
      280.0,
      550.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth - 16;
        final double otherColumnsWidth =
            95.0 + 95.0 + 160.0; // debit + credit + balance = 350.0
        final double minTargetWidth =
            maxParticularsWidth + maxDateWidth + otherColumnsWidth;
        final double targetWidth = max(minTargetWidth, availableWidth);
        final double particularsWidth =
            targetWidth - otherColumnsWidth - maxDateWidth;

        final Map<String, double> colWidths = {
          'date': maxDateWidth,
          'particulars': particularsWidth,
          'debit': 95.0,
          'credit': 95.0,
          'balance': 160.0,
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: gridColor, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: targetWidth,
                  child: Column(
                    children: [
                      // Sticky Header Row
                      Container(
                        height: 44,
                        color: headerBgColor,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeaderCell(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.ledger_col_date,
                                    style: _poppinsStyle.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isSortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                  ),
                                ],
                              ),
                              width: colWidths['date']!,
                              gridColor: gridColor,
                              alignment: Alignment.center,
                              onTap: _sortDisplayRows,
                            ),
                            _buildHeaderCell(
                              child: Text(
                                l10n.ledger_col_particulars,
                                style: _poppinsStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              width: colWidths['particulars']!,
                              gridColor: gridColor,
                            ),
                            _buildHeaderCell(
                              child: Text(
                                l10n.ledger_col_debit,
                                style: _poppinsStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              width: colWidths['debit']!,
                              gridColor: gridColor,
                              alignment: Alignment.centerRight,
                            ),
                            _buildHeaderCell(
                              child: Text(
                                l10n.ledger_col_credit,
                                style: _poppinsStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              width: colWidths['credit']!,
                              gridColor: gridColor,
                              alignment: Alignment.centerRight,
                            ),
                            _buildHeaderCell(
                              child: Text(
                                l10n.ledger_col_balance,
                                style: _poppinsStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              width: colWidths['balance']!,
                              gridColor: gridColor,
                              alignment: Alignment.centerRight,
                            ),
                          ],
                        ),
                      ),
                      // Lazy Scrollable Data Rows
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rowsData.length,
                          itemBuilder: (context, index) {
                            final rowData = rowsData[index];
                            final transaction = rowData.transaction;
                            final balance = rowData.runningBalance;
                            final bool isCredit = transaction.crdb == 'C';
                            final double debit = isCredit
                                ? 0.0
                                : transaction.amt;
                            final double credit = isCredit
                                ? transaction.amt
                                : 0.0;
                            final bool balanceIsCredit = balance >= 0;
                            final String balanceLabel = balanceIsCredit
                                ? l10n.ledger_col_credit
                                : l10n.ledger_col_debit;

                            final evenRowBg = isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white;
                            final oddRowBg = isDark
                                ? const Color(0xFF242424)
                                : const Color(0xFFF8F9FA);
                            final rowColor = index.isEven
                                ? evenRowBg
                                : oddRowBg;

                            return Container(
                              height: 40,
                              color: rowColor,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildDataCell(
                                    child: DynamicText(
                                      text: transaction.trDates != null
                                          ? formatLanguageAwareDateShort(
                                              transaction.trDates!,
                                              widget.langCode,
                                            )
                                          : '',
                                      langCode: widget.langCode,
                                      forceKiran: true,
                                      style: _poppinsStyle.copyWith(
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    width: colWidths['date']!,
                                    gridColor: gridColor,
                                    alignment: Alignment.center,
                                  ),
                                  _buildDataCell(
                                    child: DynamicText(
                                      text: transaction.opInd == 1
                                          ? l10n.ledger_openingBalance
                                          : transaction.part ?? 'N/A',
                                      langCode: widget.langCode,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _poppinsStyle.copyWith(
                                        fontSize: 16,
                                      ),
                                    ),
                                    width: colWidths['particulars']!,
                                    gridColor: gridColor,
                                  ),
                                  _buildDataCell(
                                    child: DynamicText(
                                      text: debit == 0
                                          ? ''
                                          : debit.toStringAsFixed(2),
                                      langCode: widget.langCode,
                                      forceKiran: true,
                                      style: _poppinsStyle.copyWith(
                                        color: Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                    width: colWidths['debit']!,
                                    gridColor: gridColor,
                                    alignment: Alignment.centerRight,
                                  ),
                                  _buildDataCell(
                                    child: DynamicText(
                                      text: credit == 0
                                          ? ''
                                          : credit.toStringAsFixed(2),
                                      langCode: widget.langCode,
                                      forceKiran: true,
                                      style: _poppinsStyle.copyWith(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                    width: colWidths['credit']!,
                                    gridColor: gridColor,
                                    alignment: Alignment.centerRight,
                                  ),
                                  _buildDataCell(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        DynamicText(
                                          text: balance.abs().toStringAsFixed(
                                            2,
                                          ),
                                          langCode: widget.langCode,
                                          forceKiran: true,
                                          style: _poppinsStyle.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: balanceIsCredit
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        DynamicText(
                                          text: balanceLabel,
                                          langCode: widget.langCode,
                                          forceKiran: false,
                                          style: _poppinsStyle.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: balanceIsCredit
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    width: colWidths['balance']!,
                                    gridColor: gridColor,
                                    alignment: Alignment.centerRight,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell({
    required Widget child,
    required double width,
    required Color gridColor,
    Alignment alignment = Alignment.centerLeft,
    VoidCallback? onTap,
  }) {
    final cell = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: gridColor, width: 1.0),
          bottom: BorderSide(color: gridColor, width: 2.0),
        ),
      ),
      child: Align(alignment: alignment, child: child),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: cell);
    }
    return cell;
  }

  Widget _buildDataCell({
    required Widget child,
    required double width,
    required Color gridColor,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: gridColor, width: 1.0),
          bottom: BorderSide(color: gridColor, width: 1.0),
        ),
      ),
      child: Align(alignment: alignment, child: child),
    );
  }

  /// Builds the floating summary card.
  Widget _buildSummaryCard(AppLocalizations l10n, LedgerSummary summary) {
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryRow(
                l10n.ledger_col_debit_sum,
                DynamicText(
                  text: summary.totalDebit.toStringAsFixed(2),
                  langCode: widget.langCode,
                ),
                Colors.red,
              ),
              const SizedBox(height: 8),
              _summaryRow(
                l10n.ledger_col_credit_sum,
                DynamicText(
                  text: summary.totalCredit.toStringAsFixed(2),
                  langCode: widget.langCode,
                ),
                Colors.green,
              ),
              const Divider(height: 24),
              _summaryRow(
                l10n.ledger_col_balance,
                DynamicText(
                  text: summary.closingBalance.abs().toStringAsFixed(2),
                  langCode: widget.langCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                (summary.closingBalance >= 0 ? Colors.green : Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, Widget valueWidget, [Color? color]) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle.copyWith()),
        DefaultTextStyle(style: textStyle, child: valueWidget),
      ],
    );
  }
}
