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
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 38,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Deduction Name')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Bill No.')),
                ],
                rows: deductions.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          item.dedctnDate != null
                              ? DateFormat(
                                  'dd-MM-yyyy',
                                ).format(item.dedctnDate!)
                              : 'N/A',
                        ),
                      ),
                      DataCell(Text(item.dedName ?? 'N/A')),
                      DataCell(
                        Text(item.dedctnAmt1?.toStringAsFixed(2) ?? '0.00'),
                      ),
                      DataCell(Text(item.billno?.toString() ?? 'N/A')),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}


