from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List

from app.database import get_db
from app.models import Session as DbSession, Class, ClassStudent, SessionParticipant, Student
from app.errors import AppError

router = APIRouter(tags=["sessions"])

class SessionCreate(BaseModel):
    class_id: int
    activity_name: str
    session_date: str
    session_time: str
    meeting_number: int

@router.post("/sessions", status_code=201)
def create_session(sess_input: SessionCreate, db: Session = Depends(get_db)):
    cls = db.query(Class).filter(Class.id == sess_input.class_id).first()
    if not cls:
        raise AppError("class_not_found", "Kelas tidak ditemukan", 404)
        
    roster_links = db.query(ClassStudent).filter(ClassStudent.class_id == sess_input.class_id).all()
    if not roster_links:
        raise AppError("validation_error", "Kelas belum memiliki mahasiswa.", 422)
        
    new_sess = DbSession(
        class_id=sess_input.class_id,
        activity_name=sess_input.activity_name,
        session_date=sess_input.session_date,
        session_time=sess_input.session_time,
        meeting_number=sess_input.meeting_number
    )
    db.add(new_sess)
    db.commit()
    db.refresh(new_sess)
    
    participants_info = []
    without_faces_count = 0
    
    # Masukkan semua mahasiswa dari roster ke dalam sesi ini
    for link in roster_links:
        db.add(SessionParticipant(session_id=new_sess.id, student_id=link.student_id))
        
        st = db.query(Student).filter(Student.id == link.student_id).first()
        if st:
            participants_info.append({
                "student_id": st.id, 
                "full_name": st.full_name, 
                "nim": st.nim, 
                "has_faces": bool(st.has_faces)
            })
            if not st.has_faces:
                without_faces_count += 1
                
    db.commit()
    
    return {
        "id": new_sess.id,
        "class_id": new_sess.class_id,
        "activity_name": new_sess.activity_name,
        "without_faces_count": without_faces_count,
        "participants": participants_info
    }

from app.models import Attendance, PointHistory
from app.config import settings

@router.post("/sessions/{id}/finalize")
def finalize_session(id: int, db: Session = Depends(get_db)):
    """Menyelesaikan sesi, menandai tidak hadir, dan menghitung poin (BR-10 & BR-11)"""
    sess = db.query(DbSession).filter(DbSession.id == id).first()
    if not sess or sess.status == 'final':
        raise AppError("session_finalized", "Sesi sudah final atau tidak ditemukan", 409)
        
    participants = db.query(SessionParticipant).filter(SessionParticipant.session_id == id).all()
    
    for p in participants:
        # Cek apakah mahasiswa ini ada di tabel attendance (Hadir)
        att = db.query(Attendance).filter(Attendance.session_id == id, Attendance.student_id == p.student_id).first()
        
        # 1. Jika tidak ada, tandai sebagai tidak hadir
        if not att:
            att = Attendance(session_id=id, student_id=p.student_id, status='tidak_hadir', method='auto')
            db.add(att)
            
        # 2. Hitung Poin (Hadir +10, Tidak Hadir -10)
        delta_points = settings.points_present if att.status == 'hadir' else settings.points_absent
        db.add(PointHistory(student_id=p.student_id, session_id=id, delta=delta_points, reason=att.status))

    # 3. Kunci Sesi
    sess.status = 'final'
    from datetime import datetime
    sess.finalized_at = datetime.now().isoformat()
    
    db.commit()
    return {"message": "Sesi berhasil difinalisasi", "class_id": sess.class_id, "status": "final"}