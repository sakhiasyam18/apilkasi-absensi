from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.database import get_db

router = APIRouter(tags=["points"])

@router.get("/points")
def get_class_points(class_id: int, db: Session = Depends(get_db)):
    """Mengambil total poin semua mahasiswa di kelas tertentu (BR-11)."""
    query = text("""
        SELECT s.id, s.full_name, s.nim, COALESCE(SUM(ph.delta), 0) AS total_points
        FROM class_students cs
        JOIN students s ON s.id = cs.student_id
        LEFT JOIN sessions se ON se.class_id = cs.class_id
        LEFT JOIN point_history ph ON ph.student_id = s.id AND ph.session_id = se.id
        WHERE cs.class_id = :class_id
        GROUP BY s.id
        ORDER BY total_points DESC;
    """)
    result = db.execute(query, {"class_id": class_id}).fetchall()
    return [{"student_id": r[0], "full_name": r[1], "nim": r[2], "total_points": r[3]} for r in result]