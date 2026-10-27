import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common.dart';
import '../store.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime month = DateTime.now();

  Widget _bar(double h, Color c) => Container(
        width: 12,
        height: h < 2 ? 2 : h,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );

  Widget _chart() {
    final months = [for (var k = 5; k >= 0; k--) DateTime(month.year, month.month - k)];
    final vals = months.map((d) {
      final l = store.inMonth(d);
      return [AppStore.sum(l, true), AppStore.sum(l, false)];
    }).toList();
    var mx = 1.0;
    for (final v in vals) {
      for (final x in v) {
        if (x > mx) mx = x;
      }
    }
    return SizedBox(
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                _bar(vals[i][0] / mx * 120, brand),
                const SizedBox(width: 3),
                _bar(vals[i][1] / mx * 120, expenseColor),
              ]),
              const SizedBox(height: 6),
              Text(shortMonth.format(months[i]), style: const TextStyle(fontSize: 11)),
            ]),
          ),
      ]),
    );
  }

  Widget _breakdown(String title, Map<String, double> data, double total) {
    final list = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(title),
      for (final e in list)
        Builder(builder: (ctx) {
          final c = store.cat(e.key);
          if (c == null) return const SizedBox.shrink();
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(children: [
              Row(children: [
                CatAvatar(c, radius: 14),
                const SizedBox(width: 10),
                Expanded(child: Text(c.name)),
                Text('${rp(e.value)}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 40, child: Text('${(pct * 100).round()}%', textAlign: TextAlign.right)),
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: c.tint,
                backgroundColor: c.tint.withAlpha(30),
              ),
            ]),
          );
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: Observe((context) {
          final list = store.inMonth(month);
          final inc = AppStore.sum(list, true), exp = AppStore.sum(list, false);
          final items = store.itemTotals(list.where((t) => !t.income)).take(10).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            MonthBar(month: month, onChanged: (m) => setState(() => month = m)),
            Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Pemasukan\n${rp(inc)}', style: const TextStyle(color: brand, fontWeight: FontWeight.w700))),
                    Expanded(child: Text('Pengeluaran\n${rp(exp)}', style: const TextStyle(color: expenseColor, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 8),
                  Text('Selisih bulan ini: ${rp(inc - exp)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SectionTitle('6 bulan terakhir'),
            Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _chart(),
                  const SizedBox(height: 8),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.circle, size: 10, color: brand),
                    Text(' Pemasukan    '),
                    Icon(Icons.circle, size: 10, color: expenseColor),
                    Text(' Pengeluaran'),
                  ]),
                ]),
              ),
            ),
            _breakdown('Pengeluaran per kategori', store.spentByCategory(month), exp),
            _breakdown('Pemasukan per kategori', store.spentByCategory(month, income: true), inc),
            if (items.isNotEmpty) ...[
              const SectionTitle('Barang paling banyak dibelanjakan'),
              Panel(
                child: Column(children: [
                  for (final i in items)
                    ListTile(
                      dense: true,
                      title: Text(i.name),
                      subtitle: Text('${fmtQtyText(i.qty)}x'),
                      trailing: Text(rp(i.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Salin semua transaksi (CSV)'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: store.exportCsv()));
                  if (context.mounted) snack(context, 'CSV disalin. Tempel ke Excel/Google Sheets.');
                },
              ),
            ),
          ]);
        }),
      );
}

String fmtQtyText(double q) => q == q.roundToDouble() ? q.round().toString() : q.toStringAsFixed(1).replaceAll('.', ',');
