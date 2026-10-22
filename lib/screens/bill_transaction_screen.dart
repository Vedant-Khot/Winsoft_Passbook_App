import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/bill_transaction_model.dart';
import '../service/api_service.dart';
import '../widget/company_logo.dart';

class BillTransactionsScreen extends StatefulWidget {
  final int socCode;
  final int memCode;

  const BillTransactionsScreen({
    super.key,
    required this.socCode,
    required this.memCode,
  });

  @override
  State<BillTransactionsScreen> createState() => _BillTransactionsScreenState();
}

class _BillTransactionsScreenState extends State<BillTransactionsScreen> {
  late Future<List<BillTransactionModel>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = ApiService().fetchBillTransactions(
      widget.socCode,
      widget.memCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Summary'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: const CompanyLogo(size: 32),
          ),
        ],
      ),
      body: FutureBuilder<List<BillTransactionModel>>(
        future: _billsFuture,
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
            return const Center(child: Text("No bills found."));
          }

          final bills = snapshot.data!;
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 38,
                columns: const [
                  DataColumn(label: Text('Bill Date')),
                  DataColumn(label: Text('Period')),
                  DataColumn(label: Text('Total Liters')),
                  DataColumn(label: Text('Earnings')),
                  DataColumn(label: Text('Deductions')),
                  DataColumn(label: Text('Net Amount')),
                ],
                rows: bills.map((bill) {
                  final from = bill.fromdate != null
                      ? DateFormat('dd/MM').format(bill.fromdate!)
                      : 'N/A';
                  final to = bill.todate != null
                      ? DateFormat('dd/MM').format(bill.todate!)
                      : 'N/A';
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          bill.billdate != null
                              ? DateFormat('dd-MM-yyyy').format(bill.billdate!)
                              : 'N/A',
                        ),
                      ),
                      DataCell(Text('$from - $to')),
                      DataCell(Text(bill.liters.toStringAsFixed(2))),
                      DataCell(Text(bill.totearn.toStringAsFixed(2))),
                      DataCell(Text(bill.totded.toStringAsFixed(2))),
                      DataCell(Text(bill.netamt.toStringAsFixed(2))),
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


