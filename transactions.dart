import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'txn_editor.dart';

void deleteWithUndo(BuildContext context, Txn t) {
  store.deleteTxn(t.id);
  snack(context, 'Transaksi dihapus', action: 'Urungkan', onAction: () => store.addTxn(t));
}

void showTxnDetail(BuildContext context, Txn t) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final c = store.catOrFallback(t.categoryId, t.income);
      final a = store.acc(t.accountId);
      final color = t.income ? brand : expenseColor;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                CatAvatar(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${c.name} • ${dayFmt.format(t.date)}'),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text('${t.income ? '+' : '−'}${rp(t.amount)}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              if (a != null) Text('Rekening: ${a.name}'),
              if (t.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Catatan: ${t.note}')),
              if (t.items.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Rincian barang', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final i in t.items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(i.name),
                    subtitle: Text('${fmtQty(i.qty)} × ${rp(i.price)}'),
                    trailing: Text(rp(i.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Ubah'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TxnEditorPage(txn: t)));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Duplikat',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TxnEditorPage(txn: t, duplicate: true)));
                  },
                ),
                IconButton.outlined(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    Navigator.pop(ctx);
                    deleteWithUndo(context, t);
                  },
                ),
              ]),
            ]),
          ),
        ),
      );
    },
  );
}

class TxnTile extends StatelessWidget {
  const TxnTile(this.t, {super.key});
  final Txn t;

  @override
  Widget build(BuildContext context) {
    final c = store.catOrFallback(t.categoryId, t.income);
    final a = store.acc(t.accountId);
    final color = t.income ? brand : expenseColor;
    Widget bg(Alignment al) => Container(
          color: Colors.red.shade100,
          alignment: al,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Icon(Icons.delete_outline),
        );
    return Dismissible(
      key: ValueKey('tx_${t.id}'),
      background: bg(Alignment.centerLeft),
      secondaryBackground: bg(Alignment.centerRight),
      onDismissed: (_) => deleteWithUndo(context, t),
      child: ListTile(
        onTap: () => showTxnDetail(context, t),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: CatAvatar(c),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [c.name, if (t.items.isNotEmpty) '${t.items.length} barang', if (a != null) a.name].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text('${t.income ? '+' : '−'}${rp(t.amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime month = DateTime.now();
  int type = 0; // 0 semua, 1 pengeluaran, 2 pemasukan
  String query = '';
  bool allMonths = false;

  @override
  Widget build(BuildContext context) => Observe((context) {
        final q = query.trim().toLowerCase();
        final list = store.txns.where((t) {
          if (!allMonths && (t.date.year != month.year || t.date.month != month.month)) return false;
          if (type == 1 && t.income) return false;
          if (type == 2 && !t.income) return false;
          if (q.isEmpty) return true;
          final c = store.cat(t.categoryId);
          return t.title.toLowerCase().contains(q) ||
              t.note.toLowerCase().contains(q) ||
              (c?.name.toLowerCase().contains(q) ?? false) ||
              t.items.any((i) => i.name.toLowerCase().contains(q));
        }).toList();
        final rows = <Object>[];
        DateTime? last;
        for (final t in list) {
          final d = dayOnly(t.date);
          if (last != d) {
            rows.add(d);
            last = d;
          }
          rows.add(t);
        }
        return Column(children: [
          const Header('Transaksi', subtitle: 'Cari juga berdasarkan nama barang.'),
          if (!allMonths) MonthBar(month: month, onChanged: (m) => setState(() => month = m)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cari transaksi, kategori, atau barang',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              for (final e in const {0: 'Semua', 1: 'Pengeluaran', 2: 'Pemasukan'}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: type == e.key,
                    onSelected: (_) => setState(() => type = e.key),
                  ),
                ),
              FilterChip(
                label: const Text('Semua bulan'),
                selected: allMonths,
                onSelected: (v) => setState(() => allMonths = v),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Text('Masuk ${rp(AppStore.sum(list, true))}', style: const TextStyle(color: brand, fontWeight: FontWeight.w600))),
              Text('Keluar ${rp(AppStore.sum(list, false))}', style: const TextStyle(color: expenseColor, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.receipt_long, 'Tidak ada transaksi.')
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, top: 4),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      if (r is DateTime) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                          child: Text(dayFmt.format(r), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        );
                      }
                      return TxnTile(r as Txn);
                    },
                  ),
          ),
        ]);
      });
}
