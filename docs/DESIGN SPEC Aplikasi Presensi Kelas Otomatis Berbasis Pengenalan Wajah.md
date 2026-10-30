# DESIGN SPEC: Aplikasi Presensi Kelas Otomatis Berbasis Pengenalan Wajah

> Dokumen ini adalah **sumber kebenaran tunggal** (single source of truth) untuk membangun proyek.
> Ditujukan untuk dibaca oleh AI coding agent (Antigravity) dan developer.
> Gabungan dari Tugas 1, Tugas 2, dan Diagram Spesifikasi Sistem, sudah diselaraskan.
> Penulis: Asyam Sakhi Maulana (240535600363), Daffa Aleia Amrita Waskitha (240535612453).
> **Revisi 2:** ditambahkan konsep **Kelas** dan **roster** (daftar mahasiswa per kelas, pengganti integrasi SIAKAD). Registrasi wajah kini berbasis verifikasi NIM yang sudah ada di roster.
> **Revisi 3 (Final Selesai):** Implementasi Fase 1 s/d Fase 6 selesai 100%. Ditambahkan panduan manual book resmi (`docs/MANUAL_BOOK_PANDUAN_PENGGUNAAN.md`), kalibrasi ambang batas `reg_min_det_score = 0.4`, verifikasi feedback langsung pada registrasi wajah, skema 3-warna Bounding Box (Hijau: AI Hadir, Merah: Unknown, Biru: Konfirmasi Manual), dan script reset database 1-klik (`backend/reset_db.bat`).

---

## 0. Instruksi untuk Agent (WAJIB DIBACA)

1. Bangun **dua proyek terpisah** dalam satu repo (monorepo): `backend/` (Python FastAPI) dan `mobile/` (Flutter).
2. **Jangan mengubah** kontrak API (bagian 7), skema database (bagian 6), dan aturan bisnis (bagian 4). Jika ada konflik, dokumen ini menang.
3. Semua nilai yang bisa dikalibrasi (ambang kecocokan, ambang blur, dll.) harus berada di **file konfigurasi**, bukan di-hardcode di logika.
4. Kerjakan **per fase** sesuai bagian 12. Setiap fase harus bisa dijalankan dan lulus kriteria penerimaannya sebelum lanjut.
5. Gunakan bahasa Indonesia untuk teks UI dan pesan error ke pengguna. Nama variabel, fungsi, dan file memakai bahasa Inggris.
6. Tulis kode yang sederhana dan mudah dibaca (proyek kuliah, skala kecil). Hindari over-engineering (tanpa microservice, tanpa Docker wajib, tanpa auth).
7. Jangan menambahkan fitur di luar dokumen ini tanpa diminta.

---

## 1. Ringkasan Sistem

Aplikasi Android (Flutter) untuk dosen. Dosen mengelola **kelas** dan **daftar mahasiswa (roster)**, memotret kelas, lalu backend (FastAPI + InsightFace) mendeteksi dan mengenali wajah mahasiswa serta mencatat kehadiran dan poin.

| Item | Nilai |
|---|---|
| Kapasitas | Maks. 15 mahasiswa per kelas, skala 1 sampai 2 kelas |
| Platform | Android (output `.apk`), dipasang di HP dosen |
| Backend | Berjalan di laptop/PC lokal, diakses lewat Wi-Fi yang sama |
| Autentikasi | Tidak ada login/akun. Identitas mahasiswa = NIM |
| Kelas dan roster | Dosen membuat kelas lalu mengisi roster (import CSV atau input manual). Roster berperan sebagai pengganti data SIAKAD |
| Registrasi wajah | Mahasiswa memasukkan NIM yang sudah ada di roster, lalu mengambil 5 foto, bergantian di HP dosen |
| Poin | Hadir +10, Tidak Hadir -10 (dihitung sekali saat finalisasi), total poin per kelas |

### Alur besar

0. **Persiapan dosen (sekali per kelas):** buat kelas, isi roster (nama + NIM) lewat import CSV atau input manual.
1. **Registrasi wajah (sekali per mahasiswa):** mahasiswa memasukkan NIM, sistem memverifikasi ke roster, lalu 5 foto wajah menghasilkan embedding.
2. **Sesi presensi:** dosen membuat sesi untuk sebuah kelas (nama kegiatan, tanggal, waktu, pertemuan ke-). Peserta wajib = roster kelas tersebut.
3. **Pengambilan foto:** dosen memotret kelas (boleh berkali-kali, maks. 5 capture).
4. **Pengenalan:** backend melakukan detection, recognition, matching. Hasil digabung per mahasiswa.
5. **Verifikasi manual:** wajah tidak dikenali diperiksa dosen.
6. **Finalisasi:** status hadir/tidak hadir ditentukan, poin dihitung dan disimpan.

> Integrasi SIAKAD sungguhan (butuh akses resmi kampus) adalah pengembangan lanjutan. Cukup mengganti sumber import roster, desain lainnya tidak berubah.
---

## 2. Tech Stack

| Lapisan | Teknologi | Catatan |
|---|---|---|
| Mobile | Flutter (stable) + Dart 3 | `minSdkVersion` 23 (sesuaikan dengan syarat plugin ML Kit terbaru) |
| State management | `flutter_riverpod` | |
| Navigasi | `go_router` | |
| HTTP | `dio` | Multipart, timeout, interceptor |
| Kamera | `camera` | Registrasi: kamera depan. Presensi: kamera belakang |
| Deteksi wajah (mobile) | `google_mlkit_face_detection` | Hanya panduan registrasi |
| Resize/kompres | `flutter_image_compress` | Native, cepat, koreksi orientasi |
| Analisis gambar | `image` (Dart) dalam `compute()` isolate | Blur & luminansi pada gambar kecil |
| Penyimpanan lokal | `sqflite` (antrean upload), `shared_preferences` (pengaturan) | |
| Lain-lain | `path_provider`, `crypto` (SHA-256), `uuid`, `connectivity_plus`, `file_picker` (pilih file CSV roster) | |
| Backend | Python 3.10 atau 3.11, FastAPI, Uvicorn | |
| ORM | SQLAlchemy 2.0 + Pydantic v2 | |
| Face AI | `insightface` + `onnxruntime` (CPU) | Model `buffalo_l` (alternatif ringan: `buffalo_s`) |
| Gambar | `Pillow`, `numpy`, `scipy` (Hungarian assignment) | |
| Database | SQLite (file `presensi.db`), mode WAL | |
| Upload | `python-multipart` | |

---

## 3. Struktur Repo

