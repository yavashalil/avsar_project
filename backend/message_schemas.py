from pydantic import BaseModel, constr
from typing import Optional
from datetime import datetime

class MessageCreate(BaseModel):
    sender_username: constr(min_length=3, max_length=50)
    receiver_username: constr(min_length=3, max_length=50)
    subject: Optional[constr(max_length=255)] = None
    content: Optional[constr(max_length=5000)] = None
    file_path: Optional[constr(max_length=255)] = None
    reply_to: Optional[int] = None

class MessageResponse(BaseModel):
    id: int
    sender_username: str
    receiver_username: str
    subject: Optional[str]
    content: Optional[str]
    file_path: Optional[str]
    timestamp: datetime
    is_read: bool
    reply_to: Optional[int]

    class Config:
        from_attributes = True
