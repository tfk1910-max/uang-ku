import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common.dart';
import '../store.dart';

// ======================= CADANGAN =======================
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  Widget _tile(IconData icon, String title, String desc, VoidCallback onTap, {Color? color}) => Panel(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: (color ?? brand).withAlpha(30),
            child: Icon(icon, color: color ?? brand),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(desc),
          isThreeLine: true,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cadangan & pulihkan')),
        body: Observe((context) => ListView(padding: const EdgeInsets.only(top: 8, bottom: 40), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Data: ${store.txns.length} transaksi • ${store.categories.length} kategori • '
                  '${store.accounts.length} rekening • ${store.debts.length} utang/piutang • ${store.goals.length} target.\n'
                  'Semua data hanya tersimpan di perangkat ini. Jika aplikasi dihapus, data ikut hilang — buat cadangan secara berkala.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              _tile(Icons.upload_file, 'Salin cadangan data',
                  'Menyalin seluruh data (JSON) ke clipboard. Tempel dan simpan di catatan, email, atau chat ke diri sendiri.', () async {
                await Clipboard.setData(ClipboardData(text: store.exportJson()));
                if (context.mounted) snack(context, 'Cadangan disalin ke clipboard.');
              }),
              _tile(Icons.download, 'Pulihkan dari clipboard',
                  'Salin teks cadangan lebih dulu, lalu ketuk ini. Data saat ini akan diganti.', () async {
                final d = await Clipboard.getData(Clipboard.kTextPlain);
                final text = d?.text ?? '';
                if (!context.mounted) return;
                if (text.trim().isEmpty) {
                  snack(context, 'Clipboard kosong. Salin teks cadangan dulu.');
                  return;
                }
                final ok = await confirm(context, 'Ganti semua data?', 'Data saat ini akan diganti dengan isi cadangan.', ok: 'Pulihkan');
                if (!ok) return;
                final done = store.importJson(text);
                if (context.mounted) snack(context, done ? 'Data berhasil dipulihkan.' : 'Teks di clipboard bukan cadangan Uangku yang valid.');
              }),
              _tile(Icons.table_chart_outlined, 'Salin transaksi (CSV)', 'Untuk dibuka di Excel / Google Sheets.', () async {
                await Clipboard.setData(ClipboardData(text: store.exportCsv()));
                if (context.mounted) snack(context, 'CSV disalin ke clipboard.');
              }),
              _tile(Icons.delete_forever_outlined, 'Hapus semua data', 'Mengembalikan aplikasi ke kondisi awal.', () async {
                final r = await askForm(context, 'Hapus semua data?', [
                  F('c', 'Ketik HAPUS untuk konfirmasi'),
                ], ok: 'Hapus');
                if (r == null) return;
                if ((r['c'] as String).toUpperCase() != 'HAPUS') {
                  if (context.mounted) snack(context, 'Konfirmasi tidak cocok. Data tidak dihapus.');
                  return;
                }
                await store.resetAll();
                if (context.mounted) snack(context, 'Semua data dihapus.');
              }, color: Colors.red.shade700),
            ])),
      );
}

// ======================= KEAMANAN (PIN) =======================
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  Future<void> _set(BuildContext context) async {
    final r = await askForm(context, store.hasPin ? 'PIN baru' : 'Buat PIN', [
      F('p1', 'PIN (4–6 angka)', kind: FK.pin),
      F('p2', 'Ulangi PIN', kind: FK.pin),
    ]);
    if (r == null || !context.mounted) return;
    final p1 = r['p1'] as String;
    if (p1.length < 4) return snack(context, 'PIN minimal 4 angka.');
    if (p1 != r['p2']) return snack(context, 'PIN tidak sama.');
    await store.setPin(p1);
    if (context.mounted) snack(context, 'PIN aktif. Aplikasi akan terkunci saat ditutup.');
  }

  Future<bool> _verify(BuildContext context) async {
    final r = await askForm(context, 'Masukkan PIN saat ini', [F('p', 'PIN', kind: FK.pin)], ok: 'Lanjut');
    if (r == null) return false;
    if (store.checkPin(r['p'] as String)) return true;
    if (context.mounted) snack(context, 'PIN salah.');
    return false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keamanan')),
        body: Observe((context) => ListView(padding: const EdgeInsets.only(top: 8), children: [
              Panel(
                child: ListTile(
                  leading: Icon(store.hasPin ? Icons.lock : Icons.lock_open, color: brand),
                  title: Text(store.hasPin ? 'Kunci PIN aktif' : 'Kunci PIN nonaktif', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Aplikasi meminta PIN setiap dibuka kembali. PIN tidak dapat dipulihkan jika lupa; menghapus data aplikasi akan mereset kunci.'),
                  isThreeLine: true,
                ),
              ),
              if (!store.hasPin)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(onPressed: () => _set(context), icon: const Icon(Icons.lock), label: const Text('Aktifkan PIN')),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      if (await _verify(context) && context.mounted) await _set(context);
                    },
                    icon: const Icon(Icons.password),
                    label: const Text('Ubah PIN'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (await _verify(context)) {
                        await store.setPin(null);
                        if (context.mounted) snack(context, 'PIN dinonaktifkan.');
                      }
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Matikan PIN'),
                  ),
                ),
              ],
            ])),
      );
}

// ======================= LAYAR KUNCI =======================
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String pin = '';
  bool bad = false;

  void _tap(String d) {
    if (pin.length >= 6) return;
    final next = pin + d;
    if (next.length >= 4 && store.checkPin(next)) {
      widget.onUnlock();
      return;
    }
    setState(() {
      if (next.length == 6) {
        pin = '';
        bad = true;
      } else {
        pin = next;
        bad = false;
      }
    });
  }

  Widget _key(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
            ),
            onPressed: onTap,
            child: Text(label, style: const TextStyle(fontSize: 26)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0f5a4c),
        body: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            const Text('Uangku terkunci', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(bad ? 'PIN salah, coba lagi' : 'Masukkan PIN', style: TextStyle(color: bad ? Colors.orangeAccent : Colors.white70)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 6; i++)
                Container(
                  margin: const EdgeInsets.all(5),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? Colors.white : Colors.white24),
                ),
            ]),
            const SizedBox(height: 24),
            for (final row in const ['123', '456', '789'])
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final ch in row.split('')) _key(ch, () => _tap(ch)),
              ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 88),
              _key('0', () => _tap('0')),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: IconButton(
                    onPressed: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)),
                    icon: const Icon(Icons.backspace_outlined, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      );
}
