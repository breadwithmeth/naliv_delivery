import 'package:flutter/material.dart';

Future<bool> showDiagnosticsConsentDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Улучшить приложение'),
            content: const Text('Отправлять анонимные данные о сбоях? Личная информация не собирается.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Нет')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Да')),
            ],
          );
        },
      ) ??
      false;
}
