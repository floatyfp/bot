import 'package:bot/services/websocket_service.dart';
import 'package:get_it/get_it.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import '../services/cmd_permission_check_service.dart';
import '../models/permission_level.dart';

final editor = ChatGroup(
  'editor',
  'Editor Commands',
  children: [
    editorCreate,
    editorEditPost,
    editorDeletePost,
    recoverDeploy,
  ],
);

/// Chat command to create a new editor session.
final editorDeletePost = ChatCommand(
  'delete',
  '[ADMIN] Delete a post or changelog',
  (ChatContext context, String slug, bool changelog) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    if (!websocketService.isConnected) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(
            content: 'WebSocket client is not connected', embeds: []),
      );
      return;
    }
    if (changelog) {
      final delbutton = ComponentId.generate(allowedUser: context.user.id);
      await context.respond(
        level: ResponseLevel(
            hideInteraction: true,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
              style: ButtonStyle.danger,
              label: 'Delete',
              customId: delbutton.toString(),
            )
          ])
        ], embeds: [
          EmbedBuilder(
              title: 'Are you sure?',
              description: 'You are about to delete changelog ID: $slug',
              color: DiscordColor(0x00FF00),
              author: EmbedAuthorBuilder(
                  name: (await context.user.fetch()).username,
                  iconUrl: (await context.user.fetch()).avatar.url),
              footer: EmbedFooterBuilder(
                  text: (await context.client.user.fetch()).username,
                  iconUrl: (await context.client.user.fetch()).avatar.url),
              timestamp: DateTime.now())
        ]),
      );
      await context.awaitButtonPress(delbutton).then((_) async {
        final delete = await websocketService
            .sendRequest({'type': 'delete_post', 'postId': slug});
        if (delete['error'] != null) {
          await context.respond(
            level: ResponseLevel(
                hideInteraction: true,
                isDm: false,
                mention: true,
                preserveComponentMessages: false),
            MessageBuilder(embeds: [
              EmbedBuilder(
                  title: 'Failed to delete changelog',
                  description: 'Failed to delete changelog: ${delete['error']}',
                  color: DiscordColor(0xFF0000),
                  author: EmbedAuthorBuilder(
                      name: (await context.user.fetch()).username,
                      iconUrl: (await context.user.fetch()).avatar.url),
                  footer: EmbedFooterBuilder(
                      text: (await context.client.user.fetch()).username,
                      iconUrl: (await context.client.user.fetch()).avatar.url),
                  timestamp: DateTime.now())
            ]),
          );
          return;
        }
        await context.respond(
          level: ResponseLevel(
              hideInteraction: true,
              isDm: false,
              mention: true,
              preserveComponentMessages: false),
          MessageBuilder(embeds: [
            EmbedBuilder(
                title: 'Changelog deleted',
                description: 'The changelog ID: $slug has been deleted',
                color: DiscordColor(0x00FF00),
                author: EmbedAuthorBuilder(
                    name: (await context.user.fetch()).username,
                    iconUrl: (await context.user.fetch()).avatar.url),
                footer: EmbedFooterBuilder(
                    text: (await context.client.user.fetch()).username,
                    iconUrl: (await context.client.user.fetch()).avatar.url),
                timestamp: DateTime.now())
          ]),
        );
      });
      return;
    }
    try {
      final lookup = await websocketService
          .sendRequest({'type': 'slug_to_id', 'slug': slug});
      if (lookup['error'] != null || lookup['id'] == null) {
        await context.respond(
          level: ResponseLevel(
              hideInteraction: true,
              isDm: false,
              mention: true,
              preserveComponentMessages: false),
          MessageBuilder(embeds: [
            EmbedBuilder(
                title: 'No post found',
                description: 'No post found for slug "$slug"',
                color: DiscordColor(0xFF0000),
                author: EmbedAuthorBuilder(
                    name: (await context.user.fetch()).username,
                    iconUrl: (await context.user.fetch()).avatar.url),
                footer: EmbedFooterBuilder(
                    text: (await context.client.user.fetch()).username,
                    iconUrl: (await context.client.user.fetch()).avatar.url),
                timestamp: DateTime.now())
          ]),
        );
        return;
      }
      final delbutton = ComponentId.generate(allowedUser: context.user.id);
      await context.respond(
        level: ResponseLevel(
            hideInteraction: true,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
                style: ButtonStyle.danger,
                label: 'Delete',
                customId: delbutton.toString())
          ])
        ], embeds: [
          EmbedBuilder(
              title: 'Are you sure?',
              description:
                  'You are about to delete the post "${lookup['title']}"',
              color: DiscordColor(0x00FF00),
              author: EmbedAuthorBuilder(
                  name: (await context.user.fetch()).username,
                  iconUrl: (await context.user.fetch()).avatar.url),
              footer: EmbedFooterBuilder(
                  text: (await context.client.user.fetch()).username,
                  iconUrl: (await context.client.user.fetch()).avatar.url),
              timestamp: DateTime.now())
        ]),
      );
      await context.awaitButtonPress(delbutton).then((_) async {
        final delete = await GetIt.I<WebSocketService>()
            .sendRequest({'type': 'delete_post', 'postId': lookup['id']});
        if (delete['error'] != null) {
          await context.respond(
            level: ResponseLevel(
                hideInteraction: true,
                isDm: false,
                mention: true,
                preserveComponentMessages: false),
            MessageBuilder(embeds: [
              EmbedBuilder(
                  title: 'Failed to delete post',
                  description: 'Failed to delete post: ${delete['error']}',
                  color: DiscordColor(0xFF0000),
                  author: EmbedAuthorBuilder(
                      name: (await context.user.fetch()).username,
                      iconUrl: (await context.user.fetch()).avatar.url),
                  footer: EmbedFooterBuilder(
                      text: (await context.client.user.fetch()).username,
                      iconUrl: (await context.client.user.fetch()).avatar.url),
                  timestamp: DateTime.now())
            ]),
          );
          return;
        }
        await context.respond(
          level: ResponseLevel(
              hideInteraction: true,
              isDm: false,
              mention: true,
              preserveComponentMessages: false),
          MessageBuilder(embeds: [
            EmbedBuilder(
                title: 'Post deleted',
                description: 'The post "${lookup['title']}" has been deleted',
                color: DiscordColor(0x00FF00),
                author: EmbedAuthorBuilder(
                    name: (await context.user.fetch()).username,
                    iconUrl: (await context.user.fetch()).avatar.url),
                footer: EmbedFooterBuilder(
                    text: (await context.client.user.fetch()).username,
                    iconUrl: (await context.client.user.fetch()).avatar.url),
                timestamp: DateTime.now())
          ]),
        );
      });
    } catch (e) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(content: 'Failed to delete post: $e'),
      );
    }
  },
);

