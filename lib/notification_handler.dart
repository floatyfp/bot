import 'package:nyxx/nyxx.dart';
import 'package:get_it/get_it.dart';
import 'services/websocket_service.dart';

class NotificationHandler {
  static bool _listenerRegistered = false;

  final NyxxGateway _client = GetIt.I<NyxxGateway>();

  changelogHandler() {
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

  Future<void> sendNotification(String channelId,
      {String? textString,
      String? title,
      String? description,
      String? thumbnail,
      String? image,
      bool? button = false,
      String? buttonText,
      String? buttonUrl}) async {
    final NyxxGateway bot = GetIt.I<NyxxGateway>();
    try {
      // Fetch the user and create a DM channel
      final dmChannel = await bot.channels
          .fetch(Snowflake(int.parse(channelId))) as TextChannel;
      await dmChannel.sendMessage(
        MessageBuilder(content: textString, components: [
          ActionRowBuilder(components: [
            if (button!)
              ButtonBuilder(
                  style: ButtonStyle.link,
                  label: buttonText!,
                  url: Uri.parse(buttonUrl!)),
          ])
        ], embeds: [
          if (title != null ||
              description != null ||
              thumbnail != null ||
              image != null)
            EmbedBuilder(
                title: title,
                description: description,
                color: DiscordColor(0x00FF00),
                footer: EmbedFooterBuilder(
                    text: (await bot.user.fetch()).username,
                    iconUrl: (await bot.user.fetch()).avatar.url),
                timestamp: DateTime.now())
        ]),
      );
    } catch (e) {
      print('[NotificationHandler] Failed to send DM to $channelId: $e');
    }
  }
}
