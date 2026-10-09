import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// REST and optional Socket.IO delivery are owned by the visible support page.
// Neither transport is a background push publisher.
class ChatApiService {
  ChatApiService({http.Client? client, bool enableSocket = true})
      : _client = client ?? http.Client(),
        _enableSocket = enableSocket {
    _instances.add(this);
  }

  static const String _baseUrl = 'https://bm.drawbridge.kz';
  static const String _publicKey = 'wgt_Ioj4vp2arln68wZeSMeyWd4l';
  static const String _prefsSessionKey = 'chat_widget_session';
  static final _instances = <ChatApiService>{};

  final http.Client _client;
  final bool _enableSocket;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionController =
      StreamController<ChatConnectionState>.broadcast();
  final _seenMessageIds = <int>{};
  bool _disposed = false;
  bool _foreground = true;
  bool _identityBound = false;
  bool _polling = false;
  int _historyLoads = 0;
  int _generation = 0;
  String? _identity;
  String? _sessionId;
  String? _sessionToken;
  int? _lastMessageId;
  Timer? _pollTimer;
  Future<bool>? _sessionCreation;
  io.Socket? _socket;
  bool _socketConnected = false;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<ChatConnectionState> get connectionState =>
      _connectionController.stream;
  String? get identity => _identity;
  String? get sessionId => _sessionId;
  bool get isSocketConnected => _socketConnected;
  bool get hasSession =>
      !_disposed && _identityBound && _sessionId != null && _sessionToken != null;

  static String? _identifier(Object? value) {
    if (value is! String && value is! num) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  // Token changes suspend every live capability before another account can act.
  // The owner-labelled persisted capability can be restored only after identity
  // verification, allowing same-account login continuation without reassignment.
  static void suspendAllSessions() {
    for (final service in _instances) {
      service._endSession();
      service._identityBound = false;
    }
  }

  static Future<void> retainSessionsForIdentity(
    String? identity, {
    bool Function()? isCurrent,
  }) async {
    final owner = _identifier(identity);
    for (final service in _instances) {
      if (service._identity != owner) {
        service._endSession();
        service._identityBound = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (isCurrent != null && !isCurrent()) return;
    final session = _readPersistedSession(prefs);
    if (session == null || session['identity'] != owner) {
      await prefs.remove(_prefsSessionKey);
    }
  }

  static Future<void> clearPrivateSessions() async {
    suspendAllSessions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsSessionKey);
  }

  // A push can select an existing owned conversation, never a bearer token or a
  // session belonging to another account. Unowned device-wide legacy data is not
  // migrated into the next account.
  static Future<bool> ownsSession(String sessionId, String identity) async {
    final prefs = await SharedPreferences.getInstance();
    final session = _readPersistedSession(prefs);
    return session != null &&
        session['identity'] == identity &&
        _identifier(session['id']) == sessionId &&
        _identifier(session['token']) != null;
  }

  static Map<String, dynamic>? _readPersistedSession(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsSessionKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('identity')) {
        return decoded;
      }
    } catch (_) {
      // A malformed or unowned session is not a capability we can reuse.
    }
    return null;
  }

