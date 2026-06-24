import 'package:kbuzz/domain/entities/kitchen.dart';

final RegExp _dPrefix = RegExp(r'^D');
final RegExp _taPrefix = RegExp(r'^TA');
final RegExp _tPrefix = RegExp(r'^T');

/// Short ticket code for display: `T5` (dine-in), `TA5` (takeaway), `D5`
/// (delivery). The raw `table` may already carry the prefix, so it's stripped
/// first to avoid doubling (e.g. `TT5`).
///
/// Single source of truth for the Tickets and Stations boards — both render the
/// same code from a [Kot] (`type` + `table`) or a `ScheduledMember`.
String ticketCode(KotType type, String table) {
  switch (type) {
    case KotType.delivery:
      return 'D${table.replaceFirst(_dPrefix, '')}';
    case KotType.takeaway:
      return 'TA${table.replaceFirst(_taPrefix, '')}';
    case KotType.dineIn:
      return 'T${table.replaceFirst(_tPrefix, '')}';
  }
}
