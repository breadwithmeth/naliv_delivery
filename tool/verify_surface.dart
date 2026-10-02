// Development-only fixture capture and comparison. Never launches the real app.
// Usage: dart run tool/verify_surface.dart [surface|all] [--theme dark|light|both]
import 'dart:io';
import 'package:path/path.dart' as path;

// Exact frame names from the Figma export/spec index. The exporter writes
// shots/<slug(page)>__<slug(frame)>.png (tool/figma_spec.dart).
const surfaceReferenceFrames = <String, String?>{
  'home': 'Главная - Без входа в аккаунт',
  'catalog': 'Каталог',
  'all_products': 'Каталог - Все товары',
  'cart': 'Корзина',
  'profile': 'Профиль',
  'profile_guest': 'Профиль',
  'promotion': null,
  'orders': 'История заказов',
  'order_detail': 'История заказов - Карточка заказа',
  'support': 'Поддержка',
  'certificates': 'Сертификаты',
  'onboarding': null,
  'addresses': 'Адреса - Добавленный адрес',
  'address_map': 'Адреса - Карта',
  'address_details': 'Адреса - Детали адреса - Заполненное поле',
  'cards': 'Карты - Добавленные карты',
  'payment_method': null,
  'payment_kaspi': null,
  'checkout_delivery': 'Корзина - Доставка - Скролл ниже 1',
  'checkout_pickup': 'Корзина - Самовывоз',
  'checkout_error': null,
  'certificate_purchase': 'Сертификаты - Купить сертификат',
  'product_options': null,
  'product_pour': null,
  'payment_success': 'Корзина - Оплата прошла успешно',
  'product_pour_real': null,
  'product_pour_gift': null,
  'product_pour_three_plus_one': null,
  'product_pour_fractional': null,
  'product_replacement': null,
  'search': 'Поиск - Пустое поле',
  'favorites': 'Избранное - Список пуст',
  'bonus_history': 'История бонусов - История бонусов',
  'bonus_explainer': 'История бонусов - Как работают бонусы',
  'faq': 'FAQ',
  'notifications': null,
  'intro': 'Регистрация и логин - Слайд 1',
  'sign_in': 'Регистрация и логин - Вход по номеру телефона ',
  'profile_setup': null,
  'startup': null,
  'active_route': null,
};

String surfaceReferencePath(String surface, String theme) {
  final frame = surfaceReferenceFrames[surface];
  if (frame == null || (theme != 'dark' && theme != 'light')) {
    throw ArgumentError('Unknown surface/theme: $surface/$theme');
  }
  final page = theme == 'dark' ? 'Dark' : 'Light';
  return path.join(
      '.figma_cache', 'shots', 'Design_System__${page}___${frame.trim()}.png');
}

String surfaceCapturePath(String surface, String theme) =>
    '.figma_cache/render/current_${surface}_$theme.png';

String surfaceDiffPath(String surface, String theme) =>
    '.figma_cache/render/diff_${surface}_$theme.png';

const _usage =
    '''Compare development-only fixture screenshots against Figma exports.

Usage: dart run tool/verify_surface.dart [surface|all] [--theme dark|light|both]
Surfaces: home, catalog, all_products, cart, profile, profile_guest, promotion,
          orders, order_detail, support, certificates, onboarding, addresses,
          address_map, address_details, cards, payment_method, checkout_delivery,
          checkout_pickup, checkout_error, certificate_purchase, product_options,
          product_pour, payment_success, product_pour_real, product_pour_gift,
          product_pour_fractional, product_replacement, search, favorites,
          bonus_history, bonus_explainer, faq, notifications, intro, sign_in,
          profile_setup, startup, active_route (default: all)
Themes: dark (default), light, both

Captures fixtures first, then reports visual metrics and writes heatmaps to
.figma_cache/render/. These are NOT active-route or pixel-perfectness claims.
Surfaces without an exact Figma frame are capture-only; no borrowed-frame metric.
Light exports must be available from tool/figma_spec.dart png; legacy
light_*.png snapshots are not used.''';