```
presensi-wajah/
├── DESIGN_PRESENSI_WAJAH.md        # dokumen ini
├── README.md                        # cara menjalankan (hasil fase 7)
├── backend/
│   ├── requirements.txt
│   ├── .env.example
│   ├── run_backend.bat / run_backend.sh
│   ├── app/
│   │   ├── main.py                  # FastAPI app, router, lifespan (load model sekali)
│   │   ├── config.py                # Settings dari .env (pydantic-settings)
│   │   ├── database.py              # engine, session, PRAGMA, create_all
│   │   ├── models.py                # tabel SQLAlchemy
│   │   ├── schemas.py               # Pydantic request/response
│   │   ├── errors.py                # AppError + handler format error seragam
│   │   ├── routers/
│   │   │   ├── classes.py           # /classes, roster (JSON + CSV import)
│   │   │   ├── students.py          # /students, /students/lookup, /students/{id}/faces
│   │   │   ├── sessions.py          # /sessions, participants, finalize
│   │   │   ├── attendance.py        # /attendance/recognize, confirm, list
│   │   │   └── points.py            # /points
│   │   └── services/
│   │       ├── face_engine.py       # wrapper InsightFace (singleton)
│   │       ├── image_utils.py       # Pillow: exif transpose, resize, ke BGR numpy
│   │       ├── matching.py          # cosine, Hungarian, ambang
│   │       ├── attendance_service.py# merge-max, upsert, progress
│   │       ├── points_service.py    # finalisasi + poin (transaksi)
│   │       └── roster_service.py    # parse CSV, upsert mahasiswa, tautkan ke kelas
│   ├── storage/                     # runtime: captures/ (foto presensi)
│   └── tests/                       # pytest
└── mobile/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── app/ (router.dart, theme.dart)
        ├── core/
        │   ├── api/api_client.dart
        │   ├── config/settings_repository.dart
        │   ├── models/               # student, session, recognition_result, dll
        │   └── utils/                # nim_validator, image_quality, image_prep,
        │                             # bbox_transform, backoff, progress_merge
        ├── services/upload_queue/    # queue_db.dart, queue_worker.dart
        └── features/
            ├── classes/              # daftar kelas, roster, import CSV, tambah manual
            ├── registration/         # lookup NIM + 5 foto berpandu
            ├── session/              # buat sesi, beranda sesi
            ├── attendance/           # kamera, hasil + bbox, verifikasi manual, progres
            ├── points/               # daftar poin
            └── settings/             # URL backend, tes koneksi
```

---

## 4. Aturan Bisnis (Terkunci)

| ID | Aturan |
|---|---|
| BR-01 | Roster: NIM wajib 12 digit angka (`^\d{12}$`), unik secara global. Nama tidak kosong (setelah trim). Maks. `MAX_STUDENTS_PER_CLASS` (awal 15) mahasiswa per kelas. Satu mahasiswa boleh berada di lebih dari satu kelas (data wajah dipakai bersama). |
| BR-02 | Registrasi wajah hanya untuk NIM yang sudah ada di roster minimal satu kelas. Layar registrasi **tidak** membuat mahasiswa baru. Wajah dianggap terdaftar penuh jika 5 foto valid tersimpan (`has_faces = true`). |
| BR-03 | Peserta wajib sesi = seluruh roster kelas pada saat sesi dibuat (snapshot). Peserta yang belum punya wajah tetap menjadi peserta, tetapi hanya bisa hadir lewat konfirmasi manual atau setelah mendaftarkan wajah lalu difoto ulang. |
| BR-04 | Satu capture dapat memuat banyak wajah. Hasil digabung per `student_id`, simpan **skor tertinggi**. Satu mahasiswa hanya dihitung sekali per sesi. |
| BR-05 | Dalam satu foto, satu wajah hanya boleh cocok ke satu mahasiswa dan sebaliknya (Hungarian assignment). |
| BR-06 | Wajah teridentifikasi jika cosine similarity >= `MATCH_THRESHOLD` (awal 0,4). Selain itu status `unknown`. |
| BR-07 | Wajah `unknown` **tidak** otomatis menjadi tidak hadir. Dosen memverifikasi manual: memilih nama peserta, maka status hadir dengan `method = manual`. |
| BR-08 | Penanganan wajah `unknown`: (a) peserta di roster yang belum punya wajah: konfirmasi manual, atau daftar wajah lalu capture ulang; (b) mahasiswa kelas yang belum ada di roster: dosen memakai "Tambah ke Kelas" dari layar hasil (menambah ke roster dan ke sesi berjalan), lalu konfirmasi; (c) orang di luar kelas: diabaikan, tanpa efek pada poin. |
| BR-09 | Maksimal `MAX_CAPTURES_PER_SESSION` (awal 5) capture per sesi. Dosen boleh mengakhiri kapan saja. |
| BR-10 | Finalisasi hanya sekali per sesi. Peserta tanpa catatan hadir menjadi `tidak_hadir`. |
| BR-11 | Poin: hadir `+10`, tidak hadir `-10`, ditulis ke `point_history` dalam **satu transaksi**. Total poin per kelas = jumlah `delta` pada sesi milik kelas tersebut (tidak disimpan sebagai kolom). |
| BR-12 | Poin resmi hanya dihitung di backend. Mobile menampilkan pratinjau berlabel "perkiraan". |
| BR-13 | Foto presensi tidak boleh hilang saat jaringan buruk: mobile memakai antrean upload dengan retry. |
| BR-14 | Mendaftar ulang wajah untuk mahasiswa yang sudah `has_faces` memerlukan `overwrite=true`, dan aplikasi wajib menampilkan dialog konfirmasi (dosen mendampingi), agar data wajah tidak tertimpa tanpa sengaja. |
| BR-15 | Import roster: NIM yang sudah ada di basis data hanya dihubungkan ke kelas (data lama dipertahankan). Perbedaan nama dilaporkan sebagai peringatan, tidak diubah otomatis. |
---

## 5. Konfigurasi (`backend/.env.example`)

```ini
# Database & storage
DB_PATH=./presensi.db
STORAGE_DIR=./storage

# Face engine
MODEL_NAME=buffalo_l
DET_SIZE=1280                 # ukuran deteksi; naikkan jika wajah kecil tidak terdeteksi
MIN_DET_SCORE=0.5             # skor deteksi minimal wajah di foto presensi
MAX_IMAGE_SIDE=1920           # sisi panjang maksimal gambar yang diproses

# Registrasi
REGISTRATION_PHOTOS=5
REG_MIN_DET_SCORE=0.6
REG_MIN_SELF_SIMILARITY=0.30  # rata-rata kemiripan antar 5 foto (pastikan satu orang)

# Matching & aturan
MATCH_THRESHOLD=0.40          # cosine similarity, KALIBRASI dengan data nyata
MAX_CAPTURES_PER_SESSION=5
MAX_STUDENTS_PER_CLASS=15
MAX_IMPORT_ROWS=200          # batas baris CSV/payload roster sekali kirim
POINTS_PRESENT=10
POINTS_ABSENT=-10
MAX_UPLOAD_MB=10
```

Konfigurasi mobile (konstanta di `lib/core/config/app_config.dart`, nilai default dapat diubah):

```dart
const blurThreshold = 100.0;        // variance of Laplacian, KALIBRASI di perangkat
const minLuminance = 60.0, maxLuminance = 200.0;
const maxUploadSide = 1920;         // px sisi panjang
const jpegQuality = 85;
const maxRetryAttempts = 5;         // backoff 1,2,4,8,16 detik
const analysisWidth = 320;          // lebar gambar untuk analisis blur/luminansi
```

---

## 6. Skema Database (SQLite)

Jalankan `PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;` saat koneksi dibuka. Tabel dibuat lewat `Base.metadata.create_all()`. Definisi acuan:

