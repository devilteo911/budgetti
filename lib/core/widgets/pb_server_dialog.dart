import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kDefaultPbHost = '192.168.0.144';
const kDefaultPbPort = '8090';

/// Server URL editor, shared by the login screen and Settings > Integrations.
///
/// Login needs it too: with nothing stored, `PocketBase('')` can't reach any
/// backend, so login always fails — while the only screen that could fix the
/// URL sits behind that very login.
///
/// Retargeting the live client is the other half: the provider reads the URL
/// once at construction, so without this a freshly saved URL wouldn't take
/// effect until the next cold start.
///
/// It mutates `baseURL` rather than invalidating the provider on purpose —
/// rebuilding it would also rebuild [AuthService], and the router captured the
/// old instance's `changes` stream via `ref.read`, so login would no longer
/// trigger a redirect.
///
/// Returns true when a new URL was saved.
Future<bool> showPbServerDialog(BuildContext context, WidgetRef ref) async {
  final persistence = ref.read(persistenceServiceProvider);
  // Split the stored http://host:port back into its parts for editing.
  final current = Uri.tryParse(persistence.getServerUrl());
  final hostCtrl = TextEditingController(
      text: (current?.host.isNotEmpty ?? false) ? current!.host : kDefaultPbHost);
  final portCtrl = TextEditingController(
      text: (current?.hasPort ?? false) ? '${current!.port}' : kDefaultPbPort);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.setPbServerTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: hostCtrl,
            decoration: InputDecoration(
                labelText: ctx.l10n.setPbHost, hintText: kDefaultPbHost),
            // Plain text, not number: a Tailscale hostname is as valid here
            // as a LAN address.
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: portCtrl,
            decoration: InputDecoration(
                labelText: ctx.l10n.setPbPort, hintText: kDefaultPbPort),
            keyboardType: TextInputType.number,
            autocorrect: false,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonSave)),
      ],
    ),
  );

  if (saved != true) return false;

  final host =
      hostCtrl.text.trim().isEmpty ? kDefaultPbHost : hostCtrl.text.trim();
  final port =
      portCtrl.text.trim().isEmpty ? kDefaultPbPort : portCtrl.text.trim();
  final url = 'http://$host:$port';
  await persistence.setServerUrl(url);
  ref.read(pocketbaseInstanceProvider).baseURL = url;
  return true;
}
