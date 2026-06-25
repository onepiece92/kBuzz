// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StationsTable extends Stations
    with TableInfo<$StationsTable, StationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capacityMeta = const VerificationMeta(
    'capacity',
  );
  @override
  late final GeneratedColumn<int> capacity = GeneratedColumn<int>(
    'capacity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    name,
    color,
    capacity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stations';
  @override
  VerificationContext validateIntegrity(
    Insertable<StationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('capacity')) {
      context.handle(
        _capacityMeta,
        capacity.isAcceptableOrUnknown(data['capacity']!, _capacityMeta),
      );
    } else if (isInserting) {
      context.missing(_capacityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity'],
      )!,
    );
  }

  @override
  $StationsTable createAlias(String alias) {
    return $StationsTable(attachedDatabase, alias);
  }
}

class StationRow extends DataClass implements Insertable<StationRow> {
  final String id;
  final DateTime updatedAt;
  final int version;
  final bool deleted;
  final bool dirty;
  final String name;
  final int color;
  final int capacity;
  const StationRow({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.deleted,
    required this.dirty,
    required this.name,
    required this.color,
    required this.capacity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['capacity'] = Variable<int>(capacity);
    return map;
  }

  StationsCompanion toCompanion(bool nullToAbsent) {
    return StationsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deleted: Value(deleted),
      dirty: Value(dirty),
      name: Value(name),
      color: Value(color),
      capacity: Value(capacity),
    );
  }

  factory StationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StationRow(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      capacity: serializer.fromJson<int>(json['capacity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'capacity': serializer.toJson<int>(capacity),
    };
  }

  StationRow copyWith({
    String? id,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
    bool? dirty,
    String? name,
    int? color,
    int? capacity,
  }) => StationRow(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    name: name ?? this.name,
    color: color ?? this.color,
    capacity: capacity ?? this.capacity,
  );
  StationRow copyWithCompanion(StationsCompanion data) {
    return StationRow(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      capacity: data.capacity.present ? data.capacity.value : this.capacity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StationRow(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('capacity: $capacity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    name,
    color,
    capacity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StationRow &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.name == this.name &&
          other.color == this.color &&
          other.capacity == this.capacity);
}

class StationsCompanion extends UpdateCompanion<StationRow> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> name;
  final Value<int> color;
  final Value<int> capacity;
  final Value<int> rowid;
  const StationsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.capacity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StationsCompanion.insert({
    required String id,
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String name,
    required int color,
    required int capacity,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       capacity = Value(capacity);
  static Insertable<StationRow> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? capacity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (capacity != null) 'capacity': capacity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StationsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? name,
    Value<int>? color,
    Value<int>? capacity,
    Value<int>? rowid,
  }) {
    return StationsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      name: name ?? this.name,
      color: color ?? this.color,
      capacity: capacity ?? this.capacity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (capacity.present) {
      map['capacity'] = Variable<int>(capacity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StationsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('capacity: $capacity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MenuItemsTable extends MenuItems
    with TableInfo<$MenuItemsTable, MenuItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cookMinsMeta = const VerificationMeta(
    'cookMins',
  );
  @override
  late final GeneratedColumn<int> cookMins = GeneratedColumn<int>(
    'cook_mins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holdableMeta = const VerificationMeta(
    'holdable',
  );
  @override
  late final GeneratedColumn<bool> holdable = GeneratedColumn<bool>(
    'holdable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("holdable" IN (0, 1))',
    ),
  );
  static const VerificationMeta _batchableMeta = const VerificationMeta(
    'batchable',
  );
  @override
  late final GeneratedColumn<bool> batchable = GeneratedColumn<bool>(
    'batchable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("batchable" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    name,
    emoji,
    stationId,
    cookMins,
    holdable,
    batchable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MenuItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('cook_mins')) {
      context.handle(
        _cookMinsMeta,
        cookMins.isAcceptableOrUnknown(data['cook_mins']!, _cookMinsMeta),
      );
    } else if (isInserting) {
      context.missing(_cookMinsMeta);
    }
    if (data.containsKey('holdable')) {
      context.handle(
        _holdableMeta,
        holdable.isAcceptableOrUnknown(data['holdable']!, _holdableMeta),
      );
    } else if (isInserting) {
      context.missing(_holdableMeta);
    }
    if (data.containsKey('batchable')) {
      context.handle(
        _batchableMeta,
        batchable.isAcceptableOrUnknown(data['batchable']!, _batchableMeta),
      );
    } else if (isInserting) {
      context.missing(_batchableMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      )!,
      cookMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cook_mins'],
      )!,
      holdable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}holdable'],
      )!,
      batchable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}batchable'],
      )!,
    );
  }

  @override
  $MenuItemsTable createAlias(String alias) {
    return $MenuItemsTable(attachedDatabase, alias);
  }
}

