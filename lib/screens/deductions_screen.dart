import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/deduction_model.dart';
import '../service/api_service.dart';
import '../widget/company_logo.dart';

class DeductionsScreen extends StatefulWidget {
  final int socCode;
  final int memCode;

  const DeductionsScreen({
    super.key,
    required this.socCode,
    required this.memCode,
  });

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  late Future<List<DeductionModel>> _deductionsFuture;

  @override
  void initState() {
    super.initState();
    _deductionsFuture = ApiService().fetchDeductions(
      widget.socCode,
      widget.memCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Deductions'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: const CompanyLogo(size: 32),
          ),
        ],
      ),
      body: FutureBuilder<List<DeductionModel>>(
        future: _deductionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No deductions found."));
          }

          final deductions = snapshot.data!;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headerBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F3F5);
          final borderColor = isDark ? Colors.white12 : Colors.black12;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 480,
              child: Column(
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 110, child: _HeaderCell('Date')),
                        SizedBox(width: 170, child: _HeaderCell('Deduction Name')),
                        SizedBox(width: 100, child: _HeaderCell('Amount', isNumeric: true)),
                        SizedBox(width: 100, child: _HeaderCell('Bill No.', isNumeric: true)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: deductions.length,
                      itemExtent: 42.0,
                      itemBuilder: (context, index) {
                        final item = deductions[index];
                        final dateStr = item.dedctnDate != null
                            ? DateFormat('dd-MM-yyyy').format(item.dedctnDate!)
                            : 'N/A';
                        final rowBg = index.isEven
                            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                            : (isDark ? const Color(0xFF252525) : const Color(0xFFF8F9FA));

                        return Container(
                          color: rowBg,
                          child: Row(
                            children: [
                              SizedBox(width: 110, child: _DataCell(dateStr)),
                              SizedBox(width: 170, child: _DataCell(item.dedName ?? 'N/A')),
                              SizedBox(
                                width: 100,
                                child: _DataCell(
                                  item.dedctnAmt1?.toStringAsFixed(2) ?? '0.00',
                                  isNumeric: true,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: _DataCell(
                                  item.billno?.toString() ?? 'N/A',
                                  isNumeric: true,
                                ),
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
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool isNumeric;

  const _HeaderCell(this.text, {this.isNumeric = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Align(
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool isNumeric;

  const _DataCell(this.text, {this.isNumeric = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Align(
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}


