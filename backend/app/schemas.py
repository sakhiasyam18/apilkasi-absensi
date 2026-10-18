from pydantic import BaseModel, Field

class StudentCreate(BaseModel):
    full_name: str = Field(..., min_length=1)
    nim: str = Field(..., pattern=r'^\d{12}$')

class StudentResponse(BaseModel):
    id: int
    nim: str
    full_name: str
    has_faces: bool
    total_points: int

    class Config:
        from_attributes = True