import 'package:flutter/material.dart';

int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
double numD(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0.0);
DateTime dateOf(dynamic v) => DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
DateTime? dateOrNull(dynamic v) => v == null ? null : DateTime.tryParse('$v');
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
String fmtQty(double q) => q == q.roundToDouble() ? q.round().toString() : q.toString().replaceAll('.', ',');

DateTime addMonths(DateTime d, int n, int anchorDay) {
  final first = DateTime(d.year, d.month + n, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, anchorDay > last ? last : anchorDay);
}

const Map<String, IconData> iconChoices = {
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe,
  'transport': Icons.directions_car,
  'shop': Icons.shopping_bag,
  'bill': Icons.receipt_long,
  'home': Icons.home,
  'health': Icons.favorite,
  'edu': Icons.school,
  'fun': Icons.sports_esports,
  'gift': Icons.card_giftcard,
  'salary': Icons.payments,
  'work': Icons.work,
  'saving': Icons.savings,
  'phone': Icons.phone_android,
  'pet': Icons.pets,
  'travel': Icons.flight,
  'debt': Icons.credit_card,
  'other': Icons.category,
};
IconData iconOf(String k) => iconChoices[k] ?? Icons.category;

const List<int> colorChoices = [
  0xff167d68, 0xffe65100, 0xff1565c0, 0xff6a1b9a, 0xffc62828,
  0xff2e7d32, 0xfff9a825, 0xff00838f, 0xff4e342e, 0xff546e7a,
];

const Map<String, String> accountKinds = {'tunai': 'Tunai', 'bank': 'Rekening bank', 'ewallet': 'Dompet digital'};
const Map<String, String> assetKinds = {
  'tabungan': 'Tabungan / deposito',
  'investasi': 'Investasi',
  'kendaraan': 'Kendaraan',
  'properti': 'Properti',
  'lainnya': 'Lainnya',
};
const Map<String, String> freqLabels = {'weekly': 'Mingguan', 'monthly': 'Bulanan', 'yearly': 'Tahunan'};
IconData accountIcon(String k) =>
    k == 'bank' ? Icons.account_balance : (k == 'ewallet' ? Icons.phone_android : Icons.payments);

abstract class Entity {
  Entity({required this.id});
  String id;
}

class Category extends Entity {
  Category({required super.id, required this.name, required this.income, this.icon = 'other', this.color = 0xff167d68});
  String name, icon;
  bool income;
  int color;
  Color get tint => Color(color);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'income': income, 'icon': icon, 'color': color};
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        income: j['income'] == true,
        icon: '${j['icon'] ?? 'other'}',
        color: (j['color'] as num?)?.toInt() ?? 0xff167d68,
      );
}

class Item {
  Item({required this.name, this.qty = 1, this.price = 0});
  String name;
  double qty, price;
  double get total => qty * price;
  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'price': price};
  factory Item.fromJson(Map<String, dynamic> j) =>
      Item(name: '${j['name'] ?? ''}', qty: numD(j['qty']), price: numD(j['price']));
}

class Txn extends Entity {
  Txn({
    required super.id,
    required this.title,
    required this.income,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.accountId,
    this.note = '',
    List<Item>? items,
  }) : items = items ?? [];
  String title, categoryId, accountId, note;
  bool income;
  double amount;
  DateTime date;
  List<Item> items;
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'income': income, 'amount': amount, 'date': date.toIso8601String(),
        'categoryId': categoryId, 'accountId': accountId, 'note': note,
        'items': items.map((e) => e.toJson()).toList(),
      };
  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        income: j['income'] == true,
        amount: numD(j['amount']),
        date: dateOf(j['date']),
        categoryId: '${j['categoryId']}',
        accountId: '${j['accountId']}',
        note: '${j['note'] ?? ''}',
        items: ((j['items'] as List?) ?? const []).map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class Account extends Entity {
  Account({required super.id, required this.name, required this.kind, this.initial = 0});
  String name, kind;
  double initial;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'initial': initial};
  factory Account.fromJson(Map<String, dynamic> j) =>
      Account(id: '${j['id']}', name: '${j['name'] ?? ''}', kind: '${j['kind'] ?? 'tunai'}', initial: numD(j['initial']));
}

class Asset extends Entity {
  Asset({required super.id, required this.name, required this.kind, required this.value});
  String name, kind;
  double value;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'value': value};
  factory Asset.fromJson(Map<String, dynamic> j) =>
      Asset(id: '${j['id']}', name: '${j['name'] ?? ''}', kind: '${j['kind'] ?? 'lainnya'}', value: numD(j['value']));
}

class Debt extends Entity {
  Debt({required super.id, required this.name, required this.receivable, required this.total, this.paid = 0, this.due, this.note = ''});
  String name, note;
  bool receivable; // true = piutang (orang lain berutang kepada saya)
  double total, paid;
  DateTime? due;
  double get remaining => total - paid < 0 ? 0 : total - paid;
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'receivable': receivable, 'total': total, 'paid': paid,
        'due': due?.toIso8601String(), 'note': note,
      };
  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: '${j['id']}', name: '${j['name'] ?? ''}', receivable: j['receivable'] == true,
        total: numD(j['total']), paid: numD(j['paid']), due: dateOrNull(j['due']), note: '${j['note'] ?? ''}',
      );
}

class Goal extends Entity {
  Goal({required super.id, required this.name, required this.target, this.saved = 0, this.deadline});
  String name;
  double target, saved;
  DateTime? deadline;
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'target': target, 'saved': saved, 'deadline': deadline?.toIso8601String()};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: '${j['id']}', name: '${j['name'] ?? ''}', target: numD(j['target']),
        saved: numD(j['saved']), deadline: dateOrNull(j['deadline']),
      );
}

class Recurring extends Entity {
  Recurring({
    required super.id, required this.title, required this.income, required this.amount,
    required this.categoryId, required this.accountId, required this.freq, required this.next,
    required this.day, this.active = true,
  });
  String title, categoryId, accountId, freq;
  bool income, active;
  double amount;
  DateTime next;
  int day;
  DateTime advance(DateTime d) {
    if (freq == 'weekly') return DateTime(d.year, d.month, d.day + 7);
    if (freq == 'yearly') return addMonths(d, 12, day);
    return addMonths(d, 1, day);
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'income': income, 'amount': amount, 'categoryId': categoryId,
        'accountId': accountId, 'freq': freq, 'next': next.toIso8601String(), 'day': day, 'active': active,
      };
  factory Recurring.fromJson(Map<String, dynamic> j) {
    final n = dateOf(j['next']);
    return Recurring(
      id: '${j['id']}', title: '${j['title'] ?? ''}', income: j['income'] == true, amount: numD(j['amount']),
      categoryId: '${j['categoryId']}', accountId: '${j['accountId']}', freq: '${j['freq'] ?? 'monthly'}',
      next: n, day: (j['day'] as num?)?.toInt() ?? n.day, active: j['active'] != false,
    );
  }
}

class Note extends Entity {
  Note({required super.id, required this.title, required this.body, required this.updated});
  String title, body;
  DateTime updated;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'updated': updated.toIso8601String()};
  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: '${j['id']}', title: '${j['title'] ?? ''}', body: '${j['body'] ?? ''}', updated: dateOf(j['updated']),
      );
}

class ItemAgg {
  ItemAgg(this.name);
  final String name;
  double qty = 0, total = 0;
}
