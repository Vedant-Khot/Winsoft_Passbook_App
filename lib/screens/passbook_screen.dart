import 'package:flutter/material.dart';
import 'package:passbook/l10n/app_localizations.dart';
import '../service/api_service.dart';
import '../utils/passbook_row_processor.dart';
import '../theme/app_theme.dart';
import '../widget/company_logo.dart';
import '../theme/app_text_styles.dart';

class PassbookScreen extends StatefulWidget {
  final int socCode;
  final int memCode;
  final int langCode;
  final String dairyType;

  const PassbookScreen({
    super.key,
    required this.socCode,
    required this.memCode,
    required this.langCode,
    required this.dairyType,
  });

  @override
  State<PassbookScreen> createState() => _PassbookScreenState();
}

class _PassbookScreenState extends State<PassbookScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rowData = [];
  Map<String, double>? _colWidths;

  static final _poppinsStyle = AppTextStyles.poppins(fontSize: 16);
  static final Map<String, List<Map<String, dynamic>>> _processedCache = {};
  static final Map<String, int> _processedRawCounts = {};

  String get _cacheKey =>
      '${widget.socCode}_${widget.memCode}_${widget.langCode}';

  @override
  void initState() {
    super.initState();
    _restoreProcessedCacheIfAvailable();
    _loadData();
  }

  void _restoreProcessedCacheIfAvailable() {
    final cached = _processedCache[_cacheKey];
    if (cached == null || cached.isEmpty) return;
    _rowData = cached;
    _colWidths = _computeColumnWidths(cached);
    _isLoading = false;
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final hasExistingData = _rowData.isNotEmpty;

    if (forceRefresh) {
      _processedCache.remove(_cacheKey);
      _processedRawCounts.remove(_cacheKey);
    }

    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawJson = await ApiService().fetchPassbookRawJson(
        widget.socCode,
        widget.memCode,
        forceRefresh: forceRefresh,
      );

      if (rawJson == null || rawJson.isEmpty) {
        if (mounted) {
          setState(() {
            if (!hasExistingData) {
              _rowData = [];
              _colWidths = null;
            }
            _isLoading = false;
          });
        }
        return;
      }

      final cachedRows = _processedCache[_cacheKey];
      if (!forceRefresh &&
          cachedRows != null &&
          cachedRows.isNotEmpty &&
          _processedRawCounts[_cacheKey] == rawJson.length) {
        if (mounted) {
          setState(() {
            _rowData = cachedRows;
            _colWidths = _computeColumnWidths(cachedRows);
            _isLoading = false;
          });
        }
        return;
      }

      final processedRows = await PassbookRowProcessor.process(
        rawJson,
        widget.langCode,
      );

      if (processedRows.isNotEmpty) {
        _processedCache[_cacheKey] = processedRows;
        _processedRawCounts[_cacheKey] = rawJson.length;
      } else {
        _processedCache.remove(_cacheKey);
        _processedRawCounts.remove(_cacheKey);
      }

      if (mounted) {
        setState(() {
          _rowData = processedRows;
          _colWidths = _computeColumnWidths(processedRows);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, double> _computeColumnWidths(List<Map<String, dynamic>> rows) {
    int maxDateChars = 5;
    for (final row in rows) {
      final dateStr = row['dateKey'] ?? 'N/A';
      if (dateStr.length > maxDateChars) {
        maxDateChars = dateStr.length;
      }
    }
    final double maxDateWidth =
        ((maxDateChars * 8.5) + 24.0 + 2.0).clamp(90.0, 150.0);

    return {
      'date': maxDateWidth,
      'type': 40.0,
      'session': 55.0,
      'liters': 75.0,
      'fat': 45.0,
      'snf': 45.0,
      'rate': 75.0,
      'amount': 100.0,
    };
  }

  Future<void> _handleRefresh() async {
    await _loadData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF2A2A2A) : AppTheme.lightBlue;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Passbook'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: const CompanyLogo(size: 32),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Error: $_errorMessage",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _handleRefresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (_rowData.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(child: Text(l10n.noEntriesFound)),
                        ),
                      ],
                    ),
                  );
                }

                final baseWidths = _colWidths!;
                final maxDateWidth = baseWidths['date']!;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double availableWidth = constraints.maxWidth - 8;
                    final double minTargetWidth = maxDateWidth + 185.0 + 250.0;
                    final double targetWidth = availableWidth > 750
                        ? 750.0
                        : (availableWidth < minTargetWidth
                            ? minTargetWidth
                            : availableWidth);
                    final double flexScale =
                        (targetWidth - 185.0 - maxDateWidth) / 250.0;

                    final Map<String, double> colWidths = {
                      'date': maxDateWidth,
                      'type': baseWidths['type']!,
                      'session': baseWidths['session']!,
                      'liters': baseWidths['liters']! * flexScale,
                      'fat': baseWidths['fat']!,
                      'snf': baseWidths['snf']!,
                      'rate': baseWidths['rate']! * flexScale,
                      'amount': baseWidths['amount']! * flexScale,
                    };

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: targetWidth,
                        child: Column(
                          children: [
                            // Fixed Header Row
                            Container(
                              decoration: BoxDecoration(
                                color: headerBg,
                                border: Border(
                                  bottom: BorderSide(
                                    color: borderColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: colWidths['date']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_date,
                                      colorScheme,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['type']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_type,
                                      colorScheme,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['session']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_session,
                                      colorScheme,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['liters']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_liters,
                                      colorScheme,
                                      isNumeric: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['fat']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_fat,
                                      colorScheme,
                                      isNumeric: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['snf']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_snf,
                                      colorScheme,
                                      isNumeric: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['rate']!,
                                    child: _buildTableHeader(
                                      'Rate',
                                      colorScheme,
                                      isNumeric: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colWidths['amount']!,
                                    child: _buildTableHeader(
                                      l10n.passbook_amount_me,
                                      colorScheme,
                                      isNumeric: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Lazy-loaded Data Rows
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _handleRefresh,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  itemCount: _rowData.length,
                                  itemBuilder: (context, index) {
                                    final row = _rowData[index];
                                    final isMorning = row['isMorning'] as bool;
                                    final evenRowBg = isDark
                                        ? const Color(0xFF1A1A1A)
                                        : Colors.white;
                                    final oddRowBg = isDark
                                        ? const Color(0xFF242424)
                                        : const Color(0xFFF8F9FA);

                                    return Container(
                                      color: index.isEven
                                          ? evenRowBg
                                          : oddRowBg,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: colWidths['date']!,
                                            child: _buildTableCell(
                                              row['dateKey'],
                                              colorScheme,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['type']!,
                                            child: _buildTableCell(
                                              row['cobfType'],
                                              colorScheme,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['session']!,
                                            child: _buildTableCell(
                                              isMorning ? 'M' : 'E',
                                              colorScheme,
                                              color: isMorning
                                                  ? Colors.orange.shade700
                                                  : AppTheme.primaryBlue,
                                              isBold: true,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['liters']!,
                                            child: _buildTableCell(
                                              row['liters'].toStringAsFixed(2),
                                              colorScheme,
                                              isNumeric: true,
                                              isMono: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['fat']!,
                                            child: _buildTableCell(
                                              row['fat'].toStringAsFixed(1),
                                              colorScheme,
                                              isNumeric: true,
                                              isMono: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['snf']!,
                                            child: _buildTableCell(
                                              row['degree'].toStringAsFixed(1),
                                              colorScheme,
                                              isNumeric: true,
                                              isMono: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['rate']!,
                                            child: _buildTableCell(
                                              row['rate'].toStringAsFixed(2),
                                              colorScheme,
                                              isNumeric: true,
                                              isMono: true,
                                            ),
                                          ),
                                          SizedBox(
                                            width: colWidths['amount']!,
                                            child: _buildTableCell(
                                              '₹${row['amount'].toStringAsFixed(2)}',
                                              colorScheme,
                                              isNumeric: true,
                                              isMono: true,
                                              isBold: true,
                                              color: AppTheme.successGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(
    String text,
    ColorScheme colorScheme, {
    bool isNumeric = false,
    TextAlign? textAlign,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: textAlign ?? (isNumeric ? TextAlign.right : TextAlign.left),
        style: _poppinsStyle.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text,
    ColorScheme colorScheme, {
    bool isNumeric = false,
    bool isMono = false,
    bool isBold = false,
    Color? color,
    TextAlign? textAlign,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: textAlign ?? (isNumeric ? TextAlign.right : TextAlign.left),
        style: _poppinsStyle.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? colorScheme.onSurface,
        ),
      ),
    );
  }
}
