import 'package:flutter/material.dart';
import '../common.dart';
import '../store.dart';

Color budgetColor(double ratio) => ratio >= 1 ? Colors.red.shade600 : (ratio >= 0.8 ? Colors.orange.shade700 : brand);

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime month = DateTime.now();

  Future<void> _edit(String id, String name) async {
    final cur = store.budgets[id] ?? 0;
    final r = await askForm(context, 'Anggaran $name', [
      F('limit', 'Batas per bulan (kosongkan untuk hapus)',
          kind: FK.money, init: cur > 0 ? cur.round().toString() : null, required: false),
    ]);
    if (r != null) store.setBudget(id, r['limit'] as double);
  }

  @override
  Widget build(BuildContext context) => Observe((context) {
        final spent = store.spentByCategory(month);
        final cats = store.catsOf(false)
          ..sort((a, b) {
            final ba = (store.budgets[a.id] ?? 0) > 0 ? 0 : 1, bb = (store.budgets[b.id] ?? 0) > 0 ? 0 : 1;
            if (ba != bb) return ba - bb;
            return (spent[b.id] ?? 0).compareTo(spent[a.id] ?? 0);
          });
        var totalBudget = 0.0, spentBudgeted = 0.0;
        for (final c in cats) {
          final l = store.budgets[c.id] ?? 0;
          if (l > 0) {
            totalBudget += l;
            spentBudgeted += spent[c.id] ?? 0;
          }
        }
        final totalSpent = spent.values.fold(0.0, (s, v) => s + v);
        final ratio = totalBudget > 0 ? spentBudgeted / totalBudget : 0.0;
        return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
          const Header('Anggaran', subtitle: 'Batasi pengeluaran tiap kategori per bulan.'),
          MonthBar(month: month, onChanged: (m) => setState(() => month = m)),
          Panel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: totalBudget <= 0
                  ? const Text('Belum ada anggaran. Ketuk salah satu kategori di bawah untuk mengatur batasnya.')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Sisa anggaran bulan ini', style: TextStyle(color: Colors.black54)),
                      Text(rp(totalBudget - spentBudgeted),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: budgetColor(ratio))),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: budgetColor(ratio),
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 6),
                      Text('${rp(spentBudgeted)} dari ${rp(totalBudget)} • total semua pengeluaran ${rp(totalSpent)}',
                          style: const TextStyle(fontSize: 12.5)),
                    ]),
            ),
          ),
          for (final c in cats)
            Builder(builder: (ctx) {
              final limit = store.budgets[c.id] ?? 0;
              final s = spent[c.id] ?? 0;
              final r = limit > 0 ? s / limit : 0.0;
              return Panel(
                child: InkWell(
                  onTap: () => _edit(c.id, c.name),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CatAvatar(c, radius: 18),
                        const SizedBox(width: 12),
                        Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text(limit > 0 ? '${rp(s)} / ${rp(limit)}' : rp(s), style: const TextStyle(fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      if (limit > 0) ...[
                        LinearProgressIndicator(
                          value: r.clamp(0.0, 1.0),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(4),
                          color: budgetColor(r),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s > limit ? 'Melebihi ${rp(s - limit)}' : 'Sisa ${rp(limit - s)}',
                          style: TextStyle(fontSize: 12.5, color: budgetColor(r), fontWeight: FontWeight.w600),
                        ),
                      ] else
                        Text('Ketuk untuk atur anggaran', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    ]),
                  ),
                ),
              );
            }),
        ]);
      });
}
