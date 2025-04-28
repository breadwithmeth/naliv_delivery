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
        middle: Text(
          'Настройки',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'Аккаунт',
                        style: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      backgroundColor: CupertinoColors.systemGroupedBackground,
                      margin: EdgeInsets.zero,
                      children: [
                        _buildListTile(
                          'Выйти из аккаунта',
                          icon: CupertinoIcons.square_arrow_right,
                          onTap: _showLogoutDialog,
                        ),
                        _buildListTile(
                          'Удалить аккаунт',
                          icon: CupertinoIcons.delete,
                          isDestructive: true,
                          onTap: _showDeleteAccountDialog,
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

  Widget _buildListTile(
    String title, {
    IconData? icon,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return CupertinoListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? CupertinoColors.destructiveRed
              : CupertinoColors.label,
          fontSize: 16,
        ),
      ),
      leading: icon != null
          ? Icon(
              icon,
              color: isDestructive
                  ? CupertinoColors.destructiveRed
                  : CupertinoColors.systemGrey,
              size: 22,
            )
          : null,
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: CupertinoColors.systemGrey3,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Выйти из аккаунта?'),
        content: Text(
          'Вы действительно хотите выйти?',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 14,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
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
                  CupertinoPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateAlert) {
          _setupTimer(setStateAlert);

          return CupertinoAlertDialog(
            title: Text('Удалить аккаунт?'),
            content: Column(
              children: [
                Text(
                  'Удаление приведёт к потере всех данных.',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Это действие нельзя отменить!',
                  style: TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: _buildDeleteAccountActions(context),
          );
        },
      ),
    );
  }

  void _setupTimer(StateSetter setStateAlert) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        if (seconds > 0) {
          setStateAlert(() => seconds--);
        } else {
          timer.cancel();
        }
      },
    );
  }

  List<CupertinoDialogAction> _buildDeleteAccountActions(BuildContext context) {
    return [
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
                    CupertinoPageRoute(builder: (context) => Main()),
                    (route) => false,
                  );
                });
              },
        child: Text(
          seconds > 0 ? 'Удалить (${seconds}с)' : 'Удалить',
        ),
      ),
    ];
  }
}
