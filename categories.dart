import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'transactions.dart';

/// Membuka dialog tambah/ubah kategori (nama, ikon, warna) dan langsung menyimpannya.
Future<Category?> editCategory(BuildContext context, {Category? cat, required bool income}) async {
  final r = await showDialog<Category>(
    context: context,
    builder: (ctx) => _CategoryDialog(cat: cat, income: income),
  );
  if (r != null) store.saveCategory(r);
  return r;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.cat, required this.income});
  final Category? cat;
  final bool income;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController name = TextEditingController(text: widget.cat?.name ?? '');
  late String icon = widget.cat?.icon ?? 'other';
  late int color = widget.cat?.color ?? colorChoices.first;
  String? err;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) return setState(() => err = 'Nama kategori wajib diisi');
    final dup = store.categories.any((c) =>
        c.income == widget.income && c.id != widget.cat?.id && c.name.toLowerCase() == n.toLowerCase());
    if (dup) return setState(() => err = 'Nama kategori sudah dipakai');
    Navigator.pop(
      context,
      Category(id: widget.cat?.id ?? newId(), name: n, income: widget.income, icon: icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.cat == null ? 'Kategori baru' : 'Ubah kategori'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nama kategori', errorText: err, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Ikon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in iconChoices.entries)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => icon = e.key),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: icon == e.key ? Color(color) : Colors.grey.shade200,
                    child: Icon(e.value, size: 20, color: icon == e.key ? Colors.white : Colors.black54),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            const Text('Warna', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in colorChoices)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => color = c),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(c),
                    child: color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      );
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.startIncome = false});
  final bool startIncome;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        initialIndex: startIncome ? 1 : 0,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Kategori'),
            bottom: const TabBar(tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')]),
          ),
          body: const TabBarView(children: [_CatList(income: false), _CatList(income: true)]),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              onPressed: () => editCategory(ctx, income: DefaultTabController.of(ctx).index == 1),
              icon: const Icon(Icons.add),
              label: const Text('Kategori'),
            ),
          ),
        ),
      );
}

class _CatList extends StatelessWidget {
  const _CatList({required this.income});
  final bool income;

  @override
  Widget build(BuildContext context) => Observe((context) {
        final cats = store.catsOf(income);
        final now = DateTime.now();
        final spent = store.spentByCategory(now, income: income);
        return ListView(padding: const EdgeInsets.only(top: 8, bottom: 100), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              'Ketuk kategori untuk melihat transaksi & detail barang. Ganti nama/ikon lewat ikon pensil.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
          ),
          for (final c in cats)
            Panel(
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryDetailPage(c.id))),
                leading: CatAvatar(c),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${store.txnCount(c.id)} transaksi • bulan ini ${rp(spent[c.id] ?? 0)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Ubah kategori',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => editCategory(context, cat: c, income: income),
                  ),
                  if (!store.isProtected(c.id))
                    IconButton(
                      tooltip: 'Hapus kategori',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirm(
                          context,
                          'Hapus "${c.name}"?',
                          'Transaksi di kategori ini akan dipindahkan ke "Lainnya". Anggaran kategori ikut dihapus.',
                        );
                        if (ok) store.deleteCategory(c.id);
                      },
                    ),
                ]),
              ),
            ),
        ]);
      });
}

/// Detail satu kategori: ringkasan, rincian barang yang pernah dicatat, dan daftar transaksinya.
class CategoryDetailPage extends StatelessWidget {
  const CategoryDetailPage(this.categoryId, {super.key});
  final String categoryId;

  @override
  Widget build(BuildContext context) => Observe((context) {
        final c = store.cat(categoryId);
        if (c == null) return Scaffold(appBar: AppBar(), body: const EmptyState(Icons.folder_off, 'Kategori tidak ditemukan.'));
        final list = store.txns.where((t) => t.categoryId == c.id).toList();
        final total = list.fold(0.0, (s, t) => s + t.amount);
        final now = DateTime.now();
        final thisMonth = list
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .fold(0.0, (s, t) => s + t.amount);
        final items = store.itemTotals(list);
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                tooltip: 'Ubah nama / ikon',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => editCategory(context, cat: c, income: c.income),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CatAvatar(c, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bulan ini: ${rp(thisMonth)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Total keseluruhan: ${rp(total)} • ${list.length} transaksi'),
                    ]),
                  ),
                ]),
              ),
            ),
            if (items.isNotEmpty) ...[
              const SectionTitle('Detail barang'),
              Panel(
                child: Column(children: [
                  for (final i in items)
                    ListTile(
                      dense: true,
                      title: Text(i.name),
                      subtitle: Text('Dibeli ${fmtQty(i.qty)}x'),
                      trailing: Text(rp(i.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ],
            const SectionTitle('Transaksi'),
            if (list.isEmpty) const EmptyState(Icons.receipt_long, 'Belum ada transaksi di kategori ini.'),
            for (final t in list) TxnTile(t),
          ]),
        );
      });
}
