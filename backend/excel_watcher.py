import time
import getpass
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


# -------------------- AYARLAR --------------------
DATABASE_URL = "postgresql://postgres:Halil0648.@localhost:5432/avsar_db"
IZLENECEK_KLASORLER = [
    r"\\192.168.2.7\data\ORTAK\KALİTE\4. FORMLAR",
    r"\\192.168.2.7\data\ORTAK\KALİTE\10. TALİMATLAR",
    r"\\192.168.2.7\data\ORTAK\KALİTE\11. PROSEDÜRLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\3. PLANLAR",
    r"\\192.168.2.7\data\ORTAK\KALİTE\2.TEHLİKE ANALİZLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\5. HAMMADDE-ÜRÜN TANIMLARI",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2021\DÜZELTİCİ FAALİYETLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2022\DÜZELTİCİ FAALİYETLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2023\DÜZELTİCİ FAALİYETLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2024\DÜZELTİCİ FAALİYETLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2025\DÜZELTİCİ FAALİYETLER",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2021\MÜŞTERİ BİLDİRİMLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2022\MÜŞTERİ BİLDİRİMLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2023\MÜŞTERİ BİLDİRİMLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2024\MÜŞTERİ BİLDİRİMLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2025\MÜŞTERİ BİLDİRİMLERİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2021\UYGUNSUZ ÜRÜN\UYGUN OLMAYAN ÜRÜN TAKİBİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2022\UYGUNSUZ ÜRÜN\UYGUN OLMAYAN ÜRÜN TAKİBİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2023\UYGUNSUZ ÜRÜN\UYGUN OLMAYAN ÜRÜN TAKİBİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2024\UYGUNSUZ ÜRÜN\UYGUN OLMAYAN ÜRÜN TAKİBİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\21. UYGULAMALAR\2025\UYGUNSUZ ÜRÜN\UYGUN OLMAYAN ÜRÜN TAKİBİ",
    r"\\192.168.2.7\data\ORTAK\KALİTE\22. ÜRETİM UYGULAMALAR\ÜRETİM VERİMİ",
] 
LOG_DOSYASI = "kalite_dosya_loglari.txt"
GECERLI_UZANTILAR = [".xlsx", ".xls", ".csv", ".pdf", ".doc", ".docx"]

FIREBASE_CRED_PATH = os.path.join(os.path.dirname(__file__), "service-account.json")
FCM_TEST_DEVICE_TOKEN = "fnZgpDXHRnqP4bjH7elkx7:APA91bHr2Z_DHgyuO8rqf1WqzdHpavcvK-c_38LWp3AX6hEry2bsJQ0XcArKBxF1NIMIigOd0FHS-gCdJoPtaTDSgsw0mElQmR_8hxh-W8wC0l2HvDLoADw"

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CRED_PATH)
    firebase_admin.initialize_app(cred)

conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
conn.autocommit = True

# -------------------- VERİTABANI --------------------
def db_insert_log(zaman, event_type, filename, script_user, owner):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO file_logs (event_time, event_type, filename, script_user, owner)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (zaman, event_type, filename, script_user, owner)
        )

# -------------------- FCM PUSH --------------------
def send_fcm_notification(zaman, event_type, filename, script_user, owner):
    try:
        title = "📁 Dosya Takibi - QDMS"
        body = (
            f"📝 *{filename}* dosyasında **{event_type.lower()}** işlemi yapıldı.\n\n"
            f"👤 Kullanıcı  : {script_user}\n"
            f"🕒 Zaman      : {zaman.strftime('%d.%m.%Y %H:%M:%S')}"
        )

        message = messaging.Message(
            token=FCM_TEST_DEVICE_TOKEN,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "filepath": filename,  # Veya tam yol: path
                "event_type": event_type,
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    color="#00796B",  # yeşilimsi renk
                )
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"}
            )
        )

        response = messaging.send(message)
        print(f"✅ Bildirim gönderildi (mesaj ID: {response})")

    except Exception as e:
        print(f"⚠️ Bildirim gönderme hatası: {e}")


# -------------------- DOSYA İZLEYİCİ --------------------

class ExcelWatcherHandler(FileSystemEventHandler):
    def __init__(self):
        super().__init__()
        self.bildirim_kuyrugu = defaultdict(lambda: None)
        self.bildirim_suresi = 15  # saniye

    def log_change(self, event_type: str, path: str):
        filename = os.path.basename(path)
        if not any(filename.lower().endswith(ext) for ext in GECERLI_UZANTILAR):
            return

        ilgili_klasor = next(
            (k for k in IZLENECEK_KLASORLER if os.path.commonpath([k, path]) == k),
            "Bilinmeyen klasör"
        )

        zaman = datetime.now()
        script_user = getpass.getuser()
        owner = "N/A"

        if self.bildirim_kuyrugu[filename] is not None:
            print(f"⏳ {filename} için 15 saniye bekleniyor, bildirim atlanıyor.")
            return

        self.bildirim_kuyrugu[filename] = Timer(
            self.bildirim_suresi,
            self.gonder_bildirim,
            [event_type, path, zaman, script_user, owner, ilgili_klasor]
        )
        self.bildirim_kuyrugu[filename].start()

    def gonder_bildirim(self, event_type, path, zaman, script_user, owner, ilgili_klasor):
        filename = os.path.basename(path)
        satir = (
            f"[{zaman:%Y-%m-%d %H:%M:%S}] "
            f"{event_type:<10} | {filename:<40} | "
            f"User: {script_user:<15} | Owner: {owner} | Klasör: {ilgili_klasor}\n"
        )

        with open(LOG_DOSYASI, "a", encoding="utf-8") as f:
            f.write(satir)

        try:
            db_insert_log(zaman, event_type, filename, script_user, owner)
        except Exception as e:
            print("⚠️ Veritabanına yazılamadı:", e)

        send_fcm_notification(zaman, event_type, filename, script_user, owner, klasor_adi=os.path.basename(ilgili_klasor))
        print(satir.strip())

        self.bildirim_kuyrugu[filename] = None

    def on_modified(self, event):
        if not event.is_directory:
            self.log_change("DEĞİŞTİRİLDİ", event.src_path)

    def on_created(self, event):
        if not event.is_directory:
            self.log_change("OLUŞTURULDU", event.src_path)

    def on_deleted(self, event):
        if not event.is_directory:
            self.log_change("SİLİNDİ", event.src_path)


# -------------------- ANA FONKSİYON --------------------
if __name__ == "__main__":
    print("📂 İzlenen klasörler:")
    for k in IZLENECEK_KLASORLER:
        print(f"  - {k}")

    observer = Observer()
    handler = ExcelWatcherHandler()

    for klasor in IZLENECEK_KLASORLER:
        observer.schedule(handler, path=klasor, recursive=True)

    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    conn.close()
