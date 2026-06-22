import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// The run controls shown above the boards: *Start service* before a run, then
/// elapsed time + play/pause/reset + a speed toggle (mirrors the prototype
/// footer). Reads the app-wide [ServiceClockCubit].
class ServiceControlBar extends StatelessWidget {
  const ServiceControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ServiceClockCubit cubit = context.read<ServiceClockCubit>();
    return BlocBuilder<ServiceClockCubit, ServiceClockState>(
      builder: (BuildContext context, ServiceClockState state) {
        return Container(
          color: KBuzzColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              if (!state.started)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: cubit.start,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start service'),
                  ),
                )
              else ...<Widget>[
                _ElapsedReadout(elapsed: state.elapsed),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: state.running ? 'Pause' : 'Resume',
                  onPressed: cubit.toggle,
                  icon: Icon(state.running ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Reset',
                  onPressed: cubit.reset,
                  icon: const Icon(Icons.replay),
                ),
                const Spacer(),
              ],
              _SpeedToggle(speed: state.speed, onChanged: cubit.setSpeed),
            ],
          ),
        );
      },
    );
  }
}

class _ElapsedReadout extends StatelessWidget {
  const _ElapsedReadout({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final int totalSeconds = elapsed.inSeconds;
    final String mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$mm:$ss',
      style: kMonoNumberStyle.copyWith(
        color: KBuzzColors.brandPrimary,
        fontSize: 16,
      ),
    );
  }
}

class _SpeedToggle extends StatelessWidget {
  const _SpeedToggle({required this.speed, required this.onChanged});

  final int speed;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KBuzzColors.board,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final int s in ServiceClockCubit.speeds)
            GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: s == speed
                      ? KBuzzColors.brandPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${s}x',
                  style: kMonoNumberStyle.copyWith(
                    color: s == speed ? Colors.white : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