/// Chat command to create a new editor session.
final ChatCommand editorEditPost = ChatCommand(
  'edit',
  '[ADMIN] Edit an existing post',
  (ChatContext context, String slug, bool changelog) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    try {
      if (!websocketService.isConnected) {
        await context.respond(
          level: ResponseLevel(
              hideInteraction: false,
              isDm: false,
              mention: true,
              preserveComponentMessages: false),
          MessageBuilder(
              content: 'WebSocket client is not connected', embeds: []),
        );
        return;
      }
      String postid;
      if (!changelog) {
        final lookup = await websocketService
            .sendRequest({'type': 'slug_to_id', 'slug': slug});
        postid = lookup['id'];
        if (lookup['error'] != null || lookup['id'] == null) {
          await context.respond(
            level: ResponseLevel(
                hideInteraction: false,
                isDm: false,
                mention: true,
                preserveComponentMessages: false),
            MessageBuilder(embeds: [
              EmbedBuilder(
                  title: 'No post found',
                  description: 'No post found for slug "$slug"',
                  color: DiscordColor(0xFF0000),
                  author: EmbedAuthorBuilder(
                      name: (await context.user.fetch()).username,
                      iconUrl: (await context.user.fetch()).avatar.url),
                  footer: EmbedFooterBuilder(
                      text: (await context.client.user.fetch()).username,
                      iconUrl: (await context.client.user.fetch()).avatar.url),
                  timestamp: DateTime.now())
            ]),
          );
          return;
        }
      } else {
        postid = slug;
      }
      final resp = await websocketService.sendRequest({
        'type': 'create_session',
        'mode': 'edit',
        'postId': postid,
        'postType': changelog ? 'changelog' : 'blog'
      });
      final sid = resp['sessionId'];
      await context.respond(
        level: ResponseLevel(
            hideInteraction: true,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
                style: ButtonStyle.link,
                label: 'Editor',
                url: Uri.parse('https://localhost:8080/editor?id=$sid'))
          ])
        ], embeds: [
          EmbedBuilder(
              title: 'Editor Created',
              description: 'Use the button below to open the editor',
              color: DiscordColor(0x00FF00),
              author: EmbedAuthorBuilder(
                  name: (await context.user.fetch()).username,
                  iconUrl: (await context.user.fetch()).avatar.url),
              footer: EmbedFooterBuilder(
                  text: (await context.client.user.fetch()).username,
                  iconUrl: (await context.client.user.fetch()).avatar.url),
              timestamp: DateTime.now())
        ]),
      );
    } catch (e) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(content: 'Failed to create session: $e'),
      );
    }
  },
);

