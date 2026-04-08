import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';
import '../services/gedcom_parser.dart';

class TreeProvider with ChangeNotifier {
  List<Person> _persons = [];
  Database? _database;
  String? _token;
  static const String _baseUrl = 'http://localhost:3000'; // Change to your server

  List<Person> get persons => _persons;
  bool get isLoggedIn => _token != null;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ancestry.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        name TEXT,
        birthDate TEXT,
        birthPlace TEXT,
        deathDate TEXT,
        deathPlace TEXT,
        gender TEXT,
        parentIds TEXT,
        childIds TEXT,
        spouseId TEXT
      )
    ''');
  }

  Future<void> loadPersons() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('persons');
    _persons = maps.map((map) => Person.fromMap(map)).toList();
    notifyListeners();
  }

  Future<void> addPerson(Person person) async {
    final db = await database;
    await db.insert('persons', person.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _persons.add(person);
    notifyListeners();
  }

  Future<void> importGEDCOM(String filePath) async {
    final parser = GEDCOMParser();
    final persons = await parser.parse(filePath);
    for (final person in persons) {
      await addPerson(person);
    }
  }

  Future<bool> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return true;
    }
    return false;
  }

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> syncWithServer() async {
    if (_token == null) return;
    // Upload local data
    final response = await http.post(
      Uri.parse('$_baseUrl/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'persons': _persons.map((p) => p.toMap()).toList()}),
    );
    if (response.statusCode == 200) {
      // Download and merge
      final getResponse = await http.get(
        Uri.parse('$_baseUrl/persons'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (getResponse.statusCode == 200) {
        final data = jsonDecode(getResponse.body) as List;
        final serverPersons = data.map((p) => Person.fromMap(p)).toList();
        // For simplicity, replace local with server
        final db = await database;
        await db.delete('persons');
        for (final person in serverPersons) {
          await db.insert('persons', person.toMap());
        }
        _persons = serverPersons;
        notifyListeners();
      }
    }
  }
}
