import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  Widget _addBtn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: FilledButton.tonalIcon(onPressed: onTap, icon: const Icon(Icons.add), label: Text(label)),
      );

  // ---------- rekening ----------
  Future<void> _editAccount(BuildContext context, [Account? a]) async {
    final r = await askForm(context, a == null ? 'Rekening / dompet baru' : 'Ubah rekening', [
      F('name', 'Nama', init: a?.name),
      F('kind', 'Jenis', kind: FK.choice, options: accountKinds, init: a?.kind),
      F('initial', 'Saldo awal', kind: FK.money, required: false, init: a?.initial.round().toString()),
    ]);
    if (r == null) return;
    store.saveAccount(Account(
      id: a?.id ?? newId(),
      name: r['name'] as String,
      kind: r['kind'] as String,
      initial: r['initial'] as double,
    ));
  }

  Future<void> _deleteAccount(BuildContext context, Account a) async {
    if (store.accounts.length <= 1) {
      snack(context, 'Minimal harus ada satu rekening/dompet.');
      return;
    }
    final ok = await confirm(context, 'Hapus "${a.name}"?', 'Transaksi di rekening ini dipindahkan ke rekening lain.');
    if (ok) store.deleteAccount(a.id);
  }

  // ---------- aset ----------
  Future<void> _editAsset(BuildContext context, [Asset? a]) async {
    final r = await askForm(context, a == null ? 'Aset baru' : 'Ubah aset', [
      F('name', 'Nama aset', init: a?.name),
      F('kind', 'Jenis', kind: FK.choice, options: assetKinds, init: a?.kind),
      F('value', 'Nilai saat ini', kind: FK.money, init: a?.value.round().toString()),
    ]);
    if (r == null) return;
    store.saveAsset(Asset(id: a?.id ?? newId(), name: r['name'] as String, kind: r['kind'] as String, value: r['value'] as double));
  }

  // ---------- utang ----------
  Future<void> _editDebt(BuildContext context, [Debt? d]) async {
    final r = await askForm(context, d == null ? 'Utang / piutang baru' : 'Ubah data', [
      F('name', 'Nama / pihak terkait', init: d?.name),
      F('type', 'Jenis', kind: FK.choice, init: d == null ? 'utang' : (d.receivable ? 'piutang' : 'utang'),
          options: const {'utang': 'Utang (saya berutang)', 'piutang': 'Piutang (orang lain berutang)'}),
      F('total', 'Jumlah total', kind: FK.money, init: d?.total.round().toString()),
      F('paid', 'Sudah dibayar', kind: FK.money, required: false, init: d?.paid.round().toString()),
      F('due', 'Jatuh tempo', kind: FK.date, required: false, date: d?.due),
      F('note', 'Catatan', kind: FK.text, required: false, init: d?.note),
    ]);
    if (r == null) return;
    store.saveDebt(Debt(
      id: d?.id ?? newId(),
      name: r['name'] as String,
      receivable: r['type'] == 'piutang',
      total: r['total'] as double,
      paid: r['paid'] as double,
      due: r['due'] as DateTime?,
      note: r['note'] as String,
    ));
  }

  Future<void> _payDebt(BuildContext context, Debt d) async {
    final r = await askForm(context, d.receivable ? 'Terima pembayaran' : 'Bayar utang', [
      F('amount', 'Jumlah', kind: FK.money, init: d.remaining.round().toString()),
      F('acc', 'Rekening', kind: FK.choice, options: {for (final a in store.accounts) a.id: a.name}),
      F('rec', 'Catat sebagai transaksi', kind: FK.check, check: true),
    ], ok: 'Proses');
    if (r == null) return;
    store.payDebt(d, r['amount'] as double, record: r['rec'] == true, accountId: r['acc'] as String);
  }

  @override
  Widget build(BuildContext context) => Observe((context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          const Header('Aset & utang', subtitle: 'Gambaran kekayaan bersihmu.'),
          Panel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('KEKAYAAN BERSIH', style: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.black54)),
                Text(rp(store.netWorth),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: store.netWorth < 0 ? Colors.red.shade700 : brand)),
                const SizedBox(height: 6),
                Text(
                  'Saldo ${rp(store.totalBalance)} • Aset ${rp(store.totalAssets)}\n'
                  'Piutang ${rp(store.totalReceivable)} • Utang ${rp(store.totalDebt)}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ]),
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Rekening'), Tab(text: 'Aset'), Tab(text: 'Utang')]),
          Expanded(
            child: TabBarView(children: [
              // Rekening
              ListView(padding: const EdgeInsets.only(bottom: 100), children: [
                _addBtn('Tambah rekening / dompet', () => _editAccount(context)),
                for (final a in store.accounts)
                  Panel(
                    child: ListTile(
                      onTap: () => _editAccount(context, a),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xffe1f3ed),
                        child: Icon(accountIcon(a.kind), color: brand),
                      ),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(accountKinds[a.kind] ?? ''),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(rp(store.balanceOf(a)), style: const TextStyle(fontWeight: FontWeight.w700)),
                        RowMenu(onEdit: () => _editAccount(context, a), onDelete: () => _deleteAccount(context, a)),
                      ]),
                    ),
                  ),
              ]),
              // Aset
              ListView(padding: const EdgeInsets.only(bottom: 100), children: [
                _addBtn('Tambah aset', () => _editAsset(context)),
                if (store.assets.isEmpty)
                  const EmptyState(Icons.savings_outlined, 'Catat tabungan, kendaraan, properti, atau investasi.'),
                for (final a in store.assets)
                  Panel(
                    child: ListTile(
                      onTap: () => _editAsset(context, a),
                      leading: const CircleAvatar(backgroundColor: Color(0xffe1f3ed), child: Icon(Icons.savings_outlined, color: brand)),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(assetKinds[a.kind] ?? ''),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(rp(a.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                        RowMenu(
                          onEdit: () => _editAsset(context, a),
                          onDelete: () async {
                            if (await confirm(context, 'Hapus "${a.name}"?', 'Aset ini dihapus dari daftar.')) store.deleteAsset(a.id);
                          },
                        ),
                      ]),
                    ),
                  ),
              ]),
              // Utang
              ListView(padding: const EdgeInsets.only(bottom: 100), children: [
                _addBtn('Tambah utang / piutang', () => _editDebt(context)),
                if (store.debts.isEmpty)
                  const EmptyState(Icons.credit_card, 'Catat utang, cicilan, atau uang yang dipinjamkan.'),
                for (final d in store.debts)
                  Panel(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text('${d.receivable ? 'Piutang' : 'Utang'} • ${d.name}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          RowMenu(
                            onEdit: () => _editDebt(context, d),
                            onDelete: () async {
                              if (await confirm(context, 'Hapus "${d.name}"?', 'Data ini dihapus.')) store.deleteDebt(d.id);
                            },
                          ),
                        ]),
                        Padding(
                          padding: const EdgeInsets.only(right: 12, top: 4),
                          child: LinearProgressIndicator(
                            value: d.total > 0 ? (d.paid / d.total).clamp(0.0, 1.0) : 0,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(4),
                            color: d.receivable ? brand : expenseColor,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Sisa ${rp(d.remaining)} dari ${rp(d.total)}'),
                        if (d.due != null) Text('Jatuh tempo ${dateFmt.format(d.due!)}', style: const TextStyle(fontSize: 12.5)),
                        if (d.note.isNotEmpty) Text(d.note, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                        if (d.remaining > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _payDebt(context, d),
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: Text(d.receivable ? 'Terima pembayaran' : 'Bayar / cicil'),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Lunas ✓', style: TextStyle(color: brand, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ));
}
