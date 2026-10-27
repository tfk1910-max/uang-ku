import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'categories.dart';
import 'transactions.dart';
import 'txn_editor.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onSeeAll});
  final VoidCallback onSeeAll;

  Widget _alert(IconData icon, String text, Color color) => Panel(
        color: color.withAlpha(25),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(text, style: TextStyle(color: color.withAlpha(255), fontWeight: FontWeight.w600)),
        ),
      );

  Widget _stat(String label, double v, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white.withAlpha(36), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(rp(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) => Observe((context) {
        final now = DateTime.now();
        final month = store.inMonth(now);
        final inc = AppStore.sum(month, true), exp = AppStore.sum(month, false);
        final spent = store.spentByCategory(now);
        final top = spent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        final alerts = <Widget>[];
        store.budgets.forEach((id, limit) {
          final c = store.cat(id);
          if (c == null || limit <= 0) return;
          final r = (spent[id] ?? 0) / limit;
          if (r >= 0.8) {
            alerts.add(_alert(
              Icons.warning_amber_rounded,
              r >= 1 ? 'Anggaran ${c.name} terlampaui (${(r * 100).round()}%)' : 'Anggaran ${c.name} terpakai ${(r * 100).round()}%',
              r >= 1 ? Colors.red.shade700 : Colors.orange.shade800,
            ));
          }
        });
        for (final d in store.debts) {
          if (d.remaining <= 0 || d.due == null) continue;
          final days = daysBetween(now, d.due!);
          if (days > 7) continue;
          final when = days < 0 ? 'terlambat ${-days} hari' : (days == 0 ? 'jatuh tempo hari ini' : 'jatuh tempo $days hari lagi');
          alerts.add(_alert(Icons.event_outlined, '${d.receivable ? 'Piutang' : 'Utang'} ${d.name} $when',
              days < 0 ? Colors.red.shade700 : Colors.orange.shade800));
        }

        return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
          const Header('Uangku', subtitle: 'Keuanganmu, lebih teratur.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xff126b5b), borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOTAL SALDO', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(rp(store.totalBalance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Kekayaan bersih ${rp(store.netWorth)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 18),
                Text(monthFmt.format(now), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _stat('Pemasukan', inc, Icons.arrow_downward)),
                  Expanded(child: _stat('Pengeluaran', exp, Icons.arrow_upward)),
                ]),
              ]),
            ),
          ),
          ...alerts,
          SectionTitle('Pengeluaran bulan ini'),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('Belum ada pengeluaran bulan ini.'),
            ),
          ...top.take(5).map<Widget>((e) {
            final c = store.cat(e.key);
            if (c == null) return const SizedBox.shrink();
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailPage(c.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(children: [
                  Row(children: [
                    CatAvatar(c, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(rp(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: exp > 0 ? e.value / exp : 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: c.tint,
                    backgroundColor: c.tint.withAlpha(30),
                  ),
                ]),
              ),
            );
          }),
          SectionTitle('Transaksi terbaru', trailing: TextButton(onPressed: onSeeAll, child: const Text('Lihat semua'))),
          if (store.txns.isEmpty)
            EmptyState(
              Icons.receipt_long,
              'Belum ada transaksi.\nMulai dengan mencatat pemasukan atau pengeluaran pertamamu.',
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Catat transaksi'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxnEditorPage())),
              ),
            ),
          ...store.txns.take(5).map<Widget>((t) => TxnTile(t)),
        ]);
      });
}
