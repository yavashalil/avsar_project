from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import sqlite3
import bcrypt

app = FastAPI()

# Veritabanı bağlantısı ve tablo oluşturma
conn = sqlite3.connect("users.db", check_same_thread=False)
cursor = conn.cursor()
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    unit TEXT,
    role TEXT,
    username TEXT UNIQUE,
    password TEXT
)
""")
conn.commit()

# Kullanıcı modeli
class User(BaseModel):
    name: str
    unit: str
    role: str
    username: str
    password: Optional[str] = None  # Şifre opsiyonel yapıldı

# Kullanıcı giriş modeli
class LoginRequest(BaseModel):
    username: str
    password: str

#  **Tüm kullanıcıları getir**
@app.get("/users/", response_model=List[User])
def get_users():
    cursor.execute("SELECT name, unit, role, username, password FROM users")
    users = cursor.fetchall()
    return [
        {"name": u[0], "unit": u[1], "role": u[2], "username": u[3], "password": u[4]}
        for u in users
    ]

#  **Yeni kullanıcı ekle**
@app.post("/users/")
def add_user(user: User):
    hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    try:
        cursor.execute(
            "INSERT INTO users (name, unit, role, username, password) VALUES (?, ?, ?, ?, ?)",
            (user.name, user.unit, user.role, user.username, hashed_password),
        )
        conn.commit()
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten mevcut.")

    return {"message": "Kullanıcı başarıyla eklendi"}

#  **Kullanıcı güncelle**
@app.put("/users/{username}")
def update_user(username: str, user: User):
    cursor.execute("SELECT password FROM users WHERE username = ?", (username,))
    existing_user = cursor.fetchone()

    if not existing_user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    # Kullanıcı şifreyi değiştirmek istemezse eski şifreyi koru
    hashed_password = existing_user[0]
    if user.password:
        hashed_password = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    cursor.execute(
        "UPDATE users SET name=?, unit=?, role=?, password=? WHERE username=?",
        (user.name, user.unit, user.role, hashed_password, username),
    )

    conn.commit()
    return {"message": "Kullanıcı başarıyla güncellendi"}

#  **Kullanıcı giriş yap**
@app.post("/login")
def login(user: LoginRequest):
    cursor.execute("SELECT password, role, unit FROM users WHERE username = ?", (user.username,))
    result = cursor.fetchone()
    
    if result is None or not bcrypt.checkpw(user.password.encode("utf-8"), result[0].encode("utf-8")):
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre")

    return {
        "message": "Giriş başarılı",
        "username": user.username,
        "role": result[1],
        "unit": result[2] 
    }

#  **Kullanıcıyı sil**
@app.delete("/users/{username}")
def delete_user(username: str):
    cursor.execute("DELETE FROM users WHERE username = ?", (username,))
    conn.commit()

    if cursor.rowcount == 0:
        raise HTTPException(status_code=404, detail=f"Kullanıcı '{username}' bulunamadı.")

    return {"message": f"Kullanıcı '{username}' başarıyla silindi"}

#  **Birim bazlı kullanıcı sil**
@app.delete("/users/{unit}/{username}")
def delete_user_from_unit(unit: str, username: str):
    cursor.execute("DELETE FROM users WHERE unit = ? AND username = ?", (unit, username))
    conn.commit()

    if cursor.rowcount == 0:
        raise HTTPException(status_code=404, detail=f"{unit} biriminde '{username}' kullanıcısı bulunamadı.")

    return {"message": f"{unit} biriminden '{username}' başarıyla silindi."}

#  **Birimdeki tüm kullanıcıları sil**
@app.delete("/users/{unit}/")
def delete_all_users_from_unit(unit: str):
    cursor.execute("DELETE FROM users WHERE unit = ?", (unit,))
    conn.commit()

    if cursor.rowcount == 0:
        raise HTTPException(status_code=404, detail=f"{unit} biriminde hiç kullanıcı bulunamadı.")

    return {"message": f"{unit} birimindeki tüm kullanıcılar silindi."}

# Backend'i çalıştırmak için:
# python -m uvicorn test:app --host 192.168.2.100 --port 5000