```sql
CREATE TABLE classes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,                       -- mis. "Pemrograman Mobile A"
  code        TEXT,                                -- opsional, mis. "PM-A"
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE students (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  nim         TEXT NOT NULL UNIQUE,
  full_name   TEXT NOT NULL,
  has_faces   INTEGER NOT NULL DEFAULT 0,          -- 0/1
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE class_students (                      -- roster (many-to-many)
  class_id    INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  student_id  INTEGER NOT NULL REFERENCES students(id),
  added_at    TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (class_id, student_id)
);

CREATE TABLE face_embeddings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id  INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  pose_label  TEXT,                                -- depan|kiri|kanan|atas|bawah
  embedding   BLOB NOT NULL,                       -- float32[512] ter-normalisasi (2048 byte)
  det_score   REAL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sessions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  class_id        INTEGER NOT NULL REFERENCES classes(id),
  activity_name   TEXT NOT NULL,
  session_date    TEXT NOT NULL,                   -- YYYY-MM-DD
  session_time    TEXT NOT NULL,                   -- HH:MM
  meeting_number  INTEGER NOT NULL,
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','final')),
  capture_count   INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  finalized_at    TEXT
);

CREATE TABLE session_participants (
  session_id  INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id  INTEGER NOT NULL REFERENCES students(id),
  added_at    TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (session_id, student_id)
);

CREATE TABLE captures (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id         INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  capture_no         INTEGER NOT NULL,
  client_capture_id  TEXT NOT NULL,                -- UUID dari mobile (idempotensi retry)
  image_path         TEXT NOT NULL,
  image_width        INTEGER NOT NULL,             -- dimensi gambar yang DIPROSES backend
  image_height       INTEGER NOT NULL,
  created_at         TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (session_id, client_capture_id)
);

CREATE TABLE capture_faces (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  capture_id            INTEGER NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
  bbox_x REAL NOT NULL, bbox_y REAL NOT NULL, bbox_w REAL NOT NULL, bbox_h REAL NOT NULL,
  det_score             REAL,
  student_id            INTEGER REFERENCES students(id),   -- hasil match (NULL jika unknown)
  match_score           REAL,
  status                TEXT NOT NULL CHECK (status IN ('identified','unknown','confirmed')),
  confirmed_student_id  INTEGER REFERENCES students(id)
);

CREATE TABLE attendance (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id   INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id   INTEGER NOT NULL REFERENCES students(id),
  status       TEXT NOT NULL CHECK (status IN ('hadir','tidak_hadir')),
  match_score  REAL,                                -- NULL untuk konfirmasi manual
  method       TEXT NOT NULL CHECK (method IN ('auto','manual')),
  marked_at    TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (session_id, student_id)
);

CREATE TABLE point_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id  INTEGER NOT NULL REFERENCES students(id),
  session_id  INTEGER NOT NULL REFERENCES sessions(id),
  delta       INTEGER NOT NULL,
  reason      TEXT NOT NULL,                        -- 'hadir' | 'tidak_hadir'
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (student_id, session_id)                   -- cegah poin ganda
);
```

Total poin per kelas (dipakai `GET /points` dan respons finalisasi):

```sql
SELECT s.id, s.full_name, s.nim, COALESCE(SUM(ph.delta), 0) AS total_points
FROM class_students cs
JOIN students s ON s.id = cs.student_id
LEFT JOIN sessions se ON se.class_id = cs.class_id
LEFT JOIN point_history ph ON ph.student_id = s.id AND ph.session_id = se.id
WHERE cs.class_id = :class_id
GROUP BY s.id
ORDER BY total_points DESC;
```

Catatan:
- Selama sesi `active`, baris `attendance` hanya dibuat untuk yang `hadir`. Baris `tidak_hadir` dibuat saat finalisasi.
- `has_faces` bernilai 1 hanya jika 5 embedding tersimpan.
- Waktu disimpan sebagai ISO string dengan zona waktu lokal server secara konsisten.
---

## 7. Kontrak REST API

Base URL: `http://<IP_LAPTOP>:8000`. Semua body JSON kecuali yang ditandai multipart. Tanpa autentikasi (jaringan lokal).

### 7.1 Format error seragam

HTTP status sesuai jenis error, body:

```json
{ "detail": { "code": "class_full", "message": "Kelas sudah mencapai batas 15 mahasiswa." } }
```

| code | HTTP | Arti |
|---|---|---|
| `validation_error` | 422 | Input tidak valid (format NIM, nama kosong, jumlah file salah, kelas tanpa mahasiswa) |
| `invalid_csv` | 422 | File CSV tidak terbaca, header tidak sesuai, atau baris melebihi `MAX_IMPORT_ROWS` |
| `class_not_found` | 404 | |
| `class_full` | 409 | Penambahan melebihi `MAX_STUDENTS_PER_CLASS` (tidak ada yang diterapkan) |
| `student_not_found` | 404 | NIM/ID tidak ada di roster manapun |
| `student_not_in_class` | 409 | Mahasiswa bukan anggota roster kelas sesi |
| `faces_already_registered` | 409 | Wajah sudah terdaftar dan `overwrite` tidak diberikan |
| `session_not_found` | 404 | |
| `session_finalized` | 409 | Aksi ditolak karena sesi sudah final |
| `capture_limit_reached` | 409 | Melebihi `MAX_CAPTURES_PER_SESSION` |
| `no_face_detected` | 422 | Registrasi: tidak ada wajah pada foto tertentu (lihat `details`) |
| `multiple_faces` | 422 | Registrasi: foto memuat lebih dari satu wajah |
| `inconsistent_faces` | 422 | Registrasi: 5 foto tampak bukan satu orang |
| `not_a_participant` | 409 | Mahasiswa bukan peserta sesi |
| `checksum_mismatch` | 422 | SHA-256 tidak cocok |
| `file_too_large` | 413 | |

Untuk error registrasi foto, sertakan `"details": [{"index": 2, "code": "multiple_faces"}]` di dalam `detail`.

### 7.2 Endpoint

#### `GET /health`
Respons: `{ "status": "ok", "model_loaded": true }`

#### `POST /classes`
Body: `{ "name": "Pemrograman Mobile A", "code": "PM-A" }` (`code` opsional, `name` tidak kosong).
Respons 201: `{ "id": 1, "name": "Pemrograman Mobile A", "code": "PM-A", "student_count": 0, "max_students": 15 }`

#### `GET /classes`
Respons: daftar kelas, masing-masing dengan `student_count` dan `faces_registered_count`.

#### `GET /classes/{id}`
Respons: data kelas + `students: [{ "id": 1, "nim": "...", "full_name": "...", "has_faces": false }]`.

#### `POST /classes/{id}/students` (JSON, input manual atau bulk)
Body:
```json
{ "students": [ { "nim": "240535600363", "full_name": "Asyam Sakhi Maulana" } ] }
```
Aturan per baris (indeks mulai 1):
- NIM tidak sesuai `^\d{12}$` atau nama kosong: baris ditolak dengan error `validation_error`, baris lain tetap diproses.
- NIM belum ada di basis data: buat mahasiswa baru (`has_faces=false`) lalu tautkan ke kelas (`added`).
- NIM sudah ada di basis data: hanya ditautkan ke kelas (`linked_existing`). Jika nama berbeda, tambahkan warning `name_mismatch` (nama lama tidak diubah, BR-15).
- NIM sudah ada di kelas ini: dilewati (`skipped`).
- Jika jumlah mahasiswa baru di kelas setelah penambahan akan melebihi batas: tolak seluruh request dengan `class_full`.

