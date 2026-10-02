import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/utils/api.dart';

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
    FocusScope.of(context).unfocus();
    final latestAllowed = _latestAllowedBirthDate;
    final firstAllowed = DateTime(1920);
    final initial = _dateOfBirth ?? DateTime(latestAllowed.year - 7, 1, 1);
    final initialDate = initial.isBefore(firstAllowed)
        ? firstAllowed
        : initial.isAfter(latestAllowed)
            ? latestAllowed
            : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstAllowed,
      lastDate: latestAllowed,
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
    if (mounted) setState(() => _isSaving = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              AppTypography.body.copyWith(color: context.palette.textPrimary),
        ),
        backgroundColor: context.palette.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl,
              vertical: AppSpacing.huge,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: AppSpacing.huge),
                    _nameField(),
                    const SizedBox(height: AppSpacing.xxxl),
                    _birthDateField(),
                    const SizedBox(height: AppSpacing.xxxl),
                    _sexPicker(),
                    const SizedBox(height: AppSpacing.huge),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Заполните профиль',
          style: AppTypography.display.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Имя и дата рождения нужны для аккаунта и проверки 18+.',
          style: AppTypography.body.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }

  Widget _nameField() {
    return TextFormField(
      key: const ValueKey('profile-setup-name'),
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.name],
      inputFormatters: [LengthLimitingTextInputFormatter(80)],
      validator: (value) {
        final name = value?.trim() ?? '';
        if (name.isEmpty) return 'Введите имя';
        if (name.length < 2) return 'Имя слишком короткое';
        return null;
      },
      style:
          AppTypography.bodyMedium.copyWith(color: context.palette.textPrimary),
      decoration: _inputDecoration(
        label: 'Имя',
        hint: 'Иван Иванов',
        icon: Icons.person_rounded,
      ),
    );
  }

  Widget _birthDateField() {
    final palette = context.palette;
    final date = _dateOfBirth;
    return Semantics(
      button: true,
      label: 'Дата рождения',
      value: date == null ? 'Не выбрана' : _displayDate(date),
      child: InkWell(
        key: const ValueKey('profile-setup-birthday'),
        borderRadius: AppRadii.lgAll,
        onTap: _pickDate,
        child: InputDecorator(
          decoration: _inputDecoration(
            label: 'Дата рождения',
            hint: 'Выберите дату',
            icon: Icons.cake_rounded,
          ),
          child: Text(
            date == null ? 'Выберите дату' : _displayDate(date),
            style: AppTypography.bodyMedium.copyWith(
              color: date == null ? palette.textSecondary : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sexPicker() {
    final palette = context.palette;
    return DropdownButtonFormField<int>(
      key: const ValueKey('profile-setup-sex'),
      initialValue: _sex,
      isExpanded: true,
      itemHeight: null,
      dropdownColor: palette.surface,
      iconEnabledColor: palette.accent,
      decoration: _inputDecoration(
        label: 'Пол',
        hint: 'Не указан',
        icon: Icons.wc_rounded,
      ),
      style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Не указан')),
        DropdownMenuItem(value: 1, child: Text('Мужской')),
        DropdownMenuItem(value: 2, child: Text('Женский')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _sex = value);
      },
      selectedItemBuilder: (context) => [
        for (final label in const ['Не указан', 'Мужской', 'Женский'])
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label),
          ),
      ],
    );
  }

  Widget _saveButton() {
    final palette = context.palette;
    return FilledButton(
      key: const ValueKey('profile-setup-save'),
      onPressed: _isSaving ? null : _save,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxxl,
        ),
        textStyle: AppTypography.bodyBold,
      ),
      child: _isSaving
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.textOnAccent,
                semanticsLabel: 'Сохраняем профиль',
              ),
            )
          : const Text(
              'Сохранить и продолжить',
              textAlign: TextAlign.center,
            ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final palette = context.palette;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.body.copyWith(color: palette.textSecondary),
      floatingLabelStyle:
          AppTypography.body.copyWith(color: palette.textSecondary),
      prefixIcon: Icon(icon, color: palette.accent, size: 24),
      contentPadding: const EdgeInsets.all(AppSpacing.xxxl),
      errorStyle: AppTypography.bodySmall.copyWith(color: palette.error),
      errorMaxLines: 3,
    );
  }
}
