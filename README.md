# GAME EVENT - تطبيق إدارة الأحداث والاشتراكات

<p align="center">
  <strong>GAME EVENT</strong> - تطبيق Android احترافي لإدارة الاشتراكات مع نظام دفع متكامل
</p>

---

## المحتويات

- [المتطلبات](#المتطلبات)
- [هيكل المشروع](#هيكل-المشروع)
- [تشغيل الـ Backend](#تشغيل-الـ-backend)
- [تشغيل تطبيق Flutter](#تشغيل-تطبيق-flutter)
- [بناء APK](#بناء-apk)
- [بيانات الأدمن](#بيانات-الأدمن)

---

## المتطلبات

### Backend
- Node.js >= 18
- PostgreSQL >= 14
- npm >= 9

### Mobile
- Flutter SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK (minSdk 21)

---

## هيكل المشروع

```
GAME EVENT/
├── backend/                    # Node.js + Express + TypeScript
│   ├── prisma/
│   │   ├── schema.prisma       # Prisma schema
│   │   ├── seed.ts             # Seed data
│   │   └── migrations/
│   │       └── 001_init.sql    # SQL migration
│   ├── src/
│   │   ├── controllers/        # Business logic
│   │   ├── middleware/         # Auth middleware
│   │   ├── routes/             # API routes
│   │   └── index.ts            # Entry point
│   ├── package.json
│   └── .env.example
│
└── mobile/                     # Flutter Android App
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   │   ├── auth/           # Login, Register
    │   │   ├── home/           # Home screen
    │   │   ├── subscription/   # Plans
    │   │   ├── payment/        # Payment screens
    │   │   ├── engine/         # Engine (Root required)
    │   │   ├── profile/        # User profile
    │   │   └── admin/          # Admin panel
    │   ├── widgets/            # Reusable widgets
    │   ├── services/           # API service
    │   ├── providers/          # State management
    │   ├── models/             # Data models
    │   ├── theme/              # App theme
    │   └── router/             # Go Router
    ├── pubspec.yaml
    └── android/
```

---

## تشغيل الـ Backend

### 1. إعداد قاعدة البيانات

```bash
cd backend

# نسخ ملف الإعدادات
cp .env.example .env

# تعديل DATABASE_URL في .env
# مثال: postgresql://postgres:password@localhost:5432/game_event_db
```

### 2. تنفيذ SQL Migration يدوياً

```bash
# الاتصال بـ PostgreSQL وتنفيذ:
psql -U postgres -d game_event_db -f prisma/migrations/001_init.sql
```

### 3. تثبيت وتشغيل

```bash
cd backend

# تثبيت الحزم
npm install

# توليد Prisma Client
npm run prisma:generate

# تنفيذ Seed (إنشاء الأدمن والباقات والإعدادات)
npm run prisma:seed

# تشغيل في وضع التطوير
npm run dev

# أو البناء للإنتاج
npm run build
npm start
```

الـ Backend سيعمل على: `http://localhost:3000`

---

## تشغيل تطبيق Flutter

### 1. إعداد عنوان الـ API

في ملف `mobile/lib/services/api_service.dart`:

```dart
// للمحاكي (Emulator)
static const String baseUrl = 'http://10.0.2.2:3000/api';

// للجهاز الحقيقي - ضع IP جهازك
static const String baseUrl = 'http://192.168.1.x:3000/api';
```

### 2. تثبيت الحزم

```bash
cd mobile
flutter pub get
```

### 3. تشغيل التطبيق

```bash
# تشغيل على محاكي أو جهاز متصل
flutter run

# أو تحديد الجهاز
flutter run -d android
```

---

## بناء APK

```bash
cd mobile

# بناء APK للتوزيع
flutter build apk --release

# أو بناء APK لكل معماريات CPU
flutter build apk --split-per-abi --release
```

ستجد الـ APK في:
```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## بيانات الأدمن

```
البريد الإلكتروني: charlegilmore75@gmail.com
كلمة المرور: Admin@123456
```

---

## API Endpoints

### Auth
```
POST /api/auth/register    - إنشاء حساب
POST /api/auth/login       - تسجيل دخول
GET  /api/auth/me          - بيانات المستخدم الحالي
```

### Plans
```
GET  /api/plans            - الباقات النشطة (عام)
GET  /api/plans/all        - جميع الباقات (أدمن)
PUT  /api/plans/:id        - تعديل باقة (أدمن)
```

### Payments
```
GET  /api/payments/settings          - إعدادات الدفع (عام)
POST /api/payments                   - إنشاء طلب دفع
POST /api/payments/:id/proof         - رفع صورة إثبات
POST /api/payments/:id/verify-txid   - التحقق من TXID
```

### User
```
GET  /api/users/profile              - ملف المستخدم + الاشتراك
GET  /api/users/payment-history      - سجل المدفوعات
GET  /api/users/subscription-history - سجل الاشتراكات
POST /api/users/use-operation        - استخدام عملية
```

### Admin
```
GET  /api/admin/dashboard                    - إحصائيات
GET  /api/admin/users                        - المستخدمون
PATCH /api/admin/users/:id/toggle            - تفعيل/تعطيل مستخدم
GET  /api/admin/payments                     - جميع المدفوعات
GET  /api/admin/payments/pending             - المدفوعات المعلقة
POST /api/admin/payments/:id/approve         - قبول دفع
POST /api/admin/payments/:id/reject          - رفض دفع
POST /api/admin/subscriptions/activate       - تفعيل اشتراك يدوي
```

### Settings
```
GET /api/settings/payment       - إعدادات الدفع (عام)
GET /api/settings               - جميع الإعدادات (أدمن)
PUT /api/settings/:key          - تحديث إعداد
PUT /api/settings/bulk          - تحديث متعدد
```

---

## ميزات التطبيق

### نظام الاشتراكات
| الباقة | السعر | المدة | العمليات اليومية |
|--------|-------|-------|------------------|
| اليومية | $5 | 1 يوم | 5 |
| الأسبوعية | $10 | 7 أيام | 10 |
| الشهرية | $20 | 30 يوم | 15 |

### طرق الدفع
- **Sham Cash**: رفع صورة إيصال
- **Syriatel Cash**: رفع صورة إيصال
- **USDT BEP20**: تحقق تلقائي من TXID عبر BSCScan API

### صفحة Engine
- تتطلب صلاحيات Root
- يتم فحص الجهاز تلقائياً
- إذا غير مروّت: شاشة قفل كاملة
- إذا مروّت: طلب صلاحية `su` وعرض الصفحة عند الموافقة

---

## الإعدادات المطلوبة

بعد تشغيل الـ Backend، تحتاج لتعديل الإعدادات من لوحة الأدمن:

1. **Cloudinary**: لرفع صور إثبات الدفع
   - Cloud Name, API Key, API Secret

2. **BSCScan API**: للتحقق من USDT BEP20
   - API Key من bscscan.com

3. **عناوين الدفع**:
   - رقم Sham Cash
   - رقم Syriatel Cash
   - عنوان USDT BEP20

---

## التقنيات المستخدمة

### Backend
- **Node.js + Express + TypeScript**
- **Prisma ORM** + PostgreSQL
- **JWT** للمصادقة
- **bcryptjs** لتشفير كلمات المرور
- **Cloudinary** لرفع الصور
- **Axios** للتحقق من blockchain

### Mobile (Flutter)
- **Provider** لإدارة الحالة
- **Go Router** للتنقل
- **Google Fonts (Cairo)** للخطوط العربية
- **flutter_secure_storage** لتخزين JWT
- **image_picker** لاختيار الصور
- **RTL** دعم كامل للعربية
