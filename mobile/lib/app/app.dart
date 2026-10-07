import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gurkha_guides/core/localization/locale_controller.dart';
import 'package:gurkha_guides/l10n/generated/app_localizations.dart';
import 'package:gurkha_guides/shared/widgets/retry_view.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class GurkhaGuidesApp extends ConsumerWidget {
  const GurkhaGuidesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      locale: localeState.asData?.value ?? const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final l10n = AppLocalizations.of(context)!;
        return localeState.when(
          data: (_) => child ?? const SizedBox.shrink(),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            body: RetryView(
              message: l10n.preferencesLoadError,
              retryLabel: l10n.retry,
              onRetry: () => ref.invalidate(localeProvider),
            ),
          ),
        );
      },
    );
  }
}
