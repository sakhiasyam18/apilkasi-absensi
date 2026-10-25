import numpy as np
from scipy.optimize import linear_sum_assignment

def match_faces_hungarian(detected_embeddings, registered_data, threshold):
    """
    Algoritma Hungarian untuk mencocokkan wajah (BR-05 & BR-06).
    detected_embeddings: list of numpy array (wajah dari foto kelas)
    registered_data: list of dict {'student_id': int, 'embeddings': list of numpy array}
    threshold: float (batas minimal kemiripan, misal 0.40)
    """
    if not detected_embeddings or not registered_data:
        return [], list(range(len(detected_embeddings))) # Tidak ada match, semua unknown

    # 1. Siapkan matriks skor (Baris = Wajah Terdeteksi, Kolom = Mahasiswa)
    num_detected = len(detected_embeddings)
    num_students = len(registered_data)
    score_matrix = np.zeros((num_detected, num_students))

    # 2. Hitung kemiripan tertinggi (Cosine Similarity) tiap wajah ke tiap mahasiswa
    for i, det_emb in enumerate(detected_embeddings):
        for j, student in enumerate(registered_data):
            # Cari skor kemiripan paling tinggi dari 5 foto referensi milik mahasiswa
            max_score = -1.0
            for reg_emb in student['embeddings']:
                score = np.dot(det_emb, np.frombuffer(reg_emb, dtype=np.float32))
                if score > max_score:
                    max_score = score
            score_matrix[i, j] = max_score

    # 3. Gunakan algoritma Hungarian untuk mencari pasangan paling optimal (1 wajah = 1 mahasiswa)
    row_ind, col_ind = linear_sum_assignment(-score_matrix)

    matches = []
    unmatched_detected = list(range(num_detected))

    # 4. Saring hasil berdasarkan batas kemiripan (threshold)
    for r, c in zip(row_ind, col_ind):
        match_score = float(score_matrix[r, c])
        if match_score >= threshold:
            student_id = registered_data[c]['student_id']
            matches.append({
                "detected_index": r,
                "student_id": student_id,
                "score": match_score
            })
            unmatched_detected.remove(r)

    # Mengembalikan: list pasangan yang cocok, dan list indeks wajah yang 'unknown'
    return matches, unmatched_detected