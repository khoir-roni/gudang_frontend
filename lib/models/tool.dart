
import 'dart:convert';

class Tool {
  final int id;
  final String namaBarang;
  final int jumlah;
  final String lemari;
  final String lokasi;
  final String? user; // username who added/modified
  final String? tanggal; // ISO string timestamp from backend
  final String? aksi; // 'ambil' or 'taruh'

  Tool({
    required this.id,
    required this.namaBarang,
    required this.jumlah,
    required this.lemari,
    required this.lokasi,
    this.user,
    this.tanggal,
    this.aksi,
  });

  // Factory constructor untuk membuat instance Tool dari JSON map
  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'],
      namaBarang: json['nama_barang'] ?? '',
      jumlah: json['jumlah'] ?? 0,
      lemari: json['lemari'] ?? '',
      lokasi: json['lokasi'] ?? '',
      user: json['username'] ?? json['user'],
      tanggal: json['tanggal'] ?? json['created_at'],
      aksi: json['aksi'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama_barang': namaBarang,
        'jumlah': jumlah,
        'lemari': lemari,
        'lokasi': lokasi,
        'username': user,
        'tanggal': tanggal,
        'aksi': aksi,
      };
}

// Helper function untuk mem-parse list JSON menjadi List<Tool>
List<Tool> toolsFromJson(String str) => List<Tool>.from(json.decode(str).map((x) => Tool.fromJson(x)));
