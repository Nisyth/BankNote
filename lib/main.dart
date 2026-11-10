import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// Constantes et utilitaires
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Langue : suit la langue du téléphone (français, sinon anglais)
// ---------------------------------------------------------------------------

String appLang = 'fr';

String languageFor(Iterable<Locale>? locales) {
  for (final l in locales ?? const <Locale>[]) {
    if (l.languageCode == 'fr' || l.languageCode == 'en') return l.languageCode;
  }
  return 'en';
}

// Chaque entrée : [français, anglais]. Les {x} sont remplacés par tr().
const _tr = <String, List<String>>{
  'cancel': ['Annuler', 'Cancel'],
  'undo': ['Annuler', 'Undo'],
  'validate': ['Valider', 'Confirm'],
  'add': ['Ajouter', 'Add'],
  'delete': ['Supprimer', 'Delete'],
  'rename': ['Renommer', 'Rename'],
  'uncategorized': ['Sans catégorie', 'Uncategorized'],
  'folder_root': ['{folder} (racine du stockage)', '{folder} (storage root)'],
  'folder_chosen': ['Dossier choisi', 'Chosen folder'],
  'storage_internal': ['Stockage interne', 'Internal storage'],
  'storage_sd': ['Carte SD', 'SD card'],
  'lock_reason': ['Déverrouillez BankNote', 'Unlock BankNote'],
  'locked_title': ['BankNote est verrouillé', 'BankNote is locked'],
  'unlock': ['Déverrouiller', 'Unlock'],
  'cat_exists': ['Cette catégorie existe déjà', 'This category already exists'],
  'welcome_title': ['Bienvenue sur BankNote !', 'Welcome to BankNote!'],
  'welcome_body': [
    'Enregistrez vos dépenses, organisez votre budget, visualisez vos habitudes.',
    'Record your expenses, organize your budget, visualize your habits.',
  ],
  'welcome_start': ['Commencer', 'Get started'],
  'setup_title': ['Vos catégories', 'Your categories'],
  'setup_intro': [
    'Choisissez les catégories avec lesquelles classer vos dépenses (au moins '
        'une). Vous pourrez les modifier ou les supprimer plus tard dans les '
        'Réglages.',
    'Choose the categories you want to sort your expenses into (at least one). '
        'You can edit or delete them later in Settings.',
  ],
  'cat_name_label': ['Nom de la catégorie', 'Category name'],
  'no_cat_yet': ['Aucune catégorie pour le moment.', 'No categories yet.'],
  'continue': ['Continuer', 'Continue'],
  'storage_title': ['Autoriser la sauvegarde', 'Allow backups'],
  'storage_body': [
    'Pour écrire dans le dossier « {folder} » à la racine du stockage, '
        'Android demande l’accès à tous les fichiers.\n\n'
        'Vous pouvez aussi choisir un dossier manuellement, sans cette '
        'autorisation.',
    'To write to the “{folder}” folder at the root of your storage, Android '
        'requires access to all files.\n\n'
        'You can also pick a folder manually, without this permission.',
  ],
  'later': ['Plus tard', 'Later'],
  'choose_folder': ['Choisir un dossier', 'Choose a folder'],
  'allow': ['Autoriser', 'Allow'],
  'err_settings': [
    'Impossible d’ouvrir les réglages Android.',
    'Could not open Android settings.',
  ],
  'bk_saved': ['Sauvegarde créée dans {folder}.', 'Backup saved to {folder}.'],
  'bk_unchanged': [
    'Rien de nouveau depuis la dernière sauvegarde.',
    'Nothing new since the last backup.',
  ],
  'bk_unsupported': [
    'Sauvegarde disponible uniquement sur Android.',
    'Backups are only available on Android.',
  ],
  'bk_failed': [
    'Échec de la sauvegarde dans {folder}. Choisissez à nouveau le dossier '
        'si le problème persiste.',
    'Backup to {folder} failed. Pick the folder again if the problem persists.',
  ],
  'err_pick_folder': [
    'Impossible de choisir ce dossier.',
    'Could not select this folder.',
  ],
  'new_category': ['Nouvelle catégorie', 'New category'],
  'rename_category': ['Renommer la catégorie', 'Rename category'],
  'cat_taken': [
    'Une catégorie porte déjà ce nom.',
    'A category with this name already exists.',
  ],
  'keep_one': [
    'Il faut garder au moins une catégorie.',
    'You must keep at least one category.',
  ],
  'delete_cat_title': ['Supprimer « {cat} » ?', 'Delete “{cat}”?'],
  'cat_used.one': [
    '{n} dépense utilise cette catégorie. Dans quelle catégorie la déplacer ?',
    '{n} expense uses this category. Which category should it be moved to?',
  ],
  'cat_used.other': [
    '{n} dépenses utilisent cette catégorie. Dans quelle catégorie les '
        'déplacer ?',
    '{n} expenses use this category. Which category should they be moved to?',
  ],
  'no_expense': ['Aucune dépense', 'No expenses'],
  'expenses_count.one': ['{n} dépense', '{n} expense'],
  'expenses_count.other': ['{n} dépenses', '{n} expenses'],
  'err_read': ['Impossible de lire ce fichier.', 'Could not read this file.'],
  'import_done': ['Import terminé', 'Import complete'],
  'imp_done.one': ['{n} dépense importée', '{n} expense imported'],
  'imp_done.other': ['{n} dépenses importées', '{n} expenses imported'],
  'imp_dup.one': ['{n} doublon ignoré', '{n} duplicate skipped'],
  'imp_dup.other': ['{n} doublons ignorés', '{n} duplicates skipped'],
  'imp_bad.one': ['{n} ligne illisible', '{n} unreadable row'],
  'imp_bad.other': ['{n} lignes illisibles', '{n} unreadable rows'],
  'imp_cats.one': ['{n} nouvelle catégorie ajoutée', '{n} new category added'],
  'imp_cats.other': [
    '{n} nouvelles catégories ajoutées',
    '{n} new categories added',
  ],
  'none_to_export': ['Aucune dépense à exporter.', 'No expenses to export.'],
  'save_dialog': ['Enregistrer la sauvegarde', 'Save backup'],
  'backup_saved': ['Sauvegarde enregistrée.', 'Backup saved.'],
  'today': ['Aujourd’hui', 'Today'],
  'vs_prev': [
    '{amount} ({pct} %) vs mois précédent',
    '{amount} ({pct}%) vs previous month',
  ],
  'month_total': ['Total du mois', 'Month total'],
  'by_category': ['Par catégorie', 'By category'],
  'filter_hint': [
    'Touchez une catégorie pour filtrer les dépenses, touchez-la à nouveau '
        'pour tout réafficher.',
    'Tap a category to filter the expenses, tap it again to show everything.',
  ],
  'expenses_month': ['Dépenses du mois', 'Expenses this month'],
  'expenses_filtered': ['Dépenses · {cat}', 'Expenses · {cat}'],
  'show_all': ['Tout afficher', 'Show all'],
  'none_month': ['Aucune dépense ce mois-ci.', 'No expenses this month.'],
  'none_month_cat': [
    'Aucune dépense dans « {cat} » ce mois-ci.',
    'No expenses in “{cat}” this month.',
  ],
  'expense_deleted': ['Dépense supprimée', 'Expense deleted'],
  'per_month': ['{amount}/mois', '{amount}/month'],
  'avg_title': [
    'Moyenne mensuelle (toutes catégories)',
    'Monthly average (all categories)',
  ],
  'none_year': ['Aucune dépense en {year}.', 'No expenses in {year}.'],
  'per_month_suffix': [' par mois', ' per month'],
  'year_summary.one': [
    'En {year} : {total} sur {n} mois',
    'In {year}: {total} over {n} month',
  ],
  'year_summary.other': [
    'En {year} : {total} sur {n} mois',
    'In {year}: {total} over {n} months',
  ],
  'incl_current': [' (mois en cours inclus)', ' (current month included)'],
  'breakdown': ['Répartition par catégorie', 'Breakdown by category'],
  'none_period': [
    'Aucune dépense sur cette période.',
    'No expenses in this period.',
  ],
  'total': ['Total', 'Total'],
  'avg_over.one': [
    'Moyenne mensuelle calculée sur {n} mois',
    'Monthly average computed over {n} month',
  ],
  'avg_over.other': [
    'Moyenne mensuelle calculée sur {n} mois',
    'Monthly average computed over {n} months',
  ],
  'no_chart_data': ['Aucune donnée à afficher.', 'No data to display.'],
  'current_year': ['{year} (en cours)', '{year} (current)'],
  'year_title': ['Année {year}', 'Year {year}'],
  'all_years': [
    'Toutes les années ({a} – {b})',
    'All years ({a} – {b})',
  ],
  'year_total': ['Total de l’année : {amount}', 'Year total: {amount}'],
  'lock_setup_first': [
    'Configurez d’abord un verrouillage d’écran (empreinte, code ou schéma) '
        'dans les paramètres du téléphone.',
    'First set up a screen lock (fingerprint, PIN or pattern) in your phone '
        'settings.',
  ],
  'lock_confirm_on': [
    'Confirmez pour activer le verrouillage',
    'Confirm to enable the lock',
  ],
  'lock_confirm_off': [
    'Confirmez pour désactiver le verrouillage',
    'Confirm to disable the lock',
  ],
  'auth_failed': [
    'Authentification impossible sur cet appareil.',
    'Authentication is not possible on this device.',
  ],
  'no_data': ['Aucune donnée', 'No data'],
  'range': ['Du {a} au {b}', 'From {a} to {b}'],
  'no_backup': [
    'Aucune sauvegarde pour le moment.',
    'No backup yet.',
  ],
  'last_backup': ['Dernière : {date}', 'Last: {date}'],
  'at': ['à', 'at'],
  'appearance': ['Apparence', 'Appearance'],
  'auto': ['Auto', 'Auto'],
  'light': ['Clair', 'Light'],
  'dark': ['Sombre', 'Dark'],
  'categories': ['Catégories', 'Categories'],
  'cats_count.one': ['{n} catégorie', '{n} category'],
  'cats_count.other': ['{n} catégories', '{n} categories'],
  'add_category': ['Ajouter une catégorie', 'Add a category'],
  'security': ['Sécurité', 'Security'],
  'fp_lock': ['Verrouillage par empreinte', 'Fingerprint lock'],
  'fp_sub': [
    'Demandé à l’ouverture et après 30 s en arrière-plan. Le code du '
        'téléphone sert de secours.',
    'Required when opening the app and after 30 s in the background. Your '
        'phone’s PIN is used as a fallback.',
  ],
  'backup_data': ['Sauvegarde et données', 'Backup and data'],
  'expenses_saved.one': ['{n} dépense enregistrée', '{n} expense saved'],
  'expenses_saved.other': ['{n} dépenses enregistrées', '{n} expenses saved'],
  'auto_backup': ['Sauvegarde automatique', 'Automatic backup'],
  'auto_sub': [
    'À chaque ouverture, un CSV est écrit dans le dossier ci-dessous (les '
        '{keep} derniers sont conservés).',
    'Each time the app opens, a CSV is written to the folder below (the last '
        '{keep} are kept).',
  ],
  'backup_folder': [
    'Dossier de sauvegarde automatique',
    'Automatic backup folder',
  ],
  'default_suffix': ['{folder} (par défaut)', '{folder} (default)'],
  'reset_folder': [
    'Revenir au dossier par défaut',
    'Back to the default folder',
  ],
  'export_csv': ['Exporter en CSV', 'Export to CSV'],
  'export_sub': [
    'Choisissez vous-même l’emplacement du fichier',
    'Choose where to save the file',
  ],
  'import_csv': ['Importer un fichier CSV', 'Import a CSV file'],
  'import_sub': [
    'Colonnes : date, montant, catégorie, note',
    'Columns: date, amount, category, note',
  ],
  'tab_summary': ['Résumé', 'Summary'],
  'tab_history': ['Historique', 'History'],
  'tab_charts': ['Graphiques', 'Charts'],
  'tab_settings': ['Réglages', 'Settings'],
  'fab_expense': ['Dépense', 'Expense'],
  'delete_expense_title': [
    'Supprimer cette dépense ?',
    'Delete this expense?',
  ],
  'edit_expense': ['Modifier la dépense', 'Edit expense'],
  'new_expense': ['Nouvelle dépense', 'New expense'],
  'amount_invalid': ['Saisissez un montant valide', 'Enter a valid amount'],
  'amount': ['Montant', 'Amount'],
  'category': ['Catégorie', 'Category'],
  'new_short': ['Nouvelle', 'New'],
  'save': ['Enregistrer', 'Save'],
  'note_optional': ['Note (facultatif)', 'Note (optional)'],

  // --- Entrées d'argent et budget du mois ---
  'salary_banner': ['J’ai reçu mon salaire', 'I received my salary'],
  'dismiss': ['Masquer', 'Hide'],
  'remaining': ['Reste du mois', 'Left this month'],
  'income_short': ['Entrée', 'Income'],
  'expenses_label': ['Dépenses', 'Expenses'],
  'income_label': ['Revenus', 'Income'],
  'pct_spent': ['{pct} dépensé', '{pct} spent'],
  'over_by': ['Dépassement de {amount}', 'Over by {amount}'],
  'salary_deferred': [
    'Salaire de {amount} reçu le {date}, compté pour {month}.',
    'Salary of {amount} received on {date}, counted for {month}.',
  ],
  'movements_month': ['Mouvements du mois', 'Transactions this month'],
  'salary': ['Salaire', 'Salary'],
  'income': ['Entrée d’argent', 'Income'],
  'salary_received': ['Salaire reçu', 'Salary received'],
  'new_income': ['Nouvelle entrée d’argent', 'New income'],
  'edit_income': ['Modifier l’entrée', 'Edit income'],
  'is_salary': ['C’est mon salaire du mois', 'This is my monthly salary'],
  'when_count': [
    'À partir de quand compter ce montant ?',
    'When should this amount start counting?',
  ],
  'inc_now': ['Maintenant', 'Now'],
  'inc_now_sub': [
    'Compté pour {month} : toutes les dépenses de ce mois sont décomptées '
        'dès maintenant.',
    'Counted for {month}: all of this month’s expenses are deducted right '
        'away.',
  ],
  'inc_next': ['Au 1er {month}', 'On {month} 1'],
  'inc_next_sub': [
    'Compté pour {month} : {cur} n’est pas modifié.',
    'Counted for {month}: {cur} is left unchanged.',
  ],
  'delete_income_title': ['Supprimer cette entrée ?', 'Delete this income?'],
  'income_deleted': ['Entrée supprimée', 'Income deleted'],
  'remaining_short': ['Reste {amount}', 'Left {amount}'],
  'imp_inc.one': ['{n} entrée d’argent importée', '{n} income entry imported'],
  'imp_inc.other': [
    '{n} entrées d’argent importées',
    '{n} income entries imported',
  ],
};

