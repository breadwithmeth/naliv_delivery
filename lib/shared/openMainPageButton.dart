import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/mainPage.dart';

class OpenMainPage extends StatefulWidget {
  const OpenMainPage({super.key});

  @override
  State<OpenMainPage> createState() => _OpenMainPageState();
}

class _OpenMainPageState extends State<OpenMainPage> {
  bool isLoading = false;
  List _addresses = [];
  Map _currentAddress = {};
  List<Map> _businesses = [];
  Map<String, dynamic> user = {};

  Future<List> _getBusinesses() async {
    final businesses = await getBusinesses();
    return businesses ?? [];
  }

  Future<bool> _getAddresses() async {
    final addresses = await getAddresses();

    setState(() {
      _addresses = addresses;
      _currentAddress = addresses.isEmpty
          ? {}
          : _addresses.firstWhere(
              (element) => element["is_selected"] == "1",
              orElse: () => {},
            );
    });
    return true;
  }

  void _navigateToMain() async {
    setState(() => isLoading = true);

    try {
      await _getAddresses();
      final businesses = await _getBusinesses();

      // Находим ближайший магазин
      final closestBusiness = businesses.reduce((curr, next) =>
          double.parse(curr['distance']) < double.parse(next['distance'])
              ? curr
              : next);

      final userData = await getUser();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(
          builder: (context) => MainPage(
            businesses: businesses,
            currentAddress: _currentAddress,
            user: userData!,
            business: closestBusiness,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Ошибка'),
          content: Text('Не удалось загрузить данные'),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: isLoading ? null : _navigateToMain,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: CupertinoColors.activeOrange,
      disabledColor: CupertinoColors.systemGrey4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(right: 10),
              child: CupertinoActivityIndicator(
                color: CupertinoColors.white,
              ),
            ),
          Icon(
            CupertinoIcons.home,
            color: CupertinoColors.white,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Вернуться на главную',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
