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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headerBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F3F5);
          final borderColor = isDark ? Colors.white12 : Colors.black12;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 660,
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
                        SizedBox(width: 110, child: _HeaderCell('Bill Date')),
                        SizedBox(width: 110, child: _HeaderCell('Period')),
                        SizedBox(width: 110, child: _HeaderCell('Total Liters', isNumeric: true)),
                        SizedBox(width: 110, child: _HeaderCell('Earnings', isNumeric: true)),
                        SizedBox(width: 110, child: _HeaderCell('Deductions', isNumeric: true)),
                        SizedBox(width: 110, child: _HeaderCell('Net Amount', isNumeric: true)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: bills.length,
                      itemExtent: 42.0,
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        final from = bill.fromdate != null
                            ? DateFormat('dd/MM').format(bill.fromdate!)
                            : 'N/A';
                        final to = bill.todate != null
                            ? DateFormat('dd/MM').format(bill.todate!)
                            : 'N/A';
                        final dateStr = bill.billdate != null
                            ? DateFormat('dd-MM-yyyy').format(bill.billdate!)
                            : 'N/A';
                        final rowBg = index.isEven
                            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                            : (isDark ? const Color(0xFF252525) : const Color(0xFFF8F9FA));

                        return Container(
                          color: rowBg,
                          child: Row(
                            children: [
                              SizedBox(width: 110, child: _DataCell(dateStr)),
                              SizedBox(width: 110, child: _DataCell('$from - $to')),
                              SizedBox(width: 110, child: _DataCell(bill.liters.toStringAsFixed(2), isNumeric: true)),
                              SizedBox(width: 110, child: _DataCell(bill.totearn.toStringAsFixed(2), isNumeric: true)),
                              SizedBox(width: 110, child: _DataCell(bill.totded.toStringAsFixed(2), isNumeric: true)),
                              SizedBox(width: 110, child: _DataCell(bill.netamt.toStringAsFixed(2), isNumeric: true)),
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