String tr(String key, [Map<String, Object> args = const {}]) {
  final v = _tr[key];
  var s = v == null ? key : v[appLang == 'fr' ? 0 : 1];
  args.forEach((k, val) => s = s.replaceAll('{$k}', '$val'));
  return s;
}

/// Version avec pluriel : clés « key.one » et « key.other », {n} = [n].
String trn(String key, int n, [Map<String, Object> args = const {}]) {
  final one = appLang == 'fr' ? n < 2 : n == 1;
  return tr('$key.${one ? 'one' : 'other'}', {...args, 'n': n});
}

String pctStr(double ratio) =>
    '${(ratio * 100).toStringAsFixed(0)}${appLang == 'fr' ? ' %' : '%'}';

const chartColors = [
  Color(0xFF009688),
  Color(0xFFFF7043),
  Color(0xFF5C6BC0),
  Color(0xFFFFCA28),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
  Color(0xFF26C6DA),
  Color(0xFF8D6E63),
  Color(0xFFAB47BC),
  Color(0xFF9CCC65),
  Color(0xFF78909C),
  Color(0xFFFFA726),
];

const monthInitials = [
  'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', //
];

// Formats monétaires : recréés si la langue du téléphone change.
String _fmtLang = '';
NumberFormat? _money;
NumberFormat? _moneyShort;

void _ensureFormats() {
  if (_money != null && _fmtLang == appLang) return;
  _fmtLang = appLang;
  _money = NumberFormat.currency(locale: appLang, symbol: '€');
  _moneyShort =
      NumberFormat.currency(locale: appLang, symbol: '€', decimalDigits: 0);
}

NumberFormat get money {
  _ensureFormats();
  return _money!;
}

NumberFormat get moneyShort {
  _ensureFormats();
  return _moneyShort!;
}

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

/// Nom du mois dans la langue de l'appli (en minuscules en français).
String monthWord(DateTime m) => DateFormat('MMMM', appLang).format(m);

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _norm(String s) {
  var r = s.trim().toLowerCase();
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  for (var i = 0; i < from.length; i++) {
    r = r.replaceAll(from[i], to[i]);
  }
  return r;
}

String _expenseKey(Expense e) =>
    '${_dateKey(e.date)}|${e.amount.toStringAsFixed(2)}|${_norm(e.category)}|${e.note.trim()}';

String _incomeKey(Income i) =>
    '${_dateKey(i.date)}|${i.amount.toStringAsFixed(2)}|${i.isSalary}|${_monthKey(i.month)}|${i.note.trim()}';

int _monthSpan(DateTime first, DateTime last) =>
    math.max(1, (last.year - first.year) * 12 + last.month - first.month + 1);

