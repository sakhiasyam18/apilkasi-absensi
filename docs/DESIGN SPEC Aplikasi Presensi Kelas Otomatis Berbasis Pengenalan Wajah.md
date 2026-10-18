# DESIGN SPEC: Aplikasi Presensi Kelas Otomatis Berbasis Pengenalan Wajah

> Dokumen ini adalah **sumber kebenaran tunggal** (single source of truth) untuk membangun proyek.
> Ditujukan untuk dibaca oleh AI coding agent (Antigravity) dan developer.
> Gabungan dari Tugas 1, Tugas 2, dan Diagram Spesifikasi Sistem, sudah diselaraskan.
> Penulis: Asyam Sakhi Maulana (240535600363), Daffa Aleia Amrita Waskitha (240535612453).

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

Aplikasi Android (Flutter) untuk dosen. Dosen memotret kelas, backend (FastAPI + InsightFace) mendeteksi dan mengenali wajah mahasiswa, lalu mencatat kehadiran dan poin.

| Item | Nilai |
|---|---|
| Kapasitas | Maks. 15 mahasiswa per kelas, skala 1 sampai 2 kelas |
| Platform | Android (output `.apk`), dipasang di HP dosen |
| Backend | Berjalan di laptop/PC lokal, diakses lewat Wi-Fi yang sama |
| Autentikasi | Tidak ada login/akun. Identitas = Nama Lengkap + NIM |
| Poin | Hadir +10, Tidak Hadir -10 (dihitung sekali saat finalisasi) |
| Registrasi | Mahasiswa mendaftar sendiri di aplikasi pada HP dosen (bergantian) |

### Alur besar

1. Registrasi mahasiswa (sekali): nama, NIM, 5 foto wajah, backend membuat embedding.
2. Dosen membuat sesi presensi (nama kegiatan, tanggal, waktu, pertemuan ke-).
3. Dosen memotret kelas (boleh berkali-kali, maks. 5 capture).
4. Backend: detection, recognition, matching. Hasil digabung per mahasiswa.
5. Wajah tidak dikenali: verifikasi manual oleh dosen.
6. Dosen finalisasi: status hadir/tidak hadir ditentukan, poin dihitung, disimpan.

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
| Lain-lain | `path_provider`, `crypto` (SHA-256), `uuid`, `connectivity_plus` | |
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
│   │   │   ├── students.py          # /register, /students, /students/{id}/faces
│   │   │   ├── sessions.py          # /sessions, participants, finalize
│   │   │   ├── attendance.py        # /attendance/recognize, confirm, list
│   │   │   └── points.py            # /points
│   │   └── services/
│   │       ├── face_engine.py       # wrapper InsightFace (singleton)
│   │       ├── image_utils.py       # Pillow: exif transpose, resize, ke BGR numpy
│   │       ├── matching.py          # cosine, Hungarian, ambang
│   │       ├── attendance_service.py# merge-max, upsert, progress
│   │       └── points_service.py    # finalisasi + poin (transaksi)
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
            ├── registration/         # form + 5 foto berpandu
            ├── session/              # buat sesi, beranda sesi
            ├── attendance/           # kamera, hasil + bbox, verifikasi manual, progres
            ├── points/               # daftar poin
            └── settings/             # URL backend, tes koneksi
