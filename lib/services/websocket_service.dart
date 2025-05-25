import 'dart:async';
import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../changelog_handler.dart';
import '../notification_handler.dart';

final websocketService = GetIt.I<WebSocketService>();

/// Encapsulates WebSocket client creation with token auth and requestIds.
class WebSocketService {
  bool _connected = true;
  bool get isConnected => _connected;
  final WebSocketChannel channel;
  final _uuid = Uuid();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final Stream<dynamic> messages;

  WebSocketService._(this.channel)
      : messages = channel.stream.asBroadcastStream() {
    // listen for responses
    messages.listen(_handleMessage);
  }

  /// Creates a WebSocketService using WS_PASSWORD env and optional URL.
  factory WebSocketService.fromEnv({String url = 'ws://localhost:8080/ws'}) {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final token = env['WS_PASSWORD'] ?? 'changeme';
    final uri = Uri.parse('$url?token=$token');
    final channel = IOWebSocketChannel.connect(uri);
    return WebSocketService._(channel);
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
    final rid = _uuid.v4();
    req['requestId'] = rid;
    final completer = Completer<Map<String, dynamic>>();
    _pending[rid] = completer;
    channel.sink.add(jsonEncode(req));
    return completer.future;
  }

  void close() {
    channel.sink.close();
    _connected = false;
  }

  void setConnected(bool connected) {
    _connected = connected;
  }
}