/// Chat command to create a new editor session.
final ChatCommand editorCreate = ChatCommand(
  'new',
  '[ADMIN] Create a new post',
  (ChatContext context) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    if (!websocketService.isConnected) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(
            content: 'WebSocket client is not connected', embeds: []),
      );
      return;
    }
    try {
      final resp = await websocketService.sendRequest(
          {'type': 'create_session', 'mode': 'new', 'postType': 'blog'});
      final sid = resp['sessionId'];
      await context.respond(
        level: ResponseLevel(
            hideInteraction: true,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
                style: ButtonStyle.link,
                label: 'Editor',
                url: Uri.parse('http://localhost:8080/editor?id=$sid'))
          ])
        ], embeds: [
          EmbedBuilder(
              title: 'Editor Created',
              description: 'Use the button below to open the editor',
              color: DiscordColor(0x00FF00),
              author: EmbedAuthorBuilder(
                  name: (await context.user.fetch()).username,
                  iconUrl: (await context.user.fetch()).avatar.url),
              footer: EmbedFooterBuilder(
                  text: (await context.client.user.fetch()).username,
                  iconUrl: (await context.client.user.fetch()).avatar.url),
              timestamp: DateTime.now())
        ]),
      );
    } catch (e) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(content: 'Failed to create session: $e'),
      );
    }
  },
);

/// Command to recover a deployment and create a changelog session for it
final ChatCommand recoverDeploy = ChatCommand(
  'recoverdeploy',
  '[ADMIN] Recover a deployment that is stuck (no changelog session was created)',
  (ChatContext context, String version, String flavor) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    if (!websocketService.isConnected) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(
            content: 'WebSocket client is not connected', embeds: []),
      );
      return;
    }
    try {
      // Request the last deployment id from the server
      final deploymentResp = await websocketService.sendRequest({
        'type': 'get_last_deployment_id',
      });
      if (deploymentResp['deploymentId'] == null) {
        await context.respond(
          level: ResponseLevel(
              hideInteraction: false,
              isDm: false,
              mention: true,
              preserveComponentMessages: false),
          MessageBuilder(
              content: 'Failed to recover deployment: No deployments found'),
        );
        return;
      }
      final deploymentId = deploymentResp['deploymentId'];
      final resp = await websocketService.sendRequest({
        'type': 'create_session',
        'mode': 'new',
        'postType': 'changelog',
        'metadata': {
          'version': version,
          'flavor': flavor,
          'deploymentId': deploymentId,
        }
      });
      final sid = resp['sessionId'];
      await context.respond(
        level: ResponseLevel(
            hideInteraction: true,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(components: [
          ActionRowBuilder(components: [
            ButtonBuilder(
              style: ButtonStyle.link,
              label: 'Editor',
              url: Uri.parse('http://localhost:8080/editor?id=$sid'),
            )
          ])
        ], embeds: [
          EmbedBuilder(
            title: 'Changelog Session Created',
            description:
                'A new changelog session has been created for version $version ($flavor). Use the button below to open the editor.',
            color: DiscordColor(0x00FF00),
            author: EmbedAuthorBuilder(
                name: (await context.user.fetch()).username,
                iconUrl: (await context.user.fetch()).avatar.url),
            footer: EmbedFooterBuilder(
                text: (await context.client.user.fetch()).username,
                iconUrl: (await context.client.user.fetch()).avatar.url),
            timestamp: DateTime.now(),
          )
        ]),
      );
    } catch (e) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(content: 'Failed to recover deployment: $e'),
      );
    }
  },
);
