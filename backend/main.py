import os
import json
import bcrypt
import mimetypes
import unicodedata
import urllib
from datetime import datetime
from urllib.parse import unquote
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, EmailStr
from sqlalchemy import text
from database import get_db, Base, engine
from message_routes import router as message_router
from dotenv import load_dotenv

load_dotenv()

ORTAK_DOSYA_YOLU = os.getenv("ORTAK_DOSYA_YOLU")
unit_access_map = json.loads(os.getenv("UNIT_ACCESS_MAP"))

app = FastAPI()
app.include_router(message_router)

Base.metadata.create_all(bind=engine)

class User(BaseModel):
    name: str
    unit: str
    role: str
    username: str
    email: EmailStr        
    password: Optional[str] = None

class LoginRequest(BaseModel):
    username: str
    password: str

class PasswordChangeRequest(BaseModel):
    username: str
    password: str

def normalize(text: str):
    return unicodedata.normalize("NFKD", text).encode("ASCII", "ignore").decode().lower().replace(" ", "")

@app.on_event("startup")
def startup():
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                unit TEXT NOT NULL,
                role TEXT NOT NULL,
                username TEXT UNIQUE NOT NULL,
                email TEXT NOT NULL,
                password TEXT NOT NULL
            )
        """))

@app.get("/users/", response_model=List[User])
def get_users():
    with get_db() as db:
        rows = db.execute(text("SELECT name, unit, role, username, email, password FROM users")).fetchall()
        return [
            {
                "name": row[0],
                "unit": row[1],
                "role": row[2],
                "username": row[3],
                "email": row[4],
                "password": row[5]
            }
            for row in rows
        ]

@app.post("/users/")
def add_user(user: User):
    if not user.password or len(user.password) < 6:
        raise HTTPException(status_code=400, detail="Şifre en az 6 karakter olmalı.")
    with get_db() as db:
        hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        try:
            db.execute(text("""
                INSERT INTO users (name, unit, role, username, email, password) 
                VALUES (:name, :unit, :role, :username, :email, :password)
            """), {
                "name": user.name,
                "unit": user.unit,
                "role": user.role,
                "username": user.username,
                "email": user.email,
                "password": hashed_password
            })
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten mevcut.")
    return {"message": "Kullanıcı başarıyla eklendi"}

@app.put("/users/{username}")
def update_user(username: str, user: User):
    with get_db() as db:
        result = db.execute(text("SELECT password FROM users WHERE username = :username"), {"username": username}).fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
        hashed_password = result[0]
        if user.password:
            hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        db.execute(text("""
            UPDATE users SET name=:name, unit=:unit, role=:role, email=:email, password=:password 
            WHERE username=:username
        """), {
            "name": user.name,
            "unit": user.unit,
            "role": user.role,
            "email": user.email,
            "password": hashed_password,
            "username": username
        })
        db.commit()
    return {"message": "Kullanıcı başarıyla güncellendi"}

@app.put("/change_password")
def change_password(data: PasswordChangeRequest):
    with get_db() as db:
        user = db.execute(text("SELECT * FROM users WHERE username = :username"), {"username": data.username}).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
        hashed_password = bcrypt.hashpw(data.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        db.execute(text("UPDATE users SET password = :password WHERE username = :username"), {
            "password": hashed_password,
            "username": data.username
        })
        db.commit()
    return {"message": "Şifre başarıyla güncellendi"}

@app.post("/login")
def login(user: LoginRequest):
    with get_db() as db:
        result = db.execute(text("SELECT name, password, role, unit, email FROM users WHERE username = :username"), {
            "username": user.username
        }).fetchone()
        if not result:
            raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
        stored_name, stored_password, role, unit, email = result
        if not bcrypt.checkpw(user.password.encode("utf-8"), stored_password.encode("utf-8")):
            raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
    return {
        "message": "Giriş başarılı",
        "username": user.username,
        "name": stored_name,
        "role": role,
        "unit": unit,
        "email": email
    }

@app.delete("/users/{username}")
def delete_user(username: str):
    with get_db() as db:
        result = db.execute(text("DELETE FROM users WHERE username = :username"), {"username": username})
        db.commit()
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Kullanıcı '{username}' bulunamadı.")
    return {"message": f"Kullanıcı '{username}' başarıyla silindi"}

@app.get("/files/open/{file_path:path}")
def open_file(file_path: str):
    decoded = unquote(file_path, encoding="utf-8")
    absolute_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded))
    
    # Path güvenliği
    if os.path.commonpath([absolute_path, os.path.abspath(ORTAK_DOSYA_YOLU)]) != os.path.abspath(ORTAK_DOSYA_YOLU):
        raise HTTPException(status_code=403, detail="Erişim reddedildi")

    if not os.path.exists(absolute_path) or not os.path.isfile(absolute_path):
        raise HTTPException(status_code=404, detail="Dosya bulunamadı")

    mime_type, _ = mimetypes.guess_type(absolute_path)
    filename = os.path.basename(absolute_path)
    try:
        file = open(absolute_path, "rb")
        encoded_filename = urllib.parse.quote(filename)
        return StreamingResponse(
            file,
            media_type=mime_type or "application/pdf",
            headers={
                "Content-Disposition": f"inline; filename*=UTF-8''{encoded_filename}",
                "Content-Type": mime_type or "application/pdf",
                "X-Content-Type-Options": "nosniff"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {e}")

@app.get("/files/browse")
def browse_folder(path: Optional[str] = Query(default=""), username: str = Query(...)):
    with get_db() as db:
        user = db.execute(text("SELECT unit, role FROM users WHERE username = :username"), {
            "username": username
        }).fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

        unit, role = user
        decoded_path = unquote(path)
        full_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded_path))

        # Path güvenliği
        if os.path.commonpath([full_path, os.path.abspath(ORTAK_DOSYA_YOLU)]) != os.path.abspath(ORTAK_DOSYA_YOLU):
            raise HTTPException(status_code=403, detail="Geçersiz erişim")
        
        if not os.path.exists(full_path):
            raise HTTPException(status_code=404, detail="Klasör bulunamadı")

        try:
            items = []
            with os.scandir(full_path) as entries:
                for entry in entries:
                    if role != "Admin":
                        if not decoded_path:
                            allowed_folders = unit_access_map.get(unit, [])
                            if entry.name not in allowed_folders:
                                continue
                        else:
                            allowed_prefixes = unit_access_map.get(unit, [])
                            if not any(decoded_path.startswith(folder) for folder in allowed_prefixes):
                                continue
                    item = {
                        "name": entry.name,
                        "type": "file" if entry.is_file() else "directory",
                    }
                    if entry.is_file():
                        created = datetime.fromtimestamp(entry.stat().st_ctime).strftime("%d.%m.%Y")
                        item["date"] = created
                    items.append(item)
            return items
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Sunucu hatası: {e}")
