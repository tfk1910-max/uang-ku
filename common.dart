import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'store.dart';

const brand = Color(0xff167d68);
const expenseColor = Color(0xffe65100);

final NumberFormat money = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final DateFormat dateFmt = DateFormat('d MMM yyyy', 'id_ID');
final DateFormat dayFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
final DateFormat monthFmt = DateFormat('MMMM yyyy', 'id_ID');
final DateFormat shortMonth = DateFormat('MMM', 'id_ID');

String rp(double v) => money.format(v);
double parseRupiah(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
String rupiahText(double v) => v <= 0 ? '' : NumberFormat.decimalPattern('id_ID').format(v.round());

/// Memformat angka rupiah saat mengetik: 85000 -> 85.000
class RupiahFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 13) digits = digits.substring(0, 13);
    final text = NumberFormat.decimalPattern('id_ID').format(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Membangun ulang UI setiap kali data berubah.
class Observe extends StatelessWidget {
  const Observe(this.builder, {super.key});
  final Widget Function(BuildContext) builder;
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: store, builder: (ctx, _) => builder(ctx));
}

class Header extends StatelessWidget {
  const Header(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: TextStyle(color: Colors.grey.shade700)),
                ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 5)});
  final Widget child;
  final Color? color;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: margin,
        color: color ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xffe3e8e6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.text, {super.key, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      );
}

class CatAvatar extends StatelessWidget {
  const CatAvatar(this.c, {super.key, this.radius = 20});
  final Category c;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: c.tint.withAlpha(40),
        child: Icon(iconOf(c.icon), color: c.tint, size: radius),
      );
}

class RowMenu extends StatelessWidget {
  const RowMenu({super.key, required this.onEdit, required this.onDelete});
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        onSelected: (v) => v == 0 ? onEdit() : onDelete(),
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: 0, child: Text('Ubah')),
          PopupMenuItem(value: 1, child: Text('Hapus')),
        ],
      );
}

class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
                context: context, initialDate: month, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d != null) onChanged(DateTime(d.year, d.month));
          },
          child: Text(monthFmt.format(month), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ]);
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (d != null) onChanged(dayOnly(d));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: clearable && value != null
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
                : const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(value == null ? 'Pilih tanggal' : dateFmt.format(value!)),
        ),
      );
}

class Pick<T> extends StatelessWidget {
  const Pick({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: items.containsKey(value) ? value : null,
            items: [
              for (final e in items.entries)
                DropdownMenuItem<T>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Hapus'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

void snack(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
  ));
}

// ---------- form dialog generik ----------
enum FK { text, multiline, money, number, pin, choice, date, check }

class F {
  const F(this.key, this.label,
      {this.kind = FK.text, this.init, this.options, this.date, this.check = false, this.required = true, this.hint});
  final String key, label;
  final FK kind;
  final String? init, hint;
  final Map<String, String>? options;
  final DateTime? date;
  final bool check, required;
}

Future<Map<String, dynamic>?> askForm(BuildContext context, String title, List<F> fields, {String ok = 'Simpan'}) =>
    showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _FormDialog(title, fields, ok));

class _FormDialog extends StatefulWidget {
  const _FormDialog(this.title, this.fields, this.ok);
  final String title, ok;
  final List<F> fields;
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final Map<String, TextEditingController> ctl = {};
  final Map<String, dynamic> vals = {};
  String? error;

  bool _isText(FK k) => k == FK.text || k == FK.multiline || k == FK.money || k == FK.number || k == FK.pin;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (_isText(f.kind)) {
        var text = f.init ?? '';
        if (f.kind == FK.money && text.isNotEmpty) text = rupiahText(double.tryParse(text) ?? 0);
        ctl[f.key] = TextEditingController(text: text);
      } else if (f.kind == FK.choice) {
        final o = f.options!;
        vals[f.key] = (f.init != null && o.containsKey(f.init)) ? f.init : o.keys.first;
      } else if (f.kind == FK.date) {
        vals[f.key] = f.date;
      } else {
        vals[f.key] = f.check;
      }
    }
  }

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.kind == FK.money) {
        final v = parseRupiah(ctl[f.key]!.text);
        if (f.required && v <= 0) return _fail('${f.label} harus lebih dari 0');
        out[f.key] = v;
      } else if (f.kind == FK.number) {
        final v = double.tryParse(ctl[f.key]!.text.trim().replaceAll(',', '.'));
        if (f.required && (v == null || v <= 0)) return _fail('${f.label} harus lebih dari 0');
        out[f.key] = v ?? 0.0;
      } else if (_isText(f.kind)) {
        final v = ctl[f.key]!.text.trim();
        if (f.required && v.isEmpty) return _fail('${f.label} wajib diisi');
        out[f.key] = v;
      } else {
        if (f.kind == FK.date && f.required && vals[f.key] == null) return _fail('${f.label} wajib diisi');
        out[f.key] = vals[f.key];
      }
    }
    Navigator.pop(context, out);
  }

  void _fail(String m) => setState(() => error = m);

  Widget _field(F f) {
    if (_isText(f.kind)) {
      final multi = f.kind == FK.multiline;
      return TextField(
        controller: ctl[f.key],
        obscureText: f.kind == FK.pin,
        keyboardType: f.kind == FK.money || f.kind == FK.pin
            ? TextInputType.number
            : f.kind == FK.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : multi
                    ? TextInputType.multiline
                    : TextInputType.text,
        inputFormatters: f.kind == FK.money
            ? [RupiahFormatter()]
            : f.kind == FK.pin
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]
                : null,
        textCapitalization:
            f.kind == FK.text || multi ? TextCapitalization.sentences : TextCapitalization.none,
        minLines: multi ? 4 : 1,
        maxLines: multi ? 8 : 1,
        decoration: InputDecoration(
          labelText: f.label,
          hintText: f.hint,
          prefixText: f.kind == FK.money ? 'Rp ' : null,
          border: const OutlineInputBorder(),
        ),
      );
    }
    if (f.kind == FK.choice) {
      return Pick<String>(
        label: f.label,
        value: vals[f.key] as String,
        items: f.options!,
        onChanged: (v) => setState(() => vals[f.key] = v),
      );
    }
    if (f.kind == FK.date) {
      return DateField(
        label: f.label,
        value: vals[f.key] as DateTime?,
        clearable: !f.required,
        onChanged: (v) => setState(() => vals[f.key] = v),
      );
    }
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(f.label),
      value: vals[f.key] == true,
      onChanged: (v) => setState(() => vals[f.key] = v),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final f in widget.fields) Padding(padding: const EdgeInsets.only(top: 10), child: _field(f)),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: _submit, child: Text(widget.ok)),
        ],
      );
}
