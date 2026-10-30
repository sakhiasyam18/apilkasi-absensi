import os
import glob
from app.database import engine, Base
from app.models import *

def reset_database():
    print("=== PROSES RESET DATABASE PRESENSI ===")
    
    # 1. Hapus file-file database lama jika ada
    db_files = [
        "presensi.db",
        "presensi.db-wal",
        "presensi.db-shm",
        "app/presensi.db",
    ]
    for f in db_files:
        if os.path.exists(f):
            try:
                os.remove(f)
                print(f"[OK] Dihapus: {f}")
            except Exception as e:
                print(f"[WARN] Gagal menghapus {f}: {e}")

    # 2. Hapus file gambar di storage
    storage_imgs = glob.glob("storage/*.jpg") + glob.glob("storage/*.png")
    for img in storage_imgs:
        try:
            os.remove(img)
            print(f"[OK] Dihapus: {img}")
        except Exception as e:
            print(f"[WARN] Gagal menghapus {img}: {e}")

    # 3. Buat ulang database & seluruh tabel kosong
    print("\nMembuat ulang seluruh skema tabel dari nol...")
    Base.metadata.create_all(bind=engine)
    print("[BERHASIL] Database presensi.db baru telah dibuat dari nol (100% Bersih)!\n")

if __name__ == "__main__":
    reset_database()
