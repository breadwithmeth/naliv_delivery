import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Сервис для работы с публичным REST API чата поддержки.
///
/// Основной механизм получения ответов — polling каждые 4 секунды.
/// Socket.IO подключается опционально для мгновенной доставки.
///
/// Схема:
/// 1. GET  /api/widget/:publicKey/config
/// 2. POST /api/widget/:publicKey/sessions      → 201
/// 3. GET  /api/widget/:publicKey/sessions/:id/messages?afterId=N
/// 4. POST /api/widget/:publicKey/sessions/:id/messages
class ChatApiService {
  // ─── Конфигурация ───────────────────────────────────────────────────
  static const String _baseUrl = 'https://bm.drawbridge.kz';

  /// Публичный ключ виджета (замени на реальный).
  static const String _publicKey = 'wgt_Ioj4vp2arln68wZeSMeyWd4l';

  // ─── Ключи SharedPreferences ────────────────────────────────────────
  static const String _prefsSessionKey = 'chat_widget_session';

  // ─── Приватное состояние ────────────────────────────────────────────
  String? _sessionId;
  String? _sessionToken;
  int? _lastMessageId;
  Timer? _pollTimer;

  io.Socket? _socket;
  bool _socketConnected = false;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionController =
      StreamController<ChatConnectionState>.broadcast();

  /// Поток входящих сообщений.
  Stream<ChatMessage> get messages => _messageController.stream;

  /// Поток состояния Socket.IO подключения.
  Stream<ChatConnectionState> get connectionState =>
      _connectionController.stream;

  String? get sessionId => _sessionId;
  bool get isSocketConnected => _socketConnected;
  bool get hasSession => _sessionId != null && _sessionToken != null;

  // ═══════════════════════════════════════════════════════════════════
  // Инициализация
  // ═══════════════════════════════════════════════════════════════════

