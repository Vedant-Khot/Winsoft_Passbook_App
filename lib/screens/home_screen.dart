import 'package:flutter/material.dart';
import '../model/mem_info_model.dart';
import 'bill_transaction_screen.dart';
import 'deductions_screen.dart';
import 'passbook_screen.dart';

class HomeScreen extends StatelessWidget {
  final MemInfoModel userInfo;

  const HomeScreen({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${userInfo.memName ?? "Member"}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PassbookScreen(
                      socCode: userInfo.socCode,
                      memCode: userInfo.membCode,
                      langCode: userInfo.langCode,
                      dairyType: userInfo.dairyType.toString(),
                    ),
                  ),
                );
              },
              child: const Text('View Passbook'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeductionsScreen(
                      socCode: userInfo.socCode,
                      memCode: userInfo.membCode,
                    ),
                  ),
                );
              },
              child: const Text('View Deductions'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BillTransactionsScreen(
                      socCode: userInfo.socCode,
                      memCode: userInfo.membCode,
                    ),
                  ),
                );
              },
              child: const Text('View Bill Summary'),
            ),
          ],
        ),
      ),
    );
  }
}


