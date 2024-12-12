import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'table_bloc.dart';
import './loginpage.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'АИС',
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFDEAA8)),
      home: LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _postStaff;
  PostgreSQLConnection? connection;

  // Маппинг русских и английских названий таблиц
  final Map<String, String> tableNames = {
    'Покупатель': 'buyer',
    'Доставка': 'delivery',
    'Товар': 'product',
    'Категория товара': 'product_category',
    'Покупка': 'purchase',
    'Купленный товар': 'purchased_item',
    'Персонал': 'staff'
  };

  // Маппинг русских и английских названий атрибутов
  final Map<String, Map<String, String>> attributeNames = {
    'buyer': {
      'buyer_phone_number': 'Номер телефона',
      'buyer_surname': 'Фамилия',
      'buyer_name': 'Имя',
      'buyer_patronymic': 'Отчество',
    },
    'delivery': {
      'purchase_number': 'Номер чека',
      'delivery_address': 'Адрес доставки',
      'delivery_date': 'Дата доставки',
      'delivery_price': 'Стоимость доставки',
    },
    'product': {
      'product_article': 'Артикул товара',
      'product_category_name': 'Категория',
      'product_name': 'Наименование товара',
      'product_number_of_packages_in_s': 'Кол-во пакетов на складе',
      'product_packages_price': 'Цена за пакет',
      'product_type_of_wood': 'Тип древесины',
      'product_reference_information': 'Справочная информация товара',
      'product_number_in_one_package': 'Кол-во шт в пакете',
      'product_width': 'Ширина изделия',
      'product_thickness': 'Толщина изделия',
      'product_length': 'Длина изделия',
    },
    'product_category': {
      'product_category_name': 'Категория',
    },
    'purchase': {
      'purchase_number': 'Номер чека',
      'buyer_phone_number': 'Номер телефона',
      'purchase_date': 'Дата покупки',
      'purchase_payment_method': 'Способ платежа',
    },
    'purchased_item': {
      'product_article': 'Артикул товара',
      'purchase_number': 'Номер чека',
      'purchased_item_price': 'Цена купленного товара',
      'purchased_item_amount': 'Кол-во пакетов купленного товара',
    },
    'staff': {
      'id_staff': 'Номер сотрудника',
      'lfp_staff': 'ФИО сотрудника',
      'post_staff': 'Должность',
      'login': 'Логин',
      'password': 'Пароль',
    },
  };

  // Маппинг исключаемых атрибутов
  final Map<String, List<String>> excludedAttributes = {
    'staff': ['id_staff', 'login', 'password'],
  };

  Map<String, String> primaryKeyMap = {
    'buyer': 'buyer_phone_number',
    'delivery': 'purchase_number',
    'product': 'product_article',
    'product_category': 'product_category_name',
    'purchase': 'purchase_number',
    'purchased_item': 'product_article',
    'staff': 'id_staff',
  };

  List<String> report = [
    'Сумма выручки за период времени',
    'Самый популярный товар за период времени',
    'Самый популярный тип древесины',
    'Распечатать чек'
  ];

  List<String> procedure = ['Оформить покупку'];

  String currentTable = 'buyer';

  // Маппинг должностей к доступным таблицам на их изменение и добавление
  final Map<String, List<String>> accessControl = {
    'Администратор': [
      'buyer',
      'delivery',
      'product',
      'product_category',
      'purchase',
      'purchased_item',
      'staff'
    ],
    'Продавец': [
      'buyer',
      'delivery',
      // 'purchase',
      // 'purchased_item',
    ],
    'Заведующий складом': [
      'product',
      'product_category',
    ],
    'Владелец': [
      'buyer',
      'delivery',
      'product',
      'product_category',
      'purchase',
      'purchased_item',
      'staff'
    ],
  };

  @override
  void initState() {
    super.initState();
    loadConfigAndConnect();
    _loadPostStaff();
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
      print('Подключение к базе данных прошло успешно.');
      setState(() {}); // Обновление состояния после успешного соединения
    } catch (e) {
      print('Ошибка подключения к базе данных: $e');
    }
  }

  Future<Map<String, dynamic>> loadDatabaseConfig() async {
    final configString = await rootBundle.loadString('assets/db_config.json');
    return json.decode(configString) as Map<String, dynamic>;
  }

  Future<void> _loadPostStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _postStaff = prefs.getString('post_staff');

      // Удаление доступа к таблицам и отчетам
      _postStaff == 'Продавец'
          ? {
              tableNames.remove('Персонал'),
              report.remove('Сумма выручки за период времени'),
              report.remove('Самый популярный товар за период времени'),
              report.remove('Самый популярный тип древесины')
            }
          : null;
      _postStaff == 'Заведующий складом'
          ? {
              tableNames.remove('Персонал'),
              report.remove('Сумма выручки за период времени'),
              report.remove('Самый популярный товар за период времени'),
              report.remove('Самый популярный тип древесины'),
              report.remove('Распечатать чек'),
              procedure.remove('Оформить покупку')
            }
          : null;
    });
  }

  void fetchDataFromTable(BuildContext context, String tableName) {
    String englishTableName = tableNames[tableName] ?? tableName;
    BlocProvider.of<TableBloc>(context).add(LoadTableData(englishTableName));
  }

  @override
  Widget build(BuildContext context) {
    if (connection == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Компания по торговле пиломатериалами'),
        ),
        body: Center(
          child:
              CircularProgressIndicator(), // Показываем индикатор загрузки, пока соединение устанавливается
        ),
      );
    }

    return BlocProvider<TableBloc>(
      create: (context) => TableBloc(databaseConnection: connection!),
      child: Builder(
        builder: (newContext) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Компания по торговле пиломатериалами'),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    child: const Text('Справка'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => mytext()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 18.0),
                  child: ElevatedButton(
                    child: const Text('Выход из системы'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Image.network(
                    "https://pilomaterial-info.ru/wp-content/uploads/2023/05/logo03.png",
                    scale: 2.0,
                  ),
                  const SizedBox(height: 10),
                  const Row(
                      textDirection: TextDirection.ltr,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      verticalDirection: VerticalDirection.down,
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: Center(child: Text('Таблицы')),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(child: Text('Отчёты')),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(child: Text('Процедуры')),
                        ),
                      ]),
                  SizedBox(
                    height: 370,
                    child: Row(
                      textDirection: TextDirection.ltr,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      verticalDirection: VerticalDirection.down,
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tableNames.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (BuildContext context, int index) {
                              String tableName =
                                  tableNames.keys.elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    fetchDataFromTable(newContext, tableName);
                                    currentTable = tableNames[tableName]!;
                                  },
                                  child: Text(tableName),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                            flex: 1,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: report.length,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (BuildContext context, int index) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _showReportDialog(context, index);
                                    },
                                    child: Text(report[index]),
                                  ),
                                );
                              },
                            )),
                        Expanded(
                          flex: 1,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: procedure.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (BuildContext context, int index) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showCreatePurchaseDialog(context);

                                    // _showCreateBookingInteractionDialog(context);
                                  },
                                  child: Text(procedure[index]),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 2,
                      color: Colors.black26,
                    ),
                  ),
                  BlocBuilder<TableBloc, TableState>(
                    builder: (newContext, state) {
                      if (state is TableLoading) {
                        return CircularProgressIndicator();
                      } else if (state is TableLoaded) {
                        print(state.data);
                        var columns = state.data.isNotEmpty
                            ? state.data.first.keys.toList()
                            : [];
                        var filteredColumns = columns.where((column) {
                          return !(excludedAttributes[currentTable]
                                  ?.contains(column) ??
                              false);
                        }).toList();
                        var russianColumnNames = filteredColumns.map((column) {
                          return attributeNames[currentTable]?[column] ??
                              column;
                        }).toList();

                        return Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: russianColumnNames
                                    .map((column) =>
                                        DataColumn(label: Text(column)))
                                    .toList(),
                                rows: state.data.map((row) {
                                  return DataRow(
                                    cells: filteredColumns
                                        .map((column) => DataCell(
                                            Text('${row[column] ?? ''}')))
                                        .toList(),
                                    selected: true,
                                    onLongPress: () {
                                      if (accessControl[_postStaff]
                                              ?.contains(currentTable) ??
                                          false) {
                                        _showEditDialog(
                                            context, row, currentTable);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (accessControl[_postStaff]
                                    ?.contains(currentTable) ??
                                false)
                              ElevatedButton(
                                onPressed: () {
                                  _showAddDialog(
                                      context,
                                      filteredColumns
                                          .map((column) => column.toString())
                                          .toList());
                                },
                                child: const Text(
                                  "Добавить запись",
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        );
                      } else if (state is TableError) {
                        return Text('Ошибка: ${state.message}');
                      } else {
                        return Container(); // Пустое состояние или инструкции
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, Map<String, dynamic> rowData, String tableName) {
    final textControllers = <String, TextEditingController>{};
    rowData.forEach((key, value) {
      textControllers[key] = TextEditingController(text: value.toString());
    });

    // Получение имени первичного ключа для текущей таблицы
    String? primaryKeyName = primaryKeyMap[tableName];

    if (primaryKeyName == null) {
      print("Первичный ключ для таблицы $tableName не найден.");
      return;
    }

    // Получение русских названий столбцов
    var russianColumnNames = rowData.keys.map((column) {
      return attributeNames[tableName]?[column] ?? column;
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Редактировать"),
          content: SingleChildScrollView(
            child: ListBody(
              children: List.generate(rowData.length, (index) {
                String columnName = rowData.keys.elementAt(index);
                return TextField(
                  controller: textControllers[columnName],
                  decoration: InputDecoration(
                    labelText: russianColumnNames[
                        index], // Используем русское название столбца как метку
                  ),
                );
              }),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text("Удалить", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                // Выполнение SQL запроса для удаления
                try {
                  String deleteSQL =
                      "DELETE FROM $tableName WHERE $primaryKeyName = @value";
                  await connection!.execute(deleteSQL,
                      substitutionValues: {"value": rowData[primaryKeyName]});
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => MyHomePage()),
                    (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  print("Ошибка удаления записи: $e");
                }
              },
            ),
            ElevatedButton(
              child: const Text("Сохранить"),
              onPressed: () async {
                // Выполнение SQL запроса для обновления
                try {
                  Map<String, String> updateValues = {};
                  textControllers.forEach((key, value) {
                    updateValues[key] = value.text;
                  });

                  String setString = updateValues.entries
                      .map((entry) => "${entry.key} = @${entry.key}")
                      .join(", ");
                  String updateSQL =
                      "UPDATE $tableName SET $setString WHERE $primaryKeyName = @primaryKeyValue";
                  updateValues['primaryKeyValue'] =
                      rowData[primaryKeyName].toString();

                  await connection!
                      .execute(updateSQL, substitutionValues: updateValues);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => MyHomePage()),
                    (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  print("Ошибка обновления записи: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password); // Переводим пароль в байты
    final digest = sha256.convert(bytes); // Хэшируем байты
    return digest.toString(); // Возвращаем хэш в виде строки
  }

  void _showAddDialog(BuildContext context, List<String> columnNames) {
    // Системные поля, которые не будут отображаться, но будут добавляться

    currentTable == 'staff'
        ? {columnNames.add('login'), columnNames.add('password')}
        : null;

    // Создаем контроллеры для текстовых полей каждого столбца
    final textControllers = Map.fromIterable(
      columnNames,
      // предполагается, что columnNames это List<String> названий столбцов
      key: (columnName) => columnName,
      value: (columnName) => TextEditingController(),
    );

    // Получение русских названий столбцов
    var russianColumnNames = columnNames.map((column) {
      return attributeNames[currentTable]?[column] ?? column;
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Добавить запись"),
          content: SingleChildScrollView(
            child: ListBody(
              children: List.generate(columnNames.length, (index) {
                String columnName = columnNames[index];
                return TextField(
                  controller: textControllers[columnName],
                  decoration: InputDecoration(
                    labelText: russianColumnNames[index],
                  ),
                );
              }),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text(
                "Отмена",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Сохранить"),
              onPressed: () async {
                // Выполните запрос на добавление данных
                try {
                  Map<String, String> substitutionValues = {};
                  textControllers.forEach((key, value) {
                    currentTable == 'staff' && key == 'password'
                        ? {substitutionValues[key] = hashPassword(value.text)}
                        : substitutionValues[key] = value.text;
                  });

                  // Создание строки с названиями столбцов и строкой с плейсхолдерами для значений
                  String columns = substitutionValues.keys.join(', ');
                  String values =
                      substitutionValues.keys.map((k) => '@$k').join(', ');

                  // SQL запрос на вставку
                  String insertSQL =
                      "INSERT INTO $currentTable ($columns) VALUES ($values)";
                  currentTable == 'car'
                      ? insertSQL = "SELECT insert_car($values)"
                      : currentTable == 'interaction'
                          ? insertSQL = "SELECT insert_interactions($values)"
                          : currentTable == 'booking'
                              ? insertSQL = "SELECT insert_booking($values)"
                              : null;
                  print(values);

                  // Выполнение запроса с подстановкой значений
                  await connection!.execute(insertSQL,
                      substitutionValues: substitutionValues);

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => MyHomePage()),
                    (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  // Обработка возможных ошибок при добавлении данных
                  print("Ошибка добавления записи: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, int reportIndex) async {
    // Создание контроллеров для текстовых полей
    final firstDateController = TextEditingController();
    final secondDateController = TextEditingController();

    // Создание списка виджетов для текстовых полей
    List<Widget> inputFields = [];

    if (reportIndex == 0 || reportIndex == 1) {
      inputFields.add(TextField(
        controller: firstDateController,
        decoration: const InputDecoration(labelText: 'С какой даты'),
        keyboardType: TextInputType.number,
      ));
      inputFields.add(TextField(
        controller: secondDateController,
        decoration: const InputDecoration(labelText: 'По какую дату'),
        keyboardType: TextInputType.number,
      ));
    }

    // Показать диалоговое окно
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Введите данные"),
          content: SingleChildScrollView(
            child: ListBody(children: inputFields),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text(
                'Отмена',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Показать'),
              onPressed: () async {
                // Здесь нужно подготовить и выполнить SQL запрос
                String sqlQuery = '';
                switch (reportIndex) {
                  case 0:
                    // Запрос для первого отчета
                    sqlQuery =
                        "SELECT get_total_purchase_profit('${firstDateController.text}', '${secondDateController.text}');";
                    break;
                  case 1:
                    // Запрос для второго отчета
                    sqlQuery =
                        "SELECT * FROM get_most_popular_product ('${firstDateController.text}', '${secondDateController.text}')";
                    break;
                  case 2:
                    // Запрос для третьего отчета
                    sqlQuery = "SELECT * FROM get_most_popular_wood_type ()";
                    break;
                  case 3:
                    // Запрос для чека
                    sqlQuery = "SELECT * FROM get_check()";
                    break;
                }

                try {
                  // Выполнение запроса
                  var results = await connection!.query(sqlQuery);
                  var columnNames = results.columnDescriptions
                      .map((col) => col.columnName)
                      .toList();

                  // Перевод названий столбцов
                  String englishTableName =
                      'product'; // Определите английское название таблицы
                  var translatedColumnNames = columnNames.map((column) {
                    return attributeNames[englishTableName]?[column] ?? column;
                  }).toList();

                  // Замена значений null на "-"
                  var dataRows = results.map((row) {
                    return row.map((cell) => cell?.toString() ?? "-").toList();
                  }).toList();

                  // Закрытие текущего диалогового окна
                  Navigator.of(context).pop();

                  // Загрузка шрифта
                  final fontData = await rootBundle
                      .load("assets/fonts/OpenSans-Regular.ttf");
                  final ttf = pw.Font.ttf(fontData);

                  // Создание PDF-документа
                  final pdf = pw.Document();

                  final ByteData bytes =
                      await rootBundle.load('assets/logo.png');
                  final Uint8List byteList = bytes.buffer.asUint8List();

                  // Добавление страницы с заголовком, таблицей данных и подвалом
                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) {
                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Image(pw.MemoryImage(byteList), height: 100),
                            pw.Text(
                              'Компания по торговле пиломатериалами\nОГРНИП: 3-14-50-444444444-7\nАдрес: 398055, Россия, г. Липецк, ул. Московская, д.30.\nТелефон: +7 (4742) 328-000.\nФакс: +7 (4742) 31-04-73',
                              style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Table.fromTextArray(
                              headers: translatedColumnNames,
                              data: dataRows,
                              headerStyle: pw.TextStyle(
                                  font: ttf, fontWeight: pw.FontWeight.bold),
                              cellStyle: pw.TextStyle(font: ttf),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'Дата создания отчета: ${DateTime.now()}\nОтчёт сформирован по требованию: Виноградова Артёма Михайловича',
                              style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),
                  );

                  // Открытие диалога для выбора директории
                  String? outputDir =
                      await FilePicker.platform.getDirectoryPath();

                  if (outputDir != null) {
                    final filePath =
                        "$outputDir/report_${report[reportIndex]}.pdf";

                    // Сохранение PDF-файла
                    final file = File(filePath);
                    await file.writeAsBytes(await pdf.save());

                    // Отображение сообщения об успешном сохранении
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Отчет сохранен в $filePath")),
                    );
                  } else {
                    // Отображение сообщения об отмене сохранения
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Сохранение отчета отменено")),
                    );
                  }
                } catch (e) {
                  print("Ошибка выполнения запроса: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreatePurchaseDialog(BuildContext context) {
    final inBuyerPhoneNumberController = TextEditingController();
    final inPurchasePaymentMethodController = TextEditingController();
    final inProductArticleController = TextEditingController();
    final inPurchasedItemAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isCreatingPurchase = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Создать покупку"),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    TextField(
                      controller: inBuyerPhoneNumberController,
                      decoration: InputDecoration(
                          labelText: 'Номер телефона покупателя'),
                    ),
                    TextField(
                      controller: inPurchasePaymentMethodController,
                      decoration: InputDecoration(labelText: 'Способ оплаты'),
                    ),
                    TextField(
                      controller: inProductArticleController,
                      decoration: InputDecoration(labelText: 'Артикул товара'),
                    ),
                    TextField(
                      controller: inPurchasedItemAmountController,
                      decoration: InputDecoration(
                          labelText: 'Кол-во купленного товара'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                if (isCreatingPurchase) ...[
                  ElevatedButton(
                    child: Text("Создать покупку"),
                    onPressed: () async {
                      try {
                        // Вызов хранимой процедуры с параметрами
                        await connection!.execute(
                            "CALL create_purchase_pocedure('${inBuyerPhoneNumberController.text}', ${inPurchasePaymentMethodController.text}, ${inProductArticleController.text}, ${inPurchasedItemAmountController.text})");
                        // Закрыть диалоговое окно при успехе
                        setState(() {
                          inProductArticleController.clear();
                          inPurchasedItemAmountController.clear();
                          isCreatingPurchase = false;
                        });
                      } catch (e) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Ошибка"),
                              content: Text("Произошла ошибка: $e"),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: Text("OK"),
                                  onPressed: () => Navigator.of(context)
                                      .pop(), // Закрыть окно сообщения об ошибке
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                    // onPressed: () {
                    //   try {
                    //     setState(() {
                    //       connection!.execute(
                    //           "CALL create_purchase_pocedure('${inBuyerPhoneNumberController.text}', ${inPurchasePaymentMethodController.text}, ${inProductArticleController.text}, ${inPurchasedItemAmountController.text})");
                    //       inProductArticleController.clear();
                    //       inPurchasedItemAmountController.clear();
                    //       isCreatingPurchase = false;
                    //     });
                    //   } catch (e) {
                    //     showDialog(
                    //       context: context,
                    //       builder: (BuildContext context) {
                    //         return AlertDialog(
                    //           title: Text("Ошибка"),
                    //           content: Text("Произошла ошибка: $e"),
                    //           actions: <Widget>[
                    //             ElevatedButton(
                    //               child: Text("OK"),
                    //               onPressed: () => Navigator.of(context)
                    //                   .pop(), // Закрыть окно сообщения об ошибке
                    //             ),
                    //           ],
                    //         );
                    //       },
                    //     );
                    //   }
                    // },
                  ),
                  ElevatedButton(
                    child: Text(
                      "Отмена",
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ] else ...[
                  ElevatedButton(
                    child: Text("Добавить к покупке"),
                    onPressed: () async {
                      try {
                        // Вызов хранимой процедуры с параметрами
                        await connection!.execute(
                            "CALL add_product_to_current_purchase_procedure(${inProductArticleController.text}, ${inPurchasedItemAmountController.text})");
                        // Закрыть диалоговое окно при успехе
                        setState(() {
                          inProductArticleController.clear();
                          inPurchasedItemAmountController.clear();
                        });
                      } catch (e) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Ошибка"),
                              content: Text("Произошла ошибка: $e"),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: Text("OK"),
                                  onPressed: () => Navigator.of(context)
                                      .pop(), // Закрыть окно сообщения об ошибке
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                    // onPressed: () {
                    //   setState(() {
                    //     connection!.execute(
                    //         "CALL add_product_to_current_purchase_procedure(${inProductArticleController.text}, ${inPurchasedItemAmountController.text})");
                    //     inProductArticleController.clear();
                    //     inPurchasedItemAmountController.clear();
                    //   });
                    // },
                  ),
                  ElevatedButton(
                    child: Text("Завершить покупку"),
                    onPressed: () {
                      inProductArticleController.text.isEmpty ||
                              inPurchasedItemAmountController.text.isEmpty
                          ? {
                              // Просто закроем потому что данные введены
                              Navigator.of(context).pop(),
                            }
                          : {
                              connection!.execute(
                                  "CALL add_product_to_current_purchase_procedure(${inProductArticleController.text}, ${inPurchasedItemAmountController.text})"),
                              print(
                                  'Подставим значения в функцию ${inProductArticleController.text} ${inPurchasedItemAmountController.text}'),
                              inProductArticleController.clear(),
                              inPurchasedItemAmountController.clear(),
                              Navigator.of(context).pop(),
                            };
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class mytext extends StatelessWidget {
  var randomtext = """
  1.1.	Область применения
  Данный продукт разработан для автоматизации бизнес-процессов, связанных с деятельностью магазина по продаже пиломатериалов.
  1.2.	Краткое описание возможностей
  Разработанная программа предоставляет возможность взаимодействовать с информационной системой магазина по продаже пиломатериалов разным группам пользователей. Есть возможность просматривать информацию о товарах, покупателях и т.д.. Также реализован механизм оформления продаж. Владельцу представляется возможность добавления всех данных, генерации отчетов и добавления новых пользователей.
  1.3.	Уровень подготовки пользователя
  Для взаимодействия с программой пользователь должен обладать базовыми навыками работами с операционными системами, такими как: Windows или macOS, а также иметь базовые знания в области продажи пиломатериалов.
  1.4.	Перечень эксплуатационной документации, с которыми необходимо ознакомиться пользователю
  Пользователю необходимо ознакомиться с техническим проектом и техническим заданием рассматриваемой информационной системы.
  2.	Назначение и условия применения
  2.1.	Виды деятельности, функции, для автоматизации которых предназначено данное средство автоматизации
  Данное средство автоматизации предназначено для организации оформления продажи товаров, учета покупателей и содержимого склада, а также оформления новых покупок и отслеживания уже совершённых.
  2.2.	Условия, при соблюдении которых обеспечивается применение средства автоматизации
  Минимальные требования для работы программы:
  1)	ОС Windows 10, macOS 11;
  2)	Не менее 200 МБ свободной оперативной памяти;
  3)	Не менее 200 Мб свободной памяти на накопителе;
  4)	Мышь;
  5)	Клавиатура;
  6)	Монитор.
  3.	Подготовка к работе
  3.1.	Состав и содержание дистрибутивного носителя данных
  Модуль не требует предварительной установки на рабочую станцию пользователя.
  3.2.	Порядок загрузки данных и программ
  Обращение к программе осуществляется при помощи запуска исполнительного файла «tree_app.app» или «tree_app.exe» (зависит от ОС).
  3.3.	Порядок проверки работоспособности
  После успешной загрузки приложения появится «экран входа» для выбора пользователя. После входа будут доступны дополнительные функции, объём и функционал которых зависит от уровня прав доступа конкретного пользователя.
  
  4. Описание оформления покупки:
  На вход подаётся номер телефона покупателя, способ оплаты, артикул товара, кол-во купленных пакетов, после чего проверяется существование товара с таким артикулом и корректность ввода способа оплаты. После создаётся запись в таблице «Покупка», вычисляется итоговая сумма купленного товара, добавляется запись в таблицу «Купленный товар» и из кол-ва товара на складе таблицы «Товар» вычитается кол-во купленного.
  """;
  @override
  Widget build(BuildContext context) {
    return new Container(
      child: new Scaffold(
        appBar: new AppBar(),
        body: new SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: new Text(
              randomtext,
              style: new TextStyle(fontSize: 20.0),
            ),
          ),
        ),
      ),
    );
  }
}
