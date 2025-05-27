import 'package:dotenv/dotenv.dart';
import 'package:nyxx/nyxx.dart';
import 'package:get_it/get_it.dart';
import 'services/websocket_service.dart';

final env = DotEnv(includePlatformEnvironment: true)..load();

class ChangelogHandler {
  /// Discord user ID to DM
  static const Snowflake targetUserId = Snowflake(873144137141088266);
  static bool _listenerRegistered = false;

  final NyxxGateway _client = GetIt.I<NyxxGateway>();

  ChangelogHandler() {
    if (!_listenerRegistered) {
      _listenerRegistered = true;
      _client.onMessageComponentInteraction
          .where((event) =>
              event.interaction.data.type == MessageComponentType.button &&
              event.interaction.data.customId.startsWith('required_'))
          .listen((event) async {
        final cid = event.interaction.data.customId;
        final id = int.tryParse(cid.split('_')[1]);
        if (id == null) {
          return event.interaction.respond(
            MessageBuilder(content: 'Invalid deployment ID'),
            isEphemeral: true,
          );
        }
        await GetIt.I<WebSocketService>().sendRequest({
          'type': 'set_required',
          'deploymentId': id,
        });
        return event.interaction.respond(
          MessageBuilder(content: 'Deployment #$id marked required'),
          isEphemeral: true,
        );
      });
    }
  }

  /// Sends a direct message to the target user.
  Future<void> sendChangeLogNotification(
      String sid, String version, String flavor, int deploymentId) async {
    final NyxxGateway bot = GetIt.I<NyxxGateway>();
    try {
      // Fetch the user and create a DM channel
      final dmChannel = await bot.users.createDm(targetUserId);
      await dmChannel.sendMessage(
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
                style: ButtonStyle.link,
                label: 'Editor',
                url: Uri.parse(
                    'http://${env['HOSTNAME'] ?? 'localhost:8080'}/editor?id=$sid')),
            ButtonBuilder(
                style: ButtonStyle.danger,
                label: 'Make Update Required',
                customId: 'required_$deploymentId')
          ])
        ], embeds: [
          EmbedBuilder(
              title: 'A Changelog is ready to be made!',
              description:
                  'Github actions build for $flavor version $version has completed.',
              color: DiscordColor(0x00FF00),
              author: EmbedAuthorBuilder(
                  name: (await bot.users.fetch(targetUserId)).username,
                  iconUrl: (await bot.users.fetch(targetUserId)).avatar.url),
              footer: EmbedFooterBuilder(
                  text: (await bot.user.fetch()).username,
                  iconUrl: (await bot.user.fetch()).avatar.url),
              timestamp: DateTime.now())
        ]),
      );
    } catch (e) {
      print('[ChangelogHandler] Failed to send DM to $targetUserId: $e');
    }
  }
}
