import 'package:flutter/material.dart';
import '../common.dart';
import 'categories.dart';
import 'reports.dart';
import 'settings.dart';
import 'tools.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Widget _item(BuildContext context, IconData icon, String title, String desc, Widget page) => Panel(
        child: ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          leading: CircleAvatar(backgroundColor: const Color(0xffe1f3ed), child: Icon(icon, color: brand)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(desc),
          trailing: const Icon(Icons.chevron_right),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        const Header('Lainnya', subtitle: 'Pengaturan dan alat bantu'),
        _item(context, Icons.category_outlined, 'Kategori', 'Ubah nama, ikon, dan lihat detail barang per kategori.', const CategoriesPage()),
        _item(context, Icons.bar_chart, 'Laporan', 'Grafik bulanan, kategori, dan barang terbanyak.', const ReportsPage()),
        _item(context, Icons.flag_outlined, 'Target keuangan', 'Tabungan dengan progres dan tenggat.', const GoalsPage()),
        _item(context, Icons.repeat, 'Transaksi berulang', 'Gaji, tagihan, dan cicilan otomatis.', const RecurringPage()),
        _item(context, Icons.event_note, 'Catatan & rencana', 'Simpan catatan keuangan.', const NotesPage()),
        _item(context, Icons.backup_outlined, 'Cadangan & pulihkan', 'Ekspor/impor data dan CSV.', const BackupPage()),
        _item(context, Icons.lock_outline, 'Keamanan', 'Kunci aplikasi dengan PIN.', const SecurityPage()),
        Panel(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xffe1f3ed), child: Icon(Icons.info_outline, color: brand)),
            title: const Text('Tentang', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Uangku Offline 2.0 • Rupiah (IDR) • tanpa paywall'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Uangku Offline',
              applicationVersion: '2.0.0',
              children: const [Text('Semua data tersimpan lokal di perangkat. Tidak ada akun, iklan, atau paywall.')],
            ),
          ),
        ),
      ]);
}
