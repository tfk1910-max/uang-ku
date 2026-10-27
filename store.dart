import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

const expOther = 'exp_other', incOther = 'inc_other', expDebt = 'exp_debt', accCash = 'acc_cash';

final AppStore store = AppStore();

class AppStore extends ChangeNotifier {
  static const _dataKey = 'uangku_data_v2', _pinKey = 'uangku_pin_v1', _oldKey = 'uangku_txns_v1';

  bool loaded = false;
  List<Category> categories = [];
  List<Account> accounts = [];
  List<Txn> txns = [];
  List<Asset> assets = [];
  List<Debt> debts = [];
  List<Goal> goals = [];
  List<Recurring> recurring = [];
  List<Note> notes = [];
  Map<String, double> budgets = {};
  String? pinHash;
  SharedPreferences? _prefs;

  // ---------- persistence ----------
  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    pinHash = p.getString(_pinKey);
    final raw = p.getString(_dataKey);
    var ok = false;
    if (raw != null) {
      try {
        _apply(jsonDecode(raw) as Map<String, dynamic>);
        ok = true;
      } catch (_) {
        await p.setString('uangku_data_corrupt_backup', raw);
      }
    }
    if (!ok) {
      _seed();
      _migrateV1(p.getString(_oldKey));
    }
    _ensureDefaults();
    processRecurring(commit: false);
    loaded = true;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(_dataKey, jsonEncode(toJson()));
  }

  Future<void> _commit() {
    notifyListeners();
    return _save();
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'categories': categories.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'assets': assets.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'recurring': recurring.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'budgets': budgets,
      };

  void _apply(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    categories = list('categories', Category.fromJson);
    accounts = list('accounts', Account.fromJson);
    txns = list('txns', Txn.fromJson);
    assets = list('assets', Asset.fromJson);
    debts = list('debts', Debt.fromJson);
    goals = list('goals', Goal.fromJson);
    recurring = list('recurring', Recurring.fromJson);
    notes = list('notes', Note.fromJson);
    budgets = {for (final e in ((j['budgets'] as Map?) ?? const {}).entries) '${e.key}': numD(e.value)};
  }

  void _clear() {
    categories = [];
    accounts = [];
    txns = [];
    assets = [];
    debts = [];
    goals = [];
    recurring = [];
    notes = [];
    budgets = {};
  }

  void _seed() {
    _clear();
    categories = [
      Category(id: 'exp_food', name: 'Makanan & Minuman', income: false, icon: 'food', color: 0xffe65100),
      Category(id: 'exp_transport', name: 'Transportasi', income: false, icon: 'transport', color: 0xff1565c0),
      Category(id: 'exp_shop', name: 'Belanja', income: false, icon: 'shop', color: 0xff6a1b9a),
      Category(id: 'exp_bill', name: 'Tagihan', income: false, icon: 'bill', color: 0xffc62828),
      Category(id: 'exp_home', name: 'Rumah', income: false, icon: 'home', color: 0xff4e342e),
      Category(id: 'exp_health', name: 'Kesehatan', income: false, icon: 'health', color: 0xff2e7d32),
      Category(id: 'exp_edu', name: 'Pendidikan', income: false, icon: 'edu', color: 0xff00838f),
      Category(id: 'exp_fun', name: 'Hiburan', income: false, icon: 'fun', color: 0xfff9a825),
      Category(id: expDebt, name: 'Utang & Cicilan', income: false, icon: 'debt', color: 0xffc62828),
      Category(id: expOther, name: 'Lainnya', income: false, icon: 'other', color: 0xff546e7a),
      Category(id: 'inc_salary', name: 'Gaji', income: true, icon: 'salary', color: 0xff167d68),
      Category(id: 'inc_bonus', name: 'Bonus', income: true, icon: 'gift', color: 0xfff9a825),
      Category(id: 'inc_biz', name: 'Usaha', income: true, icon: 'work', color: 0xff1565c0),
      Category(id: incOther, name: 'Lainnya', income: true, icon: 'other', color: 0xff546e7a),
    ];
    accounts = [Account(id: accCash, name: 'Dompet Tunai', kind: 'tunai')];
  }

  void _ensureDefaults() {
    if (cat(expOther) == null) {
      categories.add(Category(id: expOther, name: 'Lainnya', income: false, color: 0xff546e7a));
    }
    if (cat(incOther) == null) {
      categories.add(Category(id: incOther, name: 'Lainnya', income: true, color: 0xff546e7a));
    }
    if (accounts.isEmpty) accounts.add(Account(id: accCash, name: 'Dompet Tunai', kind: 'tunai'));
    final ids = accounts.map((a) => a.id).toSet();
    for (final t in txns) {
      if (!ids.contains(t.accountId)) t.accountId = accounts.first.id;
      if (cat(t.categoryId) == null) t.categoryId = t.income ? incOther : expOther;
    }
    for (final r in recurring) {
      if (!ids.contains(r.accountId)) r.accountId = accounts.first.id;
      if (cat(r.categoryId) == null) r.categoryId = r.income ? incOther : expOther;
    }
    _sort();
  }

  void _migrateV1(String? raw) {
    if (raw == null) return;
    try {
      for (final e in jsonDecode(raw) as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final title = '${m['title'] ?? ''}';
        if (title.startsWith('Contoh:')) continue;
        final inc = m['income'] == true;
        final name = '${m['category'] ?? ''}'.toLowerCase();
        var cid = inc ? incOther : expOther;
        if (name.isNotEmpty) {
          for (final c in categories) {
            if (c.income == inc && c.name.toLowerCase().startsWith(name)) cid = c.id;
          }
        }
        txns.add(Txn(
            id: newId(), title: title, income: inc, amount: numD(m['amount']),
            date: dateOf(m['date']), categoryId: cid, accountId: accCash));
      }
    } catch (_) {}
  }

  void _sort() => txns.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });

  // ---------- queries ----------
  Category? cat(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category catOrFallback(String id, bool income) =>
      cat(id) ?? cat(income ? incOther : expOther) ?? Category(id: id, name: 'Lainnya', income: income);

  Account? acc(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<Category> catsOf(bool income) => categories.where((c) => c.income == income).toList();
  bool isProtected(String id) => id == expOther || id == incOther;

  double balanceOf(Account a) {
    var b = a.initial;
    for (final t in txns) {
      if (t.accountId == a.id) b += t.income ? t.amount : -t.amount;
    }
    return b;
  }

  double get totalBalance => accounts.fold(0.0, (s, a) => s + balanceOf(a));
  double get totalAssets => assets.fold(0.0, (s, a) => s + a.value);
  double get totalDebt => debts.where((d) => !d.receivable).fold(0.0, (s, d) => s + d.remaining);
  double get totalReceivable => debts.where((d) => d.receivable).fold(0.0, (s, d) => s + d.remaining);
  double get netWorth => totalBalance + totalAssets + totalReceivable - totalDebt;

  List<Txn> inMonth(DateTime m) => txns.where((t) => t.date.year == m.year && t.date.month == m.month).toList();
  static double sum(Iterable<Txn> l, bool income) =>
      l.where((t) => t.income == income).fold(0.0, (s, t) => s + t.amount);

  Map<String, double> spentByCategory(DateTime m, {bool income = false}) {
    final r = <String, double>{};
    for (final t in inMonth(m)) {
      if (t.income == income) r[t.categoryId] = (r[t.categoryId] ?? 0) + t.amount;
    }
    return r;
  }

  List<Item> suggestions(String categoryId, {int max = 10}) {
    final seen = <String>{};
    final out = <Item>[];
    for (final t in txns) {
      if (t.categoryId != categoryId) continue;
      for (final i in t.items) {
        final k = i.name.trim().toLowerCase();
        if (k.isNotEmpty && seen.add(k)) {
          out.add(i);
          if (out.length >= max) return out;
        }
      }
    }
    return out;
  }

  List<ItemAgg> itemTotals(Iterable<Txn> list) {
    final m = <String, ItemAgg>{};
    for (final t in list) {
      for (final i in t.items) {
        final a = m.putIfAbsent(i.name.trim().toLowerCase(), () => ItemAgg(i.name.trim()));
        a.qty += i.qty;
        a.total += i.total;
      }
    }
    return m.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  // ---------- transactions ----------
  void addTxn(Txn t) {
    txns.add(t);
    _sort();
    _commit();
  }

  void updateTxn(Txn t) {
    final i = txns.indexWhere((x) => x.id == t.id);
    if (i >= 0) txns[i] = t;
    _sort();
    _commit();
  }

  void deleteTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    _commit();
  }

  // ---------- categories ----------
  void saveCategory(Category c) {
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      categories[i] = c;
    } else {
      categories.add(c);
    }
    _commit();
  }

  void deleteCategory(String id) {
    final c = cat(id);
    if (c == null || isProtected(id)) return;
    final fb = c.income ? incOther : expOther;
    for (final t in txns) {
      if (t.categoryId == id) t.categoryId = fb;
    }
    for (final r in recurring) {
      if (r.categoryId == id) r.categoryId = fb;
    }
    budgets.remove(id);
    categories.removeWhere((x) => x.id == id);
    _commit();
  }

  int txnCount(String categoryId) => txns.where((t) => t.categoryId == categoryId).length;

  void setBudget(String categoryId, double v) {
    if (v <= 0) {
      budgets.remove(categoryId);
    } else {
      budgets[categoryId] = v;
    }
    _commit();
  }

  // ---------- accounts / assets / debts / goals / notes ----------
  void _upsert<T extends Entity>(List<T> l, T x) {
    final i = l.indexWhere((e) => e.id == x.id);
    if (i >= 0) {
      l[i] = x;
    } else {
      l.add(x);
    }
    _commit();
  }

  void _remove<T extends Entity>(List<T> l, String id) {
    l.removeWhere((e) => e.id == id);
    _commit();
  }

  void saveAccount(Account a) => _upsert(accounts, a);
  bool deleteAccount(String id) {
    if (accounts.length <= 1) return false;
    final rest = accounts.firstWhere((a) => a.id != id);
    for (final t in txns) {
      if (t.accountId == id) t.accountId = rest.id;
    }
    for (final r in recurring) {
      if (r.accountId == id) r.accountId = rest.id;
    }
    _remove(accounts, id);
    return true;
  }

  void saveAsset(Asset a) => _upsert(assets, a);
  void deleteAsset(String id) => _remove(assets, id);
  void saveDebt(Debt d) => _upsert(debts, d);
  void deleteDebt(String id) => _remove(debts, id);
  void saveGoal(Goal g) => _upsert(goals, g);
  void deleteGoal(String id) => _remove(goals, id);
  void saveNote(Note n) => _upsert(notes, n);
  void deleteNote(String id) => _remove(notes, id);
  void deleteRecurring(String id) => _remove(recurring, id);

  void payDebt(Debt d, double amount, {required bool record, required String accountId}) {
    final pay = amount > d.remaining ? d.remaining : amount;
    d.paid += pay;
    if (record && pay > 0) {
      txns.add(Txn(
        id: newId(),
        title: d.receivable ? 'Terima piutang: ${d.name}' : 'Bayar utang: ${d.name}',
        income: d.receivable,
        amount: pay,
        date: dayOnly(DateTime.now()),
        categoryId: d.receivable ? incOther : (cat(expDebt) != null ? expDebt : expOther),
        accountId: acc(accountId) != null ? accountId : accounts.first.id,
      ));
      _sort();
    }
    _commit();
  }

  // ---------- recurring ----------
  int saveRecurring(Recurring r) {
    final i = recurring.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      recurring[i] = r;
    } else {
      recurring.add(r);
    }
    final n = processRecurring(commit: false);
    _commit();
    return n;
  }

  int processRecurring({bool commit = true}) {
    final today = dayOnly(DateTime.now());
    var n = 0;
    for (final r in recurring) {
      if (!r.active) continue;
      var guard = 0;
      while (!r.next.isAfter(today) && guard++ < 400) {
        txns.add(Txn(
          id: newId(), title: r.title, income: r.income, amount: r.amount, date: r.next,
          categoryId: r.categoryId, accountId: acc(r.accountId) != null ? r.accountId : accounts.first.id,
          note: 'Transaksi berulang',
        ));
        r.next = r.advance(r.next);
        n++;
      }
    }
    if (n > 0) {
      _sort();
      if (commit) _commit();
    }
    return n;
  }

  // ---------- PIN ----------
  bool get hasPin => pinHash != null;
  String _hash(String pin) => sha256.convert(utf8.encode('uangku::$pin')).toString();
  bool checkPin(String pin) => pinHash != null && pinHash == _hash(pin);

  Future<void> setPin(String? pin) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    if (pin == null) {
      pinHash = null;
      await p.remove(_pinKey);
    } else {
      pinHash = _hash(pin);
      await p.setString(_pinKey, pinHash!);
    }
    notifyListeners();
  }

  // ---------- backup ----------
  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  bool importJson(String s) {
    final snapshot = jsonEncode(toJson());
    try {
      final j = jsonDecode(s);
      if (j is! Map<String, dynamic> || j['v'] == null) return false;
      _apply(j);
      _ensureDefaults();
      _commit();
      return true;
    } catch (_) {
      _apply(jsonDecode(snapshot) as Map<String, dynamic>);
      return false;
    }
  }

  String exportCsv() {
    String q(String s) {
      var v = s;
      if (RegExp(r'^[=+\-@]').hasMatch(v)) v = "'$v";
      return '"${v.replaceAll('"', '""')}"';
    }

    final f = DateFormat('yyyy-MM-dd');
    final b = StringBuffer('Tanggal,Jenis,Kategori,Judul,Rekening,Jumlah,Barang,Catatan\n');
    for (final t in txns.reversed) {
      b.writeln([
        f.format(t.date),
        t.income ? 'Pemasukan' : 'Pengeluaran',
        q(catOrFallback(t.categoryId, t.income).name),
        q(t.title),
        q(acc(t.accountId)?.name ?? ''),
        t.amount.round(),
        q(t.items.map((i) => '${i.name} x${fmtQty(i.qty)} @${i.price.round()}').join('; ')),
        q(t.note),
      ].join(','));
    }
    return b.toString();
  }

  Future<void> resetAll() async {
    _seed();
    await _commit();
  }
}
