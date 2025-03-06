import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import '../globals.dart' as globals;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Timer? _timer;
  int seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Настройки'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CupertinoListSection.insetGrouped(
                      children: [
                        CupertinoListTile(
                          title: Text('Выйти из аккаунта'),
                          trailing: Icon(
                            CupertinoIcons.right_chevron,
                            color: CupertinoColors.systemGrey3,
                          ),
                          onTap: () {
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: Text('Выйти из аккаунта?'),
                                content: Text('Вы действительно хотите выйти?'),
                                actions: [
                                  CupertinoDialogAction(
                                    isDefaultAction: false,
                                    child: Text('Отмена'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    child: Text('Выйти'),
                                    onPressed: () {
                                      logout().whenComplete(() {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (context) => LoginPage(),
                                          ),
                                          (route) => false,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        CupertinoListTile(
                          title: Text(
                            'Удалить аккаунт',
                            style: TextStyle(
                              color: CupertinoColors.destructiveRed,
                            ),
                          ),
                          trailing: Icon(
                            CupertinoIcons.right_chevron,
                            color: CupertinoColors.systemGrey3,
                          ),
                          onTap: () {
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => StatefulBuilder(
                                builder: (context, setStateAlert) {
                                  _timer?.cancel();
                                  _timer = Timer(
                                    Duration(seconds: 1),
                                    () {
                                      if (seconds > 0) {
                                        setStateAlert(() => seconds--);
                                      } else {
                                        _timer?.cancel();
                                      }
                                    },
                                  );

                                  return CupertinoAlertDialog(
                                    title: Text('Удалить аккаунт?'),
                                    content: Column(
                                      children: [
                                        Text(
                                          'Удаление приведёт к потере всех данных.\nЭто действие нельзя отменить!',
                                          style: TextStyle(
                                              color: CupertinoColors
                                                  .destructiveRed),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        child: Text('Отмена'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        onPressed: seconds > 0
                                            ? null
                                            : () {
                                                logout();
                                                deleteAccount().then((_) {
                                                  Navigator.pushAndRemoveUntil(
                                                    context,
                                                    CupertinoPageRoute(
                                                      builder: (context) =>
                                                          Main(),
                                                    ),
                                                    (route) => false,
                                                  );
                                                });
                                              },
                                        child: Text(
                                          seconds > 0
                                              ? 'Удалить (${seconds}с)'
                                              : 'Удалить',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
