import 'package:flutter/material.dart';
import '../common.dart';
import '../models.dart';
import '../store.dart';

// ======================= TARGET KEUANGAN =======================
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  Future<void> _edit(BuildContext context, [Goal? g]) async {
    final r = await askForm(context, g == null ? 'Target baru' : 'Ubah target', [
      F('name', 'Nama target', init: g?.name),
      F('target', 'Jumlah target', kind: FK.money, init: g?.target.round().toString()),
      F('saved', 'Sudah terkumpul', kind: FK.money, required: false, init: g?.saved.round().toString()),
      F('deadline', 'Tenggat (opsional)', kind: FK.date, required: false, date: g?.deadline),
    ]);
    if (r == null) return;
    store.saveGoal(Goal(
      id: g?.id ?? newId(),
      name: r['name'] as String,
      target: r['target'] as double,
      saved: r['saved'] as double,
      deadline: r['deadline'] as DateTime?,
    ));
  }

  Future<void> _move(BuildContext context, Goal g, bool deposit) async {
    final r = await askForm(context, deposit ? 'Setor tabungan' : 'Tarik dana', [
      F('amount', 'Jumlah', kind: FK.money),
    ], ok: deposit ? 'Setor' : 'Tarik');
    if (r == null) return;
    final a = r['amount'] as double;
    g.saved = deposit ? g.saved + a : (g.saved - a < 0 ? 0 : g.saved - a);
    store.saveGoal(g);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Target keuangan')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Target'),
        ),
        body: Observe((context) {
          if (store.goals.isEmpty) {
            return const EmptyState(Icons.flag_outlined, 'Belum ada target.\nBuat target tabungan dan pantau progresnya.');
          }
          final now = DateTime.now();
          return ListView(padding: const EdgeInsets.only(top: 8, bottom: 100), children: [
            for (final g in store.goals)
              Panel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                      PopupMenuButton<int>(
                        onSelected: (v) async {
                          if (v == 0) {
                            _edit(context, g);
                          } else if (v == 1) {
                            _move(context, g, false);
                          } else if (await confirm(context, 'Hapus target?', '"${g.name}" akan dihapus.')) {
                            store.deleteGoal(g.id);
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 0, child: Text('Ubah')),
                          PopupMenuItem(value: 1, child: Text('Tarik dana')),
                          PopupMenuItem(value: 2, child: Text('Hapus')),
                        ],
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: LinearProgressIndicator(
                        value: g.target > 0 ? (g.saved / g.target).clamp(0.0, 1.0) : 0,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: brand,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${rp(g.saved)} dari ${rp(g.target)} (${g.target > 0 ? (g.saved / g.target * 100).round() : 0}%)'),
                    if (g.deadline != null && g.saved < g.target)
                      Builder(builder: (ctx) {
                        final months = (g.deadline!.year - now.year) * 12 + g.deadline!.month - now.month;
                        final need = (g.target - g.saved) / (months < 1 ? 1 : months);
                        return Text(
                          'Tenggat ${dateFmt.format(g.deadline!)} • perlu ${rp(need)}/bulan',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        );
                      }),
                    if (g.saved >= g.target)
                      const Text('Target tercapai 🎉', style: TextStyle(color: brand, fontWeight: FontWeight.w700)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _move(context, g, true),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Setor'),
                      ),
                    ),
                  ]),
                ),
              ),
          ]);
        }),
      );
}

