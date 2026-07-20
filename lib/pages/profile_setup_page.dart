import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/responsive.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.initialUser,
    required this.onCompleted,
  });

  final Map<String, dynamic> initialUser;
  final Future<void> Function(Map<String, dynamic>? refreshedUserInfo)
      onCompleted;

  static bool isRequiredFor(Map<String, dynamic>? userInfo) {
    final user = _userFromInfo(userInfo);
    if (user == null) return false;

    return _stringValue(user['name']).isEmpty ||
        _stringValue(user['date_of_birth'] ??
                user['dateOfBirth'] ??
                user['birth_date'] ??
                user['birthDate'])
            .isEmpty;
  }

  static Map<String, dynamic>? _userFromInfo(Map<String, dynamic>? userInfo) {
    final rawUser = userInfo?['user'];
    if (rawUser is Map<String, dynamic>) return rawUser;
    if (rawUser is Map) {
      return rawUser.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  DateTime? _dateOfBirth;
  int _sex = 0;
  bool _isSaving = false;

  static const int _minimumAge = 18;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    _nameController = TextEditingController(
      text: ProfileSetupPage._stringValue(
        user['name'] ?? user['first_name'] ?? user['firstName'],
      ),
    );
    _dateOfBirth = _parseDate(
      user['date_of_birth'] ??
          user['dateOfBirth'] ??
          user['birth_date'] ??
          user['birthDate'],
    );
    _sex = _parseSex(user['sex']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static int _parseSex(dynamic rawSex) {
    if (rawSex is int && rawSex >= 0 && rawSex <= 2) return rawSex;
    return int.tryParse(rawSex?.toString() ?? '')?.clamp(0, 2) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = ProfileSetupPage._stringValue(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  DateTime get _latestAllowedBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - _minimumAge, now.month, now.day);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _displayDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> _pickDate() async {
    final latestAllowed = _latestAllowedBirthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(latestAllowed.year - 7, 1, 1),
      firstDate: DateTime(1920),
      lastDate: latestAllowed,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.orange,
              surface: AppColors.card,
              onSurface: AppColors.text,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  ({String firstName, String? lastName}) _splitName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return (firstName: name.trim(), lastName: null);

    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : null;
    return (firstName: firstName, lastName: lastName);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth == null) {
      _showMessage('Укажите дату рождения.');
      return;
    }

    if (dateOfBirth.isAfter(_latestAllowedBirthDate)) {
      _showMessage('Сервис доступен только пользователям 18+.');
      return;
    }

    setState(() => _isSaving = true);
    final fullName = _nameController.text.trim();
    final split = _splitName(fullName);
    final result = await ApiService.updateUserProfile(
      name: fullName,
      firstName: split.firstName,
      lastName: split.lastName,
      dateOfBirth: _formatDate(dateOfBirth),
      sex: _sex,
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() => _isSaving = false);
      _showMessage(result.message);
      return;
    }

    final refreshedInfo = await ApiService.getFullInfo();
    if (!mounted) return;
    await widget.onCompleted(refreshedInfo);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 28.s),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        SizedBox(height: 28.s),
                        _nameField(),
                        SizedBox(height: 14.s),
                        _birthDateField(),
                        SizedBox(height: 14.s),
                        _sexPicker(),
                        SizedBox(height: 24.s),
                        _saveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58.s,
          height: 58.s,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18.s),
          ),
          child: Icon(
            Icons.verified_user_rounded,
            color: AppColors.orange,
            size: 31.s,
          ),
        ),
        SizedBox(height: 18.s),
        Text(
          'Заполните профиль',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 26.sp,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        SizedBox(height: 8.s),
        Text(
          'Имя и дата рождения нужны для аккаунта и проверки 18+.',
          style: TextStyle(
            color: AppColors.textMute,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [LengthLimitingTextInputFormatter(80)],
      validator: (value) {
        final name = value?.trim() ?? '';
        if (name.isEmpty) return 'Введите имя';
        if (name.length < 2) return 'Имя слишком короткое';
        return null;
      },
      style: TextStyle(
        color: AppColors.text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: AppColors.orange,
      decoration: _inputDecoration(
        label: 'Имя',
        hint: 'Иван Иванов',
        icon: Icons.person_rounded,
      ),
    );
  }

  Widget _birthDateField() {
    final date = _dateOfBirth;
    return InkWell(
      borderRadius: BorderRadius.circular(14.s),
      onTap: _pickDate,
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Дата рождения',
          hint: 'дд.мм.гггг',
          icon: Icons.cake_rounded,
        ),
        isEmpty: date == null,
        child: Text(
          date == null ? 'Выберите дату' : _displayDate(date),
          style: TextStyle(
            color: date == null
                ? AppColors.textMute.withValues(alpha: 0.55)
                : AppColors.text,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sexPicker() {
    return DropdownButtonFormField<int>(
      initialValue: _sex,
      dropdownColor: AppColors.card,
      iconEnabledColor: AppColors.orange,
      decoration: _inputDecoration(
        label: 'Пол',
        hint: 'Не указан',
        icon: Icons.wc_rounded,
      ),
      style: TextStyle(
        color: AppColors.text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
      items: const [
        DropdownMenuItem(
          value: 0,
          child: Text('Не указан'),
        ),
        DropdownMenuItem(
          value: 1,
          child: Text('Мужской'),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text('Женский'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _sex = value);
      },
      selectedItemBuilder: (context) {
        const labels = ['Не указан', 'Мужской', 'Женский'];
        return [
          for (final label in labels)
            Text(
              label,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ];
      },
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50.s,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.55),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.s),
          ),
          textStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.black,
                ),
              )
            : const Text('Сохранить и продолжить'),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final radius = BorderRadius.circular(14.s);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMute.withValues(alpha: 0.45)),
      labelStyle: const TextStyle(color: AppColors.textMute),
      prefixIcon: Icon(icon, color: AppColors.orange, size: 20.s),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 15.s),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.orange, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.red),
      ),
      errorStyle: TextStyle(color: AppColors.red, fontSize: 11.sp),
    );
  }
}
