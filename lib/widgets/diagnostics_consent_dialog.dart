import 'package:flutter/material.dart';

Future<bool> showDiagnosticsConsentDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Анонимная диагностика'),
            content: const Text(
              'Помочь нам быстрее находить и исправлять ошибки в приложении? '
              'Мы будем получать только техническую информацию о сбоях и работе приложения, без имени, телефона, email, адреса, координат и других личных данных. '
              'Настройку можно изменить позже в профиле.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Не разрешать')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Разрешить')),
            ],
          );
        },
      ) ??
      false;
}
