import time
import os
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import psycopg2
from psycopg2.extras import RealDictCursor
import firebase_admin
from firebase_admin import credentials, messaging
from threading import Timer
from collections import defaultdict
from urllib.parse import quote
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
WATCH_FOLDERS = os.getenv("WATCH_FOLDERS", "").split(";")
WATCH_BASE_PATH = os.getenv("WATCH_BASE_PATH", r"\\192.168.2.7\data")
LOG_FILE = os.getenv("LOG_FILE", "kalite_dosya_loglari.txt")
FIREBASE_CRED_PATH = os.getenv("FIREBASE_CRED_PATH", os.path.join(os.path.dirname(__file__), "service-account.json"))
FCM_TEST_DEVICE_TOKEN = os.getenv("FCM_TEST_DEVICE_TOKEN")
VALID_EXTENSIONS = [".xlsx", ".xls", ".csv", ".pdf", ".doc", ".docx"]

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CRED_PATH)
    firebase_admin.initialize_app(cred)

conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
conn.autocommit = True

def db_insert_log(zaman, event_type, filename):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO file_logs (event_time, event_type, filename)
            VALUES (%s, %s, %s)
            """,
            (zaman, event_type, filename)
        )

def send_fcm_notification(zaman, event_type, full_path, filename):
    try:
        # .env'den alınan base path ile normalize et
        relative_path = os.path.relpath(full_path, WATCH_BASE_PATH).replace("\\", "/")
        encoded_path = quote(relative_path, safe="/()~$-_")

        title = "Dosya Takibi:"
        body = (
            f"{filename} dosyasında {event_type.lower()} işlemi yapıldı.\n\n"
            f"Zaman      : {zaman.strftime('%d.%m.%Y %H:%M:%S')}"
        )

        message = messaging.Message(
            token=FCM_TEST_DEVICE_TOKEN,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "fileurl": encoded_path,
                "event_type": event_type,
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    color="#00796B",
                )
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"}
            )
        )

        response = messaging.send(message)
        print(f"Bildirim gönderildi (mesaj ID: {response})")

    except Exception as e:
        print(f"Bildirim gönderme hatası: {e}")

class ExcelWatcherHandler(FileSystemEventHandler):
    def __init__(self):
        super().__init__()
        self.bildirim_kuyrugu = defaultdict(lambda: None)
        self.bildirim_suresi = 60

    def log_change(self, event_type: str, path: str):
        if not any(path.startswith(klasor) for klasor in WATCH_FOLDERS):
            return

        filename = os.path.basename(path)
        if not any(filename.lower().endswith(ext) for ext in VALID_EXTENSIONS):
            return

        zaman = datetime.now()

        if self.bildirim_kuyrugu[filename] is not None:
            print(f"{filename} için 60 saniye bekleniyor, bildirim atlanıyor.")
            return

        self.bildirim_kuyrugu[filename] = Timer(
            self.bildirim_suresi,
            self.gonder_bildirim,
            [event_type, path, zaman]
        )
        self.bildirim_kuyrugu[filename].start()

    def gonder_bildirim(self, event_type, path, zaman):
        filename = os.path.basename(path)
        satir = (
            f"[{zaman:%Y-%m-%d %H:%M:%S}] "
            f"{event_type:<10} | {filename:<40}\n"
        )

        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(satir)

        try:
            db_insert_log(zaman, event_type, filename)
        except Exception as e:
            print("Veritabanına yazılamadı:", e)

        send_fcm_notification(zaman, event_type, path, filename)
        print(satir.strip())

        self.bildirim_kuyrugu[filename] = None

    def on_modified(self, event):
        if not event.is_directory:
            self.log_change("DEĞİŞTİRİLDİ", event.src_path)

    def on_deleted(self, event):
        if not event.is_directory:
            self.log_change("SİLİNDİ", event.src_path)

if __name__ == "__main__":
    print("İzlenen klasörler:")
    for k in WATCH_FOLDERS:
        print(f"  - {k}")

    observer = Observer()
    handler = ExcelWatcherHandler()

    for klasor in WATCH_FOLDERS:
        observer.schedule(handler, path=klasor, recursive=True)

    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    conn.close()
