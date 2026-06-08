import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class AppOnboardingScreen extends StatefulWidget {
  const AppOnboardingScreen({required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<AppOnboardingScreen> createState() => _AppOnboardingScreenState();
}

class _AppOnboardingScreenState extends State<AppOnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings txt = context.txt;
    final List<({IconData icon, String title, String body})> pages =
        <({IconData icon, String title, String body})>[
          (
            icon: Icons.history_rounded,
            title: txt.t('onboarding.title1'),
            body: txt.t('onboarding.body1'),
          ),
          (
            icon: Icons.style_rounded,
            title: txt.t('onboarding.title2'),
            body: txt.t('onboarding.body2'),
          ),
          (
            icon: Icons.query_stats_rounded,
            title: txt.t('onboarding.title3'),
            body: txt.t('onboarding.body3'),
          ),
        ];
    final bool isLast = _index == pages.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finish,
              child: Text(txt.t('common.skip')),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (int value) {
                setState(() {
                  _index = value;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                final page = pages[index];
                return Card(
                  color: const Color(0xFF1E1B1B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 52),
                        const SizedBox(height: 18),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.35,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(pages.length, (int i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _index == i ? 22 : 8,
                decoration: BoxDecoration(
                  color: _index == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              if (isLast) {
                await _finish();
                return;
              }
              await _pageController.nextPage(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            },
            child: Text(txt.t(isLast ? 'common.continue' : 'common.next')),
          ),
        ],
      ),
    );
  }
}