Future<void> main(List<String> args) async {
  String surface = 'all';
  String theme = 'dark';
  var positional = false;
  var themeProvided = false;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      stdout.writeln(_usage);
      return;
    }
    if (arg == '--theme' || arg.startsWith('--theme=')) {
      if (themeProvided) return _usageError('Duplicate --theme');
      themeProvided = true;
      if (arg == '--theme') {
        if (++i >= args.length) return _usageError('Missing --theme value');
        theme = args[i];
      } else {
        theme = arg.substring('--theme='.length);
      }
    } else if (!arg.startsWith('-') && !positional) {
      positional = true;
      surface = arg;
    } else {
      return _usageError('Unexpected argument: $arg');
    }
  }
  if (surface != 'all' && !surfaceReferenceFrames.containsKey(surface)) {
    return _usageError('Unknown surface: $surface');
  }
  if (theme != 'dark' && theme != 'light' && theme != 'both') {
    return _usageError('Unknown theme: $theme');
  }
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this command from the Flutter project root.');
    exitCode = 66;
    return;
  }

  final surfaces =
      surface == 'all' ? surfaceReferenceFrames.keys.toList() : [surface];
  final themes = theme == 'both' ? ['dark', 'light'] : [theme];
  final pairs = [
    for (final t in themes)
      for (final s in surfaces) (s, t)
  ];
  // Remove only selected artifacts, so neither a failed capture nor a failed
  // comparison can leave a stale image that looks like this run succeeded.
  for (final (s, t) in pairs) {
    for (final path in [surfaceCapturePath(s, t), surfaceDiffPath(s, t)]) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
  }
  final missing = [
    for (final (s, t) in pairs)
      if (surfaceReferenceFrames[s] != null &&
          !File(surfaceReferencePath(s, t)).existsSync())
        surfaceReferencePath(s, t),
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Missing Figma PNG export(s):\n${missing.join('\n')}');
    stderr.writeln(
        'Export the matching Figma frames with dart run tool/figma_spec.dart png.');
    exitCode = 66;
    return;
  }

  stdout.writeln('Fixture screenshots only; this does not verify live routes.');
  for (final (s, t) in pairs) {
    if (surfaceReferenceFrames[s] == null) {
      stdout.writeln('$s/$t: capture-only; no matching Figma frame.');
    }
  }
  final defines = [
    '--dart-define=SURFACE=$surface',
    '--dart-define=SURFACE_THEME=$theme'
  ];
  try {
    final capture =
        await _flutterTest('tool/design/surface_capture_test.dart', defines);
    if (capture != 0) {
      exitCode = capture;
      return;
    }
    final uncaptured = [
      for (final (s, t) in pairs)
        if (!File(surfaceCapturePath(s, t)).existsSync())
          surfaceCapturePath(s, t),
    ];
    if (uncaptured.isNotEmpty) {
      stderr.writeln(
          'Capture did not produce expected PNG(s):\n${uncaptured.join('\n')}');
      exitCode = 66;
      return;
    }
    if (pairs.every((pair) => surfaceReferenceFrames[pair.$1] == null)) return;
    exitCode =
        await _flutterTest('tool/design/surface_compare_test.dart', defines);
  } on ProcessException catch (error) {
    stderr.writeln('Could not start Flutter test runner: $error');
    exitCode = 70;
  } on FileSystemException catch (error) {
    stderr.writeln('Could not prepare fixture images: $error');
    exitCode = 74;
  }
}

void _usageError(String message) {
  stderr.writeln('$message\n\n$_usage');
  exitCode = 64;
}

Future<int> _flutterTest(String path, List<String> defines) async {
  stdout.writeln('Running flutter test $path (${defines.join(' ')})');
  final process = await Process.start(
    'flutter',
    ['test', path, ...defines],
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