  Future<void> init({String? identity}) async {
    if (_disposed) return;
    final owner = _identifier(identity);
    if (!_identityBound || _identity != owner) _endSession();
    _identity = owner;
    _identityBound = true;
    final generation = _generation;
    await _restoreSession(generation);
    if (!_isCurrent(generation)) return;
    if (hasSession && _foreground) {
      _startPolling();
      _connectSocket();
    }
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _stopPolling();
      _disconnectSocket();
    } else if (hasSession) {
      _startPolling();
      _connectSocket();
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && _identityBound && generation == _generation;

  Future<WidgetConfig?> fetchConfig() async {
    if (_disposed) return null;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/widget/$_publicKey/config'))
          .timeout(const Duration(seconds: 8));
      if (_disposed) return null;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final widget = data is Map ? data['widget'] : null;
        if (widget is Map<String, dynamic>) return WidgetConfig.fromJson(widget);
      }
    } catch (e) {
      debugPrint('[ChatApi] Ошибка загрузки конфига: $e');
    }
    return null;
  }

  Future<bool> ensureSession({String? name, String? email, String? phone}) {
    if (hasSession) return Future.value(true);
    if (_disposed || !_identityBound) return Future.value(false);
    return _sessionCreation ??= _createSession(
      _generation,
      name: name,
      email: email,
      phone: phone,
    );
  }

  Future<bool> _createSession(
    int generation, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/widget/$_publicKey/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (!_isCurrent(generation)) return false;
      if (response.statusCode != 201) return false;
      final data = jsonDecode(response.body);
      final session = data is Map ? data['session'] : null;
      if (session is! Map) return false;
      _sessionId = _identifier(session['id']);
      _sessionToken = _identifier(session['token']);
      if (!hasSession) return false;
      await _persistSession(generation);
      if (!_isCurrent(generation)) return false;
      if (_foreground) {
        _startPolling();
        _connectSocket();
      }
      return true;
    } catch (e) {
      debugPrint('[ChatApi] Ошибка создания сессии: $e');
      return false;
    } finally {
      if (generation == _generation) _sessionCreation = null;
    }
  }

  Future<bool> recreateSession({String? name, String? email, String? phone}) async {
    await _clearSession();
    return ensureSession(name: name, email: email, phone: phone);
  }

  Future<bool> updateProfile({String? name, String? email, String? phone}) async {
    if (!hasSession) return false;
    final generation = _generation;
    try {
      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (body.isEmpty) return false;
      final response = await _client
          .patch(
            Uri.parse('$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _isCurrent(generation) && response.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatApi] Ошибка обновления профиля: $e');
      return false;
    }
  }

  Future<SendResult> sendMessage(String text) async {
    if (!hasSession) return const SendResult.failure('Нет активной сессии');
    final generation = _generation;
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/messages'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode({'content': text}),
          )
          .timeout(const Duration(seconds: 10));
      if (!_isCurrent(generation)) {
        return const SendResult.failure('Учётная запись изменилась');
      }
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final message = data is Map ? data['message'] : null;
        if (message is! Map<String, dynamic>) {
          return const SendResult.failure('Пустой ответ сервера');
        }
        final parsed = ChatMessage.fromJson(message);
        if (parsed.id != null) _seenMessageIds.add(parsed.id!);
        // Sending or socket delivery must not move the REST history cursor past
        // an earlier operator reply that has not been fetched yet.
        return SendResult.success(parsed);
      }
      if (response.statusCode == 401) {
        await _clearSession();
        return const SendResult.sessionExpired();
      }
      return SendResult.failure('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[ChatApi] Ошибка отправки: $e');
      return const SendResult.failure('Сетевая ошибка');
    }
  }

  Future<FetchResult> fetchHistory({int limit = 100, bool afterLatest = false}) async {
    if (!hasSession) return const FetchResult.failure('Нет активной сессии');
    final generation = _generation;
    _historyLoads++;
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (afterLatest && _lastMessageId != null) {
        params['afterId'] = _lastMessageId.toString();
      }
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/widget/$_publicKey/sessions/$_sessionId/messages')
                .replace(queryParameters: params),
            headers: {'Authorization': 'Bearer $_sessionToken'},
          )
          .timeout(const Duration(seconds: 10));
      if (!_isCurrent(generation)) {
        return const FetchResult.failure('Учётная запись изменилась');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is Map ? data['messages'] : null;
        if (list is! List || list.any((value) => value is! Map<String, dynamic>)) {
          return const FetchResult.failure('Некорректный ответ сервера');
        }
        final messages = <ChatMessage>[];
        final responseIds = <int>{};
        for (final json in list) {
          final message = ChatMessage.fromJson(json as Map<String, dynamic>);
          final id = message.id;
          _updateLastId(id);
          if (id != null) {
            if (!responseIds.add(id)) continue;
            final unseen = _seenMessageIds.add(id);
            if (afterLatest && !unseen) continue;
          }
          messages.add(message);
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
    } finally {
      _historyLoads--;
    }
  }

  void _startPolling() {
    if (!hasSession || !_foreground) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollTick());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick() async {
    if (!hasSession || !_foreground || _polling || _historyLoads != 0) return;
    final generation = _generation;
    final identity = _identity;
    _polling = true;
    try {
      final result = await fetchHistory(afterLatest: true);
      if (_disposed || !_foreground) return;
      if (generation != _generation) {
        if (result is FetchSessionExpired &&
            _identityBound &&
            _identity == identity &&
            _sessionId == null) {
          _messageController.addError('SESSION_EXPIRED');
        }
        return;
      }
      switch (result) {
        case FetchSuccess(:final messages):
          for (final message in messages) {
            _messageController.add(message);
          }
        case FetchSessionExpired():
          _messageController.addError('SESSION_EXPIRED');
        case FetchFailure(:final error):
          _messageController.addError(error);
      }
    } finally {
      if (generation == _generation) _polling = false;
    }
  }

  void _connectSocket() {
    if (!hasSession || !_foreground || !_enableSocket) return;
    _disconnectSocket();
    final generation = _generation;
    final socket = _socket = io.io(
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
    bool current() => _isCurrent(generation) && _foreground && _socket == socket;
    socket.onConnect((_) {
      if (!current()) return;
      _socketConnected = true;
      _connectionController.add(ChatConnectionState.connected);
    });
    socket.on('message:new', (data) {
      if (!current() || data is! Map<String, dynamic>) return;
      final message = ChatMessage.fromJson(data);
      if (message.id != null && !_seenMessageIds.add(message.id!)) return;
      _messageController.add(message);
    });
    socket.onDisconnect((_) {
      if (!current()) return;
      _socketConnected = false;
      _connectionController.add(ChatConnectionState.disconnected);
    });
    socket.connect();
  }

  void _disconnectSocket() {
    _socket?.dispose();
    _socket = null;
    _socketConnected = false;
  }

  void _updateLastId(int? id) {
    if (id != null && (_lastMessageId == null || id > _lastMessageId!)) {
      _lastMessageId = id;
    }
  }

  Future<void> _persistSession(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(generation)) return;
    final identity = _identity;
    final id = _sessionId;
    await prefs.setString(_prefsSessionKey, jsonEncode({
      'identity': identity,
      'id': id,
      'token': _sessionToken,
    }));
    if (!_isCurrent(generation)) {
      final stored = _readPersistedSession(prefs);
      if (stored?['identity'] == identity && stored?['id'] == id) {
        await prefs.remove(_prefsSessionKey);
      }
    }
  }

  Future<void> _restoreSession(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(generation)) return;
    final data = _readPersistedSession(prefs);
    if (data == null || data['identity'] != _identity) {
      await prefs.remove(_prefsSessionKey);
      return;
    }
    _sessionId = _identifier(data['id']);
    _sessionToken = _identifier(data['token']);
    if (!hasSession) await prefs.remove(_prefsSessionKey);
  }

  void _endSession() {
    _generation++;
    _stopPolling();
    _disconnectSocket();
    _sessionId = null;
    _sessionToken = null;
    _lastMessageId = null;
    _sessionCreation = null;
    _seenMessageIds.clear();
    _polling = false;
  }

  Future<void> _clearSession() async {
    final oldId = _sessionId;
    _endSession();
    final prefs = await SharedPreferences.getInstance();
    final stored = _readPersistedSession(prefs);
    if (stored?['identity'] == _identity && stored?['id']?.toString() == oldId) {
      await prefs.remove(_prefsSessionKey);
    }
  }

  Future<void> resetSession() => _clearSession();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _endSession();
    _instances.remove(this);
    _client.close();
    _messageController.close();
    _connectionController.close();
  }
}

class ChatMessage {
  final int? id;
  final String content;

  // fromMe is true for the operator, false for the visitor in this widget API.
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
    final sender = json['senderUser'];
    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      content: json['content']?.toString() ?? '',
      isFromOperator: fromMe == true || fromMe == 'true',
      operatorName: sender is Map ? sender['name']?.toString() : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }
}

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

class WidgetConfig {
  final String name;
  final String? welcomeMessage;
  final String primaryColor;

  const WidgetConfig({
    required this.name,
    this.welcomeMessage,
    this.primaryColor = '#2563eb',
  });

  factory WidgetConfig.fromJson(Map<String, dynamic> json) => WidgetConfig(
        name: json['name']?.toString() ?? 'Поддержка',
        welcomeMessage: json['welcomeMessage']?.toString(),
        primaryColor: json['primaryColor']?.toString() ?? '#2563eb',
      );
}

enum ChatConnectionState { connected, disconnected }
