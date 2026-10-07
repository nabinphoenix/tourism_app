import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gurkha_guides/core/localization/locale_controller.dart';
import 'package:gurkha_guides/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale =
        ref.watch(localeProvider).asData?.value ?? const Locale('en');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.home,
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
        ),
        title: Text(l10n.settings),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.changeLanguage,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(labelText: l10n.language),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('localeSelector'),
                        value: locale.languageCode,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l10n.english),
                          ),
                          DropdownMenuItem(
                            value: 'ne',
                            child: Text(l10n.nepali),
                          ),
                        ],
                        onChanged: (code) async {
                          if (code == null) return;
                          final saved = await ref
                              .read(localeProvider.notifier)
                              .setLocale(Locale(code));
                          if (!saved && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.languageSaveError)),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
