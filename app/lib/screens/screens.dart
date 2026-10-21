import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../app_state.dart';
import 'widgets.dart';

const _h1 = TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: ink);
const _small = TextStyle(fontSize: 12, color: muted, height: 1.6);

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.app, required this.onSolo, required this.onVersus, required this.onBoard});

  final AppState app;
  final VoidCallback onSolo, onVersus, onBoard;

  @override
  Widget build(BuildContext context) {
    final who = switch (app.auth) {
      AuthStatus.pending => 'Pi 계정 확인 중…',
      AuthStatus.failed => app.authError ?? '로그인 실패',
      AuthStatus.signedIn =>
        '${app.username}${app.guest ? ' (손님)' : ''} · ${app.tier.name}${app.standing.best > 0 ? ' · 최고 ${app.standing.best}m' : ''}',
    };
    return Panel(children: [
      const Text.rich(TextSpan(text: 'Sisyphus', style: _h1, children: [
        TextSpan(text: 'ball', style: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFFC9B79C))),
      ])),
      const SizedBox(height: 6),
      const Text('정상은 없다. 그래도 민다.', style: TextStyle(color: muted)),
      const SizedBox(height: 16),
      Text(who, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: ink)),
      const SizedBox(height: 8),
      GameButton('혼자 밀기', hint: '랭킹', primary: true, onPressed: app.auth == AuthStatus.signedIn ? onSolo : null),
      GameButton('둘이서 밀기', hint: '2P · 한 기기', onPressed: onVersus),
      GameButton('명예의 전당', onPressed: onBoard),
      const SizedBox(height: 18),
      const Text(
        '누르고 있으면 돌을 위로 밀고, 손을 떼면 돌은 굴러 내려온다.\n'
        '가로지르는 바위에 닿으면 돌은 바닥까지 굴러 떨어진다. 1m = 1점.',
        textAlign: TextAlign.center,
        style: _small,
      ),
      if (app.totalRuns > 0) ...[
        const SizedBox(height: 8),
        Text(
          '${app.players}명이 ${formatMeters(app.totalRuns)}번, 모두 ${formatMeters(app.totalMeters)}m를 밀어 올렸다.\n'
          '지금 정상에 있는 돌: 0개',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: accent, height: 1.5),
        ),
      ],
    ]);
  }
}

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({
    super.key,
    required this.app,
    required this.score,
    required this.result,
    required this.refrain,
    required this.onAgain,
    required this.onBoard,
    required this.onHome,
  });

  final AppState app;
  final int score;
  final RunResult? result; // null while the score is being recorded
  final String refrain;
  final VoidCallback onAgain, onBoard, onHome;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final s = app.standing;
    final tier = tierFor(s.best);
    final next = nextTier(s.best);
    return Panel(children: [
      Text(refrain, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontStyle: FontStyle.italic)),
      const SizedBox(height: 10),
      Text.rich(TextSpan(
        text: '$score',
        style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: ink, height: 1),
        children: const [TextSpan(text: 'm', style: TextStyle(fontSize: 24, color: muted))],
      )),
      const SizedBox(height: 6),
      Text(
        r == null
            ? '기록을 새기는 중…'
            : r.error ?? (r.isBest ? '새로운 최고 기록. 돌은 여전히 바닥에 있다.' : '최고 기록 ${s.best}m'),
        textAlign: TextAlign.center,
        style: TextStyle(color: r?.isBest == true ? accent : muted),
      ),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x14E8A95B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1FEFE6D8)),
        ),
        child: Column(children: [
          Text(tier.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 6),
          Text(tier.motto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ink)),
          const SizedBox(height: 8),
          Text(
            next == null ? '더 오를 칭호는 없다. 그래도 돌은 다시 바닥에 있다.' : '다음 칭호 「${next.name}」까지 ${next.min - s.best}m',
            textAlign: TextAlign.center,
            style: _small,
          ),
        ]),
      ),
      if (s.rank != null)
        Text('전체 ${s.rank}위 / ${app.players}명',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
      const SizedBox(height: 4),
      Text(
        '당신이 지금까지 밀어 올린 거리 ${formatMeters(s.totalMeters)}m (${s.runs}번).\n그 돌은 모두 바닥에 있다.',
        textAlign: TextAlign.center,
        style: _small,
      ),
      GameButton('다시 밀기', primary: true, onPressed: onAgain),
      GameButton('명예의 전당', onPressed: onBoard),
      GameButton('처음으로', onPressed: onHome),
    ]);
  }
}

