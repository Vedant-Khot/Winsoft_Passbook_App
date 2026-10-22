import 'package:flutter/material.dart';
import 'package:passbook/l10n/app_localizations.dart';
import 'package:passbook/model/data_parser.dart';
import 'package:passbook/widget/company_logo.dart';
import '../model/passbook_model.dart';
import '../service/api_service.dart';

class MilkSlipSession {
  final DateTime date;
  final String dateString;
  final int me; // 1 for Morning, 2 for Evening
  final List<PassbookModel> records;
  double totalLiters;
  double totalAmount;

  MilkSlipSession({
    required this.date,
    required this.dateString,
    required this.me,
    required this.records,
    this.totalLiters = 0.0,
    this.totalAmount = 0.0,
  });
}

class MilkSlipScreen extends StatefulWidget {
  final int socCode;
  final int memCode;
  final int langCode;
  final String dairyType;

  const MilkSlipScreen({
    super.key,
    required this.socCode,
    required this.memCode,
    required this.langCode,
    required this.dairyType,
  });

  @override
  State<MilkSlipScreen> createState() => _MilkSlipScreenState();
}

class _MilkSlipScreenState extends State<MilkSlipScreen> {
  late Future<List<MilkSlipSession>> _milkSlipFuture;
  List<PassbookModel> _rawEntries = [];

  @override
  void initState() {
    super.initState();
    _milkSlipFuture = _fetchAndAggregateData();
  }

  Future<List<MilkSlipSession>> _fetchAndAggregateData({
    bool forceRefresh = false,
  }) async {
    _rawEntries = await ApiService().fetchPassbook(
      widget.socCode,
      widget.memCode,
      forceRefresh: forceRefresh,
    );

    return _aggregateData(_rawEntries);
  }

  List<MilkSlipSession> _aggregateData(List<PassbookModel> data) {
    final Map<String, MilkSlipSession> sessionMap = {};

    for (var entry in data) {
      final dateKey = formatLanguageAwareDateShort(
        entry.trndate,
        widget.langCode,
      );
      // Create a unique key for Date + Session
      final sessionKey = '${dateKey}_${entry.me}';

      if (!sessionMap.containsKey(sessionKey)) {
        sessionMap[sessionKey] = MilkSlipSession(
          date: entry.trndate,
          dateString: dateKey,
          me: entry.me,
          records: [],
        );
      }

      sessionMap[sessionKey]!.records.add(entry);
      sessionMap[sessionKey]!.totalLiters += entry.liters;
      sessionMap[sessionKey]!.totalAmount += entry.amount;
    }

    // Convert to list and sort by date descending, then evening (2) before morning (1)
    final sessions = sessionMap.values.toList();
    sessions.sort((a, b) {
      final dateComparison = b.date.compareTo(a.date); // Newest date first
      if (dateComparison != 0) return dateComparison;
      return a.me.compareTo(b.me); // Morning (1) before Evening (2)
    });

    for (var session in sessions) {
      session.records.sort((a, b) {
        final aCode = a.cobf?.trim().toUpperCase() ?? '';
        final bCode = b.cobf?.trim().toUpperCase() ?? '';
        if (aCode == 'C' && bCode == 'B') return -1;
        if (aCode == 'B' && bCode == 'C') return 1;
        return aCode.compareTo(bCode);
      });
    }

    return sessions;
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _milkSlipFuture = _fetchAndAggregateData(forceRefresh: true);
    });
  }

  String _getAnimalType(String? cobfCode, int langCode) {
    if (cobfCode == null) return '-';
    return cobfCode.trim().toUpperCase();
  }

  String _getSessionName(int me, AppLocalizations l10n) {
    return me == 1 ? l10n.morning : l10n.evening;
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
        Container(
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.center,
          child: const CompanyLogo(size: 32),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _buildEnhancedAppBar(l10n.milk_slips, Icons.receipt_long),
      body: FutureBuilder<List<MilkSlipSession>>(
        future: _milkSlipFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noEntriesFound));
          }

          final sessions = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(session, l10n);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(MilkSlipSession session, AppLocalizations? l10n) {
    final bool isMorning = session.me == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isMorning
        ? (isDark ? const Color(0xFF4A3000) : Colors.orange.shade100)
        : (isDark ? const Color(0xFF1A2A4A) : Colors.indigo.shade100);
    final iconColor = isMorning
        ? Colors.orange.shade600
        : Colors.indigo.shade400;
    final sessionName = _getSessionName(session.me, l10n!);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isMorning ? Icons.wb_sunny : Icons.nights_stay,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${session.dateString} - $sessionName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card Body: Data Table
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: (constraints.maxWidth / 6) * 0.15,

                      headingRowHeight: 40.0,
                      dataRowMinHeight: 40.0,
                      dataRowMaxHeight: 40.0,

                      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      dataTextStyle: TextStyle(fontSize: 16),

                      columns: const [
                        DataColumn(label: Text('C/B')),
                        DataColumn(label: Text('Liters'), numeric: true),
                        DataColumn(label: Text('Fat'), numeric: true),
                        DataColumn(label: Text('SNF'), numeric: true),
                        DataColumn(label: Text('Rate'), numeric: true),
                        DataColumn(label: Text('Total Amt'), numeric: true),
                      ],

                      rows: [
                        ...session.records.map((record) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  _getAnimalType(record.cobf, widget.langCode),
                                ),
                              ),
                              DataCell(Text(record.liters.toStringAsFixed(2))),
                              DataCell(Text(record.fat.toStringAsFixed(1))),
                              DataCell(Text(record.degree.toStringAsFixed(1))),
                              DataCell(Text(record.rate.toStringAsFixed(2))),
                              DataCell(
                                Text('${record.amount.toStringAsFixed(2)}'),
                              ),
                            ],
                          );
                        }),

                        DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((
                            Set<WidgetState> states,
                          ) {
                            return Theme.of(context).highlightColor;
                          }),
                          cells: [
                            const DataCell(
                              Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),

                            DataCell(
                              Text(
                                session.totalLiters.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),

                            DataCell(
                              Text(
                                '${session.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