Respons 200:
```json
{ "added": 2, "linked_existing": 1, "skipped": 0,
  "errors":   [ { "row": 4, "nim": "1234", "code": "validation_error" } ],
  "warnings": [ { "row": 2, "nim": "240535612453", "code": "name_mismatch", "existing_name": "Daffa Aleia A. W." } ] }
```

#### `POST /classes/{id}/students/import` (multipart, impor CSV)
Field: `file` (CSV). Aturan CSV:
- Wajib ada baris header. Kolom NIM bernama `nim`. Kolom nama bernama `nama`, `full_name`, atau `nama_lengkap` (tidak peka huruf besar/kecil).
- Pemisah koma atau titik koma. Encoding UTF-8 (BOM diterima).
- Maks. `MAX_IMPORT_ROWS` baris data, jika lebih maka `invalid_csv`.
- Setelah parsing, diproses dengan logika yang sama seperti endpoint JSON di atas dan respons berbentuk sama.

Contoh isi file:
```csv
nim,nama
240535600363,Asyam Sakhi Maulana
240535612453,Daffa Aleia Amrita Waskitha
```

#### `GET /students`
Query opsional `class_id`. Respons: `[ { "id": 1, "nim": "...", "full_name": "...", "has_faces": true } ]`.

#### `GET /students/lookup?nim=240535600363`
Dipakai layar registrasi wajah. Respons 200:
```json
{ "id": 1, "nim": "240535600363", "full_name": "Asyam Sakhi Maulana", "has_faces": false,
  "classes": [ { "id": 1, "name": "Pemrograman Mobile A" } ] }
```
Jika format NIM salah: 422 `validation_error`. Jika NIM tidak ada di roster manapun: 404 `student_not_found` (pesan: "NIM belum terdaftar di kelas manapun. Hubungi dosen.").

#### `POST /students/{id}/faces` (multipart)
Field: `files` (tepat 5 file JPEG), `pose_labels` (string dipisah koma, urutan sama dengan file, mis. `depan,kiri,kanan,atas,bawah`). Query: `overwrite` (bool, default `false`).
Aturan:
- Jika mahasiswa sudah `has_faces` dan `overwrite` bukan `true`: 409 `faces_already_registered` (BR-14).
Proses (atomik, jika satu gagal maka tidak ada yang disimpan/diubah):
1. Tiap foto: `exif_transpose`, resize jika perlu, deteksi wajah. Harus **tepat 1 wajah** dengan `det_score >= REG_MIN_DET_SCORE`.
2. Ambil `normed_embedding` tiap foto. Hitung rata-rata kemiripan antar 5 embedding. Jika `< REG_MIN_SELF_SIMILARITY` maka `inconsistent_faces`.
3. Hapus embedding lama (jika `overwrite`), simpan 5 baru, set `has_faces = true`, invalidasi cache embedding.
Respons 200: `{ "student_id": 1, "embeddings_saved": 5, "has_faces": true }`

#### `POST /sessions`
Body:
```json
{ "class_id": 1, "activity_name": "Pemrograman Mobile", "session_date": "2026-10-17",
  "session_time": "08:00", "meeting_number": 5 }
```
Proses: buat sesi `active` untuk kelas tersebut, isi `session_participants` dari seluruh roster kelas (BR-03). Jika roster kosong maka `validation_error` ("Kelas belum memiliki mahasiswa.").
Respons 201: objek sesi + `participants: [{student_id, full_name, nim, has_faces}]` + `without_faces_count` (jumlah peserta tanpa wajah, untuk peringatan di UI).

#### `GET /sessions` dan `GET /sessions/{id}`
`GET /sessions` menerima query opsional `class_id`. Detail sesi berisi `class_id`, `status`, `capture_count`, `max_captures`, `participants`, dan `progress` (bentuk sama dengan respons recognize).

#### `POST /sessions/{id}/participants`
Body: `{ "student_id": 7 }`. Syarat: sesi `active`, mahasiswa sudah ada di roster kelas sesi (jika belum: 409 `student_not_in_class`, dosen harus menambahkannya ke roster dulu lewat `POST /classes/{id}/students`). Idempoten (jika sudah peserta, kembalikan 200).
Respons: sesi terbaru dengan daftar peserta.

#### `POST /attendance/recognize` (multipart)
Field: `session_id` (int), `client_capture_id` (UUID string), `image` (JPEG).
Header opsional: `X-Content-SHA256` (hex). Jika ada dan tidak cocok maka `checksum_mismatch`.
Perilaku:
- Jika `(session_id, client_capture_id)` sudah ada, **kembalikan hasil yang sudah tersimpan** tanpa memproses ulang dan tanpa menambah `capture_count` (aman untuk retry).
- Tolak jika sesi `final` atau `capture_count >= MAX_CAPTURES_PER_SESSION`.
- Jalankan pipeline di bagian 8.3, simpan `captures`, `capture_faces`, upsert `attendance` (merge-max).
Respons 200:
```json
{
  "capture_id": 12,
  "capture_no": 2,
  "max_captures": 5,
  "image_width": 1440,
  "image_height": 1920,
  "faces": [
    { "face_id": 55, "bbox": {"x": 120.0, "y": 340.0, "w": 180.0, "h": 220.0},
      "status": "identified", "student_id": 3, "full_name": "Budi", "nim": "240535600001", "score": 0.62 },
    { "face_id": 56, "bbox": {"x": 700.0, "y": 410.0, "w": 150.0, "h": 190.0},
      "status": "unknown", "student_id": null, "full_name": null, "nim": null, "score": null }
  ],
  "progress": {
    "total_participants": 15,
    "identified": [ {"student_id": 3, "full_name": "Budi", "nim": "...", "score": 0.62, "method": "auto"} ],
    "unidentified": [ {"student_id": 4, "full_name": "Sari", "nim": "...", "has_faces": true} ]
  }
}
```
`bbox` memakai piksel pada gambar berdimensi `image_width x image_height` (gambar yang diproses backend, setelah koreksi orientasi dan resize).

#### `POST /attendance/confirm`
Body: `{ "session_id": 1, "student_id": 4, "face_id": 56 }` (`face_id` opsional).
Syarat: sesi `active`, mahasiswa peserta. Efek: upsert `attendance` = `hadir`, `method='manual'` (jika sudah `hadir` otomatis, tidak diubah). Jika `face_id` ada, set `capture_faces.status='confirmed'`, `confirmed_student_id`.
Respons: objek `progress` terbaru.

#### `POST /sessions/{id}/finalize`
Syarat: sesi `active` (jika sudah final maka `session_finalized` 409).
Transaksi tunggal:
1. Untuk tiap peserta tanpa baris `attendance`: buat `tidak_hadir` (`method='auto'`).
2. Untuk tiap peserta: `delta = +POINTS_PRESENT` jika `hadir`, selain itu `POINTS_ABSENT`. Insert `point_history`.
3. Set sesi `final`, isi `finalized_at`.
Respons:
```json
{ "session_id": 1, "class_id": 1, "status": "final",
  "results": [ {"student_id": 3, "full_name": "Budi", "status": "hadir", "method": "auto", "delta": 10, "class_total_points": 30} ] }
```
`class_total_points` dihitung dengan query total poin per kelas (bagian 6).

