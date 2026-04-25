# AI Caption Demo

Bu proje, görme engelli veya az gören kullanıcılar için kamera görüntüsünden açıklama üretip Türkçe sesli çıktı veren bir mobil uygulama ve backend servisinden oluşur.

Sistem genel akışı:

```text
Mobil uygulama kamera ile görüntü alır
→ Görüntüyü FastAPI backend servisine gönderir
→ Backend BLIP modeli ile İngilizce caption üretir
→ Backend DeepL API ile Türkçeye çevirir
→ Mobil uygulama Türkçe metni TTS ile seslendirir
```

DeepL çevirisi başarısız olursa mobil tarafta ML Kit çeviri mekanizması fallback olarak kullanılabilir.

---

## Proje Yapısı

```text
bitirme_tezi-main/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   │   └── routes.py
│   │   ├── core/
│   │   │   └── model_registry.py
│   │   ├── services/
│   │   │   ├── caption_service.py
│   │   │   └── translation_service.py
│   │   ├── utils/
│   │   │   └── logger.py
│   │   └── main.py
│   ├── requirements.txt
│   └── .env
│
└── mobile/
    ├── lib/
    │   ├── screens/
    │   │   └── home_screen.dart
    │   ├── services/
    │   │   ├── api_service.dart
    │   │   ├── translation_service.dart
    │   │   └── tts_service.dart
    │   └── main.dart
    └── pubspec.yaml
```

---

## Gereksinimler

Backend için:

- Python 3.11 önerilir
- pip
- virtualenv / venv
- CUDA destekli GPU varsa PyTorch CUDA kullanılabilir
- İnternet bağlantısı:
  - İlk model indirme için gerekir
  - DeepL API çevirisi için gerekir

Mobil için:

- Flutter SDK
- Android Studio
- Android Emulator
- Kamera izni
- İnternet / lokal backend bağlantısı

---

## Backend Kurulumu

Önce backend klasörüne girilir:

```cmd
cd backend
```

Sanal ortam oluşturulur:

```cmd
python -m venv .venv
```

Windows üzerinde sanal ortam aktif edilir:

```cmd
.venv\Scripts\activate
```

Gerekli Python paketleri kurulur:

```cmd
pip install -r requirements.txt
```

---

## DeepL API Ayarı

Backend klasörünün içinde `.env` dosyası oluşturulmalıdır:

```text
backend/.env
```

İçeriği şu şekilde olmalıdır:

```env
DEEPL_API_KEY=buraya_deepl_api_key_yazilacak
DEEPL_API_URL=https://api-free.deepl.com/v2/translate
```

DeepL Free / Developer API key genellikle `:fx` ile biter. API key kesinlikle GitHub'a gönderilmemelidir.

`.gitignore` içinde aşağıdaki satırların bulunduğundan emin olunmalıdır:

```gitignore
.env
backend/.env
.venv/
backend/.venv/
```

---

## Backend Çalıştırma

Backend klasöründeyken:

```cmd
.venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Backend başarılı şekilde çalışırsa terminalde buna benzer çıktı görülür:

```text
Application startup complete.
Uvicorn running on http://0.0.0.0:8000
```

---

## Backend Test

Health endpoint:

```text
http://127.0.0.1:8000/health
```

Beklenen örnek cevap:

```json
{
  "status": "ok program çalisiyor",
  "service": "Caption Servisi",
  "model_name": "Salesforce/blip-image-captioning-large",
  "device": "cuda",
  "loaded": true
}
```

Swagger arayüzü:

```text
http://127.0.0.1:8000/docs
```

Swagger üzerinden `POST /caption` endpoint'i test edilebilir.

Beklenen örnek cevap:

```json
{
  "caption_en": "puppy in a field of dandelions looking at the camera",
  "caption_tr": "Karahindiba tarlasında kameraya bakan bir yavru köpek",
  "translation_provider": "deepl",
  "model_name": "Salesforce/blip-image-captioning-large",
  "device": "cuda",
  "timings_ms": {
    "read": 0,
    "caption": 1000,
    "translation": 300,
    "total": 1300
  },
  "request_id": "..."
}
```

Eğer DeepL çevirisi başarısız olursa `caption_tr` alanı `null`, `translation_provider` alanı ise `deepl_failed` dönebilir.

---

## Mobil Uygulama Kurulumu

Yeni bir terminal açılır ve mobil klasörüne girilir:

```cmd
cd mobile
```

Flutter paketleri kurulur:

```cmd
flutter pub get
```

Emulator veya bağlı cihaz kontrol edilir:

```cmd
flutter devices
```

Uygulama çalıştırılır:

```cmd
flutter run
```

---

## Emulator Backend Bağlantısı

Android Emulator, bilgisayardaki localhost adresine doğrudan `127.0.0.1` veya `localhost` ile erişemez.

Bu nedenle Flutter tarafında backend adresi şu şekilde kullanılmalıdır:

```text
http://10.0.2.2:8000
```

`mobile/lib/services/api_service.dart` içinde base URL şu şekilde olmalıdır:

```dart
static const String _baseUrl = 'http://10.0.2.2:8000';
```

Fiziksel Android cihaz kullanılıyorsa bu adres yerine bilgisayarın yerel IP adresi kullanılmalıdır. Örnek:

```text
http://192.168.1.25:8000
```

Bu durumda bilgisayar ve telefon aynı Wi-Fi ağına bağlı olmalıdır.

---

## Çalıştırma Sırası

Projeyi çalıştırmak için önerilen sıra:

### 1. Backend'i başlat

```cmd
cd backend
.venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Android Emulator'ü aç

