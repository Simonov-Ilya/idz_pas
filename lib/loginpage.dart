import 'dart:convert';
import './main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class LoginPage extends StatefulWidget {
  LoginPage();

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  PostgreSQLConnection? connection;
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadConfigAndConnect();
  }

  Future<void> loadConfigAndConnect() async {
    try {
      final config = await loadDatabaseConfig();
      connection = PostgreSQLConnection(
        config['hostname'],
        config['port'],
        config['databaseName'],
        username: config['username'],
        password: config['password'],
      );
      await connection!.open();
      print('Connected to PostgreSQL database.');
      setState(() {}); // Обновление состояния после успешного соединения
    } catch (e) {
      print('Error connecting to PostgreSQL database: $e');
    }
  }

  Future<Map<String, dynamic>> loadDatabaseConfig() async {
    final configString = await rootBundle.loadString('assets/db_config.json');
    return json.decode(configString) as Map<String, dynamic>;
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password); // Переводим пароль в байты
    final digest = sha256.convert(bytes); // Хэшируем байты
    return digest.toString(); // Возвращаем хэш в виде строки
  }

  Future<void> _authenticate() async {
    final login = _loginController.text;
    final password = _passwordController.text;

    // Хэшируем пароль перед отправкой его в базу данных
    final hashedPassword = hashPassword(password);
    print(hashedPassword);

    try {
      final results = await connection!.query(
        'SELECT * FROM staff WHERE login = @login AND password = @password',
        substitutionValues: {
          'login': login,
          'password': hashedPassword,
        },
      );

      if (results.isNotEmpty) {
        final postStaff = results.first[2].toString();
        print('post_staff: $postStaff');

        // Сохраняем post_staff в shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('post_staff', postStaff);

        // Переходим на следующую страницу
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MyHomePage()),
              (Route<dynamic> route) => false,
        );
      } else {
        setState(() {
          _errorMessage = 'Неверный логин или пароль';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка авторизации: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Авторизация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _loginController,
              decoration: InputDecoration(labelText: 'Логин'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
