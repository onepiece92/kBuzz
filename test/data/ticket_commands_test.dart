import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);
  late AppDatabase db;
  late KitchenRepository repo;

  setUp(() async {
    db = AppDatabase.memory();
    repo = KitchenRepository(db);
    await repo.seedSampleData(now: now);
  });

  tearDown(() async {
    await db.close();
  });

  OrderLine lineById(DemoData snap, String id) =>
      snap.kots.expand((Kot k) => k.lines).firstWhere((OrderLine l) => l.id == id);
  Kot kotById(DemoData snap, String id) =>
      snap.kots.firstWhere((Kot k) => k.id == id);

  test('seeded lines carry an id and default open/active state', () async {
    final DemoData snap = await repo.loadSnapshot();
    final Kot k = snap.kots.first;
    expect(k.lines.first.id, isNotNull);
    expect(k.lines.first.state, LineState.open);
    expect(k.lines.first.recook, 0);
    expect(k.lines.first.reAt, isNull);
    expect(k.status, TicketState.active);
    expect(k.rush, isFalse);
  });

  test('serve / unserve / void / restore move a line through its states', () async {
    final String id = (await repo.loadSnapshot()).kots.first.lines.first.id!;

    await repo.serveLine(id);
    expect(lineById(await repo.loadSnapshot(), id).state, LineState.served);
    await repo.unserveLine(id);
    expect(lineById(await repo.loadSnapshot(), id).state, LineState.open);
    await repo.voidLine(id);
    expect(lineById(await repo.loadSnapshot(), id).state, LineState.voided);
    await repo.restoreLine(id);
    expect(lineById(await repo.loadSnapshot(), id).state, LineState.open);
  });

  test('recook reopens the line, bumps count, sets reAt+reason, reopens ticket',
      () async {
    final DemoData snap0 = await repo.loadSnapshot();
    final String kotId = snap0.kots.first.id;
    final String id = snap0.kots.first.lines.first.id!;

    await repo.markDone(kotId);
    expect(kotById(await repo.loadSnapshot(), kotId).status, TicketState.done);

    await repo.recookLine(id, reason: 'Cold', reAtMins: 10);
    final DemoData snap = await repo.loadSnapshot();
    final OrderLine l = lineById(snap, id);
    expect(l.state, LineState.open);
    expect(l.recook, 1);
    expect(l.reAt, 10);
    expect(l.reason, 'Cold');
    expect(kotById(snap, kotId).status, TicketState.active); // auto-reopened
  });

  test('fireNow sets reAt with no reason', () async {
    final String id = (await repo.loadSnapshot()).kots.first.lines.first.id!;
    await repo.fireNowLine(id, reAtMins: 3);
    final OrderLine l = lineById(await repo.loadSnapshot(), id);
    expect(l.reAt, 3);
    expect(l.reason, isNull);
    expect(l.state, LineState.open);
  });

  test('serveAll serves every non-void line', () async {
    final Kot kot = (await repo.loadSnapshot()).kots.first;
    final String voidId = kot.lines.first.id!;
    await repo.voidLine(voidId);
    await repo.serveAll(kot.id);

    for (final OrderLine l in kotById(await repo.loadSnapshot(), kot.id).lines) {
      expect(l.state, l.id == voidId ? LineState.voided : LineState.served);
    }
  });

  test('setLineNote sets, edits and clears a line note', () async {
    final String id = (await repo.loadSnapshot()).kots.first.lines.first.id!;

    await repo.setLineNote(id, 'no onions');
    expect(lineById(await repo.loadSnapshot(), id).note, 'no onions');

    await repo.setLineNote(id, 'extra spicy'); // edit
    expect(lineById(await repo.loadSnapshot(), id).note, 'extra spicy');

    await repo.setLineNote(id, null); // clear
    expect(lineById(await repo.loadSnapshot(), id).note, isNull);
  });

  test('rush toggles; done / reopen flip the ticket', () async {
    final String kotId = (await repo.loadSnapshot()).kots.first.id;

    await repo.setRush(kotId, on: true);
    expect(kotById(await repo.loadSnapshot(), kotId).rush, isTrue);
    await repo.setRush(kotId, on: false);
    expect(kotById(await repo.loadSnapshot(), kotId).rush, isFalse);

    await repo.markDone(kotId);
    expect(kotById(await repo.loadSnapshot(), kotId).status, TicketState.done);
    await repo.reopenTicket(kotId);
    expect(kotById(await repo.loadSnapshot(), kotId).status, TicketState.active);
  });
}
