import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:postgres/postgres.dart';

// События
abstract class TableEvent {}
class LoadTableData extends TableEvent {
  final String tableName;
  LoadTableData(this.tableName);
}

// Состояния
abstract class TableState {}
class TableInitial extends TableState {}
class TableLoading extends TableState {}
class TableLoaded extends TableState {
  final List<Map<String, dynamic>> data;
  TableLoaded(this.data);
}
class TableError extends TableState {
  final String message;
  TableError(this.message);
}
class ChangeTable extends TableState {
  final String message;
  ChangeTable(this.message);
}

// BLoC
class TableBloc extends Bloc<TableEvent, TableState> {
  final PostgreSQLConnection databaseConnection;

  TableBloc({required this.databaseConnection}) : super(TableInitial()) {
    on<LoadTableData>((event, emit) async {
      emit(TableLoading());
      try {
        List<Map<String, dynamic>> rows = await fetchData(event.tableName);
        emit(TableLoaded(rows));
      } catch (e) {
        emit(TableError(e.toString()));
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchData(String tableName) async {
    if (databaseConnection.isClosed) {
      await databaseConnection.open();
    }

    try {
      var result = await databaseConnection.query('SELECT * FROM $tableName');
      tableName == 'interaction' ? result = await databaseConnection.query('SELECT interaction.*, staff.lfp_staff AS staff, service.name_service AS service FROM interaction LEFT JOIN staff ON interaction.id_staff = staff.id_staff LEFT JOIN service ON interaction.id_service = service.id_service;')
          : tableName == 'car' ? result = await databaseConnection.query('SELECT car.*, brand_car.name_brand_car, brand_car.name_model_brand_car FROM car INNER JOIN brand_car ON car.id_model_brand_car = brand_car.id_model_brand_car;')
          : tableName == 'booking' ? result = await databaseConnection.query('SELECT booking.*, customer.lfp_customer FROM booking INNER JOIN customer ON booking.id_customer = customer.id_customer;')
          : null;
      print('$tableName');
      List<Map<String, dynamic>> rows = [];
      for (final row in result) {
        Map<String, dynamic> map = {};
        for (final field in row.toColumnMap().entries) {
          map[field.key] = field.value;
        }
        rows.add(map);
      }
      return rows;
    } catch (e) {
      print('Ошибка выполнения запроса к базе данных: $e');
      rethrow;
    }
  }

}
