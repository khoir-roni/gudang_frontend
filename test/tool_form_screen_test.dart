import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/tool.dart';
import '../lib/screens/tool_form_screen.dart';
import '../lib/services/api_service.dart';

// Mock ApiService Manual
class MockApiService extends ApiService {
  bool editCalled = false;

  @override
  Future<List<dynamic>> getTools() async {
    return [
      {'nama_barang': 'Obeng', 'lemari': 'A1', 'lokasi': 'Gudang 1'},
      {'nama_barang': 'Tang', 'lemari': 'A2', 'lokasi': 'Gudang 2'},
    ];
  }

  @override
  Future<dynamic> editTool({
    required int id,
    required String namaBarang,
    required int jumlah,
    required String lemari,
    required String lokasi,
    required String username,
  }) async {
    editCalled = true;
    return {'message': 'Success'};
  }
}

void main() {
  testWidgets('ToolFormScreen Edit Mode Test', (WidgetTester tester) async {
    final mockApi = MockApiService();

    // Data dummy untuk mode edit
    final tool = Tool(
      id: 1,
      namaBarang: 'Palu',
      jumlah: 5,
      lemari: 'B1',
      lokasi: 'Workshop',
      aksi: 'taruh',
      user: 'admin',
      tanggal: '2023-01-01',
    );

    await tester.pumpWidget(MaterialApp(
      home: ToolFormScreen(tool: tool, apiService: mockApi),
    ));

    // 1. Verifikasi Judul Form (Harus "Edit Barang", bukan "Ambil Barang")
    expect(find.text('Edit Barang'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    // 2. Verifikasi Nilai Awal Form
    expect(find.text('Palu'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // 3. Test Validasi Input Negatif
    await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah'), '-10');
    await tester.tap(find.text('Simpan'));
    await tester.pump(); // Rebuild UI

    // Dialog konfirmasi muncul (karena validasi form dipanggil sebelum dialog di kode asli,
    // tapi di kode yang saya berikan, dialog muncul DULU baru validasi.
    // Mari sesuaikan flow user: Klik Simpan -> Dialog Ya -> Validasi -> Error)

    // Klik 'Ya' di dialog konfirmasi
    await tester.tap(find.text('Ya'));
    await tester.pump();

    // Harusnya muncul error text di bawah field jumlah
    expect(find.text('Jumlah tidak boleh negatif'), findsOneWidget);
    expect(mockApi.editCalled, isFalse); // API belum boleh dipanggil

    // 4. Test Input Valid & Submit
    await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah'), '10');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.tap(find.text('Ya'));
    await tester.pump();

    // Verifikasi API terpanggil
    expect(mockApi.editCalled, isTrue);
  });

  testWidgets('ToolFormScreen Dropdown Test', (WidgetTester tester) async {
    final mockApi = MockApiService();

    await tester.pumpWidget(MaterialApp(
      home: ToolFormScreen(apiService: mockApi),
    ));

    // Tunggu future builder/init state selesai load suggestions
    await tester.pumpAndSettle();

    // Ketik 'Gudang' di lokasi
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lokasi / Ruangan'), 'Gudang');
    await tester.pump();

    // Verifikasi dropdown muncul (Gudang 1 dari mock data)
    expect(find.text('Gudang 1'), findsOneWidget);
  });
}