double? parseAmount(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[€\s\u00A0\u202F]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

DateTime? parseDate(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.split(' ').first.split('T').first;
  final m = RegExp(r'^(\d{1,4})[/\-.](\d{1,2})[/\-.](\d{1,4})$').firstMatch(s);
  if (m == null) return null;
  final g1 = m.group(1)!;
  final n1 = int.parse(g1);
  final n2 = int.parse(m.group(2)!);
  final n3 = int.parse(m.group(3)!);
  int year;
  int month;
  int day;
  if (g1.length == 4) {
    year = n1;
    month = n2;
    day = n3;
  } else {
    day = n1;
    month = n2;
    year = n3;
    if (year < 100) year += 2000;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final dt = DateTime(year, month, day);
  if (dt.month != month) return null;
  return dt;
}

// ---------------------------------------------------------------------------
// Modèle et base de données
// ---------------------------------------------------------------------------

class Expense {
  final int? id;
  final DateTime date;
  final double amount;
  final String category;
  final String note;

  const Expense({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    this.note = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': _dateKey(date),
        'amount': amount,
        'category': category,
        'note': note,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        note: (m['note'] as String?) ?? '',
      );
}

/// Entrée d'argent (salaire ou rentrée ponctuelle).
/// [date] = jour de réception ; [month] = mois auquel l'argent est rattaché
/// (1er jour du mois). Les deux peuvent différer : un salaire reçu le 28
/// novembre peut compter pour décembre.
class Income {
  final int? id;
  final DateTime date;
  final double amount;
  final String note;
  final bool isSalary;
  final DateTime month;

  const Income({
    this.id,
    required this.date,
    required this.amount,
    this.note = '',
    this.isSalary = false,
    required this.month,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': _dateKey(date),
        'amount': amount,
        'note': note,
        'budget_month': _monthKey(month),
        'is_salary': isSalary ? 1 : 0,
      };

  factory Income.fromMap(Map<String, Object?> m) {
    final d = DateTime.parse(m['date'] as String);
    final bm = DateTime.tryParse('${m['budget_month']}-01') ??
        DateTime(d.year, d.month);
    return Income(
      id: m['id'] as int?,
      date: d,
      amount: (m['amount'] as num).toDouble(),
      note: (m['note'] as String?) ?? '',
      isSalary: ((m['is_salary'] as int?) ?? 0) == 1,
      month: DateTime(bm.year, bm.month),
    );
  }
}

class Db {
  static Database? _db;

  static Future<Database> get instance async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'depenses.db'),
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createIncomes(db);
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE expenses('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'date TEXT NOT NULL, '
          'amount REAL NOT NULL, '
          'category TEXT NOT NULL, '
          "note TEXT NOT NULL DEFAULT '')",
        );
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await _createIncomes(db);
      },
    );
  }

  /// Table des entrées d'argent. budget_month (« yyyy-MM ») est le mois de
  /// rattachement, distinct de la date de réception.
  static Future<void> _createIncomes(Database db) async {
    await db.execute(
      'CREATE TABLE incomes('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'date TEXT NOT NULL, '
      'amount REAL NOT NULL, '
      "note TEXT NOT NULL DEFAULT '', "
      'budget_month TEXT NOT NULL, '
      'is_salary INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
        'CREATE INDEX idx_incomes_month ON incomes(budget_month)');
  }

  static Future<List<Income>> allIncomes() async {
    final db = await instance;
    final rows = await db.query('incomes', orderBy: 'date DESC, id DESC');
    return rows.map(Income.fromMap).toList();
  }

  static Future<void> insertIncome(Income i) async {
    final db = await instance;
    await db.insert('incomes', i.toMap());
  }

  static Future<void> insertManyIncomes(List<Income> list) async {
    final db = await instance;
    final batch = db.batch();
    for (final i in list) {
      batch.insert('incomes', i.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateIncome(Income i) async {
    final db = await instance;
    final m = i.toMap()..remove('id');
    await db.update('incomes', m, where: 'id = ?', whereArgs: [i.id]);
  }

  static Future<void> deleteIncome(int id) async {
    final db = await instance;
    await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Expense>> all() async {
    final db = await instance;
    final rows = await db.query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  static Future<void> insert(Expense e) async {
    final db = await instance;
    await db.insert('expenses', e.toMap());
  }

  static Future<void> insertMany(List<Expense> list) async {
    final db = await instance;
    final batch = db.batch();
    for (final e in list) {
      batch.insert('expenses', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> update(Expense e) async {
    final db = await instance;
    final m = e.toMap()..remove('id');
    await db.update('expenses', m, where: 'id = ?', whereArgs: [e.id]);
  }

  static Future<void> delete(int id) async {
    final db = await instance;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Renomme une catégorie (ou déplace ses dépenses vers une autre).
  static Future<void> renameCategory(String from, String to) async {
    final db = await instance;
    await db.update('expenses', {'category': to},
        where: 'category = ?', whereArgs: [from]);
  }
}

// ---------------------------------------------------------------------------
// Import CSV
// ---------------------------------------------------------------------------

class ParsedImport {
  final List<Expense> expenses;
  final List<Income> incomes;
  final int invalid;
  const ParsedImport(this.expenses, this.invalid,
      [this.incomes = const <Income>[]]);
}

String decodeBytes(Uint8List bytes) {
  String s;
  try {
    s = utf8.decode(bytes);
  } on FormatException {
    s = latin1.decode(bytes);
  }
  if (s.startsWith('\uFEFF')) s = s.substring(1);
  return s;
}

String detectDelimiter(String line) {
  const candidates = [';', '\t', ','];
  var best = ';';
  var bestCount = -1;
  for (final c in candidates) {
    final count = c.allMatches(line).length;
    if (count > bestCount) {
      best = c;
      bestCount = count;
    }
  }
  return best;
}

List<List<String>> parseCsv(String text, String delim) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delim) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((f) => f.trim().isNotEmpty)).toList();
}

int _findColumn(List<String> header, List<String> names) {
  for (var i = 0; i < header.length; i++) {
    final h = _norm(header[i]);
    if (names.any((n) => h.contains(n))) return i;
  }
  return -1;
}

ParsedImport parseImport(Uint8List bytes) {
  final text = decodeBytes(bytes);
  final firstLine = text
      .split(RegExp(r'\r?\n'))
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final rows = parseCsv(text, detectDelimiter(firstLine));
  if (rows.isEmpty) return const ParsedImport([], 0);

  final header = rows.first;
  var dateIdx = _findColumn(header, ['date', 'jour']);
  var amountIdx = _findColumn(
      header, ['montant', 'amount', 'prix', 'somme', 'depense', 'total']);
  var catIdx = 2;
  var noteIdx = 3;
  var natureIdx = -1;
  var monthIdx = -1;
  var start = 0;
  if (dateIdx >= 0 && amountIdx >= 0) {
    start = 1;
    catIdx = _findColumn(header, ['categor', 'type', 'poste']);
    noteIdx = _findColumn(header,
        ['note', 'libelle', 'description', 'commentaire', 'detail', 'label']);
    natureIdx = _findColumn(header, ['nature']);
    monthIdx = _findColumn(header, ['mois_budget']);
  } else {
    dateIdx = 0;
    amountIdx = 1;
  }

  final out = <Expense>[];
  final incomes = <Income>[];
  var invalid = 0;
  for (var i = start; i < rows.length; i++) {
    final r = rows[i];
    String cell(int idx) => idx >= 0 && idx < r.length ? r[idx].trim() : '';
    final date = parseDate(cell(dateIdx));
    final amount = parseAmount(cell(amountIdx));
    if (date == null || amount == null) {
      invalid++;
      continue;
    }
    // Lignes d'entrées d'argent (colonne « nature » : salaire / entree).
    final nature = _norm(cell(natureIdx));
    if (nature == 'salaire' || nature == 'entree') {
      if (amount <= 0) {
        invalid++;
        continue;
      }
      var month = DateTime(date.year, date.month);
      final mm = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(cell(monthIdx));
      if (mm != null) {
        final y = int.parse(mm.group(1)!);
        final mo = int.parse(mm.group(2)!);
        if (mo >= 1 && mo <= 12) month = DateTime(y, mo);
      }
      incomes.add(Income(
        date: date,
        amount: amount,
        note: cell(noteIdx),
        isSalary: nature == 'salaire',
        month: month,
      ));
      continue;
    }
    final cat = cell(catIdx);
    out.add(Expense(
      date: date,
      amount: amount,
      category: cat.isEmpty ? tr('uncategorized') : cat,
      note: cell(noteIdx),
    ));
  }
  return ParsedImport(out, invalid, incomes);
}

// ---------------------------------------------------------------------------
// Export CSV et sauvegardes automatiques
// ---------------------------------------------------------------------------

String buildCsv(List<Expense> all, [List<Income> incomes = const []]) {
  String q(String s) => (s.contains(';') || s.contains('"') || s.contains('\n'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;
  final list = [...all]..sort((a, b) => a.date.compareTo(b.date));
  final sb =
      StringBuffer('\uFEFFdate;montant;categorie;note;nature;mois_budget\n');
  for (final e in list) {
    sb.write('${_dateKey(e.date)};'
        '${e.amount.toStringAsFixed(2).replaceAll('.', ',')};'
        '${q(e.category)};'
        '${q(e.note)};'
        'depense;\n');
  }
  final incs = [...incomes]..sort((a, b) => a.date.compareTo(b.date));
  for (final i in incs) {
    sb.write('${_dateKey(i.date)};'
        '${i.amount.toStringAsFixed(2).replaceAll('.', ',')};'
        ';'
        '${q(i.note)};'
        '${i.isSalary ? 'salaire' : 'entree'};'
        '${_monthKey(i.month)}\n');
  }
  return sb.toString();
}

enum BackupResult { saved, unchanged, empty, unsupported, needsAccess, failed }

/// Sauvegarde automatique : écrit un CSV dans le dossier choisi (par défaut
/// le dossier « Depenses » à la racine du stockage) et ne garde que les
/// [keep] derniers fichiers.
class Backup {
  static const keep = 3;
  static const folder = 'Depenses';
  // Canal vers MainActivity.kt (écriture dans le dossier par défaut ou choisi).
  static const MethodChannel _ch = MethodChannel('depenses/backup');

  /// Libellé du dossier de sauvegarde actuellement utilisé.
  static String get folderLabel =>
      settings.backupTree == null
          ? tr('folder_root', {'folder': folder})
          : (settings.backupTreeLabel ?? tr('folder_chosen'));

  /// Le dossier par défaut demande « l'accès à tous les fichiers » d'Android.
  static Future<bool> hasAccess() async =>
      await _ch.invokeMethod<bool>('hasAllFilesAccess') ?? false;

  /// Ouvre l'écran Android où l'on autorise l'accès à tous les fichiers.
  static Future<void> requestAccess() =>
      _ch.invokeMethod<void>('requestAllFilesAccess');

  /// Ouvre le sélecteur de dossier d'Android. Renvoie null si annulé.
  static Future<Map<String, String>?> pickFolder() =>
      _ch.invokeMapMethod<String, String>('pickFolder');

  /// Transforme l'identifiant Android (« primary:Documents/Sauvegardes »)
  /// en libellé lisible.
  static String prettyLabel(String docId) {
    if (docId.isEmpty) return tr('folder_chosen');
    final i = docId.indexOf(':');
    if (i < 0) return docId;
    final volume = docId.substring(0, i);
    final path = docId.substring(i + 1);
    final root =
        volume == 'primary' ? tr('storage_internal') : tr('storage_sd');
    return path.isEmpty ? root : '$root/$path';
  }

  // Empreinte du contenu (FNV-1a) pour ne pas réécrire un fichier identique.
  static String _signature(String csv) {
    var h = 0xcbf29ce484222325;
    for (final c in csv.codeUnits) {
      h ^= c;
      h = (h * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return '${csv.length}:$h';
  }

  static Future<BackupResult> run(List<Expense> all, List<Income> incomes,
      {bool force = false}) async {
    if (!Platform.isAndroid) return BackupResult.unsupported;
    if (all.isEmpty && incomes.isEmpty) return BackupResult.empty;
    final csv = buildCsv(all, incomes);
    final sig = _signature(csv);
    if (!force && sig == settings.lastBackupSig) return BackupResult.unchanged;

    // Dossier par défaut : l'autorisation « tous les fichiers » est requise.
    if (settings.backupTree == null) {
      var allowed = false;
      try {
        allowed = await hasAccess();
      } catch (_) {}
      if (!allowed) return BackupResult.needsAccess;
    }

    final now = DateTime.now();
    final name = 'depenses_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    try {
      final ok = await _ch.invokeMethod<bool>('save', {
        'name': name,
        'bytes': Uint8List.fromList(utf8.encode(csv)),
        'tree': settings.backupTree,
      });
      if (ok != true) return BackupResult.failed;
    } catch (_) {
      return BackupResult.failed;
    }

    // Rotation : on supprime les plus anciens au-delà de [keep].
    final names = [...settings.backupFiles, name];
    while (names.length > keep) {
      final old = names.removeAt(0);
      try {
        await _ch.invokeMethod<bool>('delete', {
          'name': old,
          'tree': settings.backupTree,
        });
      } catch (_) {}
    }
    await settings.setBackupState(names, sig, now);
    return BackupResult.saved;
  }
}

// ---------------------------------------------------------------------------
// Réglages persistants (couleur, thème, verrouillage, sauvegarde)
// ---------------------------------------------------------------------------

const themeChoices = [
  Color(0xFF009688),
  Color(0xFF1E88E5),
  Color(0xFF3949AB),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFFFFB300),
  Color(0xFF43A047),
  Color(0xFF546E7A),
  Color(0xFF6D4C41),
];

class AppSettings extends ChangeNotifier {
  SharedPreferences? _p;
  Color seed = themeChoices.first;
  ThemeMode mode = ThemeMode.system;
  bool lockEnabled = false;
  bool autoBackup = true;
  DateTime? lastBackup;
  String? lastBackupSig;
  List<String> backupFiles = [];
  String? backupTree; // URI du dossier choisi (null = dossier Depenses par défaut)
  String? backupTreeLabel;
  List<String> categories = [];
  bool categoriesReady = false; // false tant que l'utilisateur n'a rien saisi
  bool welcomeShown = true; // pop-up de bienvenue (premier lancement)
  bool storagePrompted = true; // demande d'accès au stockage (premier lancement)

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _p = prefs;
    final s = prefs.getInt('seed');
    if (s != null) seed = Color(s);
    mode = ThemeMode.values[(prefs.getInt('mode') ?? 0).clamp(0, 2).toInt()];
    lockEnabled = prefs.getBool('lock') ?? false;
    dismissedBanners = prefs.getStringList('dismissedBanners') ?? [];
    autoBackup = prefs.getBool('autoBackup') ?? true;
    backupFiles = prefs.getStringList('backupFiles') ?? [];
    lastBackupSig = prefs.getString('backupSig');
    backupTree = prefs.getString('backupTree');
    backupTreeLabel = prefs.getString('backupTreeLabel');
    categories = prefs.getStringList('categories') ?? [];
    categoriesReady = categories.isNotEmpty;
    // Installation existante (catégories déjà saisies) : rien à rejouer.
    welcomeShown = prefs.getBool('welcomeShown') ?? categoriesReady;
    storagePrompted = prefs.getBool('storagePrompted') ?? categoriesReady;
    // Migration : le dossier par défaut a changé (Téléchargements/Depenses →
    // Depenses à la racine). On repart d'un suivi vide pour la rotation.
    if (prefs.getBool('backupRootV2') != true) {
      if (backupTree == null) {
        backupFiles = [];
        lastBackupSig = null;
        await prefs.setStringList('backupFiles', []);
        await prefs.remove('backupSig');
      }
      await prefs.setBool('backupRootV2', true);
    }
    final lb = prefs.getString('lastBackup');
    lastBackup = lb == null ? null : DateTime.tryParse(lb);
  }

  // Mois pour lesquels la bannière « J'ai reçu mon salaire » a été masquée.
  List<String> dismissedBanners = [];

  bool isBannerDismissed(DateTime m) => dismissedBanners.contains(_monthKey(m));

  Future<void> dismissBanner(DateTime m) async {
    final k = _monthKey(m);
    if (dismissedBanners.contains(k)) return;
    dismissedBanners = [...dismissedBanners, k];
    notifyListeners();
    await _p?.setStringList('dismissedBanners', dismissedBanners);
  }

  Future<void> setWelcomeShown() async {
    welcomeShown = true;
    await _p?.setBool('welcomeShown', true);
  }

  Future<void> setStoragePrompted() async {
    storagePrompted = true;
    await _p?.setBool('storagePrompted', true);
  }

  bool hasCategory(String name) =>
      categories.any((c) => _norm(c) == _norm(name));

  Future<void> _saveCategories() async {
    categoriesReady = categories.isNotEmpty;
    notifyListeners();
    await _p?.setStringList('categories', categories);
  }

  Future<void> setCategories(List<String> list) async {
    categories = [];
    for (final n in list) {
      final name = _cap(n.trim());
      if (name.isNotEmpty && !hasCategory(name)) categories.add(name);
    }
    await _saveCategories();
  }

  /// Ajoute les catégories qui n'existent pas encore (insensible à la casse
  /// et aux accents). Sert à l'import CSV et à la saisie d'une dépense.
  Future<void> addCategories(Iterable<String> names) async {
    var changed = false;
    for (final n in names) {
      final name = _cap(n.trim());
      if (name.isNotEmpty && !hasCategory(name)) {
        categories.add(name);
        changed = true;
      }
    }
    if (changed) await _saveCategories();
  }

  Future<void> addCategory(String name) => addCategories([name]);

  Future<void> renameCategory(String from, String to) async {
    categories = [for (final c in categories) c == from ? to : c];
    await _saveCategories();
  }

  Future<void> removeCategory(String name) async {
    categories = categories.where((c) => c != name).toList();
    await _saveCategories();
  }

  Future<void> setSeed(Color c) async {
    seed = c;
    notifyListeners();
    await _p?.setInt('seed', c.toARGB32());
  }

  Future<void> setMode(ThemeMode m) async {
    mode = m;
    notifyListeners();
    await _p?.setInt('mode', m.index);
  }

  Future<void> setLock(bool v) async {
    lockEnabled = v;
    notifyListeners();
    await _p?.setBool('lock', v);
  }

  Future<void> setAutoBackup(bool v) async {
    autoBackup = v;
    notifyListeners();
    await _p?.setBool('autoBackup', v);
  }

  /// Change le dossier de sauvegarde (null = dossier par défaut). La liste des
  /// fichiers suivis est remise à zéro : les anciennes sauvegardes restent
  /// dans l'ancien dossier, la rotation des 7 repart dans le nouveau.
  Future<void> setBackupFolder(String? tree, String? label) async {
    backupTree = tree;
    backupTreeLabel = tree == null ? null : label;
    backupFiles = [];
    lastBackupSig = null;
    notifyListeners();
    final prefs = _p;
    if (prefs == null) return;
    if (tree == null) {
      await prefs.remove('backupTree');
      await prefs.remove('backupTreeLabel');
    } else {
      await prefs.setString('backupTree', tree);
      await prefs.setString('backupTreeLabel', label ?? '');
    }
    await prefs.setStringList('backupFiles', []);
    await prefs.remove('backupSig');
  }

  Future<void> setBackupState(
      List<String> files, String sig, DateTime at) async {
    backupFiles = files;
    lastBackupSig = sig;
    lastBackup = at;
    notifyListeners();
    await _p?.setStringList('backupFiles', files);
    await _p?.setString('backupSig', sig);
    await _p?.setString('lastBackup', at.toIso8601String());
  }
}

final settings = AppSettings();

// ---------------------------------------------------------------------------
// Verrouillage (empreinte digitale ou code du téléphone)
// ---------------------------------------------------------------------------

class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _locked = settings.lockEnabled;
  bool _busy = false;
  DateTime? _pausedAt;

  static const _grace = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (!settings.lockEnabled) return;
      if (since != null && DateTime.now().difference(since) > _grace) {
        setState(() => _locked = true);
      }
      if (_locked) _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    var ok = false;
    try {
      if (!await _auth.isDeviceSupported()) {
        // Aucun verrouillage d'écran configuré sur le téléphone : on laisse passer.
        ok = true;
      } else {
        ok = await _auth.authenticate(
          localizedReason: tr('lock_reason'),
        );
      }
    } catch (_) {
      ok = false;
    }
    _busy = false;
    if (!mounted) return;
    if (ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final showLock = _locked && settings.lockEnabled;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showLock)
              Positioned.fill(
                child: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('locked_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(tr('unlock')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Graphiques (dessinés à la main, sans dépendance externe)
// ---------------------------------------------------------------------------

class DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  DonutPainter(this.values, this.colors, this.trackColor);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2;
    final stroke = outer * 0.42;
    final rect = Rect.fromCircle(center: center, radius: outer - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total <= 0) {
      paint.color = trackColor;
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      paint.color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) => true;
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final String centerLabel;
  final String centerValue;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.centerLabel,
    required this.centerValue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(200),
            painter: DonutPainter(values, colors, cs.outlineVariant),
          ),
          SizedBox(
            width: 100,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerLabel, style: tt.labelMedium),
                  Text(
                    centerValue,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appLang = languageFor(WidgetsBinding.instance.platformDispatcher.locales);
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
  await settings.load();
  // Migration : si des dépenses existent déjà mais qu'aucune liste de
  // catégories n'a été enregistrée, on la reconstitue depuis les données.
  if (!settings.categoriesReady) {
    final existing = await Db.all();
    if (existing.isNotEmpty) {
      final cats = existing.map((e) => e.category).toSet().toList()..sort();
      await settings.setCategories(cats);
    }
  }
  runApp(const DepensesApp());
}

class DepensesApp extends StatelessWidget {
  const DepensesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'BankNote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: settings.seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: settings.seed,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: settings.mode,
        // La langue suit celle du téléphone (français, sinon anglais).
        supportedLocales: const [Locale('fr'), Locale('en')],
        localeListResolutionCallback: (locales, supported) {
          appLang = languageFor(locales);
          return Locale(appLang);
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            LockGate(child: child ?? const SizedBox.shrink()),
        home: const RootPage(),
      ),
    );
  }
}

/// Affiche la saisie des catégories tant qu'il n'y en a aucune, puis l'appli.
class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => settings.categoriesReady
          ? const HomePage()
          : const CategorySetupPage(),
    );
  }
}

/// Demande un nom de catégorie. Renvoie null si annulé ou vide.
Future<String?> askCategoryName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final ctl = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
          child: Text(tr('validate')),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return null;
  return _cap(name);
}

// ---------------------------------------------------------------------------
// Premier lancement : choix des catégories
// ---------------------------------------------------------------------------

class CategorySetupPage extends StatefulWidget {
  const CategorySetupPage({super.key});

  @override
  State<CategorySetupPage> createState() => _CategorySetupPageState();
}

class _CategorySetupPageState extends State<CategorySetupPage> {
  final TextEditingController _ctl = TextEditingController();
  final List<String> _cats = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pop-up de bienvenue au tout premier lancement, avant la saisie.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
  }

  Future<void> _showWelcome() async {
    if (settings.welcomeShown || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.savings_outlined,
          size: 40,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: Text(tr('welcome_title'), textAlign: TextAlign.center),
        content: Text(tr('welcome_body'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('welcome_start')),
          ),
        ],
      ),
    );
    await settings.setWelcomeShown();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool get _canContinue => _cats.isNotEmpty || _ctl.text.trim().isNotEmpty;

  void _add() {
    final name = _cap(_ctl.text.trim());
    if (name.isEmpty) return;
    if (_cats.any((c) => _norm(c) == _norm(name))) {
      setState(() => _error = tr('cat_exists'));
      return;
    }
    setState(() {
      _cats.add(name);
      _ctl.clear();
      _error = null;
    });
  }

  Future<void> _finish() async {
    // On tient compte du texte saisi mais pas encore ajouté.
    final pending = _cap(_ctl.text.trim());
    if (pending.isNotEmpty && !_cats.any((c) => _norm(c) == _norm(pending))) {
      _cats.add(pending);
    }
    if (_cats.isEmpty) return;
    await settings.setCategories(_cats);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // se reconstruit si la langue change
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Icon(Icons.category_outlined, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text(tr('setup_title'),
                style: tt.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              tr('setup_intro'),
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctl,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: tr('cat_name_label'),
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: tr('add'),
                  onPressed: _add,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_cats.isEmpty)
              Text(
                tr('no_cat_yet'),
                style: tt.bodySmall,
                textAlign: TextAlign.center,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in _cats)
                    InputChip(
                      label: Text(c),
                      onDeleted: () => setState(() => _cats.remove(c)),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _canContinue ? _finish : null,
              icon: const Icon(Icons.check),
              label: Text(tr('continue')),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Expense> _all = [];
  List<Income> _incomes = [];
  bool _loading = true;
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _chartYear = DateTime.now().year;
  String? _filterCategory; // catégorie filtrée dans le Résumé (null = toutes)
  bool _askingAccess = false;
  bool _waitingAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload().then((_) async {
      if (!mounted) return;
      // Premier lancement : on demande l'accès au stockage une fois, même
      // sans dépense (sinon la sauvegarde ne démarre pas et rien n'est demandé).
      if (!settings.storagePrompted) {
        await settings.setStoragePrompted();
        await _firstRunStorage();
      }
      if (!mounted) return;
      if (settings.autoBackup && !_waitingAccess) _autoBackup();
    });
  }

  Future<void> _firstRunStorage() async {
    if (!Platform.isAndroid || settings.backupTree != null) return;
    var allowed = false;
    try {
      allowed = await Backup.hasAccess();
    } catch (_) {}
    if (!allowed && mounted) await _askStorageAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Au retour de l'écran d'autorisation d'Android : on relance la sauvegarde.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingAccess) {
      _waitingAccess = false;
      _autoBackup(force: true);
    }
  }

  Future<void> _askStorageAccess() async {
    if (_askingAccess) return;
    _askingAccess = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('storage_title')),
        content: Text(tr('storage_body', {'folder': Backup.folder})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('later')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'folder'),
            child: Text(tr('choose_folder')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'allow'),
            child: Text(tr('allow')),
          ),
        ],
      ),
    );
    _askingAccess = false;
    if (choice == 'allow') {
      try {
        _waitingAccess = true;
        await Backup.requestAccess();
      } catch (_) {
        _waitingAccess = false;
        if (mounted) _snack(tr('err_settings'));
      }
    } else if (choice == 'folder') {
      await _chooseBackupFolder();
    }
  }

  Future<void> _autoBackup({bool force = false}) async {
    final r = await Backup.run(_all, _incomes, force: force);
    if (!mounted) return;
    if (r == BackupResult.needsAccess) {
      await _askStorageAccess();
      return;
    }
    if (!force) return;
    switch (r) {
      case BackupResult.saved:
        _snack(tr('bk_saved', {'folder': Backup.folderLabel}));
      case BackupResult.unchanged:
        _snack(tr('bk_unchanged'));
      case BackupResult.unsupported:
        _snack(tr('bk_unsupported'));
      case BackupResult.failed:
        _snack(tr('bk_failed', {'folder': Backup.folderLabel}));
      case BackupResult.empty:
      case BackupResult.needsAccess:
        break;
    }
  }

  Future<void> _toggleAutoBackup(bool v) async {
    await settings.setAutoBackup(v);
    if (v) await _autoBackup(force: true);
  }

  Future<void> _chooseBackupFolder() async {
    try {
      final r = await Backup.pickFolder();
      if (r == null) return; // sélection annulée
      await settings.setBackupFolder(
        r['uri'],
        Backup.prettyLabel(r['label'] ?? ''),
      );
      await _autoBackup(force: true);
    } catch (_) {
      if (mounted) _snack(tr('err_pick_folder'));
    }
  }

  Future<void> _resetBackupFolder() async {
    await settings.setBackupFolder(null, null);
    await _autoBackup(force: true);
  }

  Future<void> _reload() async {
    final data = await Db.all();
    final incomes = await Db.allIncomes();
    if (!mounted) return;
    setState(() {
      _all = data;
      _incomes = incomes;
      _loading = false;
    });
  }

  // Catégories de l'utilisateur, plus (par sécurité) celles qui n'existeraient
  // que dans les données.
  List<String> get _categories {
    final extra = _all
        .map((e) => e.category)
        .where((c) => !settings.categories.contains(c))
        .toSet()
        .toList()
      ..sort();
    return [...settings.categories, ...extra];
  }

  List<Expense> get _monthExpenses => _all
      .where((e) => e.date.year == _month.year && e.date.month == _month.month)
      .toList();

  double _total(DateTime m) => _all
      .where((e) => e.date.year == m.year && e.date.month == m.month)
      .fold<double>(0, (s, e) => s + e.amount);

  // Entrées d'argent comptées pour le mois [m] (mois de rattachement).
  List<Income> _incomesFor(DateTime m) => _incomes
      .where((i) => i.month.year == m.year && i.month.month == m.month)
      .toList();

  double _incomeTotal(DateTime m) =>
      _incomesFor(m).fold<double>(0, (s, i) => s + i.amount);

  /// Ouvre la feuille de saisie d'une entrée d'argent (nouvelle ou existante).
  Future<void> _openIncomeSheet({Income? income, bool salary = false}) async {
    final now = DateTime.now();
    // Mois passé affiché : on propose le dernier jour de ce mois ; sinon
    // la date du jour.
    final isPast = DateTime(_month.year, _month.month)
        .isBefore(DateTime(now.year, now.month));
    final initial = isPast
        ? DateTime(_month.year, _month.month + 1, 0)
        : DateTime(now.year, now.month, now.day);
    final month = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => IncomeSheet(
        income: income,
        salaryDefault: salary,
        initialDate: initial,
      ),
    );
    if (month != null) {
      _month = DateTime(month.year, month.month);
      await _reload();
    }
  }

  String _monthLabel(DateTime m) =>
      toBeginningOfSentenceCase(DateFormat('MMMM yyyy', appLang).format(m))!;

  Color _colorFor(String category) {
    final i = _categories.indexOf(category);
    final k = i < 0 ? category.hashCode.abs() : i;
    return chartColors[k % chartColors.length];
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor([Expense? e]) async {
    final saved = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPage(
          expense: e,
          categories: _categories,
          initialCategory:
              _all.isNotEmpty ? _all.first.category : _categories.first,
        ),
      ),
    );
    if (saved != null) {
      _month = DateTime(saved.year, saved.month);
      await _reload();
    }
  }

  // ---- Catégories ---------------------------------------------------------

  Future<void> _addCategory() async {
    final name =
        await askCategoryName(context, title: tr('new_category'));
    if (name == null) return;
    if (settings.hasCategory(name)) {
      _snack(tr('cat_exists'));
      return;
    }
    await settings.addCategory(name);
  }

  Future<void> _renameCategory(String old) async {
    final name = await askCategoryName(
      context,
      title: tr('rename_category'),
      initial: old,
    );
    if (name == null || name == old) return;
    final taken = settings.categories.any((c) => c != old && _norm(c) == _norm(name));
    if (taken) {
      _snack(tr('cat_taken'));
      return;
    }
    await Db.renameCategory(old, name);
    await settings.renameCategory(old, name);
    if (_filterCategory == old) _filterCategory = name;
    await _reload();
  }

  Future<void> _deleteCategory(String cat) async {
    final others = settings.categories.where((c) => c != cat).toList();
    if (others.isEmpty) {
      _snack(tr('keep_one'));
      return;
    }
    final count = _all.where((e) => e.category == cat).length;
    String? target;
    if (count == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('delete_cat_title', {'cat': cat})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      var selected = others.first;
      target = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(tr('delete_cat_title', {'cat': cat})),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trn('cat_used', count)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in others)
                      ChoiceChip(
                        label: Text(c),
                        selected: c == selected,
                        onSelected: (_) => setLocal(() => selected = c),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: Text(tr('delete')),
              ),
            ],
          ),
        ),
      );
      if (target == null) return;
    }
    if (target != null) await Db.renameCategory(cat, target);
    await settings.removeCategory(cat);
    if (_filterCategory == cat) _filterCategory = null;
    await _reload();
  }

  Widget _categoryTile(String c) {
    final n = _all.where((e) => e.category == c).length;
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(c),
      subtitle: Text(n == 0 ? tr('no_expense') : trn('expenses_count', n)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: tr('rename'),
            onPressed: () => _renameCategory(c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: tr('delete'),
            onPressed: () => _deleteCategory(c),
          ),
        ],
      ),
    );
  }

  // ---- Import / export ----------------------------------------------------

  Future<void> _import() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      _snack(tr('err_read'));
      return;
    }
    await _importBytes(bytes, title: tr('import_done'));
  }

  Future<void> _importBytes(Uint8List bytes, {required String title}) async {
    final parsed = parseImport(bytes);
    final canon = <String, String>{
      for (final c in _categories) _norm(c): c,
    };
    final existing = _all.map(_expenseKey).toSet();
    final toInsert = <Expense>[];
    var duplicates = 0;
    for (final e in parsed.expenses) {
      final cat = canon.putIfAbsent(_norm(e.category), () => _cap(e.category));
      final x = Expense(
        date: e.date,
        amount: e.amount,
        category: cat,
        note: e.note,
      );
      if (existing.contains(_expenseKey(x))) {
        duplicates++;
        continue;
      }
      toInsert.add(x);
    }
    if (toInsert.isNotEmpty) await Db.insertMany(toInsert);
    // Entrées d'argent du CSV (colonne « nature »), sans doublons.
    final existingInc = _incomes.map(_incomeKey).toSet();
    final incToInsert = <Income>[];
    for (final inc in parsed.incomes) {
      if (!existingInc.add(_incomeKey(inc))) {
        duplicates++;
        continue;
      }
      incToInsert.add(inc);
    }
    if (incToInsert.isNotEmpty) await Db.insertManyIncomes(incToInsert);
    // Les catégories inconnues du CSV rejoignent la liste de l'utilisateur.
    final catsBefore = settings.categories.length;
    await settings.addCategories(toInsert.map((e) => e.category));
    final addedCats = settings.categories.length - catsBefore;
    await _reload();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text([
          trn('imp_done', toInsert.length),
          if (incToInsert.isNotEmpty) trn('imp_inc', incToInsert.length),
          trn('imp_dup', duplicates),
          trn('imp_bad', parsed.invalid),
          if (addedCats > 0) trn('imp_cats', addedCats),
        ].join('\n')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    if (_all.isEmpty && _incomes.isEmpty) {
      _snack(tr('none_to_export'));
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(buildCsv(_all, _incomes)));
    final name =
        'depenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final path = await FilePicker.saveFile(
      dialogTitle: tr('save_dialog'),
      fileName: name,
      bytes: bytes,
    );
    if (path != null) _snack(tr('backup_saved'));
  }

  // ---- Sélection du mois --------------------------------------------------

  Future<void> _pickMonth() async {
    var year = _month.year;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final now = DateTime.now();
          final withData = _all
              .where((e) => e.date.year == year)
              .map((e) => e.date.month)
              .toSet();
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setLocal(() => year--),
                ),
                Expanded(
                  child: Text('$year', textAlign: TextAlign.center),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setLocal(() => year++),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.9,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var m = 1; m <= 12; m++)
                    _monthCell(ctx, year, m, withData.contains(m)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, DateTime(now.year, now.month)),
                child: Text(tr('today')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) setState(() => _month = picked);
  }

  Widget _monthCell(BuildContext ctx, int year, int m, bool hasData) {
    final label =
        toBeginningOfSentenceCase(DateFormat('MMM', appLang).format(DateTime(year, m)))!;
    final onTap = () => Navigator.pop(ctx, DateTime(year, m));
    final text = Text(label, maxLines: 1, overflow: TextOverflow.clip);
    if (year == _month.year && m == _month.month) {
      return FilledButton(
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: onTap,
        child: text,
      );
    }
    if (hasData) {
      return FilledButton.tonal(
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: onTap,
        child: text,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      onPressed: onTap,
      child: text,
    );
  }

  // ---- Interface : en-tête de mois ---------------------------------------

  Widget _monthBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
          ),
          TextButton(
            onPressed: _pickMonth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _monthLabel(_month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
    );
  }

  // ---- Interface : résumé -------------------------------------------------

  Widget _monthlyBars(List<DateTime> months, List<double> totals) {
    final color = Theme.of(context).colorScheme.primary;
    final selected = _month.month - 1;
    final maxV = totals.fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 12; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _month = months[i]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: maxV <= 0 || totals[i] <= 0
                          ? 2.0
                          : (totals[i] / maxV * 120).clamp(2.0, 120.0).toDouble(),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == selected ? color : color.withAlpha(90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      monthInitials[i],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight:
                                i == selected ? FontWeight.bold : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryRow(String name, double value, double total) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final selected = _filterCategory == name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? cs.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              setState(() => _filterCategory = selected ? null : name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: selected
                            ? const TextStyle(fontWeight: FontWeight.bold)
                            : null,
                      ),
                    ),
                    Text(money.format(value)),
                    SizedBox(
                      width: 48,
                      child: Text(
                        total > 0
                            ? pctStr(value / total)
                            : '',
                        textAlign: TextAlign.right,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0
                        ? (value / total).clamp(0.0, 1.0).toDouble()
                        : 0.0,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryPage() {
    final textTheme = Theme.of(context).textTheme;
    final items = _monthExpenses;
    final total = items.fold<double>(0, (s, e) => s + e.amount);
    final prev = _total(DateTime(_month.year, _month.month - 1));
    final diff = total - prev;

    // Entrées d'argent comptées pour ce mois, et salaire éventuellement reçu
    // ce mois-ci mais compté pour un autre mois.
    final monthIncomes = _incomesFor(_month)
      ..sort((a, b) => b.date.compareTo(a.date));
    final deferredSalary = _incomes
        .where((i) =>
            i.isSalary &&
            i.date.year == _month.year &&
            i.date.month == _month.month &&
            !(i.month.year == _month.year && i.month.month == _month.month))
        .firstOrNull;

    // Toutes les catégories de l'utilisateur, même sans dépense ce mois-ci.
    final cats = _categories;
    final byCat = <String, double>{for (final c in cats) c: 0.0};
    for (final e in items) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : cats.indexOf(a.key).compareTo(cats.indexOf(b.key));
      });

    // Filtre : on ignore une catégorie qui n'existe plus.
    final filter = (_filterCategory != null && cats.contains(_filterCategory))
        ? _filterCategory
        : null;
    final shown =
        filter == null ? items : items.where((e) => e.category == filter).toList();

    Widget comparison = const SizedBox.shrink();
    if (prev > 0) {
      final pct = (diff / prev * 100).toStringAsFixed(0);
      final up = diff >= 0;
      comparison = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          tr('vs_prev', {
            'amount': (up ? '+' : '−') + money.format(diff.abs()),
            'pct': pct,
          }),
          style: textTheme.bodyMedium?.copyWith(
            color: up ? Colors.red.shade400 : Colors.green.shade500,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _budgetCard(
          total: total,
          count: items.length,
          comparison: comparison,
          incomes: monthIncomes,
          deferred: deferredSalary,
        ),
        const SizedBox(height: 16),
        Text(tr('by_category'), style: textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          tr('filter_hint'),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        for (final entry in entries) _categoryRow(entry.key, entry.value, total),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                filter == null
                    ? (monthIncomes.isEmpty
                        ? tr('expenses_month')
                        : tr('movements_month'))
                    : tr('expenses_filtered', {'cat': filter}),
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (filter != null)
              TextButton.icon(
                onPressed: () => setState(() => _filterCategory = null),
                icon: const Icon(Icons.close, size: 18),
                label: Text(tr('show_all')),
              ),
          ],
        ),
        if (shown.isEmpty && (filter != null || monthIncomes.isEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              filter == null
                  ? tr('none_month')
                  : tr('none_month_cat', {'cat': filter}),
            ),
          ),
        if (filter == null)
          for (final i in monthIncomes) _incomeTile(i),
        for (final e in shown) _expenseTile(e),
      ],
    );
  }

  // Bannière « J'ai reçu mon salaire » : mois en cours uniquement, masquée
  // dès qu'un salaire a été reçu dans le mois (même compté pour le suivant)
  // ou si l'utilisateur l'a fermée pour ce mois.
  Widget _salaryBanner() {
    if (_loading) return const SizedBox.shrink();
    final now = DateTime.now();
    if (_month.year != now.year || _month.month != now.month) {
      return const SizedBox.shrink();
    }
    final received = _incomes.any((i) =>
        i.isSalary && i.date.year == _month.year && i.date.month == _month.month);
    if (received || settings.isBannerDismissed(_month)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openIncomeSheet(salary: true),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, color: cs.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('salary_banner'),
                      style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 20, color: cs.onSecondaryContainer),
                    tooltip: tr('dismiss'),
                    onPressed: () async {
                      await settings.dismissBanner(_month);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Carte du haut du Résumé : « Reste du mois » si le mois a des revenus,
  // sinon le total des dépenses comme avant.
  Widget _budgetCard({
    required double total,
    required int count,
    required Widget comparison,
    required List<Income> incomes,
    Income? deferred,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasIncome = incomes.isNotEmpty;
    final incomeTotal = incomes.fold<double>(0, (s, i) => s + i.amount);
    final remaining = incomeTotal - total;
    final over = remaining < 0;
    final tone = over ? Colors.red.shade400 : Colors.green.shade500;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasIncome) ...[
              // Dépenses (gauche) et revenus (droite) en gros, en haut.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('expenses_label'),
                            style: textTheme.labelLarge),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            money.format(total),
                            style: textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tr('income_label'), style: textTheme.labelLarge),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            money.format(incomeTotal),
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (total / incomeTotal).clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  color: over ? tone : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('pct_spent', {'pct': pctStr(total / incomeTotal)}),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              // Reste du mois : à la place de l'ancienne ligne « Revenus · Dépenses ».
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('remaining'), style: textTheme.labelLarge),
                        Text(
                          money.format(remaining),
                          style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold, color: tone),
                        ),
                        if (over)
                          Text(
                            tr('over_by', {'amount': money.format(-remaining)}),
                            style: textTheme.bodyMedium?.copyWith(color: tone),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () => _openIncomeSheet(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr('income_short')),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(tr('month_total'),
                        style: textTheme.labelLarge),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () => _openIncomeSheet(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr('income_short')),
                  ),
                ],
              ),
              Text(
                money.format(total),
                style: textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(trn('expenses_count', count), style: textTheme.bodyMedium),
            ],
            comparison,
            if (deferred != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('salary_deferred', {
                    'amount': money.format(deferred.amount),
                    'date': DateFormat('d MMM', appLang).format(deferred.date),
                    'month': monthWord(deferred.month),
                  }),
                  style: textTheme.bodySmall?.copyWith(color: cs.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Une entrée d'argent : touche pour modifier, glisse vers la gauche pour
  // supprimer (comme une dépense).
  Widget _incomeTile(Income i) {
    final green = Colors.green.shade600;
    final kind = i.isSalary ? tr('salary') : tr('income');
    return Dismissible(
      key: ValueKey('income-${i.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        setState(() => _incomes.removeWhere((x) => x.id == i.id));
        await Db.deleteIncome(i.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(tr('income_deleted')),
            action: SnackBarAction(
              label: tr('undo'),
              onPressed: () async {
                await Db.insertIncome(i);
                await _reload();
              },
            ),
          ));
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.green.withAlpha(40),
          child: Icon(Icons.add, color: green),
        ),
        title: Text(i.note.isEmpty ? kind : i.note),
        subtitle: Text('${DateFormat('EEE d MMM', appLang).format(i.date)} · $kind'),
        trailing: Text(
          '+${money.format(i.amount)}',
          style: TextStyle(fontWeight: FontWeight.w600, color: green),
        ),
        onTap: () => _openIncomeSheet(income: i),
      ),
    );
  }

  // Une dépense : touche pour modifier, glisse vers la gauche pour supprimer.
  Widget _expenseTile(Expense e) {
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        setState(() => _all.removeWhere((x) => x.id == e.id));
        await Db.delete(e.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(tr('expense_deleted')),
            action: SnackBarAction(
              label: tr('undo'),
              onPressed: () async {
                await Db.insert(e);
                await _reload();
              },
            ),
          ));
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Text(e.category.isEmpty ? '?' : e.category[0].toUpperCase()),
        ),
        title: Text(e.note.isEmpty ? e.category : e.note),
        subtitle: Text(
          '${DateFormat('EEE d MMM', appLang).format(e.date)} · ${e.category}',
        ),
        trailing: Text(
          money.format(e.amount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => _openEditor(e),
      ),
    );
  }

  // ---- Interface : graphiques --------------------------------------------

  Map<String, double> _byCategory(Iterable<Expense> list) {
    final m = <String, double>{};
    for (final e in list) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return m;
  }

  Widget _legend(
      List<MapEntry<String, double>> entries, double total, int months) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _colorFor(e.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.key, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    pctStr(e.value / total),
                    textAlign: TextAlign.right,
                    style: textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        moneyShort.format(e.value),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        tr('per_month',
                            {'amount': moneyShort.format(e.value / months)}),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Nombre de mois couverts par les données d'une année : du premier mois
  // avec données jusqu'à aujourd'hui (année en cours) ou jusqu'à décembre.
  int _monthsCovered(int year, Iterable<Expense> list, DateTime now) {
    if (list.isEmpty) return 1;
    final start = list.map((e) => e.date.month).reduce(math.min);
    final end = year == now.year ? now.month : 12;
    return math.max(1, end - start + 1);
  }

  Widget _averageBlock(int selectedYear, DateTime now) {
    final textTheme = Theme.of(context).textTheme;
    final list = _all.where((e) => e.date.year == selectedYear);
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    final months = _monthsCovered(selectedYear, list, now);
    final avg = total / months;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('avg_title'), style: textTheme.titleSmall),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Text(tr('none_year', {'year': selectedYear}))
        else ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: money.format(avg),
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                    text: tr('per_month_suffix'), style: textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trn('year_summary', months, {
                  'year': selectedYear,
                  'total': moneyShort.format(total),
                }) +
                (selectedYear == now.year ? tr('incl_current') : ''),
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _chartsSection({
    required String title,
    required List<Expense> list,
    required int months,
    Widget? extra,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final entries = _byCategory(list)
        .entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(tr('breakdown'), style: textTheme.titleSmall),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(tr('none_period'))
            else ...[
              Center(
                child: DonutChart(
                  values: entries.map((e) => e.value).toList(),
                  colors: entries.map((e) => _colorFor(e.key)).toList(),
                  centerLabel: tr('total'),
                  centerValue: moneyShort.format(total),
                ),
              ),
              const SizedBox(height: 12),
              _legend(entries, total, months),
              const SizedBox(height: 4),
              Text(
                trn('avg_over', months),
                style: textTheme.bodySmall,
              ),
            ],
            if (extra != null) ...[
              const SizedBox(height: 24),
              extra,
            ],
          ],
        ),
      ),
    );
  }

  Widget _chartsPage() {
    if (_all.isEmpty) {
      return Center(child: Text(tr('no_chart_data')));
    }
    final now = DateTime.now();
    final minYear = _all.last.date.year;
    final year = _chartYear.clamp(minYear, now.year).toInt();
    final isCurrent = year == now.year;
    final yearList = _all.where((e) => e.date.year == year).toList();
    final yearMonthsCount = _monthsCovered(year, yearList, now);

    // Mois couverts par l'ensemble des données
    final first = _all.last.date;
    final lastData = _all.first.date;
    final end = lastData.isAfter(now) ? lastData : now;
    final allMonthsCount = _monthSpan(first, end);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  year > minYear ? () => setState(() => _chartYear = year - 1) : null,
            ),
            Expanded(
              child: Text(
                isCurrent ? tr('current_year', {'year': year}) : '$year',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: year < now.year
                  ? () => setState(() => _chartYear = year + 1)
                  : null,
            ),
          ],
        ),
        _chartsSection(
          title: tr('year_title', {'year': year}),
          list: yearList,
          months: yearMonthsCount,
          extra: _averageBlock(year, now),
        ),
        const SizedBox(height: 16),
        _chartsSection(
          title: tr('all_years', {'a': first.year, 'b': end.year}),
          list: _all,
          months: allMonthsCount,
        ),
      ],
    );
  }

  // ---- Interface : historique et données ---------------------------------

  Widget _historyPage() {
    final textTheme = Theme.of(context).textTheme;
    final yearMonths = List.generate(12, (i) => DateTime(_month.year, i + 1));
    final yearTotals = yearMonths.map(_total).toList();
    final yearTotal = yearTotals.fold<double>(0, (s, v) => s + v);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                  () => _month = DateTime(_month.year - 1, _month.month)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('${_month.year}', style: textTheme.titleMedium),
                  Text(
                    tr('year_total', {'amount': money.format(yearTotal)}),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                  () => _month = DateTime(_month.year + 1, _month.month)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _monthlyBars(yearMonths, yearTotals),
        const SizedBox(height: 8),
        for (var i = 0; i < 12; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: i == _month.month - 1,
            title: Text(_monthLabel(yearMonths[i])),
            subtitle: _incomeTotal(yearMonths[i]) > 0
                ? Text(
                    tr('remaining_short', {
                      'amount': money
                          .format(_incomeTotal(yearMonths[i]) - yearTotals[i]),
                    }),
                    style: TextStyle(
                      color: _incomeTotal(yearMonths[i]) - yearTotals[i] < 0
                          ? Colors.red.shade400
                          : Colors.green.shade500,
                    ),
                  )
                : null,
            trailing: Text(
              money.format(yearTotals[i]),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () => setState(() => _month = yearMonths[i]),
          ),
      ],
    );
  }

  // ---- Réglages -----------------------------------------------------------

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

  Widget _swatch(Color c) {
    final selected = settings.seed.toARGB32() == c.toARGB32();
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => settings.setSeed(c),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }

  Future<void> _toggleLock(bool enable) async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) {
        if (mounted) {
          _snack(tr('lock_setup_first'));
        }
        return;
      }
      final ok = await auth.authenticate(
        localizedReason:
            enable ? tr('lock_confirm_on') : tr('lock_confirm_off'),
      );
      if (ok) await settings.setLock(enable);
    } catch (_) {
      if (mounted) {
        _snack(tr('auth_failed'));
      }
    }
  }

  Widget _settingsPage() {
    String range = tr('no_data');
    if (_all.isNotEmpty) {
      final f = DateFormat('d MMM yyyy', appLang);
      range = tr('range', {
        'a': f.format(_all.last.date),
        'b': f.format(_all.first.date),
      });
    }
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final last = settings.lastBackup;
        final lastLabel = last == null
            ? tr('no_backup')
            : tr('last_backup', {
                'date': '${DateFormat('d MMM yyyy', appLang).format(last)} '
                    '${tr('at')} ${DateFormat('HH:mm', appLang).format(last)}',
              });
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _sectionTitle(tr('appearance')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final c in themeChoices) _swatch(c)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.system, label: Text(tr('auto'))),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text(tr('light'))),
                  ButtonSegment(value: ThemeMode.dark, label: Text(tr('dark'))),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) => settings.setMode(s.first),
              ),
            ),
            const Divider(),
            // Catégories : section dépliable, repliée par défaut, pour ne pas
            // repousser les autres réglages quand il y en a beaucoup.
            ExpansionTile(
              key: const PageStorageKey('settings-categories'),
              initiallyExpanded: false,
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              title: Text(
                tr('categories'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary),
              ),
              subtitle: Text(trn('cats_count', settings.categories.length)),
              children: [
                for (final c in settings.categories) _categoryTile(c),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(tr('add_category')),
                  onTap: _addCategory,
                ),
              ],
            ),
            const Divider(),
            _sectionTitle(tr('security')),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(tr('fp_lock')),
              subtitle: Text(tr('fp_sub')),
              value: settings.lockEnabled,
              onChanged: _toggleLock,
            ),
            const Divider(),
            _sectionTitle(tr('backup_data')),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(trn('expenses_saved', _all.length)),
              subtitle: Text(range),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.backup_outlined),
              title: Text(tr('auto_backup')),
              subtitle: Text(
                '${tr('auto_sub', {'keep': Backup.keep})}\n$lastLabel',
              ),
              isThreeLine: true,
              value: settings.autoBackup,
              onChanged: _toggleAutoBackup,
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(tr('backup_folder')),
              subtitle: Text(
                settings.backupTree == null
                    ? tr('default_suffix', {'folder': Backup.folderLabel})
                    : Backup.folderLabel,
              ),
              trailing: settings.backupTree == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.restart_alt),
                      tooltip: tr('reset_folder'),
                      onPressed: _resetBackupFolder,
                    ),
              onTap: _chooseBackupFolder,
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(tr('export_csv')),
              subtitle: Text(tr('export_sub')),
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(tr('import_csv')),
              subtitle: Text(tr('import_sub')),
              onTap: _import,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // se reconstruit si la langue change
    final titles = [
      tr('tab_summary'),
      tr('tab_history'),
      tr('tab_charts'),
      tr('tab_settings'),
    ];
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_tab == 3) {
      body = _settingsPage();
    } else if (_tab == 2) {
      body = _chartsPage();
    } else {
      body = _tab == 0
          ? Column(
              children: [
                _monthBar(),
                _salaryBanner(),
                Expanded(child: _summaryPage()),
              ],
            )
          : _historyPage();
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: body,
      floatingActionButton: _tab >= 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(tr('fab_expense')),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: tr('tab_summary'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: tr('tab_history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: tr('tab_charts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: tr('tab_settings'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran d'ajout / modification
// ---------------------------------------------------------------------------

class EditPage extends StatefulWidget {
  final Expense? expense;
  final List<String> categories;
  final String initialCategory;

  const EditPage({
    super.key,
    this.expense,
    required this.categories,
    required this.initialCategory,
  });

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _noteCtl;
  late final List<String> _cats;
  late DateTime _date;
  late String _category;
  String? _error;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _cats = List.of(widget.categories);
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? widget.initialCategory;
    if (!_cats.contains(_category)) _cats.add(_category);
    var amountText = '';
    if (e != null) {
      amountText = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      amountText = amountText.replaceAll('.', ',');
    }
    _amountCtl = TextEditingController(text: amountText);
    _noteCtl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _newCategory() async {
    final name =
        await askCategoryName(context, title: tr('new_category'));
    if (name == null) return;
    final existing = _cats.where((c) => _norm(c) == _norm(name));
    setState(() {
      if (existing.isNotEmpty) {
        _category = existing.first;
      } else {
        _cats.add(name);
        _category = name;
      }
    });
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountCtl.text);
    if (amount == null || amount == 0) {
      setState(() => _error = tr('amount_invalid'));
      return;
    }
    final e = Expense(
      id: widget.expense?.id,
      date: _date,
      amount: amount,
      category: _category,
      note: _noteCtl.text.trim(),
    );
    await settings.addCategory(_category); // sans effet si elle existe déjà
    if (_editing) {
      await Db.update(e);
    } else {
      await Db.insert(e);
    }
    if (!mounted) return;
    Navigator.pop(context, _date);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_expense_title')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Db.delete(widget.expense!.id!);
    if (!mounted) return;
    Navigator.pop(context, widget.expense!.date);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // se reconstruit si la langue change
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? tr('edit_expense') : tr('new_expense')),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountCtl,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: tr('amount'),
              suffixText: '€',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
          Text(tr('category'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in _cats)
                ChoiceChip(
                  label: Text(c),
                  selected: c == _category,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(tr('new_short')),
                onPressed: _newCategory,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(
              toBeginningOfSentenceCase(
                  DateFormat('EEEE d MMMM yyyy', appLang).format(_date))!,
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(tr('save')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('note_optional'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feuille de saisie : salaire / entrée d'argent
// ---------------------------------------------------------------------------

/// Saisie d'une entrée d'argent. L'utilisateur choisit toujours lui-même si
/// le montant compte « maintenant » (mois de la date de réception) ou « au
/// 1er du mois suivant » : aucune option n'est cochée d'office à la création.
/// Renvoie le mois de rattachement enregistré (ou null si annulé).
class IncomeSheet extends StatefulWidget {
  final Income? income;
  final bool salaryDefault;
  final DateTime initialDate;

  const IncomeSheet({
    super.key,
    this.income,
    required this.salaryDefault,
    required this.initialDate,
  });

  @override
  State<IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends State<IncomeSheet> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _noteCtl;
  late DateTime _date;
  late bool _isSalary;
  int? _choice; // 0 = maintenant (mois de la date), 1 = 1er du mois suivant
  String? _error;

  bool get _editing => widget.income != null;

  @override
  void initState() {
    super.initState();
    final i = widget.income;
    _date = i?.date ?? widget.initialDate;
    _isSalary = i?.isSalary ?? widget.salaryDefault;
    if (i != null) {
      if (i.month == DateTime(_date.year, _date.month)) {
        _choice = 0;
      } else if (i.month == DateTime(_date.year, _date.month + 1)) {
        _choice = 1;
      }
    }
    var amountText = '';
    if (i != null) {
      amountText = i.amount == i.amount.roundToDouble()
          ? i.amount.toStringAsFixed(0)
          : i.amount.toStringAsFixed(2);
      amountText = amountText.replaceAll('.', ',');
    }
    _amountCtl = TextEditingController(text: amountText);
    _noteCtl = TextEditingController(text: i?.note ?? '');
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountCtl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('amount_invalid'));
      return;
    }
    final choice = _choice;
    if (choice == null) return;
    final month = DateTime(_date.year, _date.month + choice);
    final inc = Income(
      id: widget.income?.id,
      date: _date,
      amount: amount,
      note: _noteCtl.text.trim(),
      isSalary: _isSalary,
      month: month,
    );
    if (_editing) {
      await Db.updateIncome(inc);
    } else {
      await Db.insertIncome(inc);
    }
    if (!mounted) return;
    Navigator.pop(context, month);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_income_title')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Db.deleteIncome(widget.income!.id!);
    if (!mounted) return;
    Navigator.pop(context, widget.income!.month);
  }

  Widget _choiceCard({
    required int value,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selected = _choice == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.secondaryContainer : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => setState(() => _choice = value),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: tt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cur = DateTime(_date.year, _date.month);
    final next = DateTime(_date.year, _date.month + 1);
    final title = _editing
        ? tr('edit_income')
        : (_isSalary ? tr('salary_received') : tr('new_income'));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: tt.titleLarge)),
                if (_editing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: tr('delete'),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtl,
              autofocus: !_editing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              style: tt.headlineSmall,
              decoration: InputDecoration(
                labelText: tr('amount'),
                suffixText: '€',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                toBeginningOfSentenceCase(
                    DateFormat('EEEE d MMMM yyyy', appLang).format(_date))!,
              ),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('is_salary')),
              value: _isSalary,
              onChanged: (v) => setState(() => _isSalary = v),
            ),
            const SizedBox(height: 8),
            Text(tr('when_count'), style: tt.titleSmall),
            const SizedBox(height: 8),
            _choiceCard(
              value: 0,
              title: tr('inc_now'),
              subtitle: tr('inc_now_sub', {'month': monthWord(cur)}),
            ),
            _choiceCard(
              value: 1,
              title: tr('inc_next', {'month': monthWord(next)}),
              subtitle: tr('inc_next_sub', {
                'month': monthWord(next),
                'cur': _cap(monthWord(cur)),
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('note_optional'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _choice == null ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }
}
