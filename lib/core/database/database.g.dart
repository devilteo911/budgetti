// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _iconCodeMeta = const VerificationMeta(
    'iconCode',
  );
  @override
  late final GeneratedColumn<int> iconCode = GeneratedColumn<int>(
    'icon_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<int> colorHex = GeneratedColumn<int>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    iconCode,
    colorHex,
    type,
    description,
    isDeleted,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
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
    if (data.containsKey('icon_code')) {
      context.handle(
        _iconCodeMeta,
        iconCode.isAcceptableOrUnknown(data['icon_code']!, _iconCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_iconCodeMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_code'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_hex'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String? userId;
  final String name;
  final int iconCode;
  final int colorHex;
  final String type;
  final String? description;
  final bool isDeleted;
  final DateTime? lastUpdated;
  const Category({
    required this.id,
    this.userId,
    required this.name,
    required this.iconCode,
    required this.colorHex,
    required this.type,
    this.description,
    required this.isDeleted,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['name'] = Variable<String>(name);
    map['icon_code'] = Variable<int>(iconCode);
    map['color_hex'] = Variable<int>(colorHex);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      name: Value(name),
      iconCode: Value(iconCode),
      colorHex: Value(colorHex),
      type: Value(type),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isDeleted: Value(isDeleted),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      iconCode: serializer.fromJson<int>(json['iconCode']),
      colorHex: serializer.fromJson<int>(json['colorHex']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String>(name),
      'iconCode': serializer.toJson<int>(iconCode),
      'colorHex': serializer.toJson<int>(colorHex),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String?>(description),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  Category copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? name,
    int? iconCode,
    int? colorHex,
    String? type,
    Value<String?> description = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    name: name ?? this.name,
    iconCode: iconCode ?? this.iconCode,
    colorHex: colorHex ?? this.colorHex,
    type: type ?? this.type,
    description: description.present ? description.value : this.description,
    isDeleted: isDeleted ?? this.isDeleted,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      iconCode: data.iconCode.present ? data.iconCode.value : this.iconCode,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('iconCode: $iconCode, ')
          ..write('colorHex: $colorHex, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    iconCode,
    colorHex,
    type,
    description,
    isDeleted,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.iconCode == this.iconCode &&
          other.colorHex == this.colorHex &&
          other.type == this.type &&
          other.description == this.description &&
          other.isDeleted == this.isDeleted &&
          other.lastUpdated == this.lastUpdated);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> name;
  final Value<int> iconCode;
  final Value<int> colorHex;
  final Value<String> type;
  final Value<String?> description;
  final Value<bool> isDeleted;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.iconCode = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    required int iconCode,
    required int colorHex,
    required String type,
    this.description = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       iconCode = Value(iconCode),
       colorHex = Value(colorHex),
       type = Value(type);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<int>? iconCode,
    Expression<int>? colorHex,
    Expression<String>? type,
    Expression<String>? description,
    Expression<bool>? isDeleted,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (iconCode != null) 'icon_code': iconCode,
      if (colorHex != null) 'color_hex': colorHex,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? name,
    Value<int>? iconCode,
    Value<int>? colorHex,
    Value<String>? type,
    Value<String?>? description,
    Value<bool>? isDeleted,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      description: description ?? this.description,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconCode.present) {
      map['icon_code'] = Variable<int>(iconCode.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<int>(colorHex.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('iconCode: $iconCode, ')
          ..write('colorHex: $colorHex, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<int> colorHex = GeneratedColumn<int>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    colorHex,
    isDeleted,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
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
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_hex'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String? userId;
  final String name;
  final int colorHex;
  final bool isDeleted;
  final DateTime? lastUpdated;
  const Tag({
    required this.id,
    this.userId,
    required this.name,
    required this.colorHex,
    required this.isDeleted,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<int>(colorHex);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      name: Value(name),
      colorHex: Value(colorHex),
      isDeleted: Value(isDeleted),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<int>(json['colorHex']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<int>(colorHex),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  Tag copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? name,
    int? colorHex,
    bool? isDeleted,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => Tag(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    isDeleted: isDeleted ?? this.isDeleted,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, name, colorHex, isDeleted, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.isDeleted == this.isDeleted &&
          other.lastUpdated == this.lastUpdated);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> name;
  final Value<int> colorHex;
  final Value<bool> isDeleted;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    required int colorHex,
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       colorHex = Value(colorHex);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<int>? colorHex,
    Expression<bool>? isDeleted,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? name,
    Value<int>? colorHex,
    Value<bool>? isDeleted,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<int>(colorHex.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _initialBalanceDateMeta =
      const VerificationMeta('initialBalanceDate');
  @override
  late final GeneratedColumn<DateTime> initialBalanceDate =
      GeneratedColumn<DateTime>(
        'initial_balance_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    balance,
    currency,
    providerName,
    isDefault,
    initialBalanceDate,
    isDeleted,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
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
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('initial_balance_date')) {
      context.handle(
        _initialBalanceDateMeta,
        initialBalanceDate.isAcceptableOrUnknown(
          data['initial_balance_date']!,
          _initialBalanceDateMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}balance'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      initialBalanceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}initial_balance_date'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String? userId;
  final String name;
  final double balance;
  final String currency;
  final String? providerName;
  final bool isDefault;
  final DateTime? initialBalanceDate;
  final bool isDeleted;
  final DateTime? lastUpdated;
  const Account({
    required this.id,
    this.userId,
    required this.name,
    required this.balance,
    required this.currency,
    this.providerName,
    required this.isDefault,
    this.initialBalanceDate,
    required this.isDeleted,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['name'] = Variable<String>(name);
    map['balance'] = Variable<double>(balance);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || providerName != null) {
      map['provider_name'] = Variable<String>(providerName);
    }
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || initialBalanceDate != null) {
      map['initial_balance_date'] = Variable<DateTime>(initialBalanceDate);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      name: Value(name),
      balance: Value(balance),
      currency: Value(currency),
      providerName: providerName == null && nullToAbsent
          ? const Value.absent()
          : Value(providerName),
      isDefault: Value(isDefault),
      initialBalanceDate: initialBalanceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(initialBalanceDate),
      isDeleted: Value(isDeleted),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      balance: serializer.fromJson<double>(json['balance']),
      currency: serializer.fromJson<String>(json['currency']),
      providerName: serializer.fromJson<String?>(json['providerName']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      initialBalanceDate: serializer.fromJson<DateTime?>(
        json['initialBalanceDate'],
      ),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String>(name),
      'balance': serializer.toJson<double>(balance),
      'currency': serializer.toJson<String>(currency),
      'providerName': serializer.toJson<String?>(providerName),
      'isDefault': serializer.toJson<bool>(isDefault),
      'initialBalanceDate': serializer.toJson<DateTime?>(initialBalanceDate),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  Account copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? name,
    double? balance,
    String? currency,
    Value<String?> providerName = const Value.absent(),
    bool? isDefault,
    Value<DateTime?> initialBalanceDate = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    name: name ?? this.name,
    balance: balance ?? this.balance,
    currency: currency ?? this.currency,
    providerName: providerName.present ? providerName.value : this.providerName,
    isDefault: isDefault ?? this.isDefault,
    initialBalanceDate: initialBalanceDate.present
        ? initialBalanceDate.value
        : this.initialBalanceDate,
    isDeleted: isDeleted ?? this.isDeleted,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      balance: data.balance.present ? data.balance.value : this.balance,
      currency: data.currency.present ? data.currency.value : this.currency,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      initialBalanceDate: data.initialBalanceDate.present
          ? data.initialBalanceDate.value
          : this.initialBalanceDate,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('providerName: $providerName, ')
          ..write('isDefault: $isDefault, ')
          ..write('initialBalanceDate: $initialBalanceDate, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    balance,
    currency,
    providerName,
    isDefault,
    initialBalanceDate,
    isDeleted,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.balance == this.balance &&
          other.currency == this.currency &&
          other.providerName == this.providerName &&
          other.isDefault == this.isDefault &&
          other.initialBalanceDate == this.initialBalanceDate &&
          other.isDeleted == this.isDeleted &&
          other.lastUpdated == this.lastUpdated);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> name;
  final Value<double> balance;
  final Value<String> currency;
  final Value<String?> providerName;
  final Value<bool> isDefault;
  final Value<DateTime?> initialBalanceDate;
  final Value<bool> isDeleted;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.providerName = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.initialBalanceDate = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.providerName = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.initialBalanceDate = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<double>? balance,
    Expression<String>? currency,
    Expression<String>? providerName,
    Expression<bool>? isDefault,
    Expression<DateTime>? initialBalanceDate,
    Expression<bool>? isDeleted,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (balance != null) 'balance': balance,
      if (currency != null) 'currency': currency,
      if (providerName != null) 'provider_name': providerName,
      if (isDefault != null) 'is_default': isDefault,
      if (initialBalanceDate != null)
        'initial_balance_date': initialBalanceDate,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? name,
    Value<double>? balance,
    Value<String>? currency,
    Value<String?>? providerName,
    Value<bool>? isDefault,
    Value<DateTime?>? initialBalanceDate,
    Value<bool>? isDeleted,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      providerName: providerName ?? this.providerName,
      isDefault: isDefault ?? this.isDefault,
      initialBalanceDate: initialBalanceDate ?? this.initialBalanceDate,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (initialBalanceDate.present) {
      map['initial_balance_date'] = Variable<DateTime>(
        initialBalanceDate.value,
      );
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('providerName: $providerName, ')
          ..write('isDefault: $isDefault, ')
          ..write('initialBalanceDate: $initialBalanceDate, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('expense'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<String>?>($TransactionsTable.$convertertagsn);
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    accountId,
    toAccountId,
    amount,
    description,
    category,
    type,
    date,
    tags,
    isDeleted,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      tags: $TransactionsTable.$convertertagsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        ),
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const ListStringConverter();
  static TypeConverter<List<String>?, String?> $convertertagsn =
      NullAwareTypeConverter.wrap($convertertags);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String? userId;
  final String? accountId;
  final String? toAccountId;
  final double amount;
  final String description;
  final String category;
  final String type;
  final DateTime date;
  final List<String>? tags;
  final bool isDeleted;
  final DateTime? lastUpdated;
  const Transaction({
    required this.id,
    this.userId,
    this.accountId,
    this.toAccountId,
    required this.amount,
    required this.description,
    required this.category,
    required this.type,
    required this.date,
    this.tags,
    required this.isDeleted,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    map['amount'] = Variable<double>(amount);
    map['description'] = Variable<String>(description);
    map['category'] = Variable<String>(category);
    map['type'] = Variable<String>(type);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(
        $TransactionsTable.$convertertagsn.toSql(tags),
      );
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      amount: Value(amount),
      description: Value(description),
      category: Value(category),
      type: Value(type),
      date: Value(date),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      isDeleted: Value(isDeleted),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      amount: serializer.fromJson<double>(json['amount']),
      description: serializer.fromJson<String>(json['description']),
      category: serializer.fromJson<String>(json['category']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<DateTime>(json['date']),
      tags: serializer.fromJson<List<String>?>(json['tags']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'accountId': serializer.toJson<String?>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'amount': serializer.toJson<double>(amount),
      'description': serializer.toJson<String>(description),
      'category': serializer.toJson<String>(category),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<DateTime>(date),
      'tags': serializer.toJson<List<String>?>(tags),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  Transaction copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> accountId = const Value.absent(),
    Value<String?> toAccountId = const Value.absent(),
    double? amount,
    String? description,
    String? category,
    String? type,
    DateTime? date,
    Value<List<String>?> tags = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    accountId: accountId.present ? accountId.value : this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    category: category ?? this.category,
    type: type ?? this.type,
    date: date ?? this.date,
    tags: tags.present ? tags.value : this.tags,
    isDeleted: isDeleted ?? this.isDeleted,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      tags: data.tags.present ? data.tags.value : this.tags,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('tags: $tags, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    accountId,
    toAccountId,
    amount,
    description,
    category,
    type,
    date,
    tags,
    isDeleted,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.category == this.category &&
          other.type == this.type &&
          other.date == this.date &&
          other.tags == this.tags &&
          other.isDeleted == this.isDeleted &&
          other.lastUpdated == this.lastUpdated);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> accountId;
  final Value<String?> toAccountId;
  final Value<double> amount;
  final Value<String> description;
  final Value<String> category;
  final Value<String> type;
  final Value<DateTime> date;
  final Value<List<String>?> tags;
  final Value<bool> isDeleted;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.tags = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    required double amount,
    required String description,
    required String category,
    this.type = const Value.absent(),
    required DateTime date,
    this.tags = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amount = Value(amount),
       description = Value(description),
       category = Value(category),
       date = Value(date);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<double>? amount,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? type,
    Expression<DateTime>? date,
    Expression<String>? tags,
    Expression<bool>? isDeleted,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (tags != null) 'tags': tags,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? accountId,
    Value<String?>? toAccountId,
    Value<double>? amount,
    Value<String>? description,
    Value<String>? category,
    Value<String>? type,
    Value<DateTime>? date,
    Value<List<String>?>? tags,
    Value<bool>? isDeleted,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $TransactionsTable.$convertertagsn.toSql(tags.value),
      );
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('tags: $tags, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitAmountMeta = const VerificationMeta(
    'limitAmount',
  );
  @override
  late final GeneratedColumn<double> limitAmount = GeneratedColumn<double>(
    'limit_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    category,
    limitAmount,
    period,
    isDeleted,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('limit_amount')) {
      context.handle(
        _limitAmountMeta,
        limitAmount.isAcceptableOrUnknown(
          data['limit_amount']!,
          _limitAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_limitAmountMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      limitAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limit_amount'],
      )!,
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final String? userId;
  final String category;
  final double limitAmount;
  final String period;
  final bool isDeleted;
  final DateTime? lastUpdated;
  const Budget({
    required this.id,
    this.userId,
    required this.category,
    required this.limitAmount,
    required this.period,
    required this.isDeleted,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['category'] = Variable<String>(category);
    map['limit_amount'] = Variable<double>(limitAmount);
    map['period'] = Variable<String>(period);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      category: Value(category),
      limitAmount: Value(limitAmount),
      period: Value(period),
      isDeleted: Value(isDeleted),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      category: serializer.fromJson<String>(json['category']),
      limitAmount: serializer.fromJson<double>(json['limitAmount']),
      period: serializer.fromJson<String>(json['period']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'category': serializer.toJson<String>(category),
      'limitAmount': serializer.toJson<double>(limitAmount),
      'period': serializer.toJson<String>(period),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  Budget copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? category,
    double? limitAmount,
    String? period,
    bool? isDeleted,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => Budget(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    category: category ?? this.category,
    limitAmount: limitAmount ?? this.limitAmount,
    period: period ?? this.period,
    isDeleted: isDeleted ?? this.isDeleted,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      category: data.category.present ? data.category.value : this.category,
      limitAmount: data.limitAmount.present
          ? data.limitAmount.value
          : this.limitAmount,
      period: data.period.present ? data.period.value : this.period,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('period: $period, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    category,
    limitAmount,
    period,
    isDeleted,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.category == this.category &&
          other.limitAmount == this.limitAmount &&
          other.period == this.period &&
          other.isDeleted == this.isDeleted &&
          other.lastUpdated == this.lastUpdated);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> category;
  final Value<double> limitAmount;
  final Value<String> period;
  final Value<bool> isDeleted;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.category = const Value.absent(),
    this.limitAmount = const Value.absent(),
    this.period = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String category,
    required double limitAmount,
    required String period,
    this.isDeleted = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       limitAmount = Value(limitAmount),
       period = Value(period);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? category,
    Expression<double>? limitAmount,
    Expression<String>? period,
    Expression<bool>? isDeleted,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (category != null) 'category': category,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (period != null) 'period': period,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? category,
    Value<double>? limitAmount,
    Value<String>? period,
    Value<bool>? isDeleted,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (limitAmount.present) {
      map['limit_amount'] = Variable<double>(limitAmount.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('category: $category, ')
          ..write('limitAmount: $limitAmount, ')
          ..write('period: $period, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingTransactionsTable extends PendingTransactions
    with TableInfo<$PendingTransactionsTable, PendingTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gmailMessageIdMeta = const VerificationMeta(
    'gmailMessageId',
  );
  @override
  late final GeneratedColumn<String> gmailMessageId = GeneratedColumn<String>(
    'gmail_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('widiba'),
  );
  static const VerificationMeta _emailSubjectMeta = const VerificationMeta(
    'emailSubject',
  );
  @override
  late final GeneratedColumn<String> emailSubject = GeneratedColumn<String>(
    'email_subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailReceivedAtMeta = const VerificationMeta(
    'emailReceivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> emailReceivedAt =
      GeneratedColumn<DateTime>(
        'email_received_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _parsedAmountMeta = const VerificationMeta(
    'parsedAmount',
  );
  @override
  late final GeneratedColumn<double> parsedAmount = GeneratedColumn<double>(
    'parsed_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parsedDescriptionMeta = const VerificationMeta(
    'parsedDescription',
  );
  @override
  late final GeneratedColumn<String> parsedDescription =
      GeneratedColumn<String>(
        'parsed_description',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _parsedDateMeta = const VerificationMeta(
    'parsedDate',
  );
  @override
  late final GeneratedColumn<DateTime> parsedDate = GeneratedColumn<DateTime>(
    'parsed_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _suggestedTypeMeta = const VerificationMeta(
    'suggestedType',
  );
  @override
  late final GeneratedColumn<String> suggestedType = GeneratedColumn<String>(
    'suggested_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('expense'),
  );
  static const VerificationMeta _suggestedCategoryMeta = const VerificationMeta(
    'suggestedCategory',
  );
  @override
  late final GeneratedColumn<String> suggestedCategory =
      GeneratedColumn<String>(
        'suggested_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawSnippetMeta = const VerificationMeta(
    'rawSnippet',
  );
  @override
  late final GeneratedColumn<String> rawSnippet = GeneratedColumn<String>(
    'raw_snippet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _duplicateOfIdMeta = const VerificationMeta(
    'duplicateOfId',
  );
  @override
  late final GeneratedColumn<String> duplicateOfId = GeneratedColumn<String>(
    'duplicate_of_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duplicateScoreMeta = const VerificationMeta(
    'duplicateScore',
  );
  @override
  late final GeneratedColumn<double> duplicateScore = GeneratedColumn<double>(
    'duplicate_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    gmailMessageId,
    source,
    emailSubject,
    emailReceivedAt,
    parsedAmount,
    parsedDescription,
    parsedDate,
    suggestedType,
    suggestedCategory,
    counterparty,
    rawSnippet,
    status,
    createdAt,
    duplicateOfId,
    duplicateScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('gmail_message_id')) {
      context.handle(
        _gmailMessageIdMeta,
        gmailMessageId.isAcceptableOrUnknown(
          data['gmail_message_id']!,
          _gmailMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gmailMessageIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('email_subject')) {
      context.handle(
        _emailSubjectMeta,
        emailSubject.isAcceptableOrUnknown(
          data['email_subject']!,
          _emailSubjectMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emailSubjectMeta);
    }
    if (data.containsKey('email_received_at')) {
      context.handle(
        _emailReceivedAtMeta,
        emailReceivedAt.isAcceptableOrUnknown(
          data['email_received_at']!,
          _emailReceivedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emailReceivedAtMeta);
    }
    if (data.containsKey('parsed_amount')) {
      context.handle(
        _parsedAmountMeta,
        parsedAmount.isAcceptableOrUnknown(
          data['parsed_amount']!,
          _parsedAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parsedAmountMeta);
    }
    if (data.containsKey('parsed_description')) {
      context.handle(
        _parsedDescriptionMeta,
        parsedDescription.isAcceptableOrUnknown(
          data['parsed_description']!,
          _parsedDescriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parsedDescriptionMeta);
    }
    if (data.containsKey('parsed_date')) {
      context.handle(
        _parsedDateMeta,
        parsedDate.isAcceptableOrUnknown(data['parsed_date']!, _parsedDateMeta),
      );
    } else if (isInserting) {
      context.missing(_parsedDateMeta);
    }
    if (data.containsKey('suggested_type')) {
      context.handle(
        _suggestedTypeMeta,
        suggestedType.isAcceptableOrUnknown(
          data['suggested_type']!,
          _suggestedTypeMeta,
        ),
      );
    }
    if (data.containsKey('suggested_category')) {
      context.handle(
        _suggestedCategoryMeta,
        suggestedCategory.isAcceptableOrUnknown(
          data['suggested_category']!,
          _suggestedCategoryMeta,
        ),
      );
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    }
    if (data.containsKey('raw_snippet')) {
      context.handle(
        _rawSnippetMeta,
        rawSnippet.isAcceptableOrUnknown(data['raw_snippet']!, _rawSnippetMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('duplicate_of_id')) {
      context.handle(
        _duplicateOfIdMeta,
        duplicateOfId.isAcceptableOrUnknown(
          data['duplicate_of_id']!,
          _duplicateOfIdMeta,
        ),
      );
    }
    if (data.containsKey('duplicate_score')) {
      context.handle(
        _duplicateScoreMeta,
        duplicateScore.isAcceptableOrUnknown(
          data['duplicate_score']!,
          _duplicateScoreMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      gmailMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gmail_message_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      emailSubject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email_subject'],
      )!,
      emailReceivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}email_received_at'],
      )!,
      parsedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}parsed_amount'],
      )!,
      parsedDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_description'],
      )!,
      parsedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}parsed_date'],
      )!,
      suggestedType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_type'],
      )!,
      suggestedCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_category'],
      ),
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      ),
      rawSnippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_snippet'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      duplicateOfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duplicate_of_id'],
      ),
      duplicateScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duplicate_score'],
      ),
    );
  }

  @override
  $PendingTransactionsTable createAlias(String alias) {
    return $PendingTransactionsTable(attachedDatabase, alias);
  }
}

class PendingTransaction extends DataClass
    implements Insertable<PendingTransaction> {
  final String id;
  final String? userId;
  final String gmailMessageId;
  final String source;
  final String emailSubject;
  final DateTime emailReceivedAt;
  final double parsedAmount;
  final String parsedDescription;
  final DateTime parsedDate;
  final String suggestedType;
  final String? suggestedCategory;
  final String? counterparty;
  final String rawSnippet;
  final String status;
  final DateTime createdAt;
  final String? duplicateOfId;
  final double? duplicateScore;
  const PendingTransaction({
    required this.id,
    this.userId,
    required this.gmailMessageId,
    required this.source,
    required this.emailSubject,
    required this.emailReceivedAt,
    required this.parsedAmount,
    required this.parsedDescription,
    required this.parsedDate,
    required this.suggestedType,
    this.suggestedCategory,
    this.counterparty,
    required this.rawSnippet,
    required this.status,
    required this.createdAt,
    this.duplicateOfId,
    this.duplicateScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['gmail_message_id'] = Variable<String>(gmailMessageId);
    map['source'] = Variable<String>(source);
    map['email_subject'] = Variable<String>(emailSubject);
    map['email_received_at'] = Variable<DateTime>(emailReceivedAt);
    map['parsed_amount'] = Variable<double>(parsedAmount);
    map['parsed_description'] = Variable<String>(parsedDescription);
    map['parsed_date'] = Variable<DateTime>(parsedDate);
    map['suggested_type'] = Variable<String>(suggestedType);
    if (!nullToAbsent || suggestedCategory != null) {
      map['suggested_category'] = Variable<String>(suggestedCategory);
    }
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    map['raw_snippet'] = Variable<String>(rawSnippet);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || duplicateOfId != null) {
      map['duplicate_of_id'] = Variable<String>(duplicateOfId);
    }
    if (!nullToAbsent || duplicateScore != null) {
      map['duplicate_score'] = Variable<double>(duplicateScore);
    }
    return map;
  }

  PendingTransactionsCompanion toCompanion(bool nullToAbsent) {
    return PendingTransactionsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      gmailMessageId: Value(gmailMessageId),
      source: Value(source),
      emailSubject: Value(emailSubject),
      emailReceivedAt: Value(emailReceivedAt),
      parsedAmount: Value(parsedAmount),
      parsedDescription: Value(parsedDescription),
      parsedDate: Value(parsedDate),
      suggestedType: Value(suggestedType),
      suggestedCategory: suggestedCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCategory),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      rawSnippet: Value(rawSnippet),
      status: Value(status),
      createdAt: Value(createdAt),
      duplicateOfId: duplicateOfId == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicateOfId),
      duplicateScore: duplicateScore == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicateScore),
    );
  }

  factory PendingTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingTransaction(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      gmailMessageId: serializer.fromJson<String>(json['gmailMessageId']),
      source: serializer.fromJson<String>(json['source']),
      emailSubject: serializer.fromJson<String>(json['emailSubject']),
      emailReceivedAt: serializer.fromJson<DateTime>(json['emailReceivedAt']),
      parsedAmount: serializer.fromJson<double>(json['parsedAmount']),
      parsedDescription: serializer.fromJson<String>(json['parsedDescription']),
      parsedDate: serializer.fromJson<DateTime>(json['parsedDate']),
      suggestedType: serializer.fromJson<String>(json['suggestedType']),
      suggestedCategory: serializer.fromJson<String?>(
        json['suggestedCategory'],
      ),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      rawSnippet: serializer.fromJson<String>(json['rawSnippet']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      duplicateOfId: serializer.fromJson<String?>(json['duplicateOfId']),
      duplicateScore: serializer.fromJson<double?>(json['duplicateScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'gmailMessageId': serializer.toJson<String>(gmailMessageId),
      'source': serializer.toJson<String>(source),
      'emailSubject': serializer.toJson<String>(emailSubject),
      'emailReceivedAt': serializer.toJson<DateTime>(emailReceivedAt),
      'parsedAmount': serializer.toJson<double>(parsedAmount),
      'parsedDescription': serializer.toJson<String>(parsedDescription),
      'parsedDate': serializer.toJson<DateTime>(parsedDate),
      'suggestedType': serializer.toJson<String>(suggestedType),
      'suggestedCategory': serializer.toJson<String?>(suggestedCategory),
      'counterparty': serializer.toJson<String?>(counterparty),
      'rawSnippet': serializer.toJson<String>(rawSnippet),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'duplicateOfId': serializer.toJson<String?>(duplicateOfId),
      'duplicateScore': serializer.toJson<double?>(duplicateScore),
    };
  }

  PendingTransaction copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? gmailMessageId,
    String? source,
    String? emailSubject,
    DateTime? emailReceivedAt,
    double? parsedAmount,
    String? parsedDescription,
    DateTime? parsedDate,
    String? suggestedType,
    Value<String?> suggestedCategory = const Value.absent(),
    Value<String?> counterparty = const Value.absent(),
    String? rawSnippet,
    String? status,
    DateTime? createdAt,
    Value<String?> duplicateOfId = const Value.absent(),
    Value<double?> duplicateScore = const Value.absent(),
  }) => PendingTransaction(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    gmailMessageId: gmailMessageId ?? this.gmailMessageId,
    source: source ?? this.source,
    emailSubject: emailSubject ?? this.emailSubject,
    emailReceivedAt: emailReceivedAt ?? this.emailReceivedAt,
    parsedAmount: parsedAmount ?? this.parsedAmount,
    parsedDescription: parsedDescription ?? this.parsedDescription,
    parsedDate: parsedDate ?? this.parsedDate,
    suggestedType: suggestedType ?? this.suggestedType,
    suggestedCategory: suggestedCategory.present
        ? suggestedCategory.value
        : this.suggestedCategory,
    counterparty: counterparty.present ? counterparty.value : this.counterparty,
    rawSnippet: rawSnippet ?? this.rawSnippet,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    duplicateOfId: duplicateOfId.present
        ? duplicateOfId.value
        : this.duplicateOfId,
    duplicateScore: duplicateScore.present
        ? duplicateScore.value
        : this.duplicateScore,
  );
  PendingTransaction copyWithCompanion(PendingTransactionsCompanion data) {
    return PendingTransaction(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      gmailMessageId: data.gmailMessageId.present
          ? data.gmailMessageId.value
          : this.gmailMessageId,
      source: data.source.present ? data.source.value : this.source,
      emailSubject: data.emailSubject.present
          ? data.emailSubject.value
          : this.emailSubject,
      emailReceivedAt: data.emailReceivedAt.present
          ? data.emailReceivedAt.value
          : this.emailReceivedAt,
      parsedAmount: data.parsedAmount.present
          ? data.parsedAmount.value
          : this.parsedAmount,
      parsedDescription: data.parsedDescription.present
          ? data.parsedDescription.value
          : this.parsedDescription,
      parsedDate: data.parsedDate.present
          ? data.parsedDate.value
          : this.parsedDate,
      suggestedType: data.suggestedType.present
          ? data.suggestedType.value
          : this.suggestedType,
      suggestedCategory: data.suggestedCategory.present
          ? data.suggestedCategory.value
          : this.suggestedCategory,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      rawSnippet: data.rawSnippet.present
          ? data.rawSnippet.value
          : this.rawSnippet,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      duplicateOfId: data.duplicateOfId.present
          ? data.duplicateOfId.value
          : this.duplicateOfId,
      duplicateScore: data.duplicateScore.present
          ? data.duplicateScore.value
          : this.duplicateScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingTransaction(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('source: $source, ')
          ..write('emailSubject: $emailSubject, ')
          ..write('emailReceivedAt: $emailReceivedAt, ')
          ..write('parsedAmount: $parsedAmount, ')
          ..write('parsedDescription: $parsedDescription, ')
          ..write('parsedDate: $parsedDate, ')
          ..write('suggestedType: $suggestedType, ')
          ..write('suggestedCategory: $suggestedCategory, ')
          ..write('counterparty: $counterparty, ')
          ..write('rawSnippet: $rawSnippet, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('duplicateOfId: $duplicateOfId, ')
          ..write('duplicateScore: $duplicateScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    gmailMessageId,
    source,
    emailSubject,
    emailReceivedAt,
    parsedAmount,
    parsedDescription,
    parsedDate,
    suggestedType,
    suggestedCategory,
    counterparty,
    rawSnippet,
    status,
    createdAt,
    duplicateOfId,
    duplicateScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingTransaction &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.gmailMessageId == this.gmailMessageId &&
          other.source == this.source &&
          other.emailSubject == this.emailSubject &&
          other.emailReceivedAt == this.emailReceivedAt &&
          other.parsedAmount == this.parsedAmount &&
          other.parsedDescription == this.parsedDescription &&
          other.parsedDate == this.parsedDate &&
          other.suggestedType == this.suggestedType &&
          other.suggestedCategory == this.suggestedCategory &&
          other.counterparty == this.counterparty &&
          other.rawSnippet == this.rawSnippet &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.duplicateOfId == this.duplicateOfId &&
          other.duplicateScore == this.duplicateScore);
}

class PendingTransactionsCompanion extends UpdateCompanion<PendingTransaction> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> gmailMessageId;
  final Value<String> source;
  final Value<String> emailSubject;
  final Value<DateTime> emailReceivedAt;
  final Value<double> parsedAmount;
  final Value<String> parsedDescription;
  final Value<DateTime> parsedDate;
  final Value<String> suggestedType;
  final Value<String?> suggestedCategory;
  final Value<String?> counterparty;
  final Value<String> rawSnippet;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String?> duplicateOfId;
  final Value<double?> duplicateScore;
  final Value<int> rowid;
  const PendingTransactionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.gmailMessageId = const Value.absent(),
    this.source = const Value.absent(),
    this.emailSubject = const Value.absent(),
    this.emailReceivedAt = const Value.absent(),
    this.parsedAmount = const Value.absent(),
    this.parsedDescription = const Value.absent(),
    this.parsedDate = const Value.absent(),
    this.suggestedType = const Value.absent(),
    this.suggestedCategory = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.rawSnippet = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.duplicateOfId = const Value.absent(),
    this.duplicateScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingTransactionsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String gmailMessageId,
    this.source = const Value.absent(),
    required String emailSubject,
    required DateTime emailReceivedAt,
    required double parsedAmount,
    required String parsedDescription,
    required DateTime parsedDate,
    this.suggestedType = const Value.absent(),
    this.suggestedCategory = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.rawSnippet = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.duplicateOfId = const Value.absent(),
    this.duplicateScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       gmailMessageId = Value(gmailMessageId),
       emailSubject = Value(emailSubject),
       emailReceivedAt = Value(emailReceivedAt),
       parsedAmount = Value(parsedAmount),
       parsedDescription = Value(parsedDescription),
       parsedDate = Value(parsedDate),
       createdAt = Value(createdAt);
  static Insertable<PendingTransaction> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? gmailMessageId,
    Expression<String>? source,
    Expression<String>? emailSubject,
    Expression<DateTime>? emailReceivedAt,
    Expression<double>? parsedAmount,
    Expression<String>? parsedDescription,
    Expression<DateTime>? parsedDate,
    Expression<String>? suggestedType,
    Expression<String>? suggestedCategory,
    Expression<String>? counterparty,
    Expression<String>? rawSnippet,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? duplicateOfId,
    Expression<double>? duplicateScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (gmailMessageId != null) 'gmail_message_id': gmailMessageId,
      if (source != null) 'source': source,
      if (emailSubject != null) 'email_subject': emailSubject,
      if (emailReceivedAt != null) 'email_received_at': emailReceivedAt,
      if (parsedAmount != null) 'parsed_amount': parsedAmount,
      if (parsedDescription != null) 'parsed_description': parsedDescription,
      if (parsedDate != null) 'parsed_date': parsedDate,
      if (suggestedType != null) 'suggested_type': suggestedType,
      if (suggestedCategory != null) 'suggested_category': suggestedCategory,
      if (counterparty != null) 'counterparty': counterparty,
      if (rawSnippet != null) 'raw_snippet': rawSnippet,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (duplicateOfId != null) 'duplicate_of_id': duplicateOfId,
      if (duplicateScore != null) 'duplicate_score': duplicateScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? gmailMessageId,
    Value<String>? source,
    Value<String>? emailSubject,
    Value<DateTime>? emailReceivedAt,
    Value<double>? parsedAmount,
    Value<String>? parsedDescription,
    Value<DateTime>? parsedDate,
    Value<String>? suggestedType,
    Value<String?>? suggestedCategory,
    Value<String?>? counterparty,
    Value<String>? rawSnippet,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<String?>? duplicateOfId,
    Value<double?>? duplicateScore,
    Value<int>? rowid,
  }) {
    return PendingTransactionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      source: source ?? this.source,
      emailSubject: emailSubject ?? this.emailSubject,
      emailReceivedAt: emailReceivedAt ?? this.emailReceivedAt,
      parsedAmount: parsedAmount ?? this.parsedAmount,
      parsedDescription: parsedDescription ?? this.parsedDescription,
      parsedDate: parsedDate ?? this.parsedDate,
      suggestedType: suggestedType ?? this.suggestedType,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      counterparty: counterparty ?? this.counterparty,
      rawSnippet: rawSnippet ?? this.rawSnippet,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      duplicateOfId: duplicateOfId ?? this.duplicateOfId,
      duplicateScore: duplicateScore ?? this.duplicateScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (gmailMessageId.present) {
      map['gmail_message_id'] = Variable<String>(gmailMessageId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (emailSubject.present) {
      map['email_subject'] = Variable<String>(emailSubject.value);
    }
    if (emailReceivedAt.present) {
      map['email_received_at'] = Variable<DateTime>(emailReceivedAt.value);
    }
    if (parsedAmount.present) {
      map['parsed_amount'] = Variable<double>(parsedAmount.value);
    }
    if (parsedDescription.present) {
      map['parsed_description'] = Variable<String>(parsedDescription.value);
    }
    if (parsedDate.present) {
      map['parsed_date'] = Variable<DateTime>(parsedDate.value);
    }
    if (suggestedType.present) {
      map['suggested_type'] = Variable<String>(suggestedType.value);
    }
    if (suggestedCategory.present) {
      map['suggested_category'] = Variable<String>(suggestedCategory.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (rawSnippet.present) {
      map['raw_snippet'] = Variable<String>(rawSnippet.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (duplicateOfId.present) {
      map['duplicate_of_id'] = Variable<String>(duplicateOfId.value);
    }
    if (duplicateScore.present) {
      map['duplicate_score'] = Variable<double>(duplicateScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('source: $source, ')
          ..write('emailSubject: $emailSubject, ')
          ..write('emailReceivedAt: $emailReceivedAt, ')
          ..write('parsedAmount: $parsedAmount, ')
          ..write('parsedDescription: $parsedDescription, ')
          ..write('parsedDate: $parsedDate, ')
          ..write('suggestedType: $suggestedType, ')
          ..write('suggestedCategory: $suggestedCategory, ')
          ..write('counterparty: $counterparty, ')
          ..write('rawSnippet: $rawSnippet, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('duplicateOfId: $duplicateOfId, ')
          ..write('duplicateScore: $duplicateScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $PendingTransactionsTable pendingTransactions =
      $PendingTransactionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    tags,
    accounts,
    transactions,
    budgets,
    pendingTransactions,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      Value<String?> userId,
      required String name,
      required int iconCode,
      required int colorHex,
      required String type,
      Value<String?> description,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> name,
      Value<int> iconCode,
      Value<int> colorHex,
      Value<String> type,
      Value<String?> description,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get iconCode =>
      $composableBuilder(column: $table.iconCode, builder: (column) => column);

  GeneratedColumn<int> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> iconCode = const Value.absent(),
                Value<int> colorHex = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                userId: userId,
                name: name,
                iconCode: iconCode,
                colorHex: colorHex,
                type: type,
                description: description,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String name,
                required int iconCode,
                required int colorHex,
                required String type,
                Value<String?> description = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                iconCode: iconCode,
                colorHex: colorHex,
                type: type,
                description: description,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      Value<String?> userId,
      required String name,
      required int colorHex,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> name,
      Value<int> colorHex,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorHex = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                userId: userId,
                name: name,
                colorHex: colorHex,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String name,
                required int colorHex,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                colorHex: colorHex,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      Value<String?> userId,
      required String name,
      Value<double> balance,
      Value<String> currency,
      Value<String?> providerName,
      Value<bool> isDefault,
      Value<DateTime?> initialBalanceDate,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> name,
      Value<double> balance,
      Value<String> currency,
      Value<String?> providerName,
      Value<bool> isDefault,
      Value<DateTime?> initialBalanceDate,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get initialBalanceDate => $composableBuilder(
    column: $table.initialBalanceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get initialBalanceDate => $composableBuilder(
    column: $table.initialBalanceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get initialBalanceDate => $composableBuilder(
    column: $table.initialBalanceDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> balance = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> providerName = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> initialBalanceDate = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                userId: userId,
                name: name,
                balance: balance,
                currency: currency,
                providerName: providerName,
                isDefault: isDefault,
                initialBalanceDate: initialBalanceDate,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String name,
                Value<double> balance = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> providerName = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> initialBalanceDate = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                balance: balance,
                currency: currency,
                providerName: providerName,
                isDefault: isDefault,
                initialBalanceDate: initialBalanceDate,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> accountId,
      Value<String?> toAccountId,
      required double amount,
      required String description,
      required String category,
      Value<String> type,
      required DateTime date,
      Value<List<String>?> tags,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> accountId,
      Value<String?> toAccountId,
      Value<double> amount,
      Value<String> description,
      Value<String> category,
      Value<String> type,
      Value<DateTime> date,
      Value<List<String>?> tags,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<List<String>?> tags = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                userId: userId,
                accountId: accountId,
                toAccountId: toAccountId,
                amount: amount,
                description: description,
                category: category,
                type: type,
                date: date,
                tags: tags,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                required double amount,
                required String description,
                required String category,
                Value<String> type = const Value.absent(),
                required DateTime date,
                Value<List<String>?> tags = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                userId: userId,
                accountId: accountId,
                toAccountId: toAccountId,
                amount: amount,
                description: description,
                category: category,
                type: type,
                date: date,
                tags: tags,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      Value<String?> userId,
      required String category,
      required double limitAmount,
      required String period,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> category,
      Value<double> limitAmount,
      Value<String> period,
      Value<bool> isDeleted,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get limitAmount => $composableBuilder(
    column: $table.limitAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
          Budget,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> limitAmount = const Value.absent(),
                Value<String> period = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                userId: userId,
                category: category,
                limitAmount: limitAmount,
                period: period,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String category,
                required double limitAmount,
                required String period,
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                userId: userId,
                category: category,
                limitAmount: limitAmount,
                period: period,
                isDeleted: isDeleted,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
      Budget,
      PrefetchHooks Function()
    >;
typedef $$PendingTransactionsTableCreateCompanionBuilder =
    PendingTransactionsCompanion Function({
      required String id,
      Value<String?> userId,
      required String gmailMessageId,
      Value<String> source,
      required String emailSubject,
      required DateTime emailReceivedAt,
      required double parsedAmount,
      required String parsedDescription,
      required DateTime parsedDate,
      Value<String> suggestedType,
      Value<String?> suggestedCategory,
      Value<String?> counterparty,
      Value<String> rawSnippet,
      Value<String> status,
      required DateTime createdAt,
      Value<String?> duplicateOfId,
      Value<double?> duplicateScore,
      Value<int> rowid,
    });
typedef $$PendingTransactionsTableUpdateCompanionBuilder =
    PendingTransactionsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> gmailMessageId,
      Value<String> source,
      Value<String> emailSubject,
      Value<DateTime> emailReceivedAt,
      Value<double> parsedAmount,
      Value<String> parsedDescription,
      Value<DateTime> parsedDate,
      Value<String> suggestedType,
      Value<String?> suggestedCategory,
      Value<String?> counterparty,
      Value<String> rawSnippet,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<String?> duplicateOfId,
      Value<double?> duplicateScore,
      Value<int> rowid,
    });

class $$PendingTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get emailReceivedAt => $composableBuilder(
    column: $table.emailReceivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get parsedAmount => $composableBuilder(
    column: $table.parsedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parsedDescription => $composableBuilder(
    column: $table.parsedDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get parsedDate => $composableBuilder(
    column: $table.parsedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSnippet => $composableBuilder(
    column: $table.rawSnippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duplicateOfId => $composableBuilder(
    column: $table.duplicateOfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duplicateScore => $composableBuilder(
    column: $table.duplicateScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get emailReceivedAt => $composableBuilder(
    column: $table.emailReceivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get parsedAmount => $composableBuilder(
    column: $table.parsedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedDescription => $composableBuilder(
    column: $table.parsedDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get parsedDate => $composableBuilder(
    column: $table.parsedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSnippet => $composableBuilder(
    column: $table.rawSnippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duplicateOfId => $composableBuilder(
    column: $table.duplicateOfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duplicateScore => $composableBuilder(
    column: $table.duplicateScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingTransactionsTable> {
  $$PendingTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get emailReceivedAt => $composableBuilder(
    column: $table.emailReceivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get parsedAmount => $composableBuilder(
    column: $table.parsedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parsedDescription => $composableBuilder(
    column: $table.parsedDescription,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get parsedDate => $composableBuilder(
    column: $table.parsedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedType => $composableBuilder(
    column: $table.suggestedType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCategory => $composableBuilder(
    column: $table.suggestedCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawSnippet => $composableBuilder(
    column: $table.rawSnippet,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get duplicateOfId => $composableBuilder(
    column: $table.duplicateOfId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get duplicateScore => $composableBuilder(
    column: $table.duplicateScore,
    builder: (column) => column,
  );
}

class $$PendingTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingTransactionsTable,
          PendingTransaction,
          $$PendingTransactionsTableFilterComposer,
          $$PendingTransactionsTableOrderingComposer,
          $$PendingTransactionsTableAnnotationComposer,
          $$PendingTransactionsTableCreateCompanionBuilder,
          $$PendingTransactionsTableUpdateCompanionBuilder,
          (
            PendingTransaction,
            BaseReferences<
              _$AppDatabase,
              $PendingTransactionsTable,
              PendingTransaction
            >,
          ),
          PendingTransaction,
          PrefetchHooks Function()
        > {
  $$PendingTransactionsTableTableManager(
    _$AppDatabase db,
    $PendingTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> gmailMessageId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> emailSubject = const Value.absent(),
                Value<DateTime> emailReceivedAt = const Value.absent(),
                Value<double> parsedAmount = const Value.absent(),
                Value<String> parsedDescription = const Value.absent(),
                Value<DateTime> parsedDate = const Value.absent(),
                Value<String> suggestedType = const Value.absent(),
                Value<String?> suggestedCategory = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String> rawSnippet = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> duplicateOfId = const Value.absent(),
                Value<double?> duplicateScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingTransactionsCompanion(
                id: id,
                userId: userId,
                gmailMessageId: gmailMessageId,
                source: source,
                emailSubject: emailSubject,
                emailReceivedAt: emailReceivedAt,
                parsedAmount: parsedAmount,
                parsedDescription: parsedDescription,
                parsedDate: parsedDate,
                suggestedType: suggestedType,
                suggestedCategory: suggestedCategory,
                counterparty: counterparty,
                rawSnippet: rawSnippet,
                status: status,
                createdAt: createdAt,
                duplicateOfId: duplicateOfId,
                duplicateScore: duplicateScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String gmailMessageId,
                Value<String> source = const Value.absent(),
                required String emailSubject,
                required DateTime emailReceivedAt,
                required double parsedAmount,
                required String parsedDescription,
                required DateTime parsedDate,
                Value<String> suggestedType = const Value.absent(),
                Value<String?> suggestedCategory = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String> rawSnippet = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<String?> duplicateOfId = const Value.absent(),
                Value<double?> duplicateScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingTransactionsCompanion.insert(
                id: id,
                userId: userId,
                gmailMessageId: gmailMessageId,
                source: source,
                emailSubject: emailSubject,
                emailReceivedAt: emailReceivedAt,
                parsedAmount: parsedAmount,
                parsedDescription: parsedDescription,
                parsedDate: parsedDate,
                suggestedType: suggestedType,
                suggestedCategory: suggestedCategory,
                counterparty: counterparty,
                rawSnippet: rawSnippet,
                status: status,
                createdAt: createdAt,
                duplicateOfId: duplicateOfId,
                duplicateScore: duplicateScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingTransactionsTable,
      PendingTransaction,
      $$PendingTransactionsTableFilterComposer,
      $$PendingTransactionsTableOrderingComposer,
      $$PendingTransactionsTableAnnotationComposer,
      $$PendingTransactionsTableCreateCompanionBuilder,
      $$PendingTransactionsTableUpdateCompanionBuilder,
      (
        PendingTransaction,
        BaseReferences<
          _$AppDatabase,
          $PendingTransactionsTable,
          PendingTransaction
        >,
      ),
      PendingTransaction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$PendingTransactionsTableTableManager get pendingTransactions =>
      $$PendingTransactionsTableTableManager(_db, _db.pendingTransactions);
}
