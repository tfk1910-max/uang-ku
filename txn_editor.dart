import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'categories.dart';

class TxnEditorPage extends StatefulWidget {
  const TxnEditorPage({super.key, this.txn, this.duplicate = false, this.income = false});
  final Txn? txn;
  final bool duplicate, income;
  @override
  State<TxnEditorPage> createState() => _TxnEditorPageState();
}

class _TxnEditorPageState extends State<TxnEditorPage> {
  late bool income;
  late String categoryId, accountId;
  late DateTime date;
  late List<Item> items;
  final title = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();

  bool get isEdit => widget.txn != null && !widget.duplicate;
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.total);

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    income = t?.income ?? widget.income;
    date = (t == null || widget.duplicate) ? dayOnly(DateTime.now()) : t.date;
    accountId = (t != null && store.acc(t.accountId) != null) ? t.accountId : store.accounts.first.id;
    categoryId = t?.categoryId ?? _defaultCat(income);
    items = t == null ? [] : t.items.map((i) => Item(name: i.name, qty: i.qty, price: i.price)).toList();
    title.text = t?.title ?? '';
    note.text = t?.note ?? '';
    if (t != null && t.items.isEmpty) amount.text = rupiahText(t.amount);
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  String _defaultCat(bool inc) {
    for (final t in store.txns) {
      if (t.income == inc && store.cat(t.categoryId) != null) return t.categoryId;
    }
    final cs = store.catsOf(inc);
    return cs.isNotEmpty ? cs.first.id : (inc ? incOther : expOther);
  }

  void _warn(String m) => snack(context, m);

  void _save() {
    final name = title.text.trim();
    final total = items.isNotEmpty ? itemsTotal : parseRupiah(amount.text);
    if (name.isEmpty) return _warn('Isi nama transaksi dulu.');
    if (total <= 0) return _warn('Jumlah harus lebih dari 0.');
    final txn = Txn(
      id: isEdit ? widget.txn!.id : newId(),
      title: name,
      income: income,
      amount: total,
      date: date,
      categoryId: categoryId,
      accountId: accountId,
      note: note.text.trim(),
      items: items,
    );
    if (isEdit) {
      store.updateTxn(txn);
    } else {
      store.addTxn(txn);
    }
    Navigator.pop(context, true);
  }

  Future<void> _editItem([int? idx]) async {
    final it = idx == null ? null : items[idx];
    final r = await askForm(context, it == null ? 'Tambah barang' : 'Ubah barang', [
      F('name', 'Nama barang', init: it?.name),
      F('qty', 'Jumlah', kind: FK.number, init: it == null ? '1' : fmtQty(it.qty)),
      F('price', 'Harga satuan', kind: FK.money, init: it?.price.round().toString(), required: false),
    ]);
    if (r == null) return;
    final item = Item(name: r['name'] as String, qty: r['qty'] as double, price: r['price'] as double);
    setState(() {
      if (idx == null) {
        items.add(item);
      } else {
        items[idx] = item;
      }
    });
  }

  Future<void> _newCategory() async {
    final c = await editCategory(context, income: income);
    if (c != null && mounted) setState(() => categoryId = c.id);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Hapus transaksi?', 'Transaksi ini akan dihapus.')) return;
    if (!mounted) return;
    final t = widget.txn!;
    store.deleteTxn(t.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = store.catsOf(income);
    final sug = store.suggestions(categoryId);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah transaksi' : 'Transaksi baru'),
        actions: [
          if (isEdit) IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(tooltip: 'Simpan', icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(6), child: Text('Simpan'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Pengeluaran'), icon: Icon(Icons.north_east)),
            ButtonSegment(value: true, label: Text('Pemasukan'), icon: Icon(Icons.south_west)),
          ],
          selected: {income},
          onSelectionChanged: (s) => setState(() {
            income = s.first;
            categoryId = _defaultCat(income);
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nama transaksi', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton.icon(
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Kelola'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CategoriesPage(startIncome: income)),
            ).then((_) {
              if (!mounted) return;
              setState(() {
                final c = store.cat(categoryId);
                if (c == null || c.income != income) categoryId = _defaultCat(income);
              });
            }),
          ),
        ]),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in cats)
            ChoiceChip(
              avatar: Icon(iconOf(c.icon), size: 18, color: c.tint),
              label: Text(c.name),
              selected: c.id == categoryId,
              onSelected: (_) => setState(() => categoryId = c.id),
            ),
          ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Kategori baru'), onPressed: _newCategory),
        ]),
        const SizedBox(height: 16),
        Panel(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rincian barang (opsional)', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Catat tiap barang agar total dihitung otomatis.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
              if (sug.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Pernah dibeli di kategori ini (ketuk untuk tambah):', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                Wrap(spacing: 8, children: [
                  for (final s in sug)
                    ActionChip(
                      label: Text('${s.name} • ${rp(s.price)}'),
                      onPressed: () => setState(() => items.add(Item(name: s.name, qty: 1, price: s.price))),
                    ),
                ]),
              ],
              for (var i = 0; i < items.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _editItem(i),
                  title: Text(items[i].name),
                  subtitle: Text('${fmtQty(items[i].qty)} × ${rp(items[i].price)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(rp(items[i].total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      tooltip: 'Hapus barang',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => items.removeAt(i)),
                    ),
                  ]),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(onPressed: _editItem, icon: const Icon(Icons.add), label: const Text('Tambah barang')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isNotEmpty)
          Panel(
            margin: EdgeInsets.zero,
            color: const Color(0xffe1f3ed),
            child: ListTile(
              title: Text('Total dari ${items.length} barang'),
              trailing: Text(rp(itemsTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          )
        else
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahFormatter()],
            decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp ', border: OutlineInputBorder()),
          ),
        const SizedBox(height: 16),
        Pick<String>(
          label: 'Rekening / dompet',
          value: accountId,
          items: {for (final a in store.accounts) a.id: a.name},
          onChanged: (v) => setState(() => accountId = v),
        ),
        const SizedBox(height: 16),
        DateField(label: 'Tanggal', value: date, onChanged: (d) => setState(() => date = d ?? date)),
        const SizedBox(height: 16),
        TextField(
          controller: note,
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