  /// Восстанавливает сессию из SharedPreferences и запускает polling.
  Future<void> init() async {
    await _restoreSession();
    if (hasSession) {
      _startPolling();
      _connectSocket();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Конфигурация виджета
  // ═══════════════════════════════════════════════════════════════════

  Future<WidgetConfig?> fetchConfig() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/widget/$_publicKey/config');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WidgetConfig.fromJson(data['widget'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[ChatApi] Ошибка загрузки конфига: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Сессия
  // ═══════════════════════════════════════════════════════════════════

  /// Создаёт новую сессию посетителя. Возвращает true при успехе.
  Future<bool> ensureSession({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (hasSession) return true;

    try {
      final uri = Uri.parse('$_baseUrl/api/widget/$_publicKey/sessions');
      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body.isNotEmpty ? jsonEncode(body) : '{}',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _sessionId = data['session']?['id']?.toString();
        _sessionToken = data['session']?['token']?.toString();

        if (_sessionId != null && _sessionToken != null) {
          await _persistSession();
          _startPolling();
          _connectSocket();
          debugPrint('[ChatApi] Сессия создана: $_sessionId');
          return true;
        }
      }
      debugPrint(
          '[ChatApi] Ошибка создания сессии: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[ChatApi] Ошибка создания сессии: $e');
      return false;
    }
  }

  /// Пересоздаёт сессию после 401 или ротации ключа.
  Future<bool> recreateSession({
    String? name,
    String? email,
    String? phone,
  }) async {
    await _clearSession();
    return ensureSession(name: name, email: email, phone: phone);
  }

  /// Обновляет профиль посетителя в сессии.
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (!hasSession) return false;

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/profile',
      );
      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;

      if (body.isEmpty) return false;

      debugPrint('[ChatApi] PATCH profile: $body');

      final response = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[ChatApi] Профиль обновлён');
        return true;
      }
      debugPrint(
          '[ChatApi] Ошибка обновления профиля: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[ChatApi] Ошибка обновления профиля: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Сообщения
  // ═══════════════════════════════════════════════════════════════════

  /// Отправляет текстовое сообщение.
  Future<SendResult> sendMessage(String text) async {
    if (!hasSession) return const SendResult.failure('Нет активной сессии');

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/messages',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode({'content': text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final msg = data['message'];
        if (msg != null) {
          final cm = ChatMessage.fromJson(msg as Map<String, dynamic>);
          _updateLastId(cm.id);
          // НЕ добавляем в стрим — страница получит через SendResult
          return SendResult.success(cm);
        }
        return const SendResult.failure('Пустой ответ сервера');
      }

      if (response.statusCode == 401) {
        await _clearSession();
        return const SendResult.sessionExpired();
      }

      debugPrint('[ChatApi] Ошибка отправки: ${response.statusCode}');
      return SendResult.failure('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[ChatApi] Ошибка отправки: $e');
      return const SendResult.failure('Сетевая ошибка');
    }
  }

  /// Загружает историю сообщений (полную или с afterId).
  Future<FetchResult> fetchHistory({int limit = 100}) async {
    if (!hasSession) return const FetchResult.failure('Нет активной сессии');

    try {
      final params = <String, String>{'limit': limit.toString()};
      if (_lastMessageId != null) {
        params['afterId'] = _lastMessageId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/messages',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_sessionToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['messages'] as List<dynamic>? ?? [];
        final messages = list
            .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
            .toList();

        for (final m in messages) {
          _updateLastId(m.id);
        }
        return FetchResult.success(messages);
      }

      if (response.statusCode == 401 || response.statusCode == 404) {
        await _clearSession();
        return const FetchResult.sessionExpired();
      }

      return FetchResult.failure('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[ChatApi] Ошибка загрузки истории: $e');
      return const FetchResult.failure('Сетевая ошибка');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Polling
  // ═══════════════════════════════════════════════════════════════════

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollTick();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick() async {
    if (!hasSession) return;

    final result = await fetchHistory();
    switch (result) {
      case FetchSuccess(:final messages):
        for (final m in messages) {
          _messageController.add(m);
        }
      case FetchSessionExpired():
        _messageController.addError('SESSION_EXPIRED');
      case FetchFailure():
        break; // тихая ошибка polling
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Socket.IO (опционально)
  // ═══════════════════════════════════════════════════════════════════

  void _connectSocket() {
    if (!hasSession) return;

    _socket?.dispose();
    _socket = io.io(
      '$_baseUrl/widget',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({
            'publicKey': _publicKey,
            'sessionId': _sessionId,
            'token': _sessionToken,
          })
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      _socketConnected = true;
      _connectionController.add(ChatConnectionState.connected);
      debugPrint('[ChatApi] Socket.IO подключён');
    });

    _socket!.on('connected', (_) {
      debugPrint('[ChatApi] Сессия Socket.IO авторизована');
    });

    _socket!.on('message:new', (data) {
      if (data is Map<String, dynamic>) {
        final msg = ChatMessage.fromJson(data);
        _updateLastId(msg.id);
        _messageController.add(msg);
      }
    });

    _socket!.onDisconnect((_) {
      _socketConnected = false;
      _connectionController.add(ChatConnectionState.disconnected);
      debugPrint('[ChatApi] Socket.IO отключён');
    });

    _socket!.onConnectError((err) {
      debugPrint('[ChatApi] Ошибка Socket.IO: $err');
    });

    _socket!.connect();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Persistence
  // ═══════════════════════════════════════════════════════════════════

  void _updateLastId(int? id) {
    if (id != null && (_lastMessageId == null || id > _lastMessageId!)) {
      _lastMessageId = id;
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsSessionKey,
        jsonEncode({
          'id': _sessionId,
          'token': _sessionToken,
        }));
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsSessionKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _sessionId = data['id']?.toString();
      _sessionToken = data['token']?.toString();
      if (_sessionId != null) {
        debugPrint('[ChatApi] Сессия восстановлена: $_sessionId');
      }
    } catch (_) {
      await prefs.remove(_prefsSessionKey);
    }
  }

  Future<void> _clearSession() async {
    _stopPolling();
    _socket?.dispose();
    _socket = null;
    _socketConnected = false;
    _sessionId = null;
    _sessionToken = null;
    _lastMessageId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsSessionKey);
    debugPrint('[ChatApi] Сессия сброшена');
  }

  /// Публичный сброс сессии.
  Future<void> resetSession() => _clearSession();

  /// Закрывает все ресурсы.
  void dispose() {
    _stopPolling();
    _socket?.dispose();
    _messageController.close();
    _connectionController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Модели данных
// ═══════════════════════════════════════════════════════════════════

/// Сообщение чата.
class ChatMessage {
  final int? id;
  final String content;

  /// `fromMe: true` — ответ оператора, `fromMe: false` — сообщение посетителя.
  final bool isFromOperator;
  final String? operatorName;
  final DateTime? timestamp;
  final String? status;

  const ChatMessage({
    this.id,
    required this.content,
    required this.isFromOperator,
    this.operatorName,
    this.timestamp,
    this.status,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final fromMe = json['fromMe'];
    final isOperator = fromMe == true || fromMe == 'true';
    final sender = json['senderUser'];

    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      content: json['content']?.toString() ?? '',
      isFromOperator: isOperator,
      operatorName: sender is Map ? sender['name']?.toString() : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }

  factory ChatMessage.local(String text) {
    return ChatMessage(
      content: text,
      isFromOperator: false,
      timestamp: DateTime.now(),
    );
  }
}

/// Результат отправки сообщения.
sealed class SendResult {
  const SendResult();
  const factory SendResult.success(ChatMessage message) = SendSuccess;
  const factory SendResult.failure(String error) = SendFailure;
  const factory SendResult.sessionExpired() = SendSessionExpired;
}

class SendSuccess extends SendResult {
  final ChatMessage message;
  const SendSuccess(this.message);
}

class SendFailure extends SendResult {
  final String error;
  const SendFailure(this.error);
}

class SendSessionExpired extends SendResult {
  const SendSessionExpired();
}

/// Результат загрузки истории.
sealed class FetchResult {
  const FetchResult();
  const factory FetchResult.success(List<ChatMessage> messages) = FetchSuccess;
  const factory FetchResult.failure(String error) = FetchFailure;
  const factory FetchResult.sessionExpired() = FetchSessionExpired;
}

class FetchSuccess extends FetchResult {
  final List<ChatMessage> messages;
  const FetchSuccess(this.messages);
}

class FetchFailure extends FetchResult {
  final String error;
  const FetchFailure(this.error);
}

class FetchSessionExpired extends FetchResult {
  const FetchSessionExpired();
}

/// Конфигурация виджета.
class WidgetConfig {
  final String name;
  final String? welcomeMessage;
  final String primaryColor;

  const WidgetConfig({
    required this.name,
    this.welcomeMessage,
    this.primaryColor = '#2563eb',
  });

  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    return WidgetConfig(
      name: json['name']?.toString() ?? 'Поддержка',
      welcomeMessage: json['welcomeMessage']?.toString(),
      primaryColor: json['primaryColor']?.toString() ?? '#2563eb',
    );
  }
}

/// Состояние Socket.IO подключения.
enum ChatConnectionState { connected, disconnected }
