// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TabellaEsamiTable extends TabellaEsami
    with TableInfo<$TabellaEsamiTable, TabellaEsamiData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabellaEsamiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dataIsoMeta = const VerificationMeta(
    'dataIso',
  );
  @override
  late final GeneratedColumn<String> dataIso = GeneratedColumn<String>(
    'data_iso',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 10,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _laboratorioMeta = const VerificationMeta(
    'laboratorio',
  );
  @override
  late final GeneratedColumn<String> laboratorio = GeneratedColumn<String>(
    'laboratorio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jsonDriveIdMeta = const VerificationMeta(
    'jsonDriveId',
  );
  @override
  late final GeneratedColumn<String> jsonDriveId = GeneratedColumn<String>(
    'json_drive_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfDriveIdMeta = const VerificationMeta(
    'pdfDriveId',
  );
  @override
  late final GeneratedColumn<String> pdfDriveId = GeneratedColumn<String>(
    'pdf_drive_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificatoIlMeta = const VerificationMeta(
    'modificatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> modificatoIl = GeneratedColumn<DateTime>(
    'modificato_il',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dataIso,
    laboratorio,
    jsonDriveId,
    pdfDriveId,
    modificatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabella_esami';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabellaEsamiData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('data_iso')) {
      context.handle(
        _dataIsoMeta,
        dataIso.isAcceptableOrUnknown(data['data_iso']!, _dataIsoMeta),
      );
    } else if (isInserting) {
      context.missing(_dataIsoMeta);
    }
    if (data.containsKey('laboratorio')) {
      context.handle(
        _laboratorioMeta,
        laboratorio.isAcceptableOrUnknown(
          data['laboratorio']!,
          _laboratorioMeta,
        ),
      );
    }
    if (data.containsKey('json_drive_id')) {
      context.handle(
        _jsonDriveIdMeta,
        jsonDriveId.isAcceptableOrUnknown(
          data['json_drive_id']!,
          _jsonDriveIdMeta,
        ),
      );
    }
    if (data.containsKey('pdf_drive_id')) {
      context.handle(
        _pdfDriveIdMeta,
        pdfDriveId.isAcceptableOrUnknown(
          data['pdf_drive_id']!,
          _pdfDriveIdMeta,
        ),
      );
    }
    if (data.containsKey('modificato_il')) {
      context.handle(
        _modificatoIlMeta,
        modificatoIl.isAcceptableOrUnknown(
          data['modificato_il']!,
          _modificatoIlMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dataIso};
  @override
  TabellaEsamiData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabellaEsamiData(
      dataIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_iso'],
      )!,
      laboratorio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}laboratorio'],
      ),
      jsonDriveId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_drive_id'],
      ),
      pdfDriveId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_drive_id'],
      ),
      modificatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificato_il'],
      ),
    );
  }

  @override
  $TabellaEsamiTable createAlias(String alias) {
    return $TabellaEsamiTable(attachedDatabase, alias);
  }
}

