# 🥊 PGC App

Mobile application for managing a combat sports club (boxing, MMA, kickboxing, Muay Thai, BJJ, wrestling).

Members can book classes, manage their subscription and track their schedule — admins can manage the entire club from a simple interface.

---

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Repo Structure](#repo-structure)
- [Backend — FastAPI](#backend--fastapi)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Environment Variables](#environment-variables)
  - [Running in Development](#running-in-development)
  - [API Reference](#api-reference)
  - [Data Models](#data-models)
  - [Roles & Permissions](#roles--permissions)
  - [Stripe Payments](#stripe-payments)
  - [Emails](#emails)
- [Mobile — Flutter](#mobile--flutter)
  - [Flutter Prerequisites](#flutter-prerequisites)
  - [Flutter Installation](#flutter-installation)
  - [Running the App](#running-the-app)
  - [Available Screens](#available-screens)
  - [API Connection](#api-connection)
- [Deployment](#deployment)
  - [Backend (Railway)](#backend-railway)
  - [App Store & Play Store](#app-store--play-store)
- [Roadmap](#roadmap)

---

## Architecture

```
pgc_app/
├── app/        ← Python FastAPI backend
└── mobile/     ← Flutter mobile app (iOS + Android)
```

The backend exposes a REST API consumed by the Flutter app. Both are independent and can be deployed separately.

```
[Flutter App] ──HTTP/JSON──> [FastAPI] ──SQLAlchemy──> [PostgreSQL]
                                  │
                                  ├──> [Stripe]   (payments)
                                  └──> [SMTP]     (emails)
```

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Backend | Python / FastAPI | 3.11+ / 0.111 |
| Database | PostgreSQL + SQLAlchemy | 16 / 2.0 |
| Authentication | JWT (python-jose) | HS256 |
| Password hashing | bcrypt (passlib) | — |
| Payments | Stripe | 9.9 |
| Emails | SMTP (Brevo recommended) | — |
| Mobile app | Flutter / Dart | 3.19+ |
| State management | Provider | 6.1 |
| Navigation | go_router | 13.2 |
| JWT storage | flutter_secure_storage | 9.0 |

---

## Repo Structure

```
pgc_app/
│
├── app/                          ← FastAPI backend
│   ├── main.py                   ← Entry point, table creation
│   ├── database.py               ← SQLAlchemy connection + DB session
│   │
│   ├── core/
│   │   ├── config.py             ← Environment variables (Pydantic Settings)
│   │   └── security.py           ← bcrypt hashing + JWT creation/decoding
│   │
│   ├── models/                   ← PostgreSQL tables (SQLAlchemy)
│   │   ├── member.py             ← Members, roles, belt rank, plan, subscription status
│   │   ├── course.py             ← Classes (type, level, schedule, capacity)
│   │   ├── booking.py            ← Bookings + waitlist
│   │   ├── subscription.py       ← Stripe subscriptions
│   │   ├── academy_video.py      ← Academy training videos
│   │   └── device_token.py       ← Device FCM tokens (push)
│   │
│   ├── schemas/                  ← API contracts (Pydantic)
│   │   ├── member_schema.py      ← MemberCreate, MemberOut, LoginRequest, TokenOut
│   │   ├── course_schema.py      ← CourseCreate, CourseUpdate, CourseOut
│   │   ├── booking_schema.py     ← BookingCreate, BookingOut
│   │   └── subscription_schema.py← SubscriptionCreate, SubscriptionOut
│   │
│   ├── routers/                  ← API endpoints
│   │   ├── auth.py               ← POST /auth/register, /auth/login, /auth/token
│   │   ├── members.py            ← GET/PUT /members/me, admin CRUD, avatars
│   │   ├── courses.py            ← Course CRUD + available spots + change notifications
│   │   ├── bookings.py           ← Booking, cancellation, waitlist
│   │   ├── subscriptions.py      ← Subscriptions + Stripe webhook
│   │   ├── academy.py            ← Training videos (admin-managed)
│   │   ├── notifications.py      ← Register/unregister device FCM tokens
│   │   └── tasks.py              ← Cron tasks (24h reminders)
│   │
│   └── services/                 ← Isolated business logic
│       ├── stripe_service.py     ← Subscription creation/cancellation, webhook
│       ├── email_service.py      ← Transactional emails (SMTP)
│       ├── push_service.py       ← FCM push (Firebase Admin SDK)
│       ├── notification_service.py ← Orchestrates push + email to booked members
│       └── storage_service.py    ← Google Cloud Storage (photos)
│
├── mobile/                       ← Flutter app
│   └── lib/
│       ├── main.dart             ← Flutter entry point + routing
│       ├── config/
│       │   └── api_config.dart   ← API base URL
│       ├── models/               ← Dart models (JSON deserialization)
│       │   ├── member.dart
│       │   ├── course.dart
│       │   └── booking.dart
│       ├── providers/
│       │   └── auth_provider.dart← JWT management, auto-login, auth state
│       ├── services/
│       │   └── api_service.dart  ← All HTTP calls to FastAPI
│       └── screens/
│           ├── auth/
│           │   ├── login_screen.dart
│           │   └── register_screen.dart
│           ├── courses/
│           │   ├── course_list_screen.dart
│           │   └── course_detail_screen.dart
│           ├── bookings/
│           │   └── my_bookings_screen.dart
│           └── profile/
│               └── profile_screen.dart
│
├── requirements.txt              ← Python dependencies
├── .env.example                  ← Environment variables template
└── README.md
```

---

## Backend — FastAPI

### Prerequisites

- Python 3.11+
- Docker (for PostgreSQL)
- A [Stripe](https://stripe.com) account (test mode is enough for development)
- A [Brevo](https://brevo.com) account or any other SMTP provider (optional in dev)

### Installation

```bash
# 1. Clone the repo
git clone https://github.com/your-username/pgc_app.git
cd pgc_app

# 2. Create a virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy and configure the .env
cp .env.example .env
# → edit .env with your values (see next section)
```

### Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/pgc_app

# JWT — generate a long random key:
# python -c "import secrets; print(secrets.token_hex(32))"
SECRET_KEY=change-this-to-a-very-long-random-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Stripe
STRIPE_SECRET_KEY=sk_test_...         # Stripe Dashboard > Developers > API Keys
STRIPE_WEBHOOK_SECRET=whsec_...       # Stripe Dashboard > Webhooks

# App
APP_NAME=PGC App
DEBUG=True                            # Set to False in production

# Email SMTP (Brevo: 300 free emails/day)
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=your@email.com
SMTP_PASSWORD=your_brevo_api_key
EMAIL_FROM=noreply@yourclub.com
```

> In `DEBUG=True` mode, emails are not sent — they are simply logged to the terminal. Useful for developing without an SMTP account.

### Running in Development

```bash
# 1. Start PostgreSQL with Docker
docker compose up -d

# To access database SQL:
docker exec -it pgc-app_db_1 psql -U user -d pgc_ap

# Minimal docker-compose.yml (create at project root):
# services:
#   db:
#     image: postgres:16
#     environment:
#       POSTGRES_DB: pgc_app
#       POSTGRES_USER: user
#       POSTGRES_PASSWORD: password
#     ports:
#       - "5432:5432"
#     volumes:
#       - postgres_data:/var/lib/postgresql/data
# volumes:
#   postgres_data:

# 2. Start the API (tables are created automatically on startup)
uvicorn app.main:app --reload

# API available at http://localhost:8000
# Interactive docs: http://localhost:8000/docs
```

### API Reference

Full interactive documentation is available at `/docs` (Swagger UI) and `/redoc` once the server is running.

#### Auth

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/auth/register` | Create a member account | — |
| POST | `/auth/login` | Login → returns JWT + profile | — |
| POST | `/auth/token` | OAuth2 login (for Swagger Authorize button) | — |

#### Members

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/members/me` | My profile | 🔒 member |
| PUT | `/members/me` | Update my profile | 🔒 member |
| GET | `/members/` | List all members | 🔒 admin |
| GET | `/members/{id}` | Member detail | 🔒 admin |
| DELETE | `/members/{id}` | Deactivate a member | 🔒 admin |

#### Courses

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/courses/` | List courses (filterable) | 🔒 member |
| GET | `/courses/{id}` | Course detail | 🔒 member |
| POST | `/courses/` | Create a course | 🔒 admin |
| PUT | `/courses/{id}` | Update a course | 🔒 admin |
| DELETE | `/courses/{id}` | Delete a course | 🔒 admin |

Query parameters for `GET /courses/`:
- `from_date` — start date (ISO 8601)
- `to_date` — end date (ISO 8601)
- `course_type` — course type (`mma`, `grappling`, `wrestling`, `other`)
- `coach_id` — filter by coach

#### Bookings

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/bookings/me` | My bookings | 🔒 member |
| POST | `/bookings/` | Book a course | 🔒 member |
| DELETE | `/bookings/{id}` | Cancel a booking | 🔒 member |
| GET | `/bookings/course/{id}` | All bookings for a course | 🔒 admin |

> When a course is full, the booking is automatically placed on the waitlist (`status: waitlist`). If a member cancels, the first person on the waitlist is automatically promoted and receives an email notification.

#### Subscriptions

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/subscriptions/me` | My subscriptions | 🔒 member |
| POST | `/subscriptions/` | Subscribe to a plan | 🔒 member |
| DELETE | `/subscriptions/me` | Cancel my subscription | 🔒 member |
| POST | `/subscriptions/webhook` | Stripe webhook | — (Stripe) |
| GET | `/subscriptions/` | All subscriptions | 🔒 admin |

#### Notifications & Tasks

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/notifications/device-token` | Register this device's FCM token | 🔒 member |
| DELETE | `/notifications/device-token` | Remove the token (on logout) | 🔒 member |
| POST | `/tasks/send-reminders` | Send 24h reminders (called hourly by a cron) | 🔒 `X-Cron-Secret` |

### Data Models

#### Member

```
id, email, hashed_password, first_name, last_name, phone, avatar_url
belt_rank: white | blue | purple | brown | black
role: member | coach | admin
is_active: bool
subscription_status: active | inactive | trial | suspended
subscription_plan: unlimited | two_per_week
weekly_booking_limit: int | null   # null = unlimited
stripe_customer_id
created_at, updated_at
```

#### Course

```
id, name, description
course_type: mma | grappling | wrestling | other
level: beginner | intermediate | advanced | all_levels
start_time, end_time
max_capacity
coach_id (FK → members)
reminder_sent_at   # 24h reminder dedup
created_at
```

#### Booking

```
id
member_id (FK → members)
course_id (FK → courses)
status: confirmed | cancelled | waitlist | attended
notes, booked_at, cancelled_at
```

#### Subscription

```
id
member_id (FK → members)
plan_type: monthly | quarterly | annual
price (€)
state: active | cancelled | past_due | unpaid
stripe_subscription_id, stripe_price_id
current_period_start, current_period_end
created_at, cancelled_at
```

### Roles & Permissions

| Action | member | coach | admin |
|---|---|---|---|
| View courses | ✅ | ✅ | ✅ |
| Book a course | ✅ | ✅ | ✅ |
| Create/update a course | ❌ | ❌ | ✅ |
| View all members | ❌ | ❌ | ✅ |
| Deactivate a member | ❌ | ❌ | ✅ |
| View all bookings | ❌ | ❌ | ✅ |

**Promote an account to admin** (via SQL):
```sql
UPDATE members SET role = 'admin' WHERE email = 'your@email.com';
```

### Stripe Payments

Pricing plans are configured in `app/services/stripe_service.py`:

| Plan | Price | Interval |
|---|---|---|
| `monthly` | €49/month | Monthly |
| `quarterly` | €129/quarter | Every 3 months |
| `annual` | €449/year | Yearly |

To change pricing, edit the `PLAN_PRICES` dictionary in `stripe_service.py`.

**Setting up the Stripe webhook:**
1. Stripe Dashboard → Developers → Webhooks → Add endpoint
2. URL: `https://your-domain.com/subscriptions/webhook`
3. Events to listen to: `customer.subscription.updated`, `customer.subscription.deleted`
4. Copy the `Signing secret` → paste as `STRIPE_WEBHOOK_SECRET` in your `.env`

### Notifications (push + email)

The app notifies members through **two channels at once**: **push notifications**
(Firebase Cloud Messaging) and **email** (SMTP). Email acts as a reliable fallback
and reaches members even when the app is closed or uninstalled.

| Event | Push | Email |
|---|---|---|
| Registration | — | Welcome email |
| Booking confirmed | — | Confirmation with date and time |
| Booking cancelled | — | Cancellation confirmation |
| Promoted from waitlist | — | Spot available notification |
| Subscription activated | — | Confirmation with end date |
| **Course modified** (coach, time, name…) | ✅ | ✅ |
| **Course cancelled / deleted** | ✅ | ✅ |
| **24h reminder before a course** | ✅ | ✅ |

Only members with an **active booking** (confirmed or waitlist) on the affected
course are notified. The 24h reminder explicitly asks members to cancel if they
can't attend, so the spot is freed for the waitlist.

**Architecture:**
- Device FCM tokens are stored server-side (`device_tokens` table) and registered
  automatically by the app at login.
- `app/services/push_service.py` sends FCM messages; `app/services/notification_service.py`
  orchestrates push + email. Both **degrade gracefully**: with no Firebase config
  (or `DEBUG=True` for email), notifications are just logged, never sent — nothing crashes.
- The 24h reminder is driven by an **hourly cron** hitting `POST /tasks/send-reminders`
  (protected by the `X-Cron-Secret` header).

> 📘 Full setup (Firebase project, APNs key, cron) is documented in
> [`NOTIFICATIONS_SETUP.md`](NOTIFICATIONS_SETUP.md). **iOS push requires a paid Apple
> Developer account** for APNs; Android push works with the free Firebase tier.

Recommended email provider: **[Brevo](https://brevo.com)** — 300 free emails/day, no credit card required.

---

## Mobile — Flutter

### Flutter Prerequisites

- Flutter SDK 3.19+
- Android Studio or VS Code with the Flutter extension
- An Android emulator or iOS simulator (or a real device)
- The FastAPI backend must be running and reachable from the device/emulator

### Flutter Installation

```bash
# Linux
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.6-stable.tar.xz
tar xf flutter_linux_3.19.6-stable.tar.xz
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter doctor

# Install project dependencies
cd pgc_app/mobile
flutter pub get
```

### Running the App

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device_id>

# Run in release mode (better performance)
flutter run --release
```

> **Important:** On an Android emulator, `localhost` points to the emulator itself, not your machine. Use `10.0.2.2` instead. Configure the URL in `lib/config/api_config.dart`.

### Available Screens

| Screen | File | Description |
|---|---|---|
| Login | `screens/auth/login_screen.dart` | Email/password login → JWT |
| Register | `screens/auth/register_screen.dart` | Account creation |
| Schedule | `screens/courses/course_list_screen.dart` | Courses for the next 14 days |
| Course detail | `screens/courses/course_detail_screen.dart` | Info + book button |
| My bookings | `screens/bookings/my_bookings_screen.dart` | History + cancellation |
| My profile | `screens/profile/profile_screen.dart` | Info + logout |

### API Connection

Edit `lib/config/api_config.dart` according to your environment:

```dart
// Android emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// iOS simulator
static const String baseUrl = 'http://localhost:8000';

// Real device (same WiFi network as your machine)
static const String baseUrl = 'http://192.168.1.XXX:8000';

// Production
static const String baseUrl = 'https://your-api.railway.app';
```

The JWT is stored securely via `flutter_secure_storage` (Keychain on iOS, Keystore on Android). Auto-login is handled at app startup.

---

## Deployment

### Backend (Render)

The backend is deployed on **[Render](https://render.com)** — see [`render.yaml`](render.yaml)
(Infrastructure as Code). It provisions the FastAPI web service **and** a managed
PostgreSQL database in one blueprint.

Live API: `https://pgc-app.onrender.com`

```bash
# 1. Push the repo to GitHub
# 2. Render Dashboard → New → Blueprint → select the repo (it reads render.yaml)
# 3. Render auto-creates the `pgc-api` web service + `pgc-db` Postgres
# 4. Set the remaining env vars (Render → Environment):
#    STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, SMTP_*, FIREBASE_CREDENTIALS_JSON, CRON_SECRET
```

Start command (already in `render.yaml`):
```
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

> ⚠️ On the free tier the service sleeps after inactivity (first request takes
> ~30–60s to wake up). For the 24h reminder cron, add a **Render Cron Job** (or any
> external cron) hitting `POST /tasks/send-reminders` hourly — see
> [`NOTIFICATIONS_SETUP.md`](NOTIFICATIONS_SETUP.md).

### App Store & Play Store

**Common requirements:**
- App icon: 1024×1024px (create it on Canva)
- Screenshots for each screen size
- App description in English (and your target language)

**Google Play Store:**
1. Google Play developer account — €25 one-time fee
2. Build a signed bundle: `flutter build appbundle --release`
3. Submit via the [Google Play Console](https://play.google.com/console)
4. Review time: ~24h

**Apple App Store:**
1. Apple Developer account — €99/year
2. Requires a Mac to build the IPA: `flutter build ios --release`
3. Submit via [App Store Connect](https://appstoreconnect.apple.com)
4. Review time: 24–48h

---

## Roadmap

- [x] FastAPI backend — Auth, Members, Courses, Bookings
- [x] Stripe subscription management
- [x] Transactional emails
- [x] Automatic waitlist promotion
- [x] Flutter app — Login, Schedule, Booking, Profile
- [x] Admin dashboard (members, schedule, courses) — in-app
- [x] Coach profiles & belt ranks
- [x] Academy (training videos, admin-managed)
- [x] Web build (Flutter web)
- [x] Push notifications (FCM) — course changes + 24h reminder *(needs Firebase/APNs config)*
- [ ] Club access QR code
- [ ] Attendance statistics (admin)
- [ ] Member CSV export (admin)
- [ ] Multi-club support
- [ ] Course recurrence groups (`recurrence_group_id`) — referenced in code, not yet in the model

---

## Contributing

```bash
# Create a branch
git checkout -b feature/my-feature

# Commit
git commit -m "feat: describe the feature"

# Push
git push origin feature/my-feature
```

---

## License

MIT — free to use, modify and distribute.