class VersusOverScreen extends StatelessWidget {
  const VersusOverScreen({super.key, required this.scores, required this.onAgain, required this.onHome});

  final List<int> scores;
  final VoidCallback onAgain, onHome;

  @override
  Widget build(BuildContext context) {
    final a = scores[0], b = scores[1];
    final verdict = a == b ? '무승부. 둘 다 바닥에 있다.' : 'P${a > b ? 1 : 2}가 더 높이 밀었다.';
    return Panel(children: [
      const Text('두 개의 돌이 모두 바닥으로 돌아왔다.',
          textAlign: TextAlign.center, style: TextStyle(color: muted, fontStyle: FontStyle.italic)),
      const SizedBox(height: 12),
      Text(verdict, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      Text('P1 ${a}m · P2 ${b}m', style: const TextStyle(color: muted)),
      const SizedBox(height: 6),
      const Text('그리고 둘 다, 다시 민다.', style: _small),
      GameButton('다시 둘이서', primary: true, onPressed: onAgain),
      GameButton('처음으로', onPressed: onHome),
    ]);
  }
}

class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key, required this.app, required this.onBack});

  final AppState app;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
              Text(label, style: const TextStyle(fontSize: 11, color: muted)),
            ]),
          ),
        );

    return Panel(maxWidth: 460, children: [
      const Text('명예의 전당', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
      const SizedBox(height: 4),
      const Text('모든 기록은 실시간으로 갱신된다. 모든 돌은 바닥에 있다.', textAlign: TextAlign.center, style: _small),
      const SizedBox(height: 14),
      Row(children: [
        stat(formatMeters(app.players), '시지프들'),
        stat('${formatMeters(app.totalMeters)}m', '함께 밀어 올린 거리'),
        stat('0', '정상에 있는 돌'),
      ]),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.38),
        child: app.board.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('아직 아무도 돌을 밀지 않았다.', style: TextStyle(color: muted)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: app.board.length,
                itemBuilder: (_, i) {
                  final e = app.board[i];
                  final me = e.username == app.username;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                    decoration: BoxDecoration(
                      color: me ? const Color(0x1FE8A95B) : null,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(bottom: BorderSide(color: Color(0x1FEFE6D8))),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 36,
                        child: Text('${e.rank}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800, color: e.rank <= 3 ? accent : muted)),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${e.username}${e.guest ? ' (손님)' : ''}',
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: ink)),
                          Text('${tierFor(e.best).name} · ${e.runs}번 밀었다',
                              style: const TextStyle(fontSize: 11, color: muted)),
                        ]),
                      ),
                      Text('${e.best}m', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                    ]),
                  );
                },
              ),
      ),
      const SizedBox(height: 16),
      const Align(
        alignment: Alignment.centerLeft,
        child: Row(children: [
          LiveDot(),
          Text('지금 밀고 있는 사람들', style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: app.liveClimbers.isEmpty
            ? const Text('지금은 아무도 없다. 산은 조용하다.', style: TextStyle(fontSize: 12, color: muted))
            : Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in app.liveClimbers)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x1A7BD88F),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x407BD88F)),
                    ),
                    child: Text('${c['name']} · ${c['height']}m', style: const TextStyle(fontSize: 12, color: ink)),
                  ),
              ]),
      ),
      GameButton('돌아가기', onPressed: onBack),
    ]);
  }
}

/// Score while climbing alone.
class SoloHud extends StatelessWidget {
  const SoloHud({super.key, required this.app, required this.score});

  final AppState app;
  final int score;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2))];
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text.rich(TextSpan(
                text: '$score',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: ink, height: 1, shadows: shadow),
                children: const [TextSpan(text: 'm', style: TextStyle(fontSize: 20, color: muted))],
              )),
              const SizedBox(height: 6),
              Text('${tierFor(score).name} · 최고 ${app.standing.best}m',
                  style: const TextStyle(fontSize: 13, color: muted, shadows: shadow)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const LiveDot(),
                Text('${app.liveCount}명이 지금 함께 밀고 있다',
                    style: const TextStyle(fontSize: 12, color: muted, shadows: shadow)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class VersusHud extends StatelessWidget {
  const VersusHud({super.key, required this.scores});

  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2))];
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, s) in scores.indexed)
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'P${i + 1}  ', style: const TextStyle(fontSize: 14, color: accent)),
                    TextSpan(text: '${s}m'),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink, shadows: shadow),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
