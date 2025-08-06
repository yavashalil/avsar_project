from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from message_models import Message
from message_schemas import MessageCreate, MessageResponse
from typing import List
import bleach
from auth import get_current_user

router = APIRouter(prefix="/messages", tags=["Messages"])

ALLOWED_TAGS = []  
MAX_CONTENT_LENGTH = 5000
MAX_FILE_PATH_LENGTH = 255

@router.post("/send", response_model=MessageResponse)
def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    if current_user != message.sender_username:
        raise HTTPException(status_code=403, detail="Başkasının adına mesaj gönderemezsiniz")

    if not message.content and not message.file_path:
        raise HTTPException(status_code=400, detail="Mesaj içeriği veya dosya yolu zorunlu")

    if message.content and len(message.content) > MAX_CONTENT_LENGTH:
        raise HTTPException(status_code=400, detail="Mesaj çok uzun")

    if message.file_path and len(message.file_path) > MAX_FILE_PATH_LENGTH:
        raise HTTPException(status_code=400, detail="Dosya yolu çok uzun")

    clean_content = bleach.clean(message.content, tags=ALLOWED_TAGS) if message.content else None

    new_msg = Message(
        sender_username=current_user,
        receiver_username=message.receiver_username,
        subject=message.subject,
        content=clean_content,
        file_path=message.file_path,
        reply_to=message.reply_to
    )
    db.add(new_msg)
    db.commit()
    db.refresh(new_msg)
    return new_msg

@router.get("/inbox", response_model=List[MessageResponse])
def get_inbox(
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    return db.query(Message).filter(Message.receiver_username == current_user).order_by(Message.timestamp.desc()).all()

@router.get("/sent", response_model=List[MessageResponse])
def get_sent(
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    return db.query(Message).filter(Message.sender_username == current_user).order_by(Message.timestamp.desc()).all()