```

---

## 4. Aturan Bisnis (Terkunci)

| ID | Aturan |
|---|---|
| BR-01 | Registrasi: NIM wajib 12 digit angka (`^\d{12}$`), nama tidak kosong, NIM unik (dicek di backend). |
| BR-02 | Mahasiswa dianggap terdaftar penuh hanya jika 5 foto wajah valid tersimpan (`has_faces = true`). |
| BR-03 | Sesi baru: daftar peserta wajib = semua mahasiswa dengan `has_faces = true`. |
| BR-04 | Satu capture dapat memuat banyak wajah. Hasil digabung per `student_id`, simpan **skor tertinggi**. Satu mahasiswa hanya dihitung sekali per sesi. |
| BR-05 | Dalam satu foto, satu wajah hanya boleh cocok ke satu mahasiswa dan sebaliknya (Hungarian assignment). |
| BR-06 | Wajah teridentifikasi jika cosine similarity >= `MATCH_THRESHOLD` (awal 0,4). Selain itu status `unknown`. |
| BR-07 | Wajah `unknown` **tidak** otomatis menjadi tidak hadir. Dosen memverifikasi manual: memilih nama peserta, maka status hadir dengan `method = manual`. |
| BR-08 | Jika wajah unknown adalah mahasiswa belum terdaftar: ia registrasi dulu, otomatis ditambahkan ke sesi berjalan, lalu presensi ulang (capture baru). |
| BR-09 | Maksimal `MAX_CAPTURES_PER_SESSION` (awal 5) capture per sesi. Dosen boleh mengakhiri kapan saja. |
| BR-10 | Finalisasi hanya sekali per sesi. Peserta tanpa catatan hadir menjadi `tidak_hadir`. |
| BR-11 | Poin: hadir `+10`, tidak hadir `-10`, ditulis ke `point_history` dan `students.total_points` dalam **satu transaksi**. |
| BR-12 | Poin resmi hanya dihitung di backend. Mobile menampilkan pratinjau berlabel "perkiraan". |
| BR-13 | Foto presensi tidak boleh hilang saat jaringan buruk: mobile memakai antrean upload dengan retry. |

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
CREATE TABLE students (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nim           TEXT NOT NULL UNIQUE,
  full_name     TEXT NOT NULL,
  has_faces     INTEGER NOT NULL DEFAULT 0,        -- 0/1
  total_points  INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
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

Catatan:
- Selama sesi `active`, baris `attendance` hanya dibuat untuk yang `hadir`. Baris `tidak_hadir` dibuat saat finalisasi.
- Waktu disimpan sebagai ISO string. Gunakan zona waktu lokal server secara konsisten.

---

## 7. Kontrak REST API

Base URL: `http://<IP_LAPTOP>:8000`. Semua body JSON kecuali yang ditandai multipart. Semua endpoint tanpa autentikasi (jaringan lokal).

### 7.1 Format error seragam

HTTP status sesuai jenis error, body:

```json
{ "detail": { "code": "nim_duplicate", "message": "NIM sudah terdaftar." } }
```

| code | HTTP | Arti |
|---|---|---|
| `validation_error` | 422 | Input tidak valid (format NIM, nama kosong, jumlah file salah) |
| `nim_duplicate` | 409 | NIM sudah ada |
| `student_not_found` | 404 | |
| `session_not_found` | 404 | |
| `session_finalized` | 409 | Aksi ditolak karena sesi sudah final |
| `capture_limit_reached` | 409 | Melebihi `MAX_CAPTURES_PER_SESSION` |
| `no_face_detected` | 422 | Tidak ada wajah (registrasi: foto tertentu, lihat `details`) |
| `multiple_faces` | 422 | Registrasi: foto memuat lebih dari satu wajah |
| `inconsistent_faces` | 422 | Registrasi: 5 foto tampak bukan satu orang |
| `not_a_participant` | 409 | Mahasiswa bukan peserta sesi |
| `student_not_ready` | 409 | Mahasiswa belum punya wajah terdaftar |
| `checksum_mismatch` | 422 | SHA-256 tidak cocok |
| `file_too_large` | 413 | |

Untuk error registrasi foto, sertakan `"details": [{"index": 2, "code": "multiple_faces"}]` di dalam `detail`.

### 7.2 Endpoint

#### `GET /health`
Respons: `{ "status": "ok", "model_loaded": true }`

#### `POST /register`
Body: `{ "full_name": "Asyam Sakhi Maulana", "nim": "240535600363" }`
Validasi: nama tidak kosong (trim), NIM `^\d{12}$`, unik.
Respons 201:
```json
{ "id": 1, "full_name": "Asyam Sakhi Maulana", "nim": "240535600363", "has_faces": false }
```

