import 'package:flutter/material.dart';
import 'package:budgetti/core/constants/category_icons.dart';

/// The ledger's visual language: one category is one colour and one glyph on
/// every surface that renders it, and money reads the same way everywhere.
///
/// Category colours mirror `web/src/finance.ts categoryColorMap` +
/// `web/src/theme.css --cat-1..8` — expense categories take a palette slot by
/// stable name order, income categories are always the positive green. The
/// per-category `colorHex` in the database is deliberately NOT used for
/// rendering: it holds raw Material 500 swatches (`#4CAF50`, `#2196F3`,
/// `#FF9800`, …) picked one per category, which on a dark surface read as eight
/// unrelated hues shouting at each other. `colorHex` stays authoritative for the
/// category editor's own swatch, and stays synced, so nothing is lost.

/// CVD-validated categorical ramp, re-stepped per brightness. Values come from
/// `web/src/theme.css` so a category is the same hue on phone and dashboard.
///
/// ponytail: slots 2 and 4 are both greens, so with more than ~8 expense
/// categories two of them can read alike in a scanning list. The ramp is shared
/// with the web and validated there, so it is not worth forking one side of it;
/// re-step both files together if the collision starts costing reading time.
///
/// ponytail: a slot is an index into the *sorted* category list, so adding a
/// category re-colours the ones after it. Same rule as the web, and it buys
/// guaranteed-distinct colours for the first eight — a name hash would be stable
/// but would collide inside those eight, which is the worse trade.
const List<Color> _catLight = [
  Color(0xFF2A78D6),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFF008300),
  Color(0xFF4A3AA7),
  Color(0xFFE34948),
  Color(0xFFE87BA4),
  Color(0xFFEB6834),
];

const List<Color> _catDark = [
  Color(0xFF3987E5),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFF2A9D2A),
  Color(0xFF9085E9),
  Color(0xFFE66767),
  Color(0xFFD55181),
  Color(0xFFD95926),
];

/// Money in. Mirrors web `--good`.
Color incomeInk(Brightness b) =>
    b == Brightness.dark ? const Color(0xFF34C79C) : const Color(0xFF0B7A5E);

/// Money out. Mirrors web `--danger` (clay, not the theme's `error` — an
/// expense is not an error, and `error` must stay available to mean one).
Color expenseInk(Brightness b) =>
    b == Brightness.dark ? const Color(0xFFE8815F) : const Color(0xFFC2542F);

/// Colour for a transaction amount.
///
/// Rows are overwhelmingly expenses, so painting every one of them clay is
/// noise: in a list the sign already carries direction, and colour is spent
/// marking the exceptions (money in, money merely moved). Side-by-side totals —
/// the hero's INCOME/EXPENSE pair — are the opposite case: there colour is doing
/// comparison work, so use [incomeInk]/[expenseInk] directly.
Color amountInk(
  ColorScheme scheme, {
  required bool isTransfer,
  required bool isIncome,
}) {
  if (isTransfer) return scheme.onSurfaceVariant;
  return isIncome ? incomeInk(scheme.brightness) : scheme.onSurface;
}

/// name → colour for every category, expense slots assigned by stable name
/// order exactly as the web does it.
///
/// Ordering uses a case-folded compare rather than Dart's raw codepoint order,
/// to stay in step with the web's `localeCompare`. The two can still disagree on
/// accented names — a wrong-by-one slot is cosmetic, so it does not earn an
/// ICU dependency here.
Map<String, Color> buildCategoryColors(
  List<({String name, String type})> categories,
  Brightness brightness,
) {
  final ramp = brightness == Brightness.dark ? _catDark : _catLight;
  final expenses = categories.where((c) => c.type != 'income').toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return {
    for (final (i, c) in expenses.indexed) c.name: ramp[i % ramp.length],
    for (final c in categories.where((c) => c.type == 'income'))
      c.name: incomeInk(brightness),
  };
}

/// Fallback for a category that is not in the list (deleted, or a transaction
/// carrying a stale name).
Color unknownCategoryInk(ColorScheme scheme) => scheme.onSurfaceVariant;