#### `GET /attendance?session_id=1`
Respons: daftar baris kehadiran sesi (jika `session_id` kosong, semua sesi, terbaru dulu).

#### `GET /points?class_id=1`
`class_id` wajib. Respons: `[ {"student_id": 3, "full_name": "Budi", "nim": "...", "total_points": 30} ]` urut poin menurun.
Opsional `&student_id=3` menyertakan `history` (daftar `point_history` untuk kelas tersebut).

### 7.3 Checksum (opsional tapi diimplementasikan)

Mobile mengirim header `X-Content-SHA256: <hex>` dari byte file JPEG final. Backend menghitung ulang SHA-256 atas byte yang diterima. Jika berbeda maka 422 `checksum_mismatch`, mobile menganggap gagal sementara dan retry.
---

## 8. Desain Backend

### 8.1 Face engine (`services/face_engine.py`)

```python
from insightface.app import FaceAnalysis

class FaceEngine:
    def __init__(self, model_name: str, det_size: int):
        self.app = FaceAnalysis(name=model_name, providers=["CPUExecutionProvider"])
        self.app.prepare(ctx_id=-1, det_size=(det_size, det_size))

    def analyze(self, bgr_image):          # numpy HxWx3 uint8 (BGR)
        return self.app.get(bgr_image)     # list Face: .bbox, .det_score, .normed_embedding (512,)
```

- Muat model **sekali** di `lifespan` FastAPI (singleton). Request pertama tidak boleh memuat ulang model.
- Pemanggilan `analyze` bersifat CPU-bound: jalankan dengan `run_in_threadpool` agar event loop tidak terblokir.
- Model diunduh otomatis saat pertama dijalankan (butuh internet, ~300 MB untuk `buffalo_l`), disimpan di `~/.insightface/models`.

### 8.2 Pengolahan gambar (`services/image_utils.py`)

```python
from PIL import Image, ImageOps
import numpy as np, io

def load_for_recognition(data: bytes, max_side: int):
    img = Image.open(io.BytesIO(data))
    img = ImageOps.exif_transpose(img).convert("RGB")
    w, h = img.size
    if max(w, h) > max_side:
        s = max_side / max(w, h)
        img = img.resize((round(w * s), round(h * s)), Image.LANCZOS)
    rgb = np.asarray(img)
    return rgb[:, :, ::-1].copy(), img.size   # BGR untuk InsightFace, (width, height)
```

Dimensi yang dikembalikan menjadi `image_width/image_height` pada respons dan tabel `captures`. Koordinat bbox dari InsightFace sudah dalam ruang gambar ini.

### 8.3 Pipeline recognize (`services/matching.py` + `attendance_service.py`)

1. Validasi sesi (ada, `active`, kuota capture), cek idempotensi `client_capture_id`.
2. Verifikasi checksum jika header ada.
3. `load_for_recognition` lalu `faces = engine.analyze(bgr)`; buang wajah dengan `det_score < MIN_DET_SCORE`.
4. Muat embedding peserta sesi yang `has_faces`: `E[student_id] = array (k, 512)` (cache di memori, invalidasi saat `/faces` berubah). Peserta tanpa wajah tidak ikut matriks kemiripan. Jika tidak ada satu pun peserta yang punya wajah, semua wajah pada foto berstatus `unknown`.
5. Hitung matriks kemiripan `S[f][s] = max_k dot(face.normed_embedding, E[s][k])` (kedua vektor sudah ternormalisasi, sehingga dot = cosine).
6. `scipy.optimize.linear_sum_assignment(-S)` (Hungarian). Pasangan dengan `S >= MATCH_THRESHOLD` menjadi `identified`; sisanya `unknown`. (Tangani kasus jumlah wajah tidak sama dengan jumlah peserta: matriks persegi panjang didukung.)
7. Simpan foto ke `STORAGE_DIR/captures/session_<id>/capture_<no>.jpg` (gambar yang sudah diproses), simpan `captures` dan `capture_faces`.
8. Upsert `attendance` untuk tiap `identified`: jika belum ada, insert `hadir/auto/score`; jika ada dengan skor lebih rendah, perbarui ke skor tertinggi (merge-max).
9. Naikkan `sessions.capture_count`. Bangun `progress` dari data tersimpan (peserta dengan `attendance.hadir` = identified, sisanya = unidentified). Semua langkah 7 sampai 9 dalam satu transaksi.

### 8.4 Hal teknis penting

- CORS tidak diperlukan (klien native). Aktifkan hanya bila nanti ada klien web.
- Batas ukuran upload: tolak jika `> MAX_UPLOAD_MB` dengan 413.
- Logging: catat tiap recognize (session, capture_no, jumlah wajah, jumlah identified, durasi ms).
- Endpoint berat (recognize, faces) hanya berjalan satu per satu bila perlu (gunakan `asyncio.Lock` di sekitar inferensi untuk menghindari lonjakan CPU).
- Semua operasi poin dalam transaksi. Jangan pernah menaikkan poin di luar `finalize`.

---

## 9. Desain Mobile (Flutter)

### 9.1 Layar dan navigasi

| Rute | Layar | Fungsi |
|---|---|---|
| `/` | Beranda | Menu: Kelas, Registrasi Wajah, Pengaturan. Banner status koneksi backend |
| `/settings` | Pengaturan | Input URL backend (mis. `http://192.168.1.10:8000`), tombol "Tes Koneksi" (`GET /health`) |
| `/classes` | Daftar kelas | Kartu kelas (nama, jumlah mahasiswa, jumlah yang sudah daftar wajah), tombol "Buat Kelas" |
| `/classes/:id` | Roster kelas | Daftar mahasiswa dengan lencana "wajah terdaftar / belum". Tombol: Import CSV, Tambah Manual, Sesi Baru, Riwayat Sesi, Poin Kelas |
| `/register` | Registrasi wajah | Input NIM (regex) lalu `GET /students/lookup`, tampilkan nama dan kelas, tombol "Ya, ini saya" |
| `/register/capture` | Ambil 5 foto | Kamera depan, panduan real-time (bagian 9.3) |
| `/classes/:id/sessions/new` | Buat sesi | Form kegiatan, tanggal, waktu, pertemuan ke-. Peringatan jika ada peserta belum daftar wajah |
| `/session/:id` | Beranda sesi | Daftar peserta + status hadir, tombol "Ambil Foto", "Selesaikan Presensi" |
| `/session/:id/capture` | Kamera presensi | Kamera belakang, tombol shutter |
| `/session/:id/result` | Hasil capture | Foto + kotak wajah, daftar belum teridentifikasi, verifikasi manual |
| `/classes/:id/points` | Poin kelas | Daftar poin mahasiswa kelas tersebut |

### 9.2 Alur UI

**Persiapan kelas (dosen):**
1. Buat kelas (nama, kode opsional).
2. Isi roster: **Import CSV** (pilih file dengan `file_picker`, unggah ke `/classes/{id}/students/import`) atau **Tambah Manual** (form NIM + nama, kirim ke `/classes/{id}/students`). Setelah itu tampilkan ringkasan hasil: jumlah ditambahkan, dilewati, error per baris, dan peringatan `name_mismatch`. Jika `class_full`, tampilkan pesan batas kelas.
3. Minta tiap mahasiswa mendaftarkan wajah lewat menu Registrasi Wajah (bagian 9.3). Lencana di roster berubah menjadi "wajah terdaftar".