class TabellaEsamiData extends DataClass
    implements Insertable<TabellaEsamiData> {
  final String dataIso;
  final String? laboratorio;
  final String? jsonDriveId;
  final String? pdfDriveId;

  /// modifiedTime del JSON su Drive: usato dalla sync per capire se il
  /// file remoto è cambiato rispetto alla copia in cache.
  final DateTime? modificatoIl;
  const TabellaEsamiData({
    required this.dataIso,
    this.laboratorio,
    this.jsonDriveId,
    this.pdfDriveId,
    this.modificatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['data_iso'] = Variable<String>(dataIso);
    if (!nullToAbsent || laboratorio != null) {
      map['laboratorio'] = Variable<String>(laboratorio);
    }
    if (!nullToAbsent || jsonDriveId != null) {
      map['json_drive_id'] = Variable<String>(jsonDriveId);
    }
    if (!nullToAbsent || pdfDriveId != null) {
      map['pdf_drive_id'] = Variable<String>(pdfDriveId);
    }
    if (!nullToAbsent || modificatoIl != null) {
      map['modificato_il'] = Variable<DateTime>(modificatoIl);
    }
    return map;
  }

  TabellaEsamiCompanion toCompanion(bool nullToAbsent) {
    return TabellaEsamiCompanion(
      dataIso: Value(dataIso),
      laboratorio: laboratorio == null && nullToAbsent
          ? const Value.absent()
          : Value(laboratorio),
      jsonDriveId: jsonDriveId == null && nullToAbsent
          ? const Value.absent()
          : Value(jsonDriveId),
      pdfDriveId: pdfDriveId == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfDriveId),
      modificatoIl: modificatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(modificatoIl),
    );
  }

  factory TabellaEsamiData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabellaEsamiData(
      dataIso: serializer.fromJson<String>(json['dataIso']),
      laboratorio: serializer.fromJson<String?>(json['laboratorio']),
      jsonDriveId: serializer.fromJson<String?>(json['jsonDriveId']),
      pdfDriveId: serializer.fromJson<String?>(json['pdfDriveId']),
      modificatoIl: serializer.fromJson<DateTime?>(json['modificatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dataIso': serializer.toJson<String>(dataIso),
      'laboratorio': serializer.toJson<String?>(laboratorio),
      'jsonDriveId': serializer.toJson<String?>(jsonDriveId),
      'pdfDriveId': serializer.toJson<String?>(pdfDriveId),
      'modificatoIl': serializer.toJson<DateTime?>(modificatoIl),
    };
  }

  TabellaEsamiData copyWith({
    String? dataIso,
    Value<String?> laboratorio = const Value.absent(),
    Value<String?> jsonDriveId = const Value.absent(),
    Value<String?> pdfDriveId = const Value.absent(),
    Value<DateTime?> modificatoIl = const Value.absent(),
  }) => TabellaEsamiData(
    dataIso: dataIso ?? this.dataIso,
    laboratorio: laboratorio.present ? laboratorio.value : this.laboratorio,
    jsonDriveId: jsonDriveId.present ? jsonDriveId.value : this.jsonDriveId,
    pdfDriveId: pdfDriveId.present ? pdfDriveId.value : this.pdfDriveId,
    modificatoIl: modificatoIl.present ? modificatoIl.value : this.modificatoIl,
  );
  TabellaEsamiData copyWithCompanion(TabellaEsamiCompanion data) {
    return TabellaEsamiData(
      dataIso: data.dataIso.present ? data.dataIso.value : this.dataIso,
      laboratorio: data.laboratorio.present
          ? data.laboratorio.value
          : this.laboratorio,
      jsonDriveId: data.jsonDriveId.present
          ? data.jsonDriveId.value
          : this.jsonDriveId,
      pdfDriveId: data.pdfDriveId.present
          ? data.pdfDriveId.value
          : this.pdfDriveId,
      modificatoIl: data.modificatoIl.present
          ? data.modificatoIl.value
          : this.modificatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabellaEsamiData(')
          ..write('dataIso: $dataIso, ')
          ..write('laboratorio: $laboratorio, ')
          ..write('jsonDriveId: $jsonDriveId, ')
          ..write('pdfDriveId: $pdfDriveId, ')
          ..write('modificatoIl: $modificatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(dataIso, laboratorio, jsonDriveId, pdfDriveId, modificatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabellaEsamiData &&
          other.dataIso == this.dataIso &&
          other.laboratorio == this.laboratorio &&
          other.jsonDriveId == this.jsonDriveId &&
          other.pdfDriveId == this.pdfDriveId &&
          other.modificatoIl == this.modificatoIl);
}

class TabellaEsamiCompanion extends UpdateCompanion<TabellaEsamiData> {
  final Value<String> dataIso;
  final Value<String?> laboratorio;
  final Value<String?> jsonDriveId;
  final Value<String?> pdfDriveId;
  final Value<DateTime?> modificatoIl;
  final Value<int> rowid;
  const TabellaEsamiCompanion({
    this.dataIso = const Value.absent(),
    this.laboratorio = const Value.absent(),
    this.jsonDriveId = const Value.absent(),
    this.pdfDriveId = const Value.absent(),
    this.modificatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabellaEsamiCompanion.insert({
    required String dataIso,
    this.laboratorio = const Value.absent(),
    this.jsonDriveId = const Value.absent(),
    this.pdfDriveId = const Value.absent(),
    this.modificatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dataIso = Value(dataIso);
  static Insertable<TabellaEsamiData> custom({
    Expression<String>? dataIso,
    Expression<String>? laboratorio,
    Expression<String>? jsonDriveId,
    Expression<String>? pdfDriveId,
    Expression<DateTime>? modificatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dataIso != null) 'data_iso': dataIso,
      if (laboratorio != null) 'laboratorio': laboratorio,
      if (jsonDriveId != null) 'json_drive_id': jsonDriveId,
      if (pdfDriveId != null) 'pdf_drive_id': pdfDriveId,
      if (modificatoIl != null) 'modificato_il': modificatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabellaEsamiCompanion copyWith({
    Value<String>? dataIso,
    Value<String?>? laboratorio,
    Value<String?>? jsonDriveId,
    Value<String?>? pdfDriveId,
    Value<DateTime?>? modificatoIl,
    Value<int>? rowid,
  }) {
    return TabellaEsamiCompanion(
      dataIso: dataIso ?? this.dataIso,
      laboratorio: laboratorio ?? this.laboratorio,
      jsonDriveId: jsonDriveId ?? this.jsonDriveId,
      pdfDriveId: pdfDriveId ?? this.pdfDriveId,
      modificatoIl: modificatoIl ?? this.modificatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dataIso.present) {
      map['data_iso'] = Variable<String>(dataIso.value);
    }
    if (laboratorio.present) {
      map['laboratorio'] = Variable<String>(laboratorio.value);
    }
    if (jsonDriveId.present) {
      map['json_drive_id'] = Variable<String>(jsonDriveId.value);
    }
    if (pdfDriveId.present) {
      map['pdf_drive_id'] = Variable<String>(pdfDriveId.value);
    }
    if (modificatoIl.present) {
      map['modificato_il'] = Variable<DateTime>(modificatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabellaEsamiCompanion(')
          ..write('dataIso: $dataIso, ')
          ..write('laboratorio: $laboratorio, ')
          ..write('jsonDriveId: $jsonDriveId, ')
          ..write('pdfDriveId: $pdfDriveId, ')
          ..write('modificatoIl: $modificatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TabellaValoriTable extends TabellaValori
    with TableInfo<$TabellaValoriTable, TabellaValoriData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabellaValoriTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _esameDataIsoMeta = const VerificationMeta(
    'esameDataIso',
  );
  @override
  late final GeneratedColumn<String> esameDataIso = GeneratedColumn<String>(
    'esame_data_iso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tabella_esami (data_iso) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valoreMeta = const VerificationMeta('valore');
  @override
  late final GeneratedColumn<double> valore = GeneratedColumn<double>(
    'valore',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitaMeta = const VerificationMeta('unita');
  @override
  late final GeneratedColumn<String> unita = GeneratedColumn<String>(
    'unita',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rangeMinMeta = const VerificationMeta(
    'rangeMin',
  );
  @override
  late final GeneratedColumn<double> rangeMin = GeneratedColumn<double>(
    'range_min',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rangeMaxMeta = const VerificationMeta(
    'rangeMax',
  );
  @override
  late final GeneratedColumn<double> rangeMax = GeneratedColumn<double>(
    'range_max',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    esameDataIso,
    nome,
    valore,
    unita,
    rangeMin,
    rangeMax,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabella_valori';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabellaValoriData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('esame_data_iso')) {
      context.handle(
        _esameDataIsoMeta,
        esameDataIso.isAcceptableOrUnknown(
          data['esame_data_iso']!,
          _esameDataIsoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_esameDataIsoMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('valore')) {
      context.handle(
        _valoreMeta,
        valore.isAcceptableOrUnknown(data['valore']!, _valoreMeta),
      );
    } else if (isInserting) {
      context.missing(_valoreMeta);
    }
    if (data.containsKey('unita')) {
      context.handle(
        _unitaMeta,
        unita.isAcceptableOrUnknown(data['unita']!, _unitaMeta),
      );
    }
    if (data.containsKey('range_min')) {
      context.handle(
        _rangeMinMeta,
        rangeMin.isAcceptableOrUnknown(data['range_min']!, _rangeMinMeta),
      );
    }
    if (data.containsKey('range_max')) {
      context.handle(
        _rangeMaxMeta,
        rangeMax.isAcceptableOrUnknown(data['range_max']!, _rangeMaxMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TabellaValoriData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabellaValoriData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      esameDataIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}esame_data_iso'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      valore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}valore'],
      )!,
      unita: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unita'],
      )!,
      rangeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}range_min'],
      ),
      rangeMax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}range_max'],
      ),
    );
  }

  @override
  $TabellaValoriTable createAlias(String alias) {
    return $TabellaValoriTable(attachedDatabase, alias);
  }
}

class TabellaValoriData extends DataClass
    implements Insertable<TabellaValoriData> {
  final int id;
  final String esameDataIso;
  final String nome;
  final double valore;
  final String unita;
  final double? rangeMin;
  final double? rangeMax;
  const TabellaValoriData({
    required this.id,
    required this.esameDataIso,
    required this.nome,
    required this.valore,
    required this.unita,
    this.rangeMin,
    this.rangeMax,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['esame_data_iso'] = Variable<String>(esameDataIso);
    map['nome'] = Variable<String>(nome);
    map['valore'] = Variable<double>(valore);
    map['unita'] = Variable<String>(unita);
    if (!nullToAbsent || rangeMin != null) {
      map['range_min'] = Variable<double>(rangeMin);
    }
    if (!nullToAbsent || rangeMax != null) {
      map['range_max'] = Variable<double>(rangeMax);
    }
    return map;
  }

  TabellaValoriCompanion toCompanion(bool nullToAbsent) {
    return TabellaValoriCompanion(
      id: Value(id),
      esameDataIso: Value(esameDataIso),
      nome: Value(nome),
      valore: Value(valore),
      unita: Value(unita),
      rangeMin: rangeMin == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeMin),
      rangeMax: rangeMax == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeMax),
    );
  }

  factory TabellaValoriData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabellaValoriData(
      id: serializer.fromJson<int>(json['id']),
      esameDataIso: serializer.fromJson<String>(json['esameDataIso']),
      nome: serializer.fromJson<String>(json['nome']),
      valore: serializer.fromJson<double>(json['valore']),
      unita: serializer.fromJson<String>(json['unita']),
      rangeMin: serializer.fromJson<double?>(json['rangeMin']),
      rangeMax: serializer.fromJson<double?>(json['rangeMax']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'esameDataIso': serializer.toJson<String>(esameDataIso),
      'nome': serializer.toJson<String>(nome),
      'valore': serializer.toJson<double>(valore),
      'unita': serializer.toJson<String>(unita),
      'rangeMin': serializer.toJson<double?>(rangeMin),
      'rangeMax': serializer.toJson<double?>(rangeMax),
    };
  }

  TabellaValoriData copyWith({
    int? id,
    String? esameDataIso,
    String? nome,
    double? valore,
    String? unita,
    Value<double?> rangeMin = const Value.absent(),
    Value<double?> rangeMax = const Value.absent(),
  }) => TabellaValoriData(
    id: id ?? this.id,
    esameDataIso: esameDataIso ?? this.esameDataIso,
    nome: nome ?? this.nome,
    valore: valore ?? this.valore,
    unita: unita ?? this.unita,
    rangeMin: rangeMin.present ? rangeMin.value : this.rangeMin,
    rangeMax: rangeMax.present ? rangeMax.value : this.rangeMax,
  );
  TabellaValoriData copyWithCompanion(TabellaValoriCompanion data) {
    return TabellaValoriData(
      id: data.id.present ? data.id.value : this.id,
      esameDataIso: data.esameDataIso.present
          ? data.esameDataIso.value
          : this.esameDataIso,
      nome: data.nome.present ? data.nome.value : this.nome,
      valore: data.valore.present ? data.valore.value : this.valore,
      unita: data.unita.present ? data.unita.value : this.unita,
      rangeMin: data.rangeMin.present ? data.rangeMin.value : this.rangeMin,
      rangeMax: data.rangeMax.present ? data.rangeMax.value : this.rangeMax,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabellaValoriData(')
          ..write('id: $id, ')
          ..write('esameDataIso: $esameDataIso, ')
          ..write('nome: $nome, ')
          ..write('valore: $valore, ')
          ..write('unita: $unita, ')
          ..write('rangeMin: $rangeMin, ')
          ..write('rangeMax: $rangeMax')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, esameDataIso, nome, valore, unita, rangeMin, rangeMax);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabellaValoriData &&
          other.id == this.id &&
          other.esameDataIso == this.esameDataIso &&
          other.nome == this.nome &&
          other.valore == this.valore &&
          other.unita == this.unita &&
          other.rangeMin == this.rangeMin &&
          other.rangeMax == this.rangeMax);
}

class TabellaValoriCompanion extends UpdateCompanion<TabellaValoriData> {
  final Value<int> id;
  final Value<String> esameDataIso;
  final Value<String> nome;
  final Value<double> valore;
  final Value<String> unita;
  final Value<double?> rangeMin;
  final Value<double?> rangeMax;
  const TabellaValoriCompanion({
    this.id = const Value.absent(),
    this.esameDataIso = const Value.absent(),
    this.nome = const Value.absent(),
    this.valore = const Value.absent(),
    this.unita = const Value.absent(),
    this.rangeMin = const Value.absent(),
    this.rangeMax = const Value.absent(),
  });
  TabellaValoriCompanion.insert({
    this.id = const Value.absent(),
    required String esameDataIso,
    required String nome,
    required double valore,
    this.unita = const Value.absent(),
    this.rangeMin = const Value.absent(),
    this.rangeMax = const Value.absent(),
  }) : esameDataIso = Value(esameDataIso),
       nome = Value(nome),
       valore = Value(valore);
  static Insertable<TabellaValoriData> custom({
    Expression<int>? id,
    Expression<String>? esameDataIso,
    Expression<String>? nome,
    Expression<double>? valore,
    Expression<String>? unita,
    Expression<double>? rangeMin,
    Expression<double>? rangeMax,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (esameDataIso != null) 'esame_data_iso': esameDataIso,
      if (nome != null) 'nome': nome,
      if (valore != null) 'valore': valore,
      if (unita != null) 'unita': unita,
      if (rangeMin != null) 'range_min': rangeMin,
      if (rangeMax != null) 'range_max': rangeMax,
    });
  }

  TabellaValoriCompanion copyWith({
    Value<int>? id,
    Value<String>? esameDataIso,
    Value<String>? nome,
    Value<double>? valore,
    Value<String>? unita,
    Value<double?>? rangeMin,
    Value<double?>? rangeMax,
  }) {
    return TabellaValoriCompanion(
      id: id ?? this.id,
      esameDataIso: esameDataIso ?? this.esameDataIso,
      nome: nome ?? this.nome,
      valore: valore ?? this.valore,
      unita: unita ?? this.unita,
      rangeMin: rangeMin ?? this.rangeMin,
      rangeMax: rangeMax ?? this.rangeMax,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (esameDataIso.present) {
      map['esame_data_iso'] = Variable<String>(esameDataIso.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (valore.present) {
      map['valore'] = Variable<double>(valore.value);
    }
    if (unita.present) {
      map['unita'] = Variable<String>(unita.value);
    }
    if (rangeMin.present) {
      map['range_min'] = Variable<double>(rangeMin.value);
    }
    if (rangeMax.present) {
      map['range_max'] = Variable<double>(rangeMax.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabellaValoriCompanion(')
          ..write('id: $id, ')
          ..write('esameDataIso: $esameDataIso, ')
          ..write('nome: $nome, ')
          ..write('valore: $valore, ')
          ..write('unita: $unita, ')
          ..write('rangeMin: $rangeMin, ')
          ..write('rangeMax: $rangeMax')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TabellaEsamiTable tabellaEsami = $TabellaEsamiTable(this);
  late final $TabellaValoriTable tabellaValori = $TabellaValoriTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tabellaEsami,
    tabellaValori,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tabella_esami',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tabella_valori', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TabellaEsamiTableCreateCompanionBuilder =
    TabellaEsamiCompanion Function({
      required String dataIso,
      Value<String?> laboratorio,
      Value<String?> jsonDriveId,
      Value<String?> pdfDriveId,
      Value<DateTime?> modificatoIl,
      Value<int> rowid,
    });
typedef $$TabellaEsamiTableUpdateCompanionBuilder =
    TabellaEsamiCompanion Function({
      Value<String> dataIso,
      Value<String?> laboratorio,
      Value<String?> jsonDriveId,
      Value<String?> pdfDriveId,
      Value<DateTime?> modificatoIl,
      Value<int> rowid,
    });

final class $$TabellaEsamiTableReferences
    extends
        BaseReferences<_$AppDatabase, $TabellaEsamiTable, TabellaEsamiData> {
  $$TabellaEsamiTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TabellaValoriTable, List<TabellaValoriData>>
  _tabellaValoriRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tabellaValori,
    aliasName: $_aliasNameGenerator(
      db.tabellaEsami.dataIso,
      db.tabellaValori.esameDataIso,
    ),
  );

  $$TabellaValoriTableProcessedTableManager get tabellaValoriRefs {
    final manager = $$TabellaValoriTableTableManager($_db, $_db.tabellaValori)
        .filter(
          (f) => f.esameDataIso.dataIso.sqlEquals(
            $_itemColumn<String>('data_iso')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_tabellaValoriRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TabellaEsamiTableFilterComposer
    extends Composer<_$AppDatabase, $TabellaEsamiTable> {
  $$TabellaEsamiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dataIso => $composableBuilder(
    column: $table.dataIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get laboratorio => $composableBuilder(
    column: $table.laboratorio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonDriveId => $composableBuilder(
    column: $table.jsonDriveId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfDriveId => $composableBuilder(
    column: $table.pdfDriveId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificatoIl => $composableBuilder(
    column: $table.modificatoIl,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tabellaValoriRefs(
    Expression<bool> Function($$TabellaValoriTableFilterComposer f) f,
  ) {
    final $$TabellaValoriTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dataIso,
      referencedTable: $db.tabellaValori,
      getReferencedColumn: (t) => t.esameDataIso,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabellaValoriTableFilterComposer(
            $db: $db,
            $table: $db.tabellaValori,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TabellaEsamiTableOrderingComposer
    extends Composer<_$AppDatabase, $TabellaEsamiTable> {
  $$TabellaEsamiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dataIso => $composableBuilder(
    column: $table.dataIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get laboratorio => $composableBuilder(
    column: $table.laboratorio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonDriveId => $composableBuilder(
    column: $table.jsonDriveId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfDriveId => $composableBuilder(
    column: $table.pdfDriveId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificatoIl => $composableBuilder(
    column: $table.modificatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TabellaEsamiTableAnnotationComposer
    extends Composer<_$AppDatabase, $TabellaEsamiTable> {
  $$TabellaEsamiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dataIso =>
      $composableBuilder(column: $table.dataIso, builder: (column) => column);

  GeneratedColumn<String> get laboratorio => $composableBuilder(
    column: $table.laboratorio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonDriveId => $composableBuilder(
    column: $table.jsonDriveId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfDriveId => $composableBuilder(
    column: $table.pdfDriveId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get modificatoIl => $composableBuilder(
    column: $table.modificatoIl,
    builder: (column) => column,
  );

  Expression<T> tabellaValoriRefs<T extends Object>(
    Expression<T> Function($$TabellaValoriTableAnnotationComposer a) f,
  ) {
    final $$TabellaValoriTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dataIso,
      referencedTable: $db.tabellaValori,
      getReferencedColumn: (t) => t.esameDataIso,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabellaValoriTableAnnotationComposer(
            $db: $db,
            $table: $db.tabellaValori,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TabellaEsamiTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TabellaEsamiTable,
          TabellaEsamiData,
          $$TabellaEsamiTableFilterComposer,
          $$TabellaEsamiTableOrderingComposer,
          $$TabellaEsamiTableAnnotationComposer,
          $$TabellaEsamiTableCreateCompanionBuilder,
          $$TabellaEsamiTableUpdateCompanionBuilder,
          (TabellaEsamiData, $$TabellaEsamiTableReferences),
          TabellaEsamiData,
          PrefetchHooks Function({bool tabellaValoriRefs})
        > {
  $$TabellaEsamiTableTableManager(_$AppDatabase db, $TabellaEsamiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabellaEsamiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabellaEsamiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabellaEsamiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dataIso = const Value.absent(),
                Value<String?> laboratorio = const Value.absent(),
                Value<String?> jsonDriveId = const Value.absent(),
                Value<String?> pdfDriveId = const Value.absent(),
                Value<DateTime?> modificatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabellaEsamiCompanion(
                dataIso: dataIso,
                laboratorio: laboratorio,
                jsonDriveId: jsonDriveId,
                pdfDriveId: pdfDriveId,
                modificatoIl: modificatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dataIso,
                Value<String?> laboratorio = const Value.absent(),
                Value<String?> jsonDriveId = const Value.absent(),
                Value<String?> pdfDriveId = const Value.absent(),
                Value<DateTime?> modificatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabellaEsamiCompanion.insert(
                dataIso: dataIso,
                laboratorio: laboratorio,
                jsonDriveId: jsonDriveId,
                pdfDriveId: pdfDriveId,
                modificatoIl: modificatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabellaEsamiTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tabellaValoriRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tabellaValoriRefs) db.tabellaValori,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tabellaValoriRefs)
                    await $_getPrefetchedData<
                      TabellaEsamiData,
                      $TabellaEsamiTable,
                      TabellaValoriData
                    >(
                      currentTable: table,
                      referencedTable: $$TabellaEsamiTableReferences
                          ._tabellaValoriRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TabellaEsamiTableReferences(
                            db,
                            table,
                            p0,
                          ).tabellaValoriRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.esameDataIso == item.dataIso,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TabellaEsamiTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TabellaEsamiTable,
      TabellaEsamiData,
      $$TabellaEsamiTableFilterComposer,
      $$TabellaEsamiTableOrderingComposer,
      $$TabellaEsamiTableAnnotationComposer,
      $$TabellaEsamiTableCreateCompanionBuilder,
      $$TabellaEsamiTableUpdateCompanionBuilder,
      (TabellaEsamiData, $$TabellaEsamiTableReferences),
      TabellaEsamiData,
      PrefetchHooks Function({bool tabellaValoriRefs})
    >;
typedef $$TabellaValoriTableCreateCompanionBuilder =
    TabellaValoriCompanion Function({
      Value<int> id,
      required String esameDataIso,
      required String nome,
      required double valore,
      Value<String> unita,
      Value<double?> rangeMin,
      Value<double?> rangeMax,
    });
typedef $$TabellaValoriTableUpdateCompanionBuilder =
    TabellaValoriCompanion Function({
      Value<int> id,
      Value<String> esameDataIso,
      Value<String> nome,
      Value<double> valore,
      Value<String> unita,
      Value<double?> rangeMin,
      Value<double?> rangeMax,
    });

final class $$TabellaValoriTableReferences
    extends
        BaseReferences<_$AppDatabase, $TabellaValoriTable, TabellaValoriData> {
  $$TabellaValoriTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TabellaEsamiTable _esameDataIsoTable(_$AppDatabase db) =>
      db.tabellaEsami.createAlias(
        $_aliasNameGenerator(
          db.tabellaValori.esameDataIso,
          db.tabellaEsami.dataIso,
        ),
      );

  $$TabellaEsamiTableProcessedTableManager get esameDataIso {
    final $_column = $_itemColumn<String>('esame_data_iso')!;

    final manager = $$TabellaEsamiTableTableManager(
      $_db,
      $_db.tabellaEsami,
    ).filter((f) => f.dataIso.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_esameDataIsoTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TabellaValoriTableFilterComposer
    extends Composer<_$AppDatabase, $TabellaValoriTable> {
  $$TabellaValoriTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rangeMin => $composableBuilder(
    column: $table.rangeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rangeMax => $composableBuilder(
    column: $table.rangeMax,
    builder: (column) => ColumnFilters(column),
  );

  $$TabellaEsamiTableFilterComposer get esameDataIso {
    final $$TabellaEsamiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.esameDataIso,
      referencedTable: $db.tabellaEsami,
      getReferencedColumn: (t) => t.dataIso,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabellaEsamiTableFilterComposer(
            $db: $db,
            $table: $db.tabellaEsami,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabellaValoriTableOrderingComposer
    extends Composer<_$AppDatabase, $TabellaValoriTable> {
  $$TabellaValoriTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unita => $composableBuilder(
    column: $table.unita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rangeMin => $composableBuilder(
    column: $table.rangeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rangeMax => $composableBuilder(
    column: $table.rangeMax,
    builder: (column) => ColumnOrderings(column),
  );

  $$TabellaEsamiTableOrderingComposer get esameDataIso {
    final $$TabellaEsamiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.esameDataIso,
      referencedTable: $db.tabellaEsami,
      getReferencedColumn: (t) => t.dataIso,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabellaEsamiTableOrderingComposer(
            $db: $db,
            $table: $db.tabellaEsami,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabellaValoriTableAnnotationComposer
    extends Composer<_$AppDatabase, $TabellaValoriTable> {
  $$TabellaValoriTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<double> get valore =>
      $composableBuilder(column: $table.valore, builder: (column) => column);

  GeneratedColumn<String> get unita =>
      $composableBuilder(column: $table.unita, builder: (column) => column);

  GeneratedColumn<double> get rangeMin =>
      $composableBuilder(column: $table.rangeMin, builder: (column) => column);

  GeneratedColumn<double> get rangeMax =>
      $composableBuilder(column: $table.rangeMax, builder: (column) => column);

  $$TabellaEsamiTableAnnotationComposer get esameDataIso {
    final $$TabellaEsamiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.esameDataIso,
      referencedTable: $db.tabellaEsami,
      getReferencedColumn: (t) => t.dataIso,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabellaEsamiTableAnnotationComposer(
            $db: $db,
            $table: $db.tabellaEsami,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabellaValoriTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TabellaValoriTable,
          TabellaValoriData,
          $$TabellaValoriTableFilterComposer,
          $$TabellaValoriTableOrderingComposer,
          $$TabellaValoriTableAnnotationComposer,
          $$TabellaValoriTableCreateCompanionBuilder,
          $$TabellaValoriTableUpdateCompanionBuilder,
          (TabellaValoriData, $$TabellaValoriTableReferences),
          TabellaValoriData,
          PrefetchHooks Function({bool esameDataIso})
        > {
  $$TabellaValoriTableTableManager(_$AppDatabase db, $TabellaValoriTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabellaValoriTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabellaValoriTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabellaValoriTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> esameDataIso = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<double> valore = const Value.absent(),
                Value<String> unita = const Value.absent(),
                Value<double?> rangeMin = const Value.absent(),
                Value<double?> rangeMax = const Value.absent(),
              }) => TabellaValoriCompanion(
                id: id,
                esameDataIso: esameDataIso,
                nome: nome,
                valore: valore,
                unita: unita,
                rangeMin: rangeMin,
                rangeMax: rangeMax,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String esameDataIso,
                required String nome,
                required double valore,
                Value<String> unita = const Value.absent(),
                Value<double?> rangeMin = const Value.absent(),
                Value<double?> rangeMax = const Value.absent(),
              }) => TabellaValoriCompanion.insert(
                id: id,
                esameDataIso: esameDataIso,
                nome: nome,
                valore: valore,
                unita: unita,
                rangeMin: rangeMin,
                rangeMax: rangeMax,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabellaValoriTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({esameDataIso = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (esameDataIso) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.esameDataIso,
                                referencedTable: $$TabellaValoriTableReferences
                                    ._esameDataIsoTable(db),
                                referencedColumn: $$TabellaValoriTableReferences
                                    ._esameDataIsoTable(db)
                                    .dataIso,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TabellaValoriTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TabellaValoriTable,
      TabellaValoriData,
      $$TabellaValoriTableFilterComposer,
      $$TabellaValoriTableOrderingComposer,
      $$TabellaValoriTableAnnotationComposer,
      $$TabellaValoriTableCreateCompanionBuilder,
      $$TabellaValoriTableUpdateCompanionBuilder,
      (TabellaValoriData, $$TabellaValoriTableReferences),
      TabellaValoriData,
      PrefetchHooks Function({bool esameDataIso})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TabellaEsamiTableTableManager get tabellaEsami =>
      $$TabellaEsamiTableTableManager(_db, _db.tabellaEsami);
  $$TabellaValoriTableTableManager get tabellaValori =>
      $$TabellaValoriTableTableManager(_db, _db.tabellaValori);
}
