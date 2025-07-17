from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from message_models import Message
from message_schemas import MessageCreate, MessageResponse
from typing import List

router = APIRouter(prefix="/messages", tags=["Messages"])

@router.post("/send", response_model=MessageResponse)
def send_message(message: MessageCreate, db: Session = Depends(get_db)):
    if not message.content and not message.file_path:
        raise HTTPException(status_code=400, detail="Mesaj içeriği veya dosya yolu zorunlu")

    new_msg = Message(
        sender_username=message.sender_username,
        receiver_username=message.receiver_username,
        subject=message.subject,
        content=message.content,
        file_path=message.file_path,
        reply_to=message.reply_to
    )
    db.add(new_msg)
    db.commit()
    db.refresh(new_msg)
    return new_msg

@router.get("/inbox/{username}", response_model=List[MessageResponse])
def get_inbox(username: str, db: Session = Depends(get_db)):
    return db.query(Message).filter(Message.receiver_username == username).order_by(Message.timestamp.desc()).all()

@router.get("/sent/{username}", response_model=List[MessageResponse])
def get_sent(username: str, db: Session = Depends(get_db)):
    return db.query(Message).filter(Message.sender_username == username).order_by(Message.timestamp.desc()).all()
