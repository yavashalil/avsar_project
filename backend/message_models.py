from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_username = Column(String, nullable=False)
    receiver_username = Column(String, nullable=False)
    subject = Column(String, nullable=True)
    content = Column(Text, nullable=True)
    file_path = Column(String, nullable=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    is_read = Column(Boolean, default=False)
    reply_to = Column(Integer, ForeignKey("messages.id"), nullable=True)