#### `POST /students/{id}/faces` (multipart)
Field: `files` (tepat 5 file JPEG), `pose_labels` (string dipisah koma, urutan sama dengan file, mis. `depan,kiri,kanan,atas,bawah`).
Header opsional: `X-Content-SHA256` tidak dipakai di sini (lihat 7.3).
Proses (atomik, jika satu gagal maka tidak ada yang disimpan):
1. Tiap foto: `exif_transpose`, resize jika perlu, deteksi wajah. Harus **tepat 1 wajah** dengan `det_score >= REG_MIN_DET_SCORE`.
2. Ambil `normed_embedding` tiap foto. Hitung rata-rata kemiripan antar 5 embedding. Jika `< REG_MIN_SELF_SIMILARITY` maka `inconsistent_faces`.
3. Hapus embedding lama mahasiswa (registrasi ulang aman), simpan 5 baru, set `has_faces = true`.
Respons 200: `{ "student_id": 1, "embeddings_saved": 5, "has_faces": true }`

#### `GET /students`
Respons: `[ { "id": 1, "full_name": "...", "nim": "...", "has_faces": true, "total_points": 20 } ]`

#### `POST /sessions`
Body:
```json
{ "activity_name": "Pemrograman Mobile", "session_date": "2026-10-17", "session_time": "08:00", "meeting_number": 5 }
```
Proses: buat sesi `active`, isi `session_participants` dari semua `students.has_faces = true`. Jika peserta 0, kembalikan `validation_error` ("Belum ada mahasiswa terdaftar").
Respons 201: objek sesi + `participants: [{student_id, full_name, nim}]`.

#### `GET /sessions` dan `GET /sessions/{id}`
Detail sesi berisi `status`, `capture_count`, `max_captures`, `participants`, dan `progress` (bentuk sama dengan 7.3).

#### `POST /sessions/{id}/participants`
Body: `{ "student_id": 7 }`. Syarat: sesi `active`, mahasiswa `has_faces`. Idempoten (jika sudah peserta, kembalikan 200).
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
    "unidentified": [ {"student_id": 4, "full_name": "Sari", "nim": "..."} ]
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
2. Untuk tiap peserta: `delta = +POINTS_PRESENT` jika `hadir`, selain itu `POINTS_ABSENT`. Insert `point_history`, update `students.total_points`.
3. Set sesi `final`, isi `finalized_at`.
Respons:
```json
{ "session_id": 1, "status": "final",
  "results": [ {"student_id": 3, "full_name": "Budi", "status": "hadir", "method": "auto", "delta": 10, "total_points": 30} ] }
```

#### `GET /attendance?session_id=1`
Respons: daftar baris kehadiran sesi (jika `session_id` kosong, semua sesi terbaru dulu).

#### `GET /points`
Respons: `[ {"student_id": 3, "full_name": "Budi", "nim": "...", "total_points": 30} ]` urut poin menurun.
Opsional `?student_id=3` menyertakan `history`.

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
4. Muat embedding semua peserta sesi: `E[student_id] = array (k, 512)` (cache di memori, invalidasi saat `/faces` berubah).
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
| `/` | Beranda | Menu: Registrasi, Sesi Baru, Sesi Berjalan/Riwayat, Poin, Pengaturan. Banner status koneksi backend |
| `/settings` | Pengaturan | Input URL backend (mis. `http://192.168.1.10:8000`), tombol "Tes Koneksi" (`GET /health`) |
| `/register` | Form registrasi | Nama + NIM (validasi regex), lanjut ke kamera |
| `/register/capture` | Ambil 5 foto | Kamera depan, panduan real-time (bagian 9.3) |
| `/session/new` | Buat sesi | Form kegiatan, tanggal, waktu, pertemuan ke- |
| `/session/:id` | Beranda sesi | Daftar peserta + status hadir, tombol "Ambil Foto", "Selesaikan Presensi" |
| `/session/:id/capture` | Kamera presensi | Kamera belakang, tombol shutter |
| `/session/:id/result` | Hasil capture | Foto + kotak wajah, daftar belum teridentifikasi, verifikasi manual |
| `/points` | Poin | Daftar poin mahasiswa |

