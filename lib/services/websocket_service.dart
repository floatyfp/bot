import 'dart:async';
import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../changelog_handler.dart';
import '../notification_handler.dart';

/// Represents the connection state of the WebSocket
enum WebSocketConnectionState {
  connected,
  disconnected,
  reconnecting,
}

final websocketService = GetIt.I<WebSocketService>();

/// Encapsulates WebSocket client creation with token auth and requestIds.
class WebSocketService {
  bool _connected = false;
  bool get isConnected => _connected;
  WebSocketChannel? _channel;
  final _uuid = Uuid();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  late Stream<dynamic> messages;
  final String _url;
  final String _token;
  final _connectionController =
      StreamController<WebSocketConnectionState>.broadcast();

  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionController.stream;

  /// Stream of connection errors
  final _errorController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get connectionError => _errorController.stream;

  WebSocketService._(this._url, this._token) {
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse('$_url?token=$_token');
      _channel = IOWebSocketChannel.connect(uri);
      messages = _channel!.stream.asBroadcastStream();
      _connected = true;
      _connectionController.add(WebSocketConnectionState.connected);

      // Listen for messages
      messages.listen(
        _handleMessage,
        onError: (error) {
          _errorController.add(error);
          _handleDisconnect();
        },
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (e) {
      _errorController.add(e);
      _handleDisconnect();
      rethrow;
    }
  }

  void _handleDisconnect() {
    if (_connected) {
      _connected = false;
      _connectionController.add(WebSocketConnectionState.disconnected);
    }
  }

  /// Creates a WebSocketService using WS_PASSWORD env and optional URL.
  factory WebSocketService.fromEnv() {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final token = env['WS_PASSWORD'] ?? 'changeme';
    return WebSocketService._(env['WS_URL'] ?? 'ws://localhost:8080/ws', token);
  }

  /// Connect or reconnect to the WebSocket server
  Future<void> connect() async {
    if (_connected) return;
    _connect();
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final rid = msg['requestId'] as String?;
    if (rid != null && _pending.containsKey(rid)) {
      _pending.remove(rid)!.complete(msg);
      return;
    }
    // Handle changelog session notification
    if (msg['type'] == 'changelog_session_created') {
      final sessionId = msg['sessionId'] as String?;
      final version = msg['version'] as String?;
      final flavor = msg['flavor'] as String?;
      final deploymentId = msg['deploymentId'] as int?;
      print(
          '[BOT] New changelog session: sessionId=$sessionId, version=$version, flavor=$flavor');
      ChangelogHandler().sendChangeLogNotification(
          sessionId!, version!, flavor!, deploymentId!);
    }
    // Handle notifications
    if (msg['type'] == 'notification') {
      final id = msg['id'] as String?;
      final textString = msg['textString'] as String?;
      final title = msg['title'] as String?;
      final description = msg['description'] as String?;
      final thumbnail = msg['thumbnail'] as String?;
      final image = msg['image'] as String?;
      final button = msg['button'] as bool?;
      final buttonText = msg['buttonText'] as String?;
      final buttonUrl = msg['buttonUrl'] as String?;
      print(
          '[BOT] New notification: title=$title, description=$description, thumbnail=$thumbnail, image=$image');
      if (id == null) return;
      NotificationHandler().sendNotification(id,
          textString: textString,
          title: title,
          description: description,
          thumbnail: thumbnail,
          image: image,
          button: button,
          buttonText: buttonText,
          buttonUrl: buttonUrl);
    }
  }

  /// Sends a JSON request with unique requestId and returns a Future for the response.
  Future<Map<String, dynamic>> sendRequest(Map<String, dynamic> req) {
    if (!_connected || _channel == null) {
      return Future.error('Not connected to WebSocket server');
    }

    final rid = _uuid.v4();
    req['requestId'] = rid;
    final completer = Completer<Map<String, dynamic>>();
    _pending[rid] = completer;
    _channel!.sink.add(jsonEncode(req));

    // Set a timeout for the request
    Future.delayed(const Duration(seconds: 30), () {
      if (_pending.containsKey(rid)) {
        _pending
            .remove(rid)
            ?.completeError(TimeoutException('Request timed out'));
      }
    });

    return completer.future;
  }

  Future<void> close() async {
    try {
      await _channel?.sink.close();
    } finally {
      _connected = false;
      _channel = null;
      _connectionController.add(WebSocketConnectionState.disconnected);
    }
  }

  void setConnected(bool connected) {
    if (_connected != connected) {
      _connected = connected;
      _connectionController.add(
        connected
            ? WebSocketConnectionState.connected
            : WebSocketConnectionState.disconnected,
      );
    }
  }
}