**Presensi:**
1. `session/:id` menampilkan checklist peserta (hadir/belum) dan jumlah capture (mis. 2/5).
2. Tombol "Ambil Foto" membuka kamera. Setelah jepret: siapkan gambar (bagian 9.4), masukkan ke antrean upload, tampilkan "Memproses...".
3. Saat respons diterima: tampilkan hasil dengan bbox (bagian 9.6), perbarui progres lokal (bagian 9.7).
4. Jika masih ada `unidentified`: tampilkan opsi "Foto dari sudut lain" (jika kuota ada), "Verifikasi manual", atau "Selesaikan".
5. Verifikasi manual (BR-07, BR-08): ketuk kotak wajah `unknown`, muncul bottom sheet daftar peserta `unidentified` untuk dipilih, panggil `/attendance/confirm`. Peserta bertanda "belum daftar wajah" dapat dikonfirmasi manual atau didaftarkan wajahnya lalu difoto ulang. Opsi **"Tambah ke Kelas"** (untuk mahasiswa kelas yang belum ada di roster) membuka form NIM + nama, memanggil `/classes/{id}/students` lalu `/sessions/{id}/participants`, kemudian peserta baru muncul di daftar untuk dikonfirmasi. Wajah orang di luar kelas cukup diabaikan.
6. "Selesaikan Presensi": dialog konfirmasi menampilkan pratinjau poin berlabel "perkiraan" (+10 / -10), lalu `POST /sessions/{id}/finalize`. Setelah sukses, tampilkan hasil resmi dari backend.

### 9.3 Registrasi wajah berpandu (5 foto)

**Langkah 0 (verifikasi NIM):** mahasiswa mengetik NIM, divalidasi regex `^\d{12}$` di mobile, lalu aplikasi memanggil `GET /students/lookup`. Tampilkan nama dan kelas, lalu tombol "Ya, ini saya". Jika `404 student_not_found`, tampilkan pesan agar menghubungi dosen. Jika `has_faces = true`, tampilkan dialog "Wajah sudah terdaftar. Daftar ulang? (minta dosen mengonfirmasi)". Jika disetujui, lanjutkan dengan `overwrite=true` (BR-14).

**Langkah 1 sampai 5 (pengambilan foto):** kamera depan, `ImageFormatGroup.nv21`, `startImageStream` untuk ML Kit.

- ML Kit `FaceDetector` opsi: `performanceMode: fast`, `enableClassification: false`, `enableLandmarks: false`, `enableTracking: false`. Proses frame secara throttle (mis. satu frame per ~150 ms) dan lewati frame bila deteksi sebelumnya belum selesai.
- Tombol ambil foto aktif **hanya jika**: tepat 1 wajah, wajah cukup besar (lebar bbox >= 25% lebar frame), dan sudut kepala masuk rentang target foto aktif.
- Sudut dari `face.headEulerAngleY` (yaw) dan `face.headEulerAngleX` (pitch).

Rentang pose awal (konfigurasi, tanda yaw/pitch **harus diverifikasi di perangkat nyata** karena bergantung kamera depan/mirror):

| # | Label | Syarat |
|---|---|---|
| 1 | depan | \|yaw\| <= 10 dan \|pitch\| <= 10 |
| 2 | kiri | yaw dalam [-35, -12] |
| 3 | kanan | yaw dalam [12, 35] |
| 4 | atas | pitch dalam [10, 25] dan \|yaw\| <= 15 |
| 5 | bawah | pitch dalam [-25, -10] dan \|yaw\| <= 15 |

Setelah jepret tiap foto, jalankan cek kualitas (bagian 9.5). Jika gagal, tampilkan pesan ("Foto buram", "Terlalu gelap", "Terlalu terang") dan ulangi foto yang sama. Setelah 5 foto lolos: tampilkan pratinjau, lalu kirim `POST /students/{id}/faces` (dengan `overwrite=true` bila daftar ulang). Jika backend mengembalikan error per foto (`details[].index`), tandai foto itu untuk diulang.

### 9.4 Persiapan gambar sebelum upload (`image_prep.dart`)

```dart
final bytes = await FlutterImageCompress.compressWithFile(
  path,
  minWidth: maxUploadSide, minHeight: maxUploadSide, // sisi panjang <= 1920
  quality: jpegQuality,
  autoCorrectionAngle: true, // putar piksel sesuai EXIF
  keepExif: false,           // EXIF dibuang agar tidak terjadi rotasi ganda di backend
  format: CompressFormat.jpeg,
);
final sha256Hex = sha256.convert(bytes!).toString();
```

Hasil (bytes, sha256, nama file) disimpan ke direktori aplikasi lalu didaftarkan sebagai job antrean.

### 9.5 Pemeriksaan kualitas (`image_quality.dart`)

Jalankan di isolate (`compute`) pada gambar yang diperkecil ke lebar `analysisWidth` (320 px) dan diubah ke grayscale.

- **Blur:** variance of Laplacian dengan kernel `[[0,1,0],[1,-4,1],[0,1,0]]`. Jika variance `< blurThreshold` maka buram.
- **Pencahayaan:** rata-rata luminansi `Y = 0.299R + 0.587G + 0.114B`. Di luar `[minLuminance, maxLuminance]` maka terlalu gelap/terang.

```dart
double laplacianVariance(Uint8List gray, int w, int h) {
  final vals = <double>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      vals.add((gray[i - w] + gray[i + w] + gray[i - 1] + gray[i + 1] - 4 * gray[i]).toDouble());
    }
  }
  final mean = vals.reduce((a, b) => a + b) / vals.length;
  return vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
}
```

Ambang `blurThreshold` adalah titik awal, wajib dikalibrasi dengan foto nyata di HP target.

### 9.6 Validasi NIM dan transformasi bounding box

```dart
final nimRegex = RegExp(r'^\d{12}$');
bool isValidNim(String s) => nimRegex.hasMatch(s.trim());
```

Bbox dari backend (piksel pada `image_width x image_height`) digambar di atas gambar yang ditampilkan dengan `BoxFit.contain`:

```dart
Rect toScreen(Rect b, Size img, Size view) {
  final scale = min(view.width / img.width, view.height / img.height);
  final dx = (view.width  - img.width  * scale) / 2;   // offset letterbox
  final dy = (view.height - img.height * scale) / 2;
  return Rect.fromLTWH(b.left * scale + dx, b.top * scale + dy, b.width * scale, b.height * scale);
}
```

Gambar dengan `CustomPainter`:
- 🟩 **Hijau (`identified`)**: Wajah dikenali otomatis oleh AI InsightFace. Menampilkan label nama mahasiswa dan persentase skor kecocokan di atas kotak.
- 🟥 **Merah (`unknown`)**: Wajah terdeteksi kamera tetapi belum cocok dengan database (misal belum setor wajah atau pose tertutup). Kotak ini interaktif: dapat **diketuk langsung oleh dosen** via `GestureDetector` untuk memicu bottom sheet konfirmasi manual (BR-07, BR-08).
- 🟦 **Biru (`confirmed`)**: Wajah yang awalnya merah/unknown, lalu dikonfirmasi manual oleh dosen dengan memilih nama mahasiswa dari daftar yang belum hadir. Status kehadiran otomatis diperbarui menjadi hadir.

