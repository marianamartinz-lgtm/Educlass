import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Banco SQLite local do EduClass.
///
/// No Windows/Linux/macOS usamos sqflite_common_ffi.
/// No Android/iOS o sqflite normal é usado.
class BancoDados {
  static Database? _database;

  static const String nomeBanco = 'educlass.db';
  static const int versaoBanco = 2;

  /// Inicializa o SQLite para desktop.
  static void inicializarSQLite() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Retorna a conexão única com o banco.
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _abrirBanco();
    return _database!;
  }

  static Future<Database> _abrirBanco() async {
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, nomeBanco);

    print('==============================================');
    print('EduClass - SQLite');
    print('Banco: $caminho');
    print('==============================================');

    return openDatabase(
      caminho,
      version: versaoBanco,
      onCreate: (db, version) async {
        await _criarTabelas(db);
        print('Banco SQLite criado com sucesso!');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Atualizando SQLite: $oldVersion -> $newVersion');
        await _criarTabelas(db);
        await _garantirColunasUsuarios(db);
      },
      onOpen: (db) async {
        // Garante a tabela mesmo se um banco antigo já existir.
        await _criarTabelaUsuarios(db);
        await _garantirColunasUsuarios(db);
      },
    );
  }

  static Future<void> _criarTabelas(Database db) async {
    await _criarTabelaUsuarios(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS professores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT UNIQUE,
        cidade TEXT,
        estado TEXT,
        criado_em TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS escolas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        municipio TEXT,
        estado TEXT,
        codigo_inep TEXT,
        criado_em TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS turmas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        serie TEXT,
        criado_em TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _criarTabelaUsuarios(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL,
        escola TEXT,
        municipio TEXT,
        estado TEXT,
        materias TEXT,
        criado_em TEXT NOT NULL
      )
    ''');
  }

  /// Adiciona colunas que possam não existir em bancos antigos.
  static Future<void> _garantirColunasUsuarios(Database db) async {
    final colunas = await db.rawQuery('PRAGMA table_info(usuarios)');
    final nomes = colunas
        .map((e) => e['name']?.toString())
        .whereType<String>()
        .toSet();

    final novasColunas = <String, String>{
      'escola': 'TEXT',
      'municipio': 'TEXT',
      'estado': 'TEXT',
      'materias': 'TEXT',
      'criado_em': 'TEXT',
    };

    for (final entry in novasColunas.entries) {
      if (!nomes.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE usuarios ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  /// Salva um novo cadastro no SQLite.
  static Future<int> inserirUsuario({
    required String nome,
    required String email,
    required String senha,
    String? escola,
    String? municipio,
    String? estado,
    List<String>? materias,
  }) async {
    final db = await database;

    final dados = <String, dynamic>{
      'nome': nome.trim(),
      'email': email.trim().toLowerCase(),
      'senha': senha,
      'escola': escola?.trim() ?? '',
      'municipio': municipio?.trim() ?? '',
      'estado': estado?.trim() ?? '',
      'materias': jsonEncode(materias ?? <String>[]),
      'criado_em': DateTime.now().toIso8601String(),
    };

    final id = await db.insert(
      'usuarios',
      dados,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    print('Cadastro salvo no SQLite! ID: $id');
    print('E-mail: ${dados['email']}');
    print('Escola: ${dados['escola']}');
    print('Município: ${dados['municipio']}');
    print('Estado: ${dados['estado']}');
    print('Matérias: ${dados['materias']}');

    return id;
  }

  /// Busca um usuário pelo e-mail.
  static Future<Map<String, dynamic>?> buscarUsuario(String email) async {
    final db = await database;

    final resultado = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (resultado.isEmpty) return null;
    return resultado.first;
  }

  /// Lista todos os usuários cadastrados.
  static Future<List<Map<String, dynamic>>> listarUsuarios() async {
    final db = await database;
    return db.query('usuarios', orderBy: 'id DESC');
  }

  /// Remove um usuário pelo ID.
  static Future<int> deletarUsuario(int id) async {
    final db = await database;
    return db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  /// Exclui o arquivo/banco inteiro. Use apenas durante o desenvolvimento.
  static Future<void> apagarBanco() async {
    await fecharBanco();
    final pasta = await getDatabasesPath();
    final caminho = join(pasta, nomeBanco);
    await databaseFactory.deleteDatabase(caminho);
    print('Banco EduClass apagado.');
  }

  static Future<void> fecharBanco() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