/// Codepoints the icon picker actually offers.
///
/// A stored `iconCode` is trusted only if it is still on this menu. Legacy rows
/// carry codepoints from an older Material Icons build that now resolve to
/// unrelated glyphs — that is why "Shopping" was rendering as a boat — and
/// there is no way to tell a stale code from a deliberately chosen one except by
/// asking whether the picker could have produced it. This supersedes
/// `FinanceService._repairDefaultCategoryIcons`, which only ever covered ten
/// hardcoded names on ids shaped `${userId}_cat_<Name>`, so every user-created
/// category (UUID id) stayed broken.
///
/// Maps to the picker's own `const IconData` rather than rebuilding one from
/// the codepoint: `IconData(code)` is opaque to the icon tree-shaker, which
/// fails the release build outright.
final Map<int, IconData> _pickableIcons = {
  for (final group in categoryIconGroups)
    for (final icon in group.icons) icon.codePoint: icon,
};

/// Name fragment → glyph, first match wins, most specific first. Italian and
/// English both, because the user's own categories mix the two.
const List<(List<String>, IconData)> _keywordIcons = [
  (['grocer', 'spesa', 'supermerc', 'alimentar'], Icons.local_grocery_store),
  (
    ['eating', 'dining', 'restaur', 'ristor', 'pizz', 'food', 'cibo', 'bar', 'caff', 'coffee', 'sushi'],
    Icons.restaurant
  ),
  (
    ['fuel', 'carburant', 'benzin', 'diesel', 'gasol', 'distributor'],
    Icons.local_gas_station
  ),
  (
    ['transport', 'trasport', 'car', 'auto', 'train', 'treno', 'bus', 'taxi', 'metro', 'parch', 'parking'],
    Icons.directions_car
  ),
  (['shop', 'negoz', 'abbigl', 'cloth', 'vestit'], Icons.shopping_bag),
  (
    ['entertain', 'svago', 'movie', 'cinema', 'game', 'gioch', 'gioco', 'music', 'event', 'concert', 'teatro'],
    Icons.movie
  ),
  (
    ['health', 'salute', 'medic', 'pharma', 'farmac', 'doctor', 'dentist', 'ospedal'],
    Icons.local_hospital
  ),
  (
    ['bill', 'bollett', 'utenz', 'rent', 'affitt', 'mutuo', 'mortgage', 'insur', 'assicur', 'tax', 'tass'],
    Icons.receipt_long
  ),
  (['home', 'casa', 'house', 'furnit', 'mobil', 'arred'], Icons.home),
  (
    ['travel', 'viaggi', 'vacanz', 'vacation', 'hotel', 'flight', 'volo', 'aere'],
    Icons.flight
  ),
  (['pet', 'animal', 'cane', 'gatto'], Icons.pets),
  (['gym', 'sport', 'fitness', 'palestr'], Icons.fitness_center),
  (['school', 'scuola', 'educat', 'universit', 'cors', 'course', 'libr', 'book'], Icons.school),
  (['gift', 'regal', 'donaz', 'charit'], Icons.card_giftcard),
  (['subscri', 'abbonament', 'streaming', 'netflix', 'spotify'], Icons.subscriptions),
  (['phone', 'telefon', 'internet', 'wifi', 'mobile'], Icons.wifi),
  (['beauty', 'parrucchier', 'barber', 'estetic', 'cura'], Icons.content_cut),
  (['child', 'bambin', 'figli', 'kid', 'baby'], Icons.child_care),
  (['salar', 'stipend', 'paycheck', 'busta'], Icons.payments),
  (['freelance', 'consulen', 'partita'], Icons.laptop_mac),
  (['invest', 'dividend', 'interess', 'interest', 'azion'], Icons.trending_up),
  (['saving', 'risparmi'], Icons.savings),
  (['refund', 'rimbors'], Icons.undo),
  (['other', 'altro', 'misc', 'varie'], Icons.more_horiz),
];

/// Glyph for a category. Falls back to the name when the stored code cannot be
/// trusted, and to a neutral glyph when the name says nothing either — an
/// honest blank beats a confidently wrong boat.
IconData categoryIcon(String name, {int? iconCode, bool isIncome = false}) {
  final picked = iconCode == null ? null : _pickableIcons[iconCode];
  if (picked != null) return picked;
  final needle = name.toLowerCase();
  for (final (fragments, icon) in _keywordIcons) {
    for (final fragment in fragments) {
      if (needle.contains(fragment)) return icon;
    }
  }
  return isIncome ? Icons.payments : Icons.category_outlined;
}