### 9.7 Penggabungan hasil dan progres (`progress_merge.dart`)

```dart
// key = studentId, value = skor tertinggi
void mergeMax(Map<int, double> acc, Iterable<FaceResult> faces) {
  for (final f in faces.where((f) => f.status == 'identified')) {
    final cur = acc[f.studentId!];
    if (cur == null || f.score! > cur) acc[f.studentId!] = f.score!;
  }
}
Set<int> unidentified(Set<int> required, Set<int> identified) => required.difference(identified);
```

UI memakai hasil lokal agar instan, lalu menyelaraskan dengan `progress` dari respons backend (backend yang resmi). Pratinjau poin: `+10` untuk identified, `-10` untuk unidentified, diberi label "perkiraan".

### 9.8 Antrean upload dan retry (`services/upload_queue`)

Tabel `sqflite`:

```sql
CREATE TABLE upload_queue (
  id TEXT PRIMARY KEY,          -- UUID (= client_capture_id untuk recognize)
  type TEXT NOT NULL,           -- 'recognize' | 'faces'
  payload TEXT NOT NULL,        -- JSON: path file, session_id / student_id, overwrite, sha256, dll
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL,   -- epoch ms
  status TEXT NOT NULL,         -- 'pending' | 'done' | 'failed'
  created_at INTEGER NOT NULL
);
```

Aturan worker (FIFO berdasarkan `created_at`):
- Kirim job `pending` yang `next_attempt_at <= now`. Berhasil maka `done` (simpan hasil agar UI dapat menampilkan).
- Gagal karena jaringan/timeout/5xx/`checksum_mismatch`: `attempts++`, `next_attempt_at = now + 1s * 2^(attempts-1)` (1, 2, 4, 8, 16 detik). Jika `attempts >= maxRetryAttempts` maka `failed` dan tampilkan notifikasi dengan tombol "Coba lagi" (reset `attempts`).
- Error 4xx (kecuali `checksum_mismatch`) **tidak** di-retry: tampilkan pesan ke pengguna.
- Job tetap tersimpan saat aplikasi ditutup dan dilanjutkan saat dibuka atau saat konektivitas kembali (`connectivity_plus`).
- Idempotensi `recognize` dijamin oleh `client_capture_id` (UUID per jepretan).

### 9.9 Konfigurasi Android

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<application android:usesCleartextTraffic="true" ...>
```

`usesCleartextTraffic="true"` diperlukan karena backend lokal memakai HTTP (bukan HTTPS). Timeout Dio: connect 10 detik, receive 60 detik (inferensi CPU bisa lambat).

---

## 10. Deployment dan Menjalankan

### 10.1 Backend (laptop/PC dosen)

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate    Linux/Mac: source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

`requirements.txt` (versi disematkan saat implementasi):

```
fastapi
uvicorn[standard]
python-multipart
sqlalchemy>=2.0
pydantic>=2
pydantic-settings
pillow
numpy
scipy
insightface
onnxruntime
pytest
httpx
```

Catatan penting:
- Jalankan pertama kali **dengan internet** agar model InsightFace terunduh.
- Di Windows, `insightface` kadang butuh *Microsoft C++ Build Tools*. Gunakan Python 3.10/3.11.
- Jika CPU lemah/lambat, ganti `MODEL_NAME=buffalo_s` dan/atau turunkan `DET_SIZE`.
- Buka port 8000 di firewall (Windows: izinkan Python/uvicorn pada jaringan Private).
- Cari IP laptop (`ipconfig` / `ip a`), HP dan laptop harus satu Wi-Fi. Pastikan "AP/client isolation" pada router mati.
- Uji dari browser HP: `http://<IP>:8000/health` harus menampilkan `{"status":"ok",...}`. Dokumentasi interaktif di `http://<IP>:8000/docs`.
- Lisensi: model pretrained InsightFace umumnya hanya untuk penggunaan riset/non-komersial. Cukup untuk tugas kuliah, jangan untuk produk komersial tanpa memeriksa lisensi.

Skrip `run_backend.bat` / `run_backend.sh`: aktifkan venv lalu jalankan perintah uvicorn di atas.

### 10.2 Mobile

```bash
cd mobile
flutter pub get
flutter run                      # uji di HP via USB (USB debugging aktif)
flutter build apk --release      # hasil: build/app/outputs/flutter-apk/app-release.apk
```

Install: salin `.apk` ke HP lalu buka (izinkan sumber tidak dikenal), atau `adb install -r app-release.apk`. Untuk tugas kuliah, penandatanganan debug bawaan sudah cukup.

Setelah terpasang: buka **Pengaturan**, isi URL backend, tekan **Tes Koneksi**. Lalu buat kelas dan isi roster (import CSV atau manual) sebelum mahasiswa mendaftarkan wajah.

---

## 11. Pengujian dan Kalibrasi

### 11.1 Backend (`pytest`, `TestClient`)

- Kelas dan roster: buat kelas, tambah mahasiswa manual (NIM tidak valid dilaporkan per baris), import CSV (header `nim,nama`, pemisah `;`, BOM, baris salah), NIM yang sudah ada hanya ditautkan dengan warning `name_mismatch`, kelas ke-16 ditolak (409 `class_full`), CSV tanpa header (422 `invalid_csv`).
- Lookup NIM: ada (200), tidak ada di roster manapun (404), format salah (422).
- Registrasi wajah: 5 foto valid (200), foto 2 berisi dua wajah (422 `multiple_faces` dengan index), 5 foto orang berbeda (422 `inconsistent_faces`), mahasiswa yang sudah punya wajah tanpa `overwrite` (409 `faces_already_registered`) dan dengan `overwrite=true` (200, embedding lama diganti).
- Sesi: peserta = seluruh roster kelas (termasuk yang belum punya wajah). Roster kosong ditolak. Menambah peserta idempoten, mahasiswa di luar roster kelas ditolak (409 `student_not_in_class`).
- Recognize: wajah dikenal teridentifikasi, wajah asing `unknown`, capture ke-6 ditolak (409), `client_capture_id` yang sama dikirim ulang tidak menambah `capture_count`, merge-max (skor lebih tinggi menggantikan), sesi final menolak recognize.
- Confirm: peserta valid menjadi `hadir/manual`, bukan peserta ditolak (409).
- Poin per kelas: mahasiswa di dua kelas memiliki total poin terpisah per kelas.
- Finalize: poin +10/-10 benar, panggilan kedua ditolak (409), `UNIQUE(student_id, session_id)` mencegah poin ganda.
- Gunakan 3 sampai 4 foto uji sintetis atau foto sukarelawan. Mock `FaceEngine` untuk unit test logika matching.

### 11.2 Mobile

- Unit test: `isValidNim`, `laplacianVariance` (gambar tajam vs blur), `toScreen` (rasio berbeda), `mergeMax`, perhitungan backoff, logika worker antrean (gagal lalu sukses, gagal sampai maksimum).
- Uji manual di HP nyata: matikan Wi-Fi saat upload lalu nyalakan lagi (retry berjalan, tidak ada duplikasi capture), putar HP (orientasi), foto di ruangan gelap/terang.

