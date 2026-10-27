# Uangku Offline 2.0 — Paket Final untuk Build APK

Aplikasi pencatat keuangan pribadi berbahasa Indonesia. Data disimpan lokal di perangkat menggunakan `shared_preferences`; aplikasi tidak memerlukan akun atau koneksi internet untuk pencatatan sehari-hari.

## Fitur

- Pemasukan dan pengeluaran: tambah, edit, hapus, duplikat, pencarian, serta filter bulan/jenis.
- Kategori yang dapat diubah: nama, ikon, warna, tambah, dan hapus.
- Rincian barang per transaksi: nama barang, kuantitas, harga satuan, dan perhitungan total.
- Rekening/dompet dengan saldo otomatis.
- Aset, utang-piutang, anggaran bulanan, dan peringatan anggaran.
- Laporan 6 bulan, rincian kategori/barang, dan ekspor CSV.
- Target tabungan, transaksi berulang, catatan, serta PIN aplikasi.
- Cadangan dan pemulihan data melalui JSON.
- Migrasi data versi lama dan pencadangan data yang gagal dibaca.

## Membuat APK Android (disarankan: GitHub Actions)

Paket ini berisi kode sumber Flutter, bukan APK yang telah dikompilasi. APK harus dibuat menggunakan Flutter SDK dan Android SDK. Workflow sudah disiapkan agar proses build dilakukan otomatis di GitHub.

1. Unduh dan ekstrak ZIP ini di komputer atau HP.
2. Buat repositori baru di <https://github.com/new>.
3. Unggah **isi folder** `uangku_offline` ke repositori (termasuk folder tersembunyi `.github`). Pastikan file `pubspec.yaml` berada di root repositori.
4. Buka tab **Actions** pada repositori dan izinkan Actions bila diminta.
5. Pilih workflow **Build APK**, lalu tekan **Run workflow**.
6. Tunggu sampai workflow berstatus sukses.
7. Buka hasil run dan unduh artifact bernama **uangku-apk**.
8. Ekstrak ZIP artifact, lalu pasang `app-release.apk` pada perangkat Android.

Workflow juga berjalan otomatis saat ada push ke branch `main` atau `master`.

## Build lokal

Persyaratan: Flutter stable, Java 17, dan Android SDK. Jalankan dari root proyek:

```bash
chmod +x build_apk.sh
./build_apk.sh
```

APK akan dibuat di `build/app/outputs/flutter-apk/app-release.apk`.

## Catatan rilis

- Build standar menggunakan konfigurasi signing debug bawaan Flutter; ini cocok untuk instalasi pribadi/pengujian, bukan rilis Play Store.
- Simpan cadangan data secara berkala. Menghapus data aplikasi atau menghapus aplikasi dapat menghilangkan data lokal.
- PIN aplikasi bukan pengganti enkripsi seluruh penyimpanan perangkat.
- Kode sumber belum diklaim lolos pengujian build pada lingkungan ini; jalankan workflow dan periksa hasilnya sebelum mengandalkan aplikasi untuk pencatatan penting.
