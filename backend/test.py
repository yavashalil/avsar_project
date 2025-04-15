from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
import asyncpg
import bcrypt
import os
from datetime import datetime
from urllib.parse import unquote
from fastapi.responses import FileResponse
import unicodedata

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
            password TEXT NOT NULL
        )
    """)
    await conn.close()

@app.get("/users/", response_model=List[User])
async def get_users():
    conn = await get_db()
    rows = await conn.fetch("SELECT name, unit, role, username, password FROM users")
    await conn.close()
    return [
        {
            "name": row["name"],
            "unit": row["unit"],
            "role": row["role"],
            "username": row["username"],
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
            "INSERT INTO users (name, unit, role, username, password) VALUES ($1, $2, $3, $4, $5)",
            user.name, user.unit, user.role, user.username, hashed_password
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
        "UPDATE users SET name=$1, unit=$2, role=$3, password=$4 WHERE username=$5",
        user.name, user.unit, user.role, hashed_password, username
    )
    await conn.close()
    return {"message": "Kullanıcı başarıyla güncellendi"}

@app.post("/login")
async def login(user: LoginRequest):
    conn = await get_db()
    result = await conn.fetchrow("SELECT name, password, role, unit FROM users WHERE username = $1", user.username)
    if result is None:
        await conn.close()
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
    stored_name, stored_password, role, unit = result["name"], result["password"], result["role"], result["unit"]
    if not bcrypt.checkpw(user.password.encode("utf-8"), stored_password.encode("utf-8")):
        await conn.close()
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")
    await conn.close()
    return {
        "message": "Giriş başarılı",
        "username": user.username,
        "name": stored_name,
        "role": role,
        "unit": unit
    }

@app.delete("/users/{username}")
async def delete_user(username: str):
    conn = await get_db()
    result = await conn.execute("DELETE FROM users WHERE username = $1", username)
    await conn.close()
    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail=f"Kullanıcı '{username}' bulunamadı.")
    return {"message": f"Kullanıcı '{username}' başarıyla silindi"}

BIRIM_KLASOR_IZINLERI = {
    "Muhasebe": ["001-ŞUAYP DEMİREL MADENSUYU A.Ş (MUHASEBE)", "AFAD BÖLGE KAPAK YAZISI.docx", "RESMİ BELGELER"],
    "Satis": ["BİM PALET GÜNCEL", "ESKİ SATIŞ", "PAZARLAMA", "İHRACAT 2022", "İHRACAT ÜRÜN FOTOLARI"],
    "Finans": ["FİNANS", "M3145"],
    "Satin Alma": ["SATINALMA", "Akis Kart İzleme Aracı.lnk", "KatilimciBilgileri (17).xlsx", "REKLAM-GÖRSEL"],
    "Bilgi Islem": ["BILGI ISLEM", "Thumbs.db"],
    "Kalite": ["KALİTE", "ÜRETİM SAVUNMA TUTANAK"],
    "Lojistik": ["LOJISTIK"],
    "Pazarlama": ["PAZARLAMA"],
    "Sekretarya": ["SEKRETERYA"]
}

def get_izinli_klasorler(unit: str, role: str):
    if role.lower() == "admin":
        return None
    for key, klasorler in BIRIM_KLASOR_IZINLERI.items():
        if normalize(key) == normalize(unit):
            return klasorler
    return []

@app.get("/files/")
async def list_files(username: str):
    conn = await get_db()
    user = await conn.fetchrow("SELECT unit, role FROM users WHERE username=$1", username)
    await conn.close()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    izinli_klasorler = get_izinli_klasorler(user["unit"], user["role"])

    try:
        items = []
        with os.scandir(ORTAK_DOSYA_YOLU) as entries:
            for entry in entries:
                if izinli_klasorler is not None and entry.name not in izinli_klasorler:
                    continue
                if not entry.is_dir():
                    continue
                item = {
                    "name": entry.name,
                    "type": "directory",
                }
                items.append(item)
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Hata: {e}")

@app.get("/files/browse")
async def browse_folder(path: Optional[str] = Query(default=""), username: str = Query(...)):
    conn = await get_db()
    user = await conn.fetchrow("SELECT unit, role FROM users WHERE username=$1", username)
    await conn.close()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    izinli_klasorler = get_izinli_klasorler(user["unit"], user["role"])

    decoded_path = unquote(path, encoding="utf-8")
    full_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded_path))

    if not full_path.startswith(os.path.abspath(ORTAK_DOSYA_YOLU)):
        raise HTTPException(status_code=403, detail="Erişim izniniz yok.")

    ilk_klasor = decoded_path.split("/")[0] if decoded_path else ""
    if izinli_klasorler is not None and ilk_klasor and ilk_klasor not in izinli_klasorler:
        raise HTTPException(status_code=403, detail="Bu klasöre erişim izniniz yok")

    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="Klasör bulunamadı")

    try:
        items = []
        with os.scandir(full_path) as entries:
            for entry in entries:
                if izinli_klasorler is not None and decoded_path == "" and entry.name not in izinli_klasorler:
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

@app.get("/files/download/{file_path:path}")
async def download_file(file_path: str):
    decoded = unquote(file_path, encoding="utf-8")
    absolute_path = os.path.abspath(os.path.join(ORTAK_DOSYA_YOLU, decoded))

    if not os.path.exists(absolute_path) or not os.path.isfile(absolute_path):
        raise HTTPException(status_code=404, detail="Dosya bulunamadı")

    if not absolute_path.startswith(os.path.abspath(ORTAK_DOSYA_YOLU)):
        raise HTTPException(status_code=403, detail="Erişim reddedildi")

    return FileResponse(path=absolute_path, filename=os.path.basename(absolute_path))




# python -m uvicorn test:app --host 192.168.2.100 --port 5000 --reload 