### 9.2 Alur UI presensi

1. `session/:id` menampilkan checklist peserta (hadir/belum) dan jumlah capture (mis. 2/5).
2. Tombol "Ambil Foto" membuka kamera. Setelah jepret: siapkan gambar (bagian 9.4), masukkan ke antrean upload, tampilkan "Memproses...".
3. Saat respons diterima: tampilkan hasil dengan bbox (bagian 9.6), perbarui progres lokal (bagian 9.7).
4. Jika masih ada `unidentified`: tampilkan opsi "Foto dari sudut lain" (jika kuota ada), "Verifikasi manual", atau "Selesaikan".
5. Verifikasi manual: ketuk kotak wajah `unknown`, muncul bottom sheet daftar peserta `unidentified` untuk dipilih, panggil `/attendance/confirm`. Opsi "Belum terdaftar" menampilkan petunjuk: registrasi dulu lalu ambil foto ulang (peserta ditambah lewat `/sessions/{id}/participants` otomatis setelah registrasi selesai bila ada sesi aktif).
6. "Selesaikan Presensi": dialog konfirmasi menampilkan pratinjau poin berlabel "perkiraan" (+10 / -10), lalu `POST /sessions/{id}/finalize`. Setelah sukses, tampilkan hasil resmi dari backend.

### 9.3 Registrasi berpandu (5 foto)

Kamera depan, `ImageFormatGroup.nv21`, `startImageStream` untuk ML Kit.

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

Setelah jepret tiap foto, jalankan cek kualitas (bagian 9.5). Jika gagal, tampilkan pesan ("Foto buram", "Terlalu gelap", "Terlalu terang") dan ulangi foto yang sama. Setelah 5 foto lolos: tampilkan pratinjau, lalu kirim `POST /register` (jika belum) dan `POST /students/{id}/faces`. Jika backend mengembalikan error per foto (`details[].index`), tandai foto itu untuk diulang.

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

Gambar dengan `CustomPainter`: hijau untuk `identified` (label nama + skor), merah untuk `unknown` (dapat diketuk untuk verifikasi manual), biru untuk `confirmed`.

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
  payload TEXT NOT NULL,        -- JSON: path file, session_id / student_id, sha256, dll
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

Setelah terpasang: buka **Pengaturan**, isi URL backend, tekan **Tes Koneksi**.

---

## 11. Pengujian dan Kalibrasi

### 11.1 Backend (`pytest`, `TestClient`)

- Registrasi: NIM tidak valid (422), NIM duplikat (409), 5 foto valid (200), foto 2 berisi dua wajah (422 `multiple_faces` dengan index), 5 foto orang berbeda (422 `inconsistent_faces`).
- Sesi: peserta = semua `has_faces`. Menambah peserta idempoten.
- Recognize: wajah dikenal teridentifikasi, wajah asing `unknown`, capture ke-6 ditolak (409), `client_capture_id` yang sama dikirim ulang tidak menambah `capture_count`, merge-max (skor lebih tinggi menggantikan), sesi final menolak recognize.
- Confirm: peserta valid menjadi `hadir/manual`, bukan peserta ditolak (409).
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

### Fase 1: Backend dasar
Buat struktur `backend/`, `config.py`, `database.py`, `models.py` (skema bagian 6), `errors.py`, `GET /health`, `/register`, `/students`.
**Kriteria:** `uvicorn` berjalan, `/docs` terbuka, registrasi nama+NIM berfungsi, NIM duplikat 409, format NIM salah 422, test pytest lulus.

### Fase 2: Face engine dan pendaftaran wajah
Implementasi `face_engine.py` (load sekali di lifespan), `image_utils.py`, `POST /students/{id}/faces` sesuai aturan atomik bagian 7.2.
**Kriteria:** 5 foto valid tersimpan dan `has_faces=true`; foto dengan 0 atau 2 wajah ditolak dengan `details.index`; registrasi ulang mengganti embedding lama.

