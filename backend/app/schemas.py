from pydantic import BaseModel, Field
from typing import List, Optional

class ClassInfo(BaseModel):
    id: int
    name: str
    code: Optional[str] = None
    room: Optional[str] = None
    schedule_day: Optional[str] = None
    schedule_time: Optional[str] = None
    class Config:
        from_attributes = True

class StudentResponse(BaseModel):
    id: int
    nim: str
    full_name: str
    has_faces: bool
    class Config:
        from_attributes = True

class StudentLookupResponse(StudentResponse):
    classes: List[ClassInfo]

class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    identifier: Optional[str] = None
    role: str
    program_study: Optional[str] = None
    class Config:
        from_attributes = True

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    identifier: Optional[str] = None
    role: str = "dosen"
    program_study: Optional[str] = None