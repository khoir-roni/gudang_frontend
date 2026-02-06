import 'package:flutter/material.dart';
import '../models/tool.dart';
import '../services/api_service.dart';

class ToolFormScreen extends StatefulWidget {
  // Jika `tool` tidak null, berarti ini adalah mode edit.
  // Jika null, ini adalah mode tambah.
  final Tool? tool;
  final ApiService? apiService; // Untuk testing
  final String? initialName;

  const ToolFormScreen({Key? key, this.tool, this.apiService, this.initialName})
      : super(key: key);

  @override
  _ToolFormScreenState createState() => _ToolFormScreenState();
}

class _ToolFormScreenState extends State<ToolFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiService _apiService;
  bool _isLoading = false;
  String _selectedAction = 'taruh';

  // Controller untuk setiap field
  late TextEditingController _namaController;
  late TextEditingController _jumlahController;
  late TextEditingController _lemariController;
  late TextEditingController _lokasiController;

  // List untuk dropdown
  List<String> _allLokasi = [];
  List<String> _filteredLokasiList = [];
  List<String> _allLemari = [];
  List<String> _filteredLemariList = [];
  List<String> _allNamaBarang = [];
  List<String> _filteredNamaBarangList = [];
  List<String> _allJumlah = [];
  List<String> _filteredJumlahList = [];

  bool get _isEditing => widget.tool != null;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    // Inisialisasi controller dengan data yang ada jika dalam mode edit
    _namaController = TextEditingController(
        text: widget.tool?.namaBarang ?? widget.initialName ?? '');
    _jumlahController =
        TextEditingController(text: widget.tool?.jumlah.toString() ?? '');
    _lemariController = TextEditingController(text: widget.tool?.lemari ?? '');
    _lokasiController = TextEditingController(text: widget.tool?.lokasi ?? '');
    _selectedAction = widget.tool?.aksi ?? 'taruh';

    _lokasiController.addListener(_onLokasiChanged);
    _lemariController.addListener(_onLemariChanged);
    _namaController.addListener(_onNamaBarangChanged);
    _jumlahController.addListener(_onJumlahChanged);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final tools = await _apiService.getTools();
      if (mounted) {
        setState(() {
          _allLokasi =
              tools.map((e) => e['lokasi'].toString()).toSet().toList();
          _allLemari =
              tools.map((e) => e['lemari'].toString()).toSet().toList();
          _allNamaBarang =
              tools.map((e) => e['nama_barang'].toString()).toSet().toList();
          _allJumlah =
              tools.map((e) => e['jumlah'].toString()).toSet().toList();
        });
      }
    } catch (e) {
      print('Error loading suggestions: $e');
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _jumlahController.dispose();
    _lemariController.dispose();
    _lokasiController.dispose();
    super.dispose();
  }

  void _onLokasiChanged() {
    final query = _lokasiController.text.toLowerCase();
    setState(() {
      _filteredLokasiList = _allLokasi
          .where((item) => item.toLowerCase().contains(query))
          .take(5)
          .toList();
    });
  }

  void _onLemariChanged() {
    final query = _lemariController.text.toLowerCase();
    setState(() {
      _filteredLemariList = _allLemari
          .where((item) => item.toLowerCase().contains(query))
          .take(5)
          .toList();
    });
  }

  void _onNamaBarangChanged() {
    final query = _namaController.text.toLowerCase();
    setState(() {
      _filteredNamaBarangList = _allNamaBarang
          .where((item) => item.toLowerCase().contains(query))
          .take(5)
          .toList();
    });
  }

  void _onJumlahChanged() {
    final query = _jumlahController.text.toLowerCase();
    setState(() {
      _filteredJumlahList = _allJumlah
          .where((item) => item.toLowerCase().contains(query))
          .take(5)
          .toList();
    });
  }

  Future<void> _submitForm() async {
    // Validasi form
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (_isEditing) {
          // Mode edit: Update data barang (termasuk merge & history)
          await _apiService.editTool(
            id: widget.tool!.id,
            namaBarang: _namaController.text,
            jumlah: int.tryParse(_jumlahController.text) ?? 0,
            lemari: _lemariController.text,
            lokasi: _lokasiController.text,
            username: 'admin', // TODO: Ganti dengan username yang sedang login
          );
        } else {
          // Mode tambah: Tambah barang baru
          final toolData = {
            'nama_barang': _namaController.text,
            'jumlah': int.tryParse(_jumlahController.text) ?? 0,
            'lemari': _lemariController.text,
            'lokasi': _lokasiController.text,
            'username':
                'admin', // TODO: Ganti dengan username yang sedang login
          };
          await _apiService.addTool(toolData);
        }

        // Kembali ke layar sebelumnya dengan hasil sukses
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        // Tampilkan pesan error jika gagal
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDropdownList(List<String> items,
      TextEditingController controller, Function(List<String>) onClear) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            dense: true,
            title: Text(items[index]),
            onTap: () {
              controller.text = items[index];
              onClear([]); // Tutup dropdown
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Barang' : 'Tambah Barang';
    final buttonLabel = _isEditing ? 'Simpan' : 'Tambah';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Barang'),
                validator: (value) =>
                    value!.isEmpty ? 'Nama barang tidak boleh kosong' : null,
              ),
              if (_filteredNamaBarangList.isNotEmpty)
                _buildDropdownList(_filteredNamaBarangList, _namaController,
                    (l) => setState(() => _filteredNamaBarangList = l)),
              TextFormField(
                controller: _jumlahController,
                decoration: InputDecoration(
                  labelText: 'Jumlah',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Jumlah tidak boleh kosong';
                  final n = int.tryParse(value);
                  if (n == null) return 'Masukkan angka yang valid';
                  if (n < 0) return 'Jumlah tidak boleh negatif';
                  return null;
                },
              ),
              if (_filteredJumlahList.isNotEmpty)
                _buildDropdownList(_filteredJumlahList, _jumlahController,
                    (l) => setState(() => _filteredJumlahList = l)),
              TextFormField(
                controller: _lemariController,
                decoration: const InputDecoration(labelText: 'Lemari / Rak'),
                validator: (value) =>
                    value!.isEmpty ? 'Lemari tidak boleh kosong' : null,
              ),
              if (_filteredLemariList.isNotEmpty)
                _buildDropdownList(_filteredLemariList, _lemariController,
                    (l) => setState(() => _filteredLemariList = l)),
              TextFormField(
                controller: _lokasiController,
                decoration:
                    const InputDecoration(labelText: 'Lokasi / Ruangan'),
                validator: (value) =>
                    value!.isEmpty ? 'Lokasi tidak boleh kosong' : null,
              ),
              if (_filteredLokasiList.isNotEmpty)
                _buildDropdownList(_filteredLokasiList, _lokasiController,
                    (l) => setState(() => _filteredLokasiList = l)),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(_isEditing
                                ? 'Konfirmasi Ambil'
                                : 'Konfirmasi Tambah'),
                            content: Text(
                              _isEditing
                                  ? 'Simpan perubahan untuk "${_namaController.text}"?'
                                  : 'Tambah "${_namaController.text}" sebanyak ${_jumlahController.text}?',
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Batal')),
                              ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Ya')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _submitForm();
                        }
                      },
                      child: Text(buttonLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