### Fase 3: Sesi, recognize, confirm, finalize
Implementasi router sessions/attendance/points, `matching.py` (Hungarian + ambang), `attendance_service.py` (merge-max, idempotensi `client_capture_id`, kuota capture), `points_service.py` (transaksi).
**Kriteria:** semua kasus uji bagian 11.1 lulus; `/docs` dapat dipakai menguji end-to-end dengan foto contoh.

### Fase 4: Mobile fondasi
Buat proyek Flutter, routing, tema, `settings_repository` + layar Pengaturan + Tes Koneksi, `api_client` (Dio) beserta model, layar Beranda.
**Kriteria:** aplikasi terhubung ke backend lewat URL yang diatur; error jaringan ditampilkan ramah.

### Fase 5: Registrasi di mobile
Form + validasi regex, kamera depan, ML Kit panduan, cek pose, cek kualitas, pratinjau 5 foto, kompresi, upload (lewat antrean).
**Kriteria:** registrasi lengkap berhasil dari HP; foto buram/gelap/terang ditolak di tempat; tombol foto nonaktif bila wajah != 1.

### Fase 6: Sesi dan presensi di mobile
Buat sesi, beranda sesi, kamera belakang, `image_prep`, antrean upload + retry + idempotensi, hasil dengan bbox (`toScreen`), progres `mergeMax`, verifikasi manual, finalisasi, layar Poin.
**Kriteria:** alur lengkap dari buat sesi sampai finalisasi berjalan; saat Wi-Fi diputus lalu dinyalakan, foto terkirim tanpa duplikasi; bbox tepat pada berbagai ukuran layar.

### Fase 7: Pengemasan
`README.md` (langkah bagian 10), skrip `run_backend`, build `.apk` release, uji end-to-end di HP nyata, kalibrasi (bagian 11.3).
**Kriteria:** orang lain dapat menjalankan backend dan memasang `.apk` hanya dengan mengikuti README.

---

## 13. Definition of Done

- [ ] Semua endpoint bagian 7 berfungsi sesuai kontrak (diuji di `/docs` dan pytest).
- [ ] Aturan BR-01 sampai BR-13 terpenuhi.
- [ ] Kesepuluh proses komputasi mobile (bagian 9.3 sampai 9.8) terimplementasi: validasi regex, koreksi orientasi, ML Kit panduan, cek blur/cahaya, cek pose, resize+kompres, payload JSON/multipart (+SHA-256), antrean+backoff, merge-max+set difference, transformasi bbox.
- [ ] Poin tidak pernah terhitung ganda (dibuktikan test finalisasi dua kali).
- [ ] `.apk` release terpasang dan berjalan dengan backend lokal.
- [ ] Ambang kecocokan telah dikalibrasi dengan data kelas nyata dan dicatat di README.

---

## 14. Asumsi dan Keterbatasan Versi 1

| Hal | Keputusan v1 |
|---|---|
| Dua kelas | Daftar peserta sesi = semua mahasiswa terdaftar. Jika dipakai untuk 2 kelas berbeda, gunakan satu instance backend/database per kelas, atau tambahkan atribut kelas pada versi berikutnya. |
| Keamanan | Tanpa autentikasi, hanya untuk jaringan lokal tepercaya. Data wajah (embedding dan foto) bersifat sensitif: jangan dipublikasikan, beri tahu mahasiswa tujuan penggunaannya. |
| Anti-spoofing | Tidak ada deteksi foto/layar palsu (liveness). Di luar cakupan. |
| Konfirmasi manual | Dihitung sama seperti hadir otomatis (+10). Dapat diubah di `points_service.py` bila aturan berubah. |
| Registrasi di HP dosen | Asumsi. Jika kelak ada aplikasi terpisah untuk mahasiswa, kontrak API tidak perlu diubah. |
| Kinerja | Inferensi CPU: capture dapat memakan beberapa detik. UI menampilkan indikator proses. |