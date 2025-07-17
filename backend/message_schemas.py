from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class MessageCreate(BaseModel):
    sender_username: str
    receiver_username: str
    subject: Optional[str] = None
    content: Optional[str] = None
    file_path: Optional[str] = None
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