### 11.3 Kalibrasi ambang (wajib sebelum dipakai nyata)

1. Daftarkan 5 sampai 10 sukarelawan.
2. Ambil beberapa foto kelas simulasi dari berbagai sudut.
3. Catat skor cosine untuk pasangan benar (orang sama) dan pasangan salah (orang berbeda).
4. Pilih `MATCH_THRESHOLD` yang memisahkan keduanya dengan baik (prioritaskan menghindari salah-kenal daripada gagal-kenal, karena gagal-kenal bisa diperbaiki lewat verifikasi manual).
5. Kalibrasi `blurThreshold` dan rentang luminansi di HP target dengan foto yang jelas baik dan buruk.

---

## 12. Rencana Implementasi untuk Agent (Per Fase)

Setiap fase: kerjakan, jalankan, verifikasi kriteria, baru lanjut.

### Fase 1: Backend dasar, kelas, dan roster
Buat struktur `backend/`, `config.py`, `database.py`, `models.py` (skema bagian 6), `errors.py`, `GET /health`, `/classes`, roster (`POST /classes/{id}/students` dan `/students/import` dengan `roster_service.py`), `GET /students`, `GET /students/lookup`.
**Kriteria:** `uvicorn` berjalan, `/docs` terbuka. Kelas dapat dibuat, roster terisi lewat JSON dan CSV contoh (baris salah dilaporkan per baris, `name_mismatch` muncul), kelas ke-16 ditolak (`class_full`), lookup NIM bekerja. Test pytest lulus.

### Fase 2: Face engine dan pendaftaran wajah
Implementasi `face_engine.py` (load sekali di lifespan), `image_utils.py`, `POST /students/{id}/faces` sesuai aturan atomik dan `overwrite` (bagian 7.2).
**Kriteria:** 5 foto valid tersimpan dan `has_faces=true`; foto dengan 0 atau 2 wajah ditolak dengan `details.index`; tanpa `overwrite` mahasiswa yang sudah terdaftar ditolak (409), dengan `overwrite=true` embedding lama diganti.

### Fase 3: Sesi, recognize, confirm, finalize
Implementasi router sessions/attendance/points (sesi terikat `class_id`, peserta = snapshot roster), `matching.py` (Hungarian + ambang), `attendance_service.py` (merge-max, idempotensi `client_capture_id`, kuota capture), `points_service.py` (transaksi, total poin per kelas).
**Kriteria:** semua kasus uji bagian 11.1 lulus; `/docs` dapat dipakai menguji end-to-end dengan foto contoh.

### Fase 4: Mobile fondasi, kelas, dan roster
Buat proyek Flutter, routing, tema, `settings_repository` + layar Pengaturan + Tes Koneksi, `api_client` (Dio) beserta model, Beranda, daftar kelas, roster kelas (lencana wajah), buat kelas, Import CSV (`file_picker`), Tambah Manual beserta tampilan ringkasan hasil.
**Kriteria:** aplikasi terhubung ke backend lewat URL yang diatur; dosen dapat membuat kelas dan mengisi roster dari HP; error jaringan dan `class_full` ditampilkan ramah.

### Fase 5: Registrasi wajah di mobile
Layar NIM (regex + lookup + konfirmasi nama), dialog daftar ulang (`overwrite`), kamera depan, ML Kit panduan, cek pose, cek kualitas, pratinjau 5 foto, kompresi, upload (lewat antrean).
**Kriteria:** registrasi berhasil untuk NIM yang ada di roster; NIM di luar roster ditolak dengan pesan jelas; foto buram/gelap/terang ditolak di tempat; tombol foto nonaktif bila wajah != 1.

### Fase 6: Sesi dan presensi di mobile
Buat sesi per kelas, beranda sesi, kamera belakang, `image_prep`, antrean upload + retry + idempotensi, hasil dengan bbox (`toScreen`), progres `mergeMax`, verifikasi manual, "Tambah ke Kelas", finalisasi, layar Poin kelas.
**Kriteria:** alur lengkap dari buat sesi sampai finalisasi berjalan; saat Wi-Fi diputus lalu dinyalakan, foto terkirim tanpa duplikasi; bbox tepat pada berbagai ukuran layar; peserta tanpa wajah dapat dikonfirmasi manual.

### Fase 7: Pengemasan
`README.md` (langkah bagian 10, termasuk format CSV roster), skrip `run_backend`, build `.apk` release, uji end-to-end di HP nyata, kalibrasi (bagian 11.3).
**Kriteria:** orang lain dapat menjalankan backend dan memasang `.apk` hanya dengan mengikuti README.
---

## 13. Definition of Done

- [ ] Semua endpoint bagian 7 berfungsi sesuai kontrak (diuji di `/docs` dan pytest).
- [ ] Aturan BR-01 sampai BR-15 terpenuhi.
- [ ] Dosen dapat membuat kelas dan mengisi roster lewat import CSV maupun input manual dari aplikasi.
- [ ] Mahasiswa hanya dapat mendaftarkan wajah dengan NIM yang ada di roster, dan daftar ulang meminta konfirmasi.
- [ ] Kesepuluh proses komputasi mobile (bagian 9.3 sampai 9.8) terimplementasi: validasi regex, koreksi orientasi, ML Kit panduan, cek blur/cahaya, cek pose, resize+kompres, payload JSON/multipart (+SHA-256), antrean+backoff, merge-max+set difference, transformasi bbox.
- [ ] Poin tidak pernah terhitung ganda (dibuktikan test finalisasi dua kali) dan dihitung terpisah per kelas.
- [ ] `.apk` release terpasang dan berjalan dengan backend lokal.
- [ ] Ambang kecocokan telah dikalibrasi dengan data kelas nyata dan dicatat di README.
---

## 14. Asumsi dan Keterbatasan Versi 1

| Hal | Keputusan v1 |
|---|---|
| Sumber data mahasiswa | Roster diisi dosen (CSV atau manual) sebagai pengganti SIAKAD. Integrasi SIAKAD sungguhan ditunda, cukup mengganti sumber import. |
| Banyak kelas | Ditangani lewat tabel `classes` dan roster many-to-many. Sesi, peserta, dan poin terikat pada kelas. Satu data wajah dipakai di semua kelas yang diikuti mahasiswa. |
| Mengubah roster | v1 hanya menambah mahasiswa ke kelas. Menghapus atau memindahkan mahasiswa dari kelas belum didukung (ditunda ke versi berikutnya). Nama mahasiswa tidak diubah otomatis saat import (BR-15). |
| Keamanan | Tanpa autentikasi, hanya untuk jaringan lokal tepercaya. Siapa pun yang tahu NIM dapat mendaftarkan wajah untuk NIM itu, dengan mitigasi: pendaftaran berlangsung di HP dosen dan daftar ulang memerlukan konfirmasi (BR-14). Data wajah (embedding dan foto) bersifat sensitif: jangan dipublikasikan, beri tahu mahasiswa tujuan penggunaannya. |
| Anti-spoofing | Tidak ada deteksi foto/layar palsu (liveness). Di luar cakupan. |
| Konfirmasi manual | Dihitung sama seperti hadir otomatis (+10). Dapat diubah di `points_service.py` bila aturan berubah. |
| Kinerja | Inferensi CPU: capture dapat memakan beberapa detik. UI menampilkan indikator proses. |