from PIL import Image, ImageOps
import numpy as np
import io

def load_for_recognition(data: bytes, max_side: int):
    # Buka gambar dari memori (bytes)
    img = Image.open(io.BytesIO(data))
    
    # Koreksi rotasi foto bawaan HP (EXIF)
    img = ImageOps.exif_transpose(img).convert("RGB")
    w, h = img.size
    
    # Perkecil gambar jika terlalu besar agar proses AI tidak lemot
    if max(w, h) > max_side:
        s = max_side / max(w, h)
        img = img.resize((round(w * s), round(h * s)), Image.LANCZOS)
        
    # Ubah format ke RGB Numpy Array, lalu ke BGR (format yang dibaca InsightFace)
    rgb = np.asarray(img)
    return rgb[:, :, ::-1].copy(), img.size