Android Studio üzerinden:

```text
Tools → Device Manager → Emulator başlat
```

### 3. Flutter uygulamasını çalıştır

```cmd
cd mobile
flutter run
```

---

## Sistem Akışı

```text
1. Kullanıcı mobil uygulamada başlat butonuna basar.
2. Uygulama kameradan görüntü alır.
3. Görüntü backend'e gönderilir.
4. Backend BLIP modeli ile İngilizce caption üretir.
5. Backend DeepL API ile Türkçeye çevirir.
6. Mobil uygulama Türkçe metni alır.
7. TTS servisi Türkçe metni sesli okur.
8. Belirlenen süre sonunda yeni döngü başlar.
```

Varsayılan otomatik çekim aralığı:

```text
15 saniye
```

---

## Çeviri Önceliği

Mobil uygulamada çeviri önceliği şu şekildedir:

```text
1. Backend'den gelen caption_tr doluysa:
   - DeepL çevirisi kullanılır.
   - Metin doğrudan TTS ile okunur.

2. Backend'den caption_tr boş veya null gelirse:
   - Mobil tarafta ML Kit fallback çeviri çalışır.
   - Elde edilen Türkçe metin TTS ile okunur.
```

Bu sayede DeepL API hata verdiğinde sistem tamamen durmaz.

---

## Sık Karşılaşılan Hatalar

### Backend bağlantısı kurulamadı

Kontrol edilmesi gerekenler:

```text
Backend çalışıyor mu?
Uvicorn 8000 portunda açık mı?
Flutter base URL doğru mu?
Emulator için 10.0.2.2 kullanılıyor mu?
```

### Port 8000 kullanımda

Windows üzerinde portu kullanan işlem bulunur:

```cmd
netstat -ano | findstr :8000
```

İşlem kapatılır:

```cmd
taskkill /PID PID_NUMARASI /F
```

### DeepL çevirisi başarısız

Kontrol edilmesi gerekenler:

```text
.env dosyasında gerçek DeepL API key var mı?
DEEPL_API_URL doğru mu?
Free API key için api-free.deepl.com kullanılıyor mu?
Backend yeniden başlatıldı mı?
```

Doğru `.env` örneği:

```env
DEEPL_API_KEY=gercek_api_key_buraya
DEEPL_API_URL=https://api-free.deepl.com/v2/translate
```

### Emulator açılmıyor

Android Studio Device Manager üzerinden sırayla denenebilir:

```text
Cold Boot Now
Wipe Data
Yeni emulator oluşturma
```

---

## Git Notları

`.env` dosyası commit edilmemelidir.

Değişiklikleri kontrol etmek için:

```cmd
git status
```

Dosyaları eklemek için:

```cmd
git add .
```

Commit atmak için:

```cmd
git commit -m "add deepl translation"
```

Branch adını main yapmak için:

```cmd
git branch -M main
```

---

## Özet

Bu proje iki ana parçadan oluşur:

```text
Backend:
FastAPI + BLIP image captioning + DeepL translation

Mobile:
Flutter camera + backend API connection + Turkish TTS + ML Kit fallback
```

Çalıştırma sırası:

```text
1. Backend'i başlat
2. Emulator'ü aç
3. Flutter uygulamasını çalıştır
4. Görüntü al ve Türkçe sesli açıklamayı test et
```
