import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/preLoadDataPage2.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _number = "";
  bool _isLoading = false;
  bool isCodeSend = false;

  Future<void> _getOneTimeCode() async {
    await getOneTimeCode("+7$_number").then(
      (value) {
        setState(() {
          _isLoading = false;
          isCodeSend = true;
        });
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => VerifyPage(phone: "+7$_number"),
          ),
        );
      },
    );
  }

  Widget buildNumPadDigitWidget(String digit, BoxConstraints constraints) {
    return Container(
      margin: EdgeInsets.all(4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Container(
          height: constraints.maxHeight * 0.18,
          width: constraints.maxWidth * 0.28,
          decoration: BoxDecoration(
            color:
                CupertinoColors.secondarySystemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
        onPressed: () {
          if (_number.length < 10) {
            setState(() {
              _number += digit;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Container()),
                      Flexible(
                        flex: 3,
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            "+7$_number",
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      Flexible(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _number = "";
                            });
                          },
                          child: Icon(CupertinoIcons.clear_circled),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      "Введите номер телефона, для получения кода верификации",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Spacer(
                  flex: 3,
                ),
                Flexible(
                  flex: 10,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["1", "2", "3"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["4", "5", "6"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["7", "8", "9"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                margin: EdgeInsets.all(4),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: constraints.maxHeight * 0.18,
                                    width: constraints.maxWidth * 0.28,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors
                                          .tertiarySystemBackground
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        CupertinoIcons.delete_left,
                                        color: CupertinoColors.systemGrey
                                            .resolveFrom(context),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (_number.isNotEmpty) {
                                        _number = _number.substring(
                                            0, _number.length - 1);
                                      }
                                    });
                                  },
                                ),
                              ),
                              buildNumPadDigitWidget("0", constraints),
                              Container(
                                margin: EdgeInsets.all(4),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    height: constraints.maxHeight * 0.18,
                                    width: constraints.maxWidth * 0.28,
                                    decoration: BoxDecoration(
                                      color: _number.length == 10
                                          ? CupertinoColors.activeOrange
                                          : CupertinoColors.systemGrey6
                                              .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        CupertinoIcons.arrow_right,
                                        color: _number.length == 10
                                            ? CupertinoColors.white
                                            : CupertinoColors.systemGrey,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  onPressed: _number.length == 10
                                      ? () {
                                          setState(() {
                                            _isLoading = true;
                                          });
                                          _getOneTimeCode();
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: CupertinoColors.systemBackground.withOpacity(0.5),
                child: Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.phone});
  final String phone;
  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  String _code = "";
  bool _isLoading = false;

  _verify() {
    verify(widget.phone, _code).then((value) {
      if (value) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => Preloaddatapage2()),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Widget buildNumPadDigitWidget(String digit, BoxConstraints constraints) {
    return Container(
      margin: EdgeInsets.all(5),
      height: constraints.maxHeight * 0.2,
      width: constraints.maxWidth * 0.3,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Container(
          height: constraints.maxHeight * 0.18,
          width: constraints.maxWidth * 0.28,
          decoration: BoxDecoration(
            color:
                CupertinoColors.secondarySystemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
        onPressed: () {
          if (_code.length < 10) {
            setState(() {
              _code += digit;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Flexible(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      _code,
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    alignment: Alignment.center,
                    child: CupertinoButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Изменить ${widget.phone}",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text("Введите код"),
                  ),
                ),
                Flexible(
                  flex: 10,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["1", "2", "3"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["4", "5", "6"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i in ["7", "8", "9"])
                                buildNumPadDigitWidget(i, constraints),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: constraints.maxHeight * 0.2,
                                width: constraints.maxWidth * 0.3,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _code = "";
                                    });
                                  },
                                  child: Icon(CupertinoIcons.clear),
                                ),
                              ),
                              buildNumPadDigitWidget("0", constraints),
                              Container(
                                height: constraints.maxHeight * 0.2,
                                width: constraints.maxWidth * 0.3,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    _verify();
                                  },
                                  child: Icon(CupertinoIcons.arrow_right),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: CupertinoColors.systemBackground.withOpacity(0.5),
                child: Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
