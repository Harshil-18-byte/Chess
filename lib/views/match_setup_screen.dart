import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/board_themes.dart';
import '../core/constants/chess_constants.dart';
import '../state/game_state_notifier.dart';
import 'game_board/game_board_view.dart';
import '../models/chess_grade.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  final String matchType; // 'human' or 'engine'

  const MatchSetupScreen({required this.matchType, super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  bool _isTimedMatch = true;
  String _preset = 'Rapid (10+0)'; // Default
  int _customMinutes = 10;
  int _customIncrement = 0;
  ChessGrade _engineGrade = ChessGrade.intermediate;
  bool _isQueueing = false;

  final List<String> _presets = [
    'Bullet (1+0)',
    'Blitz (3+2)',
    'Rapid (10+0)',
    'Classical (30+0)',
    'Custom'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardThemes.surfaceDark,
      appBar: AppBar(
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        title: Text(
          widget.matchType == 'human' ? 'Online Match Setup' : 'Engine Match Setup',
          style: const TextStyle(color: BoardThemes.pureWhite, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: BoardThemes.pureWhite),
      ),
      body: _isQueueing
          ? _buildQueueingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Control', style: BoardThemes.headerMedium),
                  const SizedBox(height: 16),
                  
                  // Time Control ON / OFF
                  Container(
                    decoration: BoxDecoration(
                      color: BoardThemes.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BoardThemes.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        _buildRadioOption<bool>(
                          title: 'ON (Timed Match)',
                          value: true,
                          groupValue: _isTimedMatch,
                          onChanged: (v) => setState(() => _isTimedMatch = v!),
                        ),
                        Divider(height: 1, color: BoardThemes.borderSubtle),
                        _buildRadioOption<bool>(
                          title: 'OFF (Untimed Match)',
                          value: false,
                          groupValue: _isTimedMatch,
                          onChanged: (v) => setState(() => _isTimedMatch = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isTimedMatch) ...[
                    const Text('Preset', style: BoardThemes.headerMedium),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: BoardThemes.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BoardThemes.borderSubtle),
                      ),
                      child: Column(
                        children: _presets.map((p) {
                          return Column(
                            children: [
                              _buildRadioOption<String>(
                                title: p,
                                value: p,
                                groupValue: _preset,
                                onChanged: (v) => setState(() => _preset = v!),
                              ),
                              if (p != _presets.last) Divider(height: 1, color: BoardThemes.borderSubtle),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_isTimedMatch && _preset == 'Custom') ...[
                    const Text('Custom Time Control', style: BoardThemes.headerMedium),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Initial Time (min)',
                            value: _customMinutes,
                            min: 1,
                            max: 180,
                            onChanged: (v) => setState(() => _customMinutes = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Increment (sec)',
                            value: _customIncrement,
                            min: 0,
                            max: 60,
                            onChanged: (v) => setState(() => _customIncrement = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (widget.matchType == 'engine') ...[
                    const Text('Engine Difficulty', style: BoardThemes.headerMedium),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: BoardThemes.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BoardThemes.borderSubtle),
                      ),
                      child: Column(
                        children: ChessGrade.values.map((g) {
                          return Column(
                            children: [
                              _buildRadioOption<ChessGrade>(
                                title: g.title,
                                value: g,
                                groupValue: _engineGrade,
                                onChanged: (v) => setState(() => _engineGrade = v!),
                              ),
                              if (g != ChessGrade.values.last) Divider(height: 1, color: BoardThemes.borderSubtle),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BoardThemes.accentCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        widget.matchType == 'human' ? 'Find Match' : 'Play',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQueueingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: BoardThemes.accentCyan),
          const SizedBox(height: 24),
          const Text('Searching for opponent...', style: BoardThemes.headerMedium),
          const SizedBox(height: 8),
          Text(
            _isTimedMatch ? _preset : 'Untimed',
            style: BoardThemes.bodyRegular.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _cancelMatchmaking,
            child: const Text('Cancel', style: TextStyle(color: BoardThemes.accentRose, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption<T>({
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ignore: deprecated_member_use
            Radio<T>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              activeColor: BoardThemes.accentCyan,
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: BoardThemes.pureWhite, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BoardThemes.pureWhite, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Text('-', style: TextStyle(color: BoardThemes.pureWhite, fontSize: 24, fontWeight: FontWeight.bold)),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: BoardThemes.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$value', style: const TextStyle(color: BoardThemes.pureWhite, fontSize: 16)),
              ),
            ),
            IconButton(
              icon: const Text('+', style: TextStyle(color: BoardThemes.pureWhite, fontSize: 24, fontWeight: FontWeight.bold)),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startGame() async {
    final firestore = ref.read(firestoreServiceProvider);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUid.isNotEmpty ? auth.currentUid : 'player_local';

    int? initMin;
    int? incSec;
    int? totalMillis;
    String? presetName;

    if (_isTimedMatch) {
      if (_preset == 'Custom') {
        initMin = _customMinutes;
        incSec = _customIncrement;
        totalMillis = _customMinutes * 60 * 1000;
        presetName = 'Custom ($_customMinutes+$_customIncrement)';
      } else {
        presetName = _preset;
        if (_preset == 'Bullet (1+0)') {
          initMin = 1;
          incSec = 0;
          totalMillis = ChessConstants.bulletMillis;
        } else if (_preset == 'Blitz (3+2)') {
          initMin = 3;
          incSec = 2;
          totalMillis = ChessConstants.blitzMillis;
        } else if (_preset == 'Rapid (10+0)') {
          initMin = 10;
          incSec = 0;
          totalMillis = ChessConstants.rapidMillis;
        } else if (_preset == 'Classical (30+0)') {
          initMin = 30;
          incSec = 0;
          totalMillis = 30 * 60 * 1000;
        }
      }
    }

    if (widget.matchType == 'engine') {
      try {
        final match = await firestore.createMatch(
          whiteUid: uid,
          blackUid: 'engine_stockfish',
          matchType: 'engine',
          isTimedMatch: _isTimedMatch,
          timeControlPreset: presetName,
          initialMinutes: initMin,
          incrementSeconds: incSec,
          timeControlMillis: totalMillis,
          engineDifficulty: _engineGrade.stockfishSkill,
        );
        if (mounted) _navigateToMatch(match.matchId);
      } catch (e) {
        _showError(e.toString());
      }
    } else {
      setState(() => _isQueueing = true);
      try {
        final matchId = await firestore.findOrCreateMatchmakingMatch(
          uid: uid,
          isTimedMatch: _isTimedMatch,
          timeControlPreset: presetName,
          initialMinutes: initMin,
          incrementSeconds: incSec,
          timeControlMillis: totalMillis,
        );
        if (!mounted) return;
        if (matchId != null) {
          setState(() => _isQueueing = false);
          _navigateToMatch(matchId);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isQueueing = false);
          _showError(e.toString());
        }
      }
    }
  }

  Future<void> _cancelMatchmaking() async {
    final firestore = ref.read(firestoreServiceProvider);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUid;
    if (uid.isNotEmpty) {
      await firestore.leaveMatchmakingQueue(uid);
    }
    if (mounted) {
      setState(() => _isQueueing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: BoardThemes.dangerAlert),
    );
  }

  void _navigateToMatch(String matchId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameBoardView(matchId: matchId),
      ),
    );
  }
}
