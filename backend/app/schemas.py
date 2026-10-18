from pydantic import BaseModel, Field
from typing import List, Optional

class ClassInfo(BaseModel):
    id: int
    name: str
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