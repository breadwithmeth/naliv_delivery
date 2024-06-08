// import 'package:flutter/material.dart';
import '../globals.dart'
    as globals;// import 'package:naliv_delivery/misc/api.dart';
// import 'package:naliv_delivery/pages/addressesPage.dart';
// import 'package:naliv_delivery/pages/loginPage.dart';
// import 'package:naliv_delivery/pages/settingsPage.dart';

// class ProfilePage extends StatefulWidget {
//   const ProfilePage({super.key});

//   @override
//   State<ProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<ProfilePage> {
//   Map user = {};
//   Future<void> _getUser() async {
//     Map<String, dynamic>? user = await getUser();
//     if (user != null) {
//       setState(() {
//         user = user;
//       });
//     }
//   }

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _getUser();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
//             child: Row(
//               children: [
//                 CircleAvatar(
//                   radius: MediaQuery.of(context).size.width * 0.15,
//                   backgroundImage: const NetworkImage(
//                       "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg"),
//                 ),
//                 const SizedBox(
//                   width: 20,
//                 ),
//                 SizedBox(
//                   width: MediaQuery.of(context).size.width * 0.3,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         user["name"] ?? "",
//                         style: const TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w500,
//                             fontSize: 16),
//                       ),
//                       Text(
//                         user["login"] ?? "",
//                         style: const TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 14),
//                       ),
//                       Text(
//                         user["user_id"] ?? "",
//                         style: TextStyle(
//                             color: Colors.grey.shade400,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 14),
//                       )
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
//             child: Column(
//               children: [
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {},
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.shopping_bag_outlined,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "История заказов",
//                         style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//                 const Divider(),
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {
//                     // Navigator.push(
//                     //   context,
//                     //   CupertinoPageRoute(
//                     //       builder: (context) => const AddressesPage()),
//                     // );
//                   },
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.home_outlined,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "Адреса доставки",
//                         style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//                 const Divider(),
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {},
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.credit_card,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "Карты оплаты",
//                         style: TextStyle(
//                             color: Colors.grey,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//                 const Divider(),
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {
//                     Navigator.push(context, CupertinoPageRoute(
//                       builder: (context) {
//                         return const SettingsPage();
//                       },
//                     ));
//                   },
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.settings_outlined,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "Настройки",
//                         style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//                 const Divider(),
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {},
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.chat_bubble_outline,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "Поддержка",
//                         style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//                 const Divider(),
//                 TextButton(
//                   style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 20)),
//                   onPressed: () {
//                     print(123);
//                     logout();
//                     Navigator.pushReplacement(context, CupertinoPageRoute(
//                       builder: (context) {
//                         return const LoginPage();
//                       },
//                     ));
//                   },
//                   child: const Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.exit_to_app_outlined,
//                         size: 24,
//                         color: Colors.black,
//                       ),
//                       SizedBox(
//                         width: 10,
//                       ),
//                       Text(
//                         "Выйти",
//                         style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.w400,
//                             fontSize: 20),
//                       )
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