// ======================= TRANSAKSI BERULANG =======================
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  Future<void> _edit(BuildContext context, [Recurring? r0]) async {
    final catOptions = <String, String>{
      for (final c in store.catsOf(false)) c.id: 'Pengeluaran · ${c.name}',
      for (final c in store.catsOf(true)) c.id: 'Pemasukan · ${c.name}',
    };
    final r = await askForm(context, r0 == null ? 'Transaksi berulang baru' : 'Ubah transaksi berulang', [
      F('title', 'Nama (mis. Listrik, Gaji)', init: r0?.title),
      F('amount', 'Jumlah', kind: FK.money, init: r0?.amount.round().toString()),
      F('cat', 'Kategori', kind: FK.choice, options: catOptions, init: r0?.categoryId),
      F('acc', 'Rekening', kind: FK.choice, options: {for (final a in store.accounts) a.id: a.name}, init: r0?.accountId),
      F('freq', 'Pengulangan', kind: FK.choice, options: freqLabels, init: r0?.freq ?? 'monthly'),
      F('next', 'Tanggal berikutnya', kind: FK.date, date: r0?.next ?? dayOnly(DateTime.now())),
    ]);
    if (r == null) return;
    final cat = store.cat(r['cat'] as String);
    final next = r['next'] as DateTime;
    final n = store.saveRecurring(Recurring(
      id: r0?.id ?? newId(),
      title: r['title'] as String,
      income: cat?.income ?? false,
      amount: r['amount'] as double,
      categoryId: r['cat'] as String,
      accountId: r['acc'] as String,
      freq: r['freq'] as String,
      next: next,
      day: next.day,
      active: r0?.active ?? true,
    ));
    if (n > 0 && context.mounted) snack(context, '$n transaksi dibuat otomatis untuk tanggal yang sudah lewat.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Transaksi berulang')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Berulang'),
        ),
        body: Observe((context) {
          if (store.recurring.isEmpty) {
            return const EmptyState(Icons.repeat, 'Belum ada transaksi berulang.\nCocok untuk gaji, listrik, internet, atau cicilan.');
          }
          return ListView(padding: const EdgeInsets.only(top: 8, bottom: 100), children: [
            for (final r in store.recurring)
              Panel(
                child: ListTile(
                  leading: CatAvatar(store.catOrFallback(r.categoryId, r.income)),
                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r.income ? '+' : '−'}${rp(r.amount)} • ${freqLabels[r.freq] ?? ''}\nBerikutnya ${dateFmt.format(r.next)}'),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: r.active,
                      onChanged: (v) {
                        r.active = v;
                        store.saveRecurring(r);
                      },
                    ),
                    RowMenu(
                      onEdit: () => _edit(context, r),
                      onDelete: () async {
                        if (await confirm(context, 'Hapus "${r.title}"?', 'Transaksi yang sudah tercatat tidak ikut terhapus.')) {
                          store.deleteRecurring(r.id);
                        }
                      },
                    ),
                  ]),
                ),
              ),
          ]);
        }),
      );
}

// ======================= CATATAN =======================
class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  Future<void> _edit(BuildContext context, [Note? n]) async {
    final r = await askForm(context, n == null ? 'Catatan baru' : 'Ubah catatan', [
      F('title', 'Judul', init: n?.title),
      F('body', 'Isi catatan', kind: FK.multiline, required: false, init: n?.body),
    ]);
    if (r == null) return;
    store.saveNote(Note(id: n?.id ?? newId(), title: r['title'] as String, body: r['body'] as String, updated: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Catatan & rencana')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Catatan'),
        ),
        body: Observe((context) {
          if (store.notes.isEmpty) return const EmptyState(Icons.event_note, 'Belum ada catatan.');
          final list = [...store.notes]..sort((a, b) => b.updated.compareTo(a.updated));
          return ListView(padding: const EdgeInsets.only(top: 8, bottom: 100), children: [
            for (final n in list)
              Dismissible(
                key: ValueKey('note_${n.id}'),
                background: Container(color: Colors.red.shade100, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 24), child: const Icon(Icons.delete_outline)),
                secondaryBackground: Container(color: Colors.red.shade100, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.delete_outline)),
                onDismissed: (_) {
                  store.deleteNote(n.id);
                  snack(context, 'Catatan dihapus', action: 'Urungkan', onAction: () => store.saveNote(n));
                },
                child: Panel(
                  child: ListTile(
                    onTap: () => _edit(context, n),
                    title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      n.body.isEmpty ? dateFmt.format(n.updated) : '${n.body}\n${dateFmt.format(n.updated)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ]);
        }),
      );
}
