import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/tab_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '📡',
      title: 'Общайтесь без интернета\nи сотовой связи',
      text:
          'Сообщения идут напрямую между устройствами '
          'Meshtastic по радио. Никаких тарифов и вышек — '
          'связь работает даже там, где нет сети.',
    ),
    _OnboardingPage(
      emoji: '🔌',
      title: 'Нужен Meshtastic-девайс',
      text:
          'Включите девайс и держите его рядом с телефоном. '
          'Приложение само подключится к нему по Bluetooth.',
    ),
    _OnboardingPage(
      emoji: '👋',
      title: 'Люди, которым\nвы доверяете',
      text:
          'Обменяйтесь QR-кодами с теми, кому доверяете, '
          'и создайте общий канал для своих.',
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_v1', true);
    if (!mounted) return;
    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ScanScreen(meshService: widget.meshService),
        ),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      unawaited(_finish());
    } else {
      unawaited(
        _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: TabGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _isLast
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.s8),
                          child: TextButton(
                            onPressed: () => unawaited(_finish()),
                            child: const Text('Пропустить'),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: _pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                      ),
                      width: i == _page
                          ? AppSizes.pageDotActiveWidth
                          : AppSizes.pageDot,
                      height: AppSizes.pageDot,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? primary
                            : primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.dot),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? 'Начать' : 'Далее'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.text,
  });

  final String emoji;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: AppSizes.emojiHero)),
          const SizedBox(height: AppSpacing.s24),
          Text(
            title,
            style: AppTextStyles.pageTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            text,
            style: AppTextStyles.bodyLargeSecondary(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