class MenuItemRow extends DataClass implements Insertable<MenuItemRow> {
  final String id;
  final DateTime updatedAt;
  final int version;
  final bool deleted;
  final bool dirty;
  final String name;
  final String emoji;
  final String stationId;
  final int cookMins;
  final bool holdable;
  final bool batchable;
  const MenuItemRow({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.deleted,
    required this.dirty,
    required this.name,
    required this.emoji,
    required this.stationId,
    required this.cookMins,
    required this.holdable,
    required this.batchable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['station_id'] = Variable<String>(stationId);
    map['cook_mins'] = Variable<int>(cookMins);
    map['holdable'] = Variable<bool>(holdable);
    map['batchable'] = Variable<bool>(batchable);
    return map;
  }

  MenuItemsCompanion toCompanion(bool nullToAbsent) {
    return MenuItemsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deleted: Value(deleted),
      dirty: Value(dirty),
      name: Value(name),
      emoji: Value(emoji),
      stationId: Value(stationId),
      cookMins: Value(cookMins),
      holdable: Value(holdable),
      batchable: Value(batchable),
    );
  }

  factory MenuItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuItemRow(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      stationId: serializer.fromJson<String>(json['stationId']),
      cookMins: serializer.fromJson<int>(json['cookMins']),
      holdable: serializer.fromJson<bool>(json['holdable']),
      batchable: serializer.fromJson<bool>(json['batchable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'stationId': serializer.toJson<String>(stationId),
      'cookMins': serializer.toJson<int>(cookMins),
      'holdable': serializer.toJson<bool>(holdable),
      'batchable': serializer.toJson<bool>(batchable),
    };
  }

  MenuItemRow copyWith({
    String? id,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
    bool? dirty,
    String? name,
    String? emoji,
    String? stationId,
    int? cookMins,
    bool? holdable,
    bool? batchable,
  }) => MenuItemRow(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    stationId: stationId ?? this.stationId,
    cookMins: cookMins ?? this.cookMins,
    holdable: holdable ?? this.holdable,
    batchable: batchable ?? this.batchable,
  );
  MenuItemRow copyWithCompanion(MenuItemsCompanion data) {
    return MenuItemRow(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      cookMins: data.cookMins.present ? data.cookMins.value : this.cookMins,
      holdable: data.holdable.present ? data.holdable.value : this.holdable,
      batchable: data.batchable.present ? data.batchable.value : this.batchable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemRow(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('stationId: $stationId, ')
          ..write('cookMins: $cookMins, ')
          ..write('holdable: $holdable, ')
          ..write('batchable: $batchable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    name,
    emoji,
    stationId,
    cookMins,
    holdable,
    batchable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuItemRow &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.stationId == this.stationId &&
          other.cookMins == this.cookMins &&
          other.holdable == this.holdable &&
          other.batchable == this.batchable);
}

class MenuItemsCompanion extends UpdateCompanion<MenuItemRow> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> name;
  final Value<String> emoji;
  final Value<String> stationId;
  final Value<int> cookMins;
  final Value<bool> holdable;
  final Value<bool> batchable;
  final Value<int> rowid;
  const MenuItemsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.stationId = const Value.absent(),
    this.cookMins = const Value.absent(),
    this.holdable = const Value.absent(),
    this.batchable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MenuItemsCompanion.insert({
    required String id,
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String name,
    required String emoji,
    required String stationId,
    required int cookMins,
    required bool holdable,
    required bool batchable,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       emoji = Value(emoji),
       stationId = Value(stationId),
       cookMins = Value(cookMins),
       holdable = Value(holdable),
       batchable = Value(batchable);
  static Insertable<MenuItemRow> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<String>? stationId,
    Expression<int>? cookMins,
    Expression<bool>? holdable,
    Expression<bool>? batchable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (stationId != null) 'station_id': stationId,
      if (cookMins != null) 'cook_mins': cookMins,
      if (holdable != null) 'holdable': holdable,
      if (batchable != null) 'batchable': batchable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MenuItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? name,
    Value<String>? emoji,
    Value<String>? stationId,
    Value<int>? cookMins,
    Value<bool>? holdable,
    Value<bool>? batchable,
    Value<int>? rowid,
  }) {
    return MenuItemsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      stationId: stationId ?? this.stationId,
      cookMins: cookMins ?? this.cookMins,
      holdable: holdable ?? this.holdable,
      batchable: batchable ?? this.batchable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (cookMins.present) {
      map['cook_mins'] = Variable<int>(cookMins.value);
    }
    if (holdable.present) {
      map['holdable'] = Variable<bool>(holdable.value);
    }
    if (batchable.present) {
      map['batchable'] = Variable<bool>(batchable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('stationId: $stationId, ')
          ..write('cookMins: $cookMins, ')
          ..write('holdable: $holdable, ')
          ..write('batchable: $batchable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KotsTable extends Kots with TableInfo<$KotsTable, KotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _tableLabelMeta = const VerificationMeta(
    'tableLabel',
  );
  @override
  late final GeneratedColumn<String> tableLabel = GeneratedColumn<String>(
    'table_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderedAtMeta = const VerificationMeta(
    'orderedAt',
  );
  @override
  late final GeneratedColumn<DateTime> orderedAt = GeneratedColumn<DateTime>(
    'ordered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _rushMeta = const VerificationMeta('rush');
  @override
  late final GeneratedColumn<bool> rush = GeneratedColumn<bool>(
    'rush',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rush" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    tableLabel,
    type,
    orderedAt,
    status,
    rush,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kots';
  @override
  VerificationContext validateIntegrity(
    Insertable<KotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('table_label')) {
      context.handle(
        _tableLabelMeta,
        tableLabel.isAcceptableOrUnknown(data['table_label']!, _tableLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_tableLabelMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('ordered_at')) {
      context.handle(
        _orderedAtMeta,
        orderedAt.isAcceptableOrUnknown(data['ordered_at']!, _orderedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_orderedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('rush')) {
      context.handle(
        _rushMeta,
        rush.isAcceptableOrUnknown(data['rush']!, _rushMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      tableLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_label'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      orderedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ordered_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rush: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rush'],
      )!,
    );
  }

  @override
  $KotsTable createAlias(String alias) {
    return $KotsTable(attachedDatabase, alias);
  }
}

class KotRow extends DataClass implements Insertable<KotRow> {
  final String id;
  final DateTime updatedAt;
  final int version;
  final bool deleted;
  final bool dirty;
  final String tableLabel;
  final String type;
  final DateTime orderedAt;
  final String status;
  final bool rush;
  const KotRow({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.deleted,
    required this.dirty,
    required this.tableLabel,
    required this.type,
    required this.orderedAt,
    required this.status,
    required this.rush,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['table_label'] = Variable<String>(tableLabel);
    map['type'] = Variable<String>(type);
    map['ordered_at'] = Variable<DateTime>(orderedAt);
    map['status'] = Variable<String>(status);
    map['rush'] = Variable<bool>(rush);
    return map;
  }

  KotsCompanion toCompanion(bool nullToAbsent) {
    return KotsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deleted: Value(deleted),
      dirty: Value(dirty),
      tableLabel: Value(tableLabel),
      type: Value(type),
      orderedAt: Value(orderedAt),
      status: Value(status),
      rush: Value(rush),
    );
  }

  factory KotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KotRow(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      tableLabel: serializer.fromJson<String>(json['tableLabel']),
      type: serializer.fromJson<String>(json['type']),
      orderedAt: serializer.fromJson<DateTime>(json['orderedAt']),
      status: serializer.fromJson<String>(json['status']),
      rush: serializer.fromJson<bool>(json['rush']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'tableLabel': serializer.toJson<String>(tableLabel),
      'type': serializer.toJson<String>(type),
      'orderedAt': serializer.toJson<DateTime>(orderedAt),
      'status': serializer.toJson<String>(status),
      'rush': serializer.toJson<bool>(rush),
    };
  }

  KotRow copyWith({
    String? id,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
    bool? dirty,
    String? tableLabel,
    String? type,
    DateTime? orderedAt,
    String? status,
    bool? rush,
  }) => KotRow(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    tableLabel: tableLabel ?? this.tableLabel,
    type: type ?? this.type,
    orderedAt: orderedAt ?? this.orderedAt,
    status: status ?? this.status,
    rush: rush ?? this.rush,
  );
  KotRow copyWithCompanion(KotsCompanion data) {
    return KotRow(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      tableLabel: data.tableLabel.present
          ? data.tableLabel.value
          : this.tableLabel,
      type: data.type.present ? data.type.value : this.type,
      orderedAt: data.orderedAt.present ? data.orderedAt.value : this.orderedAt,
      status: data.status.present ? data.status.value : this.status,
      rush: data.rush.present ? data.rush.value : this.rush,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KotRow(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('type: $type, ')
          ..write('orderedAt: $orderedAt, ')
          ..write('status: $status, ')
          ..write('rush: $rush')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    tableLabel,
    type,
    orderedAt,
    status,
    rush,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KotRow &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.tableLabel == this.tableLabel &&
          other.type == this.type &&
          other.orderedAt == this.orderedAt &&
          other.status == this.status &&
          other.rush == this.rush);
}

class KotsCompanion extends UpdateCompanion<KotRow> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> tableLabel;
  final Value<String> type;
  final Value<DateTime> orderedAt;
  final Value<String> status;
  final Value<bool> rush;
  final Value<int> rowid;
  const KotsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.tableLabel = const Value.absent(),
    this.type = const Value.absent(),
    this.orderedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rush = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KotsCompanion.insert({
    required String id,
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String tableLabel,
    required String type,
    required DateTime orderedAt,
    this.status = const Value.absent(),
    this.rush = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tableLabel = Value(tableLabel),
       type = Value(type),
       orderedAt = Value(orderedAt);
  static Insertable<KotRow> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? tableLabel,
    Expression<String>? type,
    Expression<DateTime>? orderedAt,
    Expression<String>? status,
    Expression<bool>? rush,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (tableLabel != null) 'table_label': tableLabel,
      if (type != null) 'type': type,
      if (orderedAt != null) 'ordered_at': orderedAt,
      if (status != null) 'status': status,
      if (rush != null) 'rush': rush,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KotsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? tableLabel,
    Value<String>? type,
    Value<DateTime>? orderedAt,
    Value<String>? status,
    Value<bool>? rush,
    Value<int>? rowid,
  }) {
    return KotsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      tableLabel: tableLabel ?? this.tableLabel,
      type: type ?? this.type,
      orderedAt: orderedAt ?? this.orderedAt,
      status: status ?? this.status,
      rush: rush ?? this.rush,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (tableLabel.present) {
      map['table_label'] = Variable<String>(tableLabel.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (orderedAt.present) {
      map['ordered_at'] = Variable<DateTime>(orderedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rush.present) {
      map['rush'] = Variable<bool>(rush.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KotsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('type: $type, ')
          ..write('orderedAt: $orderedAt, ')
          ..write('status: $status, ')
          ..write('rush: $rush, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderLinesTable extends OrderLines
    with TableInfo<$OrderLinesTable, OrderLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _kotIdMeta = const VerificationMeta('kotId');
  @override
  late final GeneratedColumn<String> kotId = GeneratedColumn<String>(
    'kot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dishIdMeta = const VerificationMeta('dishId');
  @override
  late final GeneratedColumn<String> dishId = GeneratedColumn<String>(
    'dish_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cookOverrideMinsMeta = const VerificationMeta(
    'cookOverrideMins',
  );
  @override
  late final GeneratedColumn<int> cookOverrideMins = GeneratedColumn<int>(
    'cook_override_mins',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _recookMeta = const VerificationMeta('recook');
  @override
  late final GeneratedColumn<int> recook = GeneratedColumn<int>(
    'recook',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reAtMinsMeta = const VerificationMeta(
    'reAtMins',
  );
  @override
  late final GeneratedColumn<int> reAtMins = GeneratedColumn<int>(
    're_at_mins',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    kotId,
    dishId,
    qty,
    cookOverrideMins,
    state,
    recook,
    reAtMins,
    reason,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrderLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('kot_id')) {
      context.handle(
        _kotIdMeta,
        kotId.isAcceptableOrUnknown(data['kot_id']!, _kotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kotIdMeta);
    }
    if (data.containsKey('dish_id')) {
      context.handle(
        _dishIdMeta,
        dishId.isAcceptableOrUnknown(data['dish_id']!, _dishIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dishIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('cook_override_mins')) {
      context.handle(
        _cookOverrideMinsMeta,
        cookOverrideMins.isAcceptableOrUnknown(
          data['cook_override_mins']!,
          _cookOverrideMinsMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('recook')) {
      context.handle(
        _recookMeta,
        recook.isAcceptableOrUnknown(data['recook']!, _recookMeta),
      );
    }
    if (data.containsKey('re_at_mins')) {
      context.handle(
        _reAtMinsMeta,
        reAtMins.isAcceptableOrUnknown(data['re_at_mins']!, _reAtMinsMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      kotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kot_id'],
      )!,
      dishId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dish_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      cookOverrideMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cook_override_mins'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      recook: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recook'],
      )!,
      reAtMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}re_at_mins'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $OrderLinesTable createAlias(String alias) {
    return $OrderLinesTable(attachedDatabase, alias);
  }
}

class OrderLineRow extends DataClass implements Insertable<OrderLineRow> {
  final String id;
  final DateTime updatedAt;
  final int version;
  final bool deleted;
  final bool dirty;
  final String kotId;
  final String dishId;
  final int qty;
  final int? cookOverrideMins;
  final String state;
  final int recook;
  final int? reAtMins;
  final String? reason;
  final String? note;
  const OrderLineRow({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.deleted,
    required this.dirty,
    required this.kotId,
    required this.dishId,
    required this.qty,
    this.cookOverrideMins,
    required this.state,
    required this.recook,
    this.reAtMins,
    this.reason,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['kot_id'] = Variable<String>(kotId);
    map['dish_id'] = Variable<String>(dishId);
    map['qty'] = Variable<int>(qty);
    if (!nullToAbsent || cookOverrideMins != null) {
      map['cook_override_mins'] = Variable<int>(cookOverrideMins);
    }
    map['state'] = Variable<String>(state);
    map['recook'] = Variable<int>(recook);
    if (!nullToAbsent || reAtMins != null) {
      map['re_at_mins'] = Variable<int>(reAtMins);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  OrderLinesCompanion toCompanion(bool nullToAbsent) {
    return OrderLinesCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deleted: Value(deleted),
      dirty: Value(dirty),
      kotId: Value(kotId),
      dishId: Value(dishId),
      qty: Value(qty),
      cookOverrideMins: cookOverrideMins == null && nullToAbsent
          ? const Value.absent()
          : Value(cookOverrideMins),
      state: Value(state),
      recook: Value(recook),
      reAtMins: reAtMins == null && nullToAbsent
          ? const Value.absent()
          : Value(reAtMins),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory OrderLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderLineRow(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      kotId: serializer.fromJson<String>(json['kotId']),
      dishId: serializer.fromJson<String>(json['dishId']),
      qty: serializer.fromJson<int>(json['qty']),
      cookOverrideMins: serializer.fromJson<int?>(json['cookOverrideMins']),
      state: serializer.fromJson<String>(json['state']),
      recook: serializer.fromJson<int>(json['recook']),
      reAtMins: serializer.fromJson<int?>(json['reAtMins']),
      reason: serializer.fromJson<String?>(json['reason']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'kotId': serializer.toJson<String>(kotId),
      'dishId': serializer.toJson<String>(dishId),
      'qty': serializer.toJson<int>(qty),
      'cookOverrideMins': serializer.toJson<int?>(cookOverrideMins),
      'state': serializer.toJson<String>(state),
      'recook': serializer.toJson<int>(recook),
      'reAtMins': serializer.toJson<int?>(reAtMins),
      'reason': serializer.toJson<String?>(reason),
      'note': serializer.toJson<String?>(note),
    };
  }

  OrderLineRow copyWith({
    String? id,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
    bool? dirty,
    String? kotId,
    String? dishId,
    int? qty,
    Value<int?> cookOverrideMins = const Value.absent(),
    String? state,
    int? recook,
    Value<int?> reAtMins = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => OrderLineRow(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    kotId: kotId ?? this.kotId,
    dishId: dishId ?? this.dishId,
    qty: qty ?? this.qty,
    cookOverrideMins: cookOverrideMins.present
        ? cookOverrideMins.value
        : this.cookOverrideMins,
    state: state ?? this.state,
    recook: recook ?? this.recook,
    reAtMins: reAtMins.present ? reAtMins.value : this.reAtMins,
    reason: reason.present ? reason.value : this.reason,
    note: note.present ? note.value : this.note,
  );
  OrderLineRow copyWithCompanion(OrderLinesCompanion data) {
    return OrderLineRow(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      kotId: data.kotId.present ? data.kotId.value : this.kotId,
      dishId: data.dishId.present ? data.dishId.value : this.dishId,
      qty: data.qty.present ? data.qty.value : this.qty,
      cookOverrideMins: data.cookOverrideMins.present
          ? data.cookOverrideMins.value
          : this.cookOverrideMins,
      state: data.state.present ? data.state.value : this.state,
      recook: data.recook.present ? data.recook.value : this.recook,
      reAtMins: data.reAtMins.present ? data.reAtMins.value : this.reAtMins,
      reason: data.reason.present ? data.reason.value : this.reason,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderLineRow(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('kotId: $kotId, ')
          ..write('dishId: $dishId, ')
          ..write('qty: $qty, ')
          ..write('cookOverrideMins: $cookOverrideMins, ')
          ..write('state: $state, ')
          ..write('recook: $recook, ')
          ..write('reAtMins: $reAtMins, ')
          ..write('reason: $reason, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    version,
    deleted,
    dirty,
    kotId,
    dishId,
    qty,
    cookOverrideMins,
    state,
    recook,
    reAtMins,
    reason,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderLineRow &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.kotId == this.kotId &&
          other.dishId == this.dishId &&
          other.qty == this.qty &&
          other.cookOverrideMins == this.cookOverrideMins &&
          other.state == this.state &&
          other.recook == this.recook &&
          other.reAtMins == this.reAtMins &&
          other.reason == this.reason &&
          other.note == this.note);
}

class OrderLinesCompanion extends UpdateCompanion<OrderLineRow> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> kotId;
  final Value<String> dishId;
  final Value<int> qty;
  final Value<int?> cookOverrideMins;
  final Value<String> state;
  final Value<int> recook;
  final Value<int?> reAtMins;
  final Value<String?> reason;
  final Value<String?> note;
  final Value<int> rowid;
  const OrderLinesCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.kotId = const Value.absent(),
    this.dishId = const Value.absent(),
    this.qty = const Value.absent(),
    this.cookOverrideMins = const Value.absent(),
    this.state = const Value.absent(),
    this.recook = const Value.absent(),
    this.reAtMins = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderLinesCompanion.insert({
    required String id,
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String kotId,
    required String dishId,
    required int qty,
    this.cookOverrideMins = const Value.absent(),
    this.state = const Value.absent(),
    this.recook = const Value.absent(),
    this.reAtMins = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kotId = Value(kotId),
       dishId = Value(dishId),
       qty = Value(qty);
  static Insertable<OrderLineRow> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? kotId,
    Expression<String>? dishId,
    Expression<int>? qty,
    Expression<int>? cookOverrideMins,
    Expression<String>? state,
    Expression<int>? recook,
    Expression<int>? reAtMins,
    Expression<String>? reason,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (kotId != null) 'kot_id': kotId,
      if (dishId != null) 'dish_id': dishId,
      if (qty != null) 'qty': qty,
      if (cookOverrideMins != null) 'cook_override_mins': cookOverrideMins,
      if (state != null) 'state': state,
      if (recook != null) 'recook': recook,
      if (reAtMins != null) 're_at_mins': reAtMins,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderLinesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? kotId,
    Value<String>? dishId,
    Value<int>? qty,
    Value<int?>? cookOverrideMins,
    Value<String>? state,
    Value<int>? recook,
    Value<int?>? reAtMins,
    Value<String?>? reason,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return OrderLinesCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      kotId: kotId ?? this.kotId,
      dishId: dishId ?? this.dishId,
      qty: qty ?? this.qty,
      cookOverrideMins: cookOverrideMins ?? this.cookOverrideMins,
      state: state ?? this.state,
      recook: recook ?? this.recook,
      reAtMins: reAtMins ?? this.reAtMins,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (kotId.present) {
      map['kot_id'] = Variable<String>(kotId.value);
    }
    if (dishId.present) {
      map['dish_id'] = Variable<String>(dishId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (cookOverrideMins.present) {
      map['cook_override_mins'] = Variable<int>(cookOverrideMins.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (recook.present) {
      map['recook'] = Variable<int>(recook.value);
    }
    if (reAtMins.present) {
      map['re_at_mins'] = Variable<int>(reAtMins.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderLinesCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('kotId: $kotId, ')
          ..write('dishId: $dishId, ')
          ..write('qty: $qty, ')
          ..write('cookOverrideMins: $cookOverrideMins, ')
          ..write('state: $state, ')
          ..write('recook: $recook, ')
          ..write('reAtMins: $reAtMins, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StationsTable stations = $StationsTable(this);
  late final $MenuItemsTable menuItems = $MenuItemsTable(this);
  late final $KotsTable kots = $KotsTable(this);
  late final $OrderLinesTable orderLines = $OrderLinesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stations,
    menuItems,
    kots,
    orderLines,
  ];
}

typedef $$StationsTableCreateCompanionBuilder =
    StationsCompanion Function({
      required String id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      required String name,
      required int color,
      required int capacity,
      Value<int> rowid,
    });
typedef $$StationsTableUpdateCompanionBuilder =
    StationsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> name,
      Value<int> color,
      Value<int> capacity,
      Value<int> rowid,
    });

class $$StationsTableFilterComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StationsTableOrderingComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get capacity =>
      $composableBuilder(column: $table.capacity, builder: (column) => column);
}

class $$StationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StationsTable,
          StationRow,
          $$StationsTableFilterComposer,
          $$StationsTableOrderingComposer,
          $$StationsTableAnnotationComposer,
          $$StationsTableCreateCompanionBuilder,
          $$StationsTableUpdateCompanionBuilder,
          (
            StationRow,
            BaseReferences<_$AppDatabase, $StationsTable, StationRow>,
          ),
          StationRow,
          PrefetchHooks Function()
        > {
  $$StationsTableTableManager(_$AppDatabase db, $StationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> capacity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StationsCompanion(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                name: name,
                color: color,
                capacity: capacity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String name,
                required int color,
                required int capacity,
                Value<int> rowid = const Value.absent(),
              }) => StationsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                name: name,
                color: color,
                capacity: capacity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StationsTable,
      StationRow,
      $$StationsTableFilterComposer,
      $$StationsTableOrderingComposer,
      $$StationsTableAnnotationComposer,
      $$StationsTableCreateCompanionBuilder,
      $$StationsTableUpdateCompanionBuilder,
      (StationRow, BaseReferences<_$AppDatabase, $StationsTable, StationRow>),
      StationRow,
      PrefetchHooks Function()
    >;
typedef $$MenuItemsTableCreateCompanionBuilder =
    MenuItemsCompanion Function({
      required String id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      required String name,
      required String emoji,
      required String stationId,
      required int cookMins,
      required bool holdable,
      required bool batchable,
      Value<int> rowid,
    });
typedef $$MenuItemsTableUpdateCompanionBuilder =
    MenuItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> name,
      Value<String> emoji,
      Value<String> stationId,
      Value<int> cookMins,
      Value<bool> holdable,
      Value<bool> batchable,
      Value<int> rowid,
    });

class $$MenuItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stationId => $composableBuilder(
    column: $table.stationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cookMins => $composableBuilder(
    column: $table.cookMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get holdable => $composableBuilder(
    column: $table.holdable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get batchable => $composableBuilder(
    column: $table.batchable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MenuItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stationId => $composableBuilder(
    column: $table.stationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cookMins => $composableBuilder(
    column: $table.cookMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get holdable => $composableBuilder(
    column: $table.holdable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get batchable => $composableBuilder(
    column: $table.batchable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MenuItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get stationId =>
      $composableBuilder(column: $table.stationId, builder: (column) => column);

  GeneratedColumn<int> get cookMins =>
      $composableBuilder(column: $table.cookMins, builder: (column) => column);

  GeneratedColumn<bool> get holdable =>
      $composableBuilder(column: $table.holdable, builder: (column) => column);

  GeneratedColumn<bool> get batchable =>
      $composableBuilder(column: $table.batchable, builder: (column) => column);
}

class $$MenuItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MenuItemsTable,
          MenuItemRow,
          $$MenuItemsTableFilterComposer,
          $$MenuItemsTableOrderingComposer,
          $$MenuItemsTableAnnotationComposer,
          $$MenuItemsTableCreateCompanionBuilder,
          $$MenuItemsTableUpdateCompanionBuilder,
          (
            MenuItemRow,
            BaseReferences<_$AppDatabase, $MenuItemsTable, MenuItemRow>,
          ),
          MenuItemRow,
          PrefetchHooks Function()
        > {
  $$MenuItemsTableTableManager(_$AppDatabase db, $MenuItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenuItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenuItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenuItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> stationId = const Value.absent(),
                Value<int> cookMins = const Value.absent(),
                Value<bool> holdable = const Value.absent(),
                Value<bool> batchable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MenuItemsCompanion(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                name: name,
                emoji: emoji,
                stationId: stationId,
                cookMins: cookMins,
                holdable: holdable,
                batchable: batchable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String name,
                required String emoji,
                required String stationId,
                required int cookMins,
                required bool holdable,
                required bool batchable,
                Value<int> rowid = const Value.absent(),
              }) => MenuItemsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                name: name,
                emoji: emoji,
                stationId: stationId,
                cookMins: cookMins,
                holdable: holdable,
                batchable: batchable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MenuItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MenuItemsTable,
      MenuItemRow,
      $$MenuItemsTableFilterComposer,
      $$MenuItemsTableOrderingComposer,
      $$MenuItemsTableAnnotationComposer,
      $$MenuItemsTableCreateCompanionBuilder,
      $$MenuItemsTableUpdateCompanionBuilder,
      (
        MenuItemRow,
        BaseReferences<_$AppDatabase, $MenuItemsTable, MenuItemRow>,
      ),
      MenuItemRow,
      PrefetchHooks Function()
    >;
typedef $$KotsTableCreateCompanionBuilder =
    KotsCompanion Function({
      required String id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      required String tableLabel,
      required String type,
      required DateTime orderedAt,
      Value<String> status,
      Value<bool> rush,
      Value<int> rowid,
    });
typedef $$KotsTableUpdateCompanionBuilder =
    KotsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> tableLabel,
      Value<String> type,
      Value<DateTime> orderedAt,
      Value<String> status,
      Value<bool> rush,
      Value<int> rowid,
    });

class $$KotsTableFilterComposer extends Composer<_$AppDatabase, $KotsTable> {
  $$KotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get orderedAt => $composableBuilder(
    column: $table.orderedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rush => $composableBuilder(
    column: $table.rush,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KotsTableOrderingComposer extends Composer<_$AppDatabase, $KotsTable> {
  $$KotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get orderedAt => $composableBuilder(
    column: $table.orderedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rush => $composableBuilder(
    column: $table.rush,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KotsTable> {
  $$KotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get orderedAt =>
      $composableBuilder(column: $table.orderedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get rush =>
      $composableBuilder(column: $table.rush, builder: (column) => column);
}

class $$KotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KotsTable,
          KotRow,
          $$KotsTableFilterComposer,
          $$KotsTableOrderingComposer,
          $$KotsTableAnnotationComposer,
          $$KotsTableCreateCompanionBuilder,
          $$KotsTableUpdateCompanionBuilder,
          (KotRow, BaseReferences<_$AppDatabase, $KotsTable, KotRow>),
          KotRow,
          PrefetchHooks Function()
        > {
  $$KotsTableTableManager(_$AppDatabase db, $KotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> tableLabel = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> orderedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> rush = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KotsCompanion(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                tableLabel: tableLabel,
                type: type,
                orderedAt: orderedAt,
                status: status,
                rush: rush,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String tableLabel,
                required String type,
                required DateTime orderedAt,
                Value<String> status = const Value.absent(),
                Value<bool> rush = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KotsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                tableLabel: tableLabel,
                type: type,
                orderedAt: orderedAt,
                status: status,
                rush: rush,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KotsTable,
      KotRow,
      $$KotsTableFilterComposer,
      $$KotsTableOrderingComposer,
      $$KotsTableAnnotationComposer,
      $$KotsTableCreateCompanionBuilder,
      $$KotsTableUpdateCompanionBuilder,
      (KotRow, BaseReferences<_$AppDatabase, $KotsTable, KotRow>),
      KotRow,
      PrefetchHooks Function()
    >;
typedef $$OrderLinesTableCreateCompanionBuilder =
    OrderLinesCompanion Function({
      required String id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      required String kotId,
      required String dishId,
      required int qty,
      Value<int?> cookOverrideMins,
      Value<String> state,
      Value<int> recook,
      Value<int?> reAtMins,
      Value<String?> reason,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$OrderLinesTableUpdateCompanionBuilder =
    OrderLinesCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> kotId,
      Value<String> dishId,
      Value<int> qty,
      Value<int?> cookOverrideMins,
      Value<String> state,
      Value<int> recook,
      Value<int?> reAtMins,
      Value<String?> reason,
      Value<String?> note,
      Value<int> rowid,
    });

class $$OrderLinesTableFilterComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kotId => $composableBuilder(
    column: $table.kotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cookOverrideMins => $composableBuilder(
    column: $table.cookOverrideMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recook => $composableBuilder(
    column: $table.recook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reAtMins => $composableBuilder(
    column: $table.reAtMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrderLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kotId => $composableBuilder(
    column: $table.kotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dishId => $composableBuilder(
    column: $table.dishId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cookOverrideMins => $composableBuilder(
    column: $table.cookOverrideMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recook => $composableBuilder(
    column: $table.recook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reAtMins => $composableBuilder(
    column: $table.reAtMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrderLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get kotId =>
      $composableBuilder(column: $table.kotId, builder: (column) => column);

  GeneratedColumn<String> get dishId =>
      $composableBuilder(column: $table.dishId, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get cookOverrideMins => $composableBuilder(
    column: $table.cookOverrideMins,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get recook =>
      $composableBuilder(column: $table.recook, builder: (column) => column);

  GeneratedColumn<int> get reAtMins =>
      $composableBuilder(column: $table.reAtMins, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$OrderLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrderLinesTable,
          OrderLineRow,
          $$OrderLinesTableFilterComposer,
          $$OrderLinesTableOrderingComposer,
          $$OrderLinesTableAnnotationComposer,
          $$OrderLinesTableCreateCompanionBuilder,
          $$OrderLinesTableUpdateCompanionBuilder,
          (
            OrderLineRow,
            BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLineRow>,
          ),
          OrderLineRow,
          PrefetchHooks Function()
        > {
  $$OrderLinesTableTableManager(_$AppDatabase db, $OrderLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> kotId = const Value.absent(),
                Value<String> dishId = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int?> cookOverrideMins = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> recook = const Value.absent(),
                Value<int?> reAtMins = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderLinesCompanion(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                kotId: kotId,
                dishId: dishId,
                qty: qty,
                cookOverrideMins: cookOverrideMins,
                state: state,
                recook: recook,
                reAtMins: reAtMins,
                reason: reason,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String kotId,
                required String dishId,
                required int qty,
                Value<int?> cookOverrideMins = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> recook = const Value.absent(),
                Value<int?> reAtMins = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderLinesCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                version: version,
                deleted: deleted,
                dirty: dirty,
                kotId: kotId,
                dishId: dishId,
                qty: qty,
                cookOverrideMins: cookOverrideMins,
                state: state,
                recook: recook,
                reAtMins: reAtMins,
                reason: reason,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrderLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrderLinesTable,
      OrderLineRow,
      $$OrderLinesTableFilterComposer,
      $$OrderLinesTableOrderingComposer,
      $$OrderLinesTableAnnotationComposer,
      $$OrderLinesTableCreateCompanionBuilder,
      $$OrderLinesTableUpdateCompanionBuilder,
      (
        OrderLineRow,
        BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLineRow>,
      ),
      OrderLineRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StationsTableTableManager get stations =>
      $$StationsTableTableManager(_db, _db.stations);
  $$MenuItemsTableTableManager get menuItems =>
      $$MenuItemsTableTableManager(_db, _db.menuItems);
  $$KotsTableTableManager get kots => $$KotsTableTableManager(_db, _db.kots);
  $$OrderLinesTableTableManager get orderLines =>
      $$OrderLinesTableTableManager(_db, _db.orderLines);
}
