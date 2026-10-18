from sqlalchemy import Column, Integer, String, Float, ForeignKey, LargeBinary
from sqlalchemy.sql import func
from app.database import Base

class Class(Base):
    __tablename__ = "classes"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    code = Column(String, nullable=True)
    created_at = Column(String, default=func.datetime('now'), nullable=False)

class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True, autoincrement=True)
    nim = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    has_faces = Column(Integer, default=0, nullable=False)
    created_at = Column(String, default=func.datetime('now'), nullable=False)

class ClassStudent(Base):
    __tablename__ = "class_students"
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), primary_key=True)
    added_at = Column(String, default=func.datetime('now'), nullable=False)

class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"
    id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    pose_label = Column(String)
    embedding = Column(LargeBinary, nullable=False)
    det_score = Column(Float)
    created_at = Column(String, default=func.datetime('now'), nullable=False)

class Session(Base):
    __tablename__ = "sessions"
    id = Column(Integer, primary_key=True, autoincrement=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    activity_name = Column(String, nullable=False)
    session_date = Column(String, nullable=False)
    session_time = Column(String, nullable=False)
    meeting_number = Column(Integer, nullable=False)
    status = Column(String, default='active', nullable=False)
    capture_count = Column(Integer, default=0, nullable=False)
    created_at = Column(String, default=func.datetime('now'), nullable=False)
    finalized_at = Column(String, nullable=True)

class SessionParticipant(Base):
    __tablename__ = "session_participants"
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), primary_key=True)
    added_at = Column(String, default=func.datetime('now'), nullable=False)

class Capture(Base):
    __tablename__ = "captures"
    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    capture_no = Column(Integer, nullable=False)
    client_capture_id = Column(String, nullable=False, unique=True)
    image_path = Column(String, nullable=False)
    image_width = Column(Integer, nullable=False)
    image_height = Column(Integer, nullable=False)
    created_at = Column(String, default=func.datetime('now'), nullable=False)

class CaptureFace(Base):
    __tablename__ = "capture_faces"
    id = Column(Integer, primary_key=True, autoincrement=True)
    capture_id = Column(Integer, ForeignKey("captures.id", ondelete="CASCADE"), nullable=False)
    bbox_x = Column(Float, nullable=False)
    bbox_y = Column(Float, nullable=False)
    bbox_w = Column(Float, nullable=False)
    bbox_h = Column(Float, nullable=False)
    det_score = Column(Float)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    match_score = Column(Float)
    status = Column(String, nullable=False)
    confirmed_student_id = Column(Integer, ForeignKey("students.id"), nullable=True)

class Attendance(Base):
    __tablename__ = "attendance"
    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    status = Column(String, nullable=False)
    match_score = Column(Float)
    method = Column(String, nullable=False)
    marked_at = Column(String, default=func.datetime('now'), nullable=False)

class PointHistory(Base):
    __tablename__ = "point_history"
    id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    delta = Column(Integer, nullable=False)
    reason = Column(String, nullable=False)
    created_at = Column(String, default=func.datetime('now'), nullable=False)