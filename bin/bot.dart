import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:bot/commands/restart.dart';
import 'package:bot/commands/editor.dart';
import 'package:bot/commands/ping.dart';
import 'package:bot/commands/requestclients.dart';
import 'package:bot/services/websocket_service.dart';
import 'package:bot/services/permission_service.dart';
import 'package:get_it/get_it.dart';
import 'dart:async';
import 'dart:io';
import 'package:bot/commands/permission.dart';
import 'package:dotenv/dotenv.dart';

// Reconnection configuration
const int _maxFastRetries = 10;
const int _fastRetryDelay = 60; // 1 minute
const int _maxSlowRetries = 24; // 24 hours of hourly retries
const int _slowRetryDelay = 3600; // 1 hour

// WebSocket reconnection state
int _reconnectAttempts = 0;
bool _isReconnecting = false;
Timer? _reconnectTimer;

// Global service locator
final getIt = GetIt.instance;

final commandsPlugin = CommandsPlugin(
  prefix: (_) => '/',
  options: CommandsOptions(
    type: CommandType.slashOnly,
  ),
);

// Initialize the bot client
late final NyxxGateway botclient;

void main() async {
  // Load environment variables and initialize permission service
  DotEnv(includePlatformEnvironment: true).load();
  PermissionService();

  // Add commands
  commandsPlugin.addCommand(editor);
  commandsPlugin.addCommand(ping);
  commandsPlugin.addCommand(requestClients);
  commandsPlugin.addCommand(restart);
  commandsPlugin.addCommand(permissionGroup);

  // Initialize WebSocket client
  getIt.registerSingleton<WebSocketService>(
    WebSocketService.fromEnv(),
  );

  websocketService
      .sendRequest({'type': 'identify', 'name': 'bot'})
      .then((resp) => print('Identify ack: $resp'))
      .catchError((e) => print('Identify error: $e'));
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // Initialize the bot client
  botclient = await Nyxx.connectGateway(
    env['BOT_TOKEN'] ?? 'changeme',
    GatewayIntents.guilds |
        GatewayIntents.guildMessages |
        GatewayIntents.messageContent,
    options: GatewayClientOptions(
      plugins: [
        logging,
        cliIntegration,
        ignoreExceptions,
        commandsPlugin,
      ],
    ),
  );

  // Register the bot client with GetIt
  getIt.registerSingleton<NyxxGateway>(botclient);

  // Set up graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down...');
    websocketService.close();
    await botclient.close();
    exit(0);
  });

  // Set up WebSocket connection state listeners
  _setupWebSocketHandlers();
}

void _setupWebSocketHandlers() {
  // Handle connection state changes
  websocketService.connectionState.listen((state) {
    print('WebSocket connection state changed to: $state');

    switch (state) {
      case WebSocketConnectionState.connected:
        _handleConnected();
        break;
      case WebSocketConnectionState.disconnected:
        _handleDisconnected();
        break;
      case WebSocketConnectionState.reconnecting:
        break;
    }
  });

  // Handle connection errors
  websocketService.connectionError.listen((error) {
    print('WebSocket connection error: $error');
    _handleDisconnected();
  });

  // Listen for messages (empty handler to keep the stream active)
  websocketService.messages.listen((_) {});
}

void _handleConnected() {
  print('Successfully connected to WebSocket server');
  _reconnectAttempts = 0; // Reset retry counter on successful connection
  _isReconnecting = false;
  _reconnectTimer?.cancel();
  _reconnectTimer = null;

  // Identify with the WebSocket server
  websocketService
      .sendRequest({'type': 'identify', 'name': 'bot'})
      .then((resp) => print('Identify ack: $resp'))
      .catchError((e) => print('Identify error: $e'));

  // Update bot presence to show it's connected
  botclient.updatePresence(
    PresenceBuilder(
      status: CurrentUserStatus.online,
      isAfk: false,
    ),
  );
}

void _handleDisconnected() {
  if (_isReconnecting) return; // Already reconnecting
  _isReconnecting = true;

  // Update bot presence to show it's retrying
  botclient.updatePresence(
    PresenceBuilder(
      status: CurrentUserStatus.idle,
      isAfk: false,
    ),
  );

  _scheduleReconnect();
}

void _scheduleReconnect() {
  // Cancel any pending reconnect
  _reconnectTimer?.cancel();

  // Check if we've exceeded max retries
  final bool isFastRetry = _reconnectAttempts < _maxFastRetries;
  final bool hasMoreRetries = isFastRetry
      ? _reconnectAttempts < _maxFastRetries + _maxSlowRetries
      : (_reconnectAttempts - _maxFastRetries) < _maxSlowRetries;

  if (!hasMoreRetries) {
    print(
        'Max reconnection attempts ($_reconnectAttempts) reached. Giving up.');
    // Update presence to show permanent failure
    botclient.updatePresence(
      PresenceBuilder(
        status: CurrentUserStatus.dnd,
        isAfk: false,
      ),
    );
    return;
  }

  // Calculate delay based on retry count
  final int delaySeconds = isFastRetry ? _fastRetryDelay : _slowRetryDelay;
  _reconnectAttempts++;

  final retryType = isFastRetry ? 'fast' : 'slow';
  print(
      'Scheduling reconnection attempt $_reconnectAttempts in ${delaySeconds}s ($retryType)');

  // Schedule reconnection
  _reconnectTimer = Timer(Duration(seconds: delaySeconds), _reconnect);
}

Future<void> _reconnect() async {
  if (websocketService.isConnected) {
    print('Already connected, skipping reconnection');
    return;
  }

  try {
    print('Attempting to reconnect to WebSocket server...');
    await websocketService.connect();
  } catch (e) {
    print('Reconnection attempt failed: $e');
    _scheduleReconnect();
  }
}
