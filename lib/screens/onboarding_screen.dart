import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/main_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
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

  static const _pageCount = 3;

  List<Widget> _pages(BuildContext context) {
    final l10n = context.l10n;
    return [
      _OnboardingPage(
        emoji: '📡',
        title: l10n.onboardingTitle1,
        text: l10n.onboardingText1,
      ),
      _OnboardingPage(
        emoji: '🔌',
        title: l10n.onboardingTitle2,
        text: l10n.onboardingText2,
      ),
      _OnboardingPage(
        emoji: '👋',
        title: l10n.onboardingTitle3,
        text: l10n.onboardingText3,
      ),
    ];
  }

  bool get _isLast => _page == _pageCount - 1;

  /// Marks the intro as seen and hands off to the scan screen. The display
  /// name is no longer asked here — see [ScanScreen] and [NameStepScreen]:
  /// the node id (which the self-contact is keyed by) is only known once a
  /// device has actually connected, so asking for it earlier meant either a
  /// broken record under a placeholder id or a stash-and-poll workaround.
  /// Both "Skip" and "Начать" land here — there is nothing left on this
  /// screen to skip past except the remaining intro pages.
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_v1', true);
    if (!mounted) return;
    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ScanScreen(
            meshService: widget.meshService,
            askForName: true,
          ),
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

  void _onPageChanged(int i) {
    setState(() => _page = i);
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
                  // Always available: nobody should feel trapped by the
                  // intro during first launch.
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: TextButton(
                      onPressed: () => unawaited(_finish()),
                      child: Text(context.l10n.onboardingSkip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  children: _pages(context),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++)
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
                    child: Text(
                      _isLast
                          ? context.l10n.onboardingStart
                          : context.l10n.onboardingNext,
                    ),
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
    // PageView keeps every page mounted for smooth swiping, so a page
    // pushed offscreen is still laid out under whatever text scale and
    // keyboard inset apply to the screen as a whole — a plain centered
    // Column would overflow there at large text scales. Scroll instead.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: AppSizes.emojiHero),
                ),
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
          ),
        );
      },
    );
  }
}

/// Asks for a display name once a device is actually connected — pushed by
/// [ScanScreen] in place of [MainScreen] right after a successful connect,
/// but only when there is no self-contact yet (see
/// `ScanScreen._connectDevice`). At that point the radio's node id is
/// already known, so the name (if any) is saved directly as the
/// self-contact, the same way "Мой контакт" does — no placeholder id, no
/// stash-and-poll.
///
/// Skippable, like every onboarding step: skipping (or submitting a blank
/// name) leaves the app exactly as it is today — no self-contact, node-id
/// fallback everywhere a name would have shown.
class NameStepScreen extends StatefulWidget {
  const NameStepScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<NameStepScreen> createState() => _NameStepScreenState();
}

class _NameStepScreenState extends State<NameStepScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // This is the only thing on screen — unlike the intro pages, there is
    // no reason to wait before popping up the keyboard.
    _nameFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// [save] is false for the explicit "Skip" button, which discards
  /// whatever may already be typed in the field rather than saving it.
  Future<void> _finish({bool save = true}) async {
    if (save) {
      final name = sanitizeDisplayName(_nameController.text);
      final nodeId = widget.meshService.myNodeId;
      // The node id should always be known here — this screen only appears
      // after a successful connect — but a missing one is still handled
      // honestly (no contact) rather than under a placeholder id.
      if (name.isNotEmpty && nodeId != null) {
        await ContactStore.instance.saveContact(
          Contact(nodeId: nodeId, displayName: name),
        );
      }
    }
    if (!mounted) return;
    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MainScreen(meshService: widget.meshService),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: TextButton(
                      onPressed: () => unawaited(_finish(save: false)),
                      child: Text(context.l10n.onboardingSkip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NameStepPage(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  onSubmitted: () => unawaited(_finish()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => unawaited(_finish()),
                    child: Text(context.l10n.onboardingStart),
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

class _NameStepPage extends StatelessWidget {
  const _NameStepPage({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '✍️',
                  style: TextStyle(fontSize: AppSizes.emojiHero),
                ),
                const SizedBox(height: AppSpacing.s24),
                Text(
                  l10n.onboardingNameTitle,
                  style: AppTextStyles.pageTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  l10n.onboardingNameText,
                  style: AppTextStyles.bodyLargeSecondary(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s24),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [_DisplayNameInputFormatter()],
                  decoration: InputDecoration(hintText: l10n.yourNameHint),
                  onSubmitted: (_) => onSubmitted(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Keeps a typed display name within [kDisplayNameMaxLength] Unicode code
/// points and free of newlines/control characters as the person types —
/// the same treatment [sanitizeDisplayName] applies before saving, surfaced
/// here so the field visibly refuses what would otherwise be silently
/// cleaned up later. Duplicated from `my_card_screen.dart`'s formatter of
/// the same name/shape: both screens accept the one display-name field,
/// each privately, and neither needs to see the other's widget tree.
class _DisplayNameInputFormatter extends TextInputFormatter {
  const _DisplayNameInputFormatter();

  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final flattened = newValue.text.replaceAll(_controlChars, ' ');
    final capped = flattened.runes.length > kDisplayNameMaxLength
        ? String.fromCharCodes(flattened.runes.take(kDisplayNameMaxLength))
        : flattened;
    if (capped == newValue.text) return newValue;
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}
