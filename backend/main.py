from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
import asyncpg
import bcrypt
import os
from datetime import datetime
from urllib.parse import unquote
from fastapi.responses import FileResponse, Response
import unicodedata
import mimetypes
from fastapi.responses import StreamingResponse
import urllib

app = FastAPI()

DATABASE_URL = "postgresql://postgres:Halil0648.@localhost:5432/avsar_db"
ORTAK_DOSYA_YOLU = r"\\192.168.2.7\data\ORTAK"

async def get_db():
    return await asyncpg.connect(DATABASE_URL)

class User(BaseModel):
    name: str
    unit: str
    role: str
    username: str
    email: str        
    password: Optional[str] = None

class LoginRequest(BaseModel):
    username: str
    password: str
 
def normalize(text: str):
    return unicodedata.normalize("NFKD", text).encode("ASCII", "ignore").decode().lower().replace(" ", "")

@app.on_event("startup")
async def startup():
    conn = await get_db()
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            role TEXT NOT NULL,
            username TEXT UNIQUE NOT NULL,
            email TEXT NOT NULL,
            password TEXT NOT NULL
        )
    """)
    await conn.close()

@app.get("/users/", response_model=List[User])
async def get_users():
    conn = await get_db()
    rows = await conn.fetch("SELECT name, unit, role, username, email, password FROM users")
    await conn.close()
    return [
        {
            "name": row["name"],
            "unit": row["unit"],
            "role": row["role"],
            "username": row["username"],
            "email": row["email"],
            "password": row["password"]
        }
        for row in rows 
    ]

@app.post("/users/")
async def add_user(user: User):
    conn = await get_db()
    hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    try:
        await conn.execute(
            "INSERT INTO users (name, unit, role, username, email, password) VALUES ($1, $2, $3, $4, $5, $6)",
            user.name, user.unit, user.role, user.username, user.email, hashed_password
        )
        await conn.close()
    except asyncpg.UniqueViolationError:
        await conn.close()
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten mevcut.")
    return {"message": "Kullanıcı başarıyla eklendi"}

@app.put("/users/{username}")
async def update_user(username: str, user: User):
    conn = await get_db()
    existing_user = await conn.fetchrow("SELECT password FROM users WHERE username = $1", username)
    if not existing_user:
        await conn.close()
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
    hashed_password = existing_user["password"]
    if user.password:
        hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    await conn.execute(
        "UPDATE users SET name=$1, unit=$2, role=$3, email=$4, password=$5 WHERE username=$6",
        user.name, user.unit, user.role, user.email, hashed_password, username
    )
    await conn.close()
    return {"message": "Kullanıcı başarıyla güncellendi"}
 
@app.post("/login")
async def login(user: LoginRequest):
    conn = await get_db()
    result = await conn.fetchrow("SELECT name, password, role, unit, email FROM users WHERE username = $1", user.username)
    if result is None:
        await conn.close()
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
    stored_name, stored_password, role, unit, email = result["name"], result["password"], result["role"], result["unit"], result["email"]
    if not bcrypt.checkpw(user.password.encode("utf-8"), stored_password.encode("utf-8")):
        await conn.close()
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
    await conn.close()
    return {
        "message": "Giriş başarılı",
        "username": user.username,
        "name": stored_name,
        "role": role,
        "unit": unit,
        "email": email
    }

@app.delete("/users/{username}")
async def delete_user(username: str):
    conn = await get_db()
    result = await conn.execute("DELETE FROM users WHERE username = $1", username)
    await conn.close()
    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail=f"Kullanıcı '{username}' bulunamadı.")
    return {"message": f"Kullanıcı '{username}' başarıyla silindi"}

@app.get("/files/open/{file_path:path}")
async def open_file(file_path: str):
    decoded = unquote(file_path, encoding="utf-8")
    print("📂 İstek geldi:", file_path)
    print("🧹 Çözülmüş path:", decoded)
    absolute_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded))

    if not os.path.exists(absolute_path) or not os.path.isfile(absolute_path):
        raise HTTPException(status_code=404, detail="Dosya bulunamadı")

    if not absolute_path.startswith(os.path.abspath(ORTAK_DOSYA_YOLU)):
        raise HTTPException(status_code=403, detail="Erişim reddedildi")

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
async def browse_folder(path: Optional[str] = Query(default=""), username: str = Query(...)):
    conn = await get_db()
    user = await conn.fetchrow("SELECT unit, role FROM users WHERE username=$1", username)
    await conn.close()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    decoded_path = unquote(path)
    full_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded_path))
    print("🔍 İstenen path:", decoded_path)
    print("🗂️ Tam sistem path:", full_path)

    if not full_path.startswith(os.path.abspath(ORTAK_DOSYA_YOLU)):
        raise HTTPException(status_code=403, detail="Geçersiz erişim")

    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="Klasör bulunamadı")

    try:
        items = []
        with os.scandir(full_path) as entries:
            for entry in entries:
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
