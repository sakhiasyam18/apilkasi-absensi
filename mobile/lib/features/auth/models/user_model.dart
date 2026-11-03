class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? identifier; // NIP for dosen, NIM for mahasiswa
  final String role; // "dosen" or "mahasiswa"
  final String? programStudy;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.identifier,
    required this.role,
    this.programStudy,
  });

  bool get isDosen => role.toLowerCase() == 'dosen';
  bool get isMahasiswa => role.toLowerCase() == 'mahasiswa';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      identifier: json['identifier'] as String?,
      role: json['role'] as String? ?? 'dosen',
      programStudy: json['program_study'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'identifier': identifier,
      'role': role,
      'program_study': programStudy,
    };
  }

  static UserModel defaultDosen() {
    return UserModel(
      id: 1,
      email: 'ashar.pakawaru@um.ac.id',
      fullName: 'Dr. Ir. Ashar Pakawaru, S.T., M.T.',
      identifier: '19750815 200212 1 002',
      role: 'dosen',
      programStudy: 'S1 Teknik Informatika - Universitas Negeri Malang',
    );
  }

  static UserModel defaultMahasiswa() {
    return UserModel(
      id: 2,
      email: 'allen.sebastian@um.ac.id',
      fullName: 'Allen Sebastian',
      identifier: '240535678149',
      role: 'mahasiswa',
      programStudy: 'S1 Teknik Informatika',
    );
  }
}
