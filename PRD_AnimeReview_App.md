# 📋 Product Requirements Document (PRD)
## AniTrack — Aplikasi Review & Komunitas Anime (Android & iOS)

**Versi:** 2.0  
**Tanggal:** Juni 2026  
**Status:** In Development  
**Platform:** Android (API 26+) & iOS (16.0+) — Flutter Cross-Platform  
**Tipe:** Aplikasi Mobile Realtime — Komunitas & Review Anime  

---

## 1. RINGKASAN EKSEKUTIF

### 1.1 Deskripsi Produk

AniTrack adalah aplikasi mobile cross-platform (Android & iOS) berbasis komunitas yang memungkinkan pengguna untuk menulis dan membaca review anime, berinteraksi melalui komentar dan live chat, serta berbagi status penyelesaian anime ke profil mereka secara realtime. Dibangun dengan Flutter untuk pengalaman konsisten di kedua platform. Aplikasi ini dirancang untuk menjadi pusat aktivitas penggemar anime di Indonesia dan global.

### 1.2 Tujuan Produk

- Menyediakan platform terpusat untuk review dan rating anime
- Membangun komunitas interaktif antar penggemar anime secara realtime
- Memungkinkan pengguna melacak dan membagikan progress menonton anime mereka
- Menghadirkan pengalaman sosial seperti feed aktivitas dan status update

### 1.3 Target Pengguna

| Segmen | Deskripsi |
|--------|-----------|
| **Primary** | Penggemar anime usia 15–30 tahun, aktif di media sosial |
| **Secondary** | Reviewer konten dan kreator komunitas anime |
| **Tertiary** | Pengguna kasual yang ingin rekomendasi anime |

---

## 2. FITUR UTAMA (FEATURE SET)

### 2.1 Peta Fitur Tingkat Tinggi

```
AniTrack
├── Autentikasi & Profil
│   ├── Register / Login (Email, Google)
│   ├── Profil Publik User
│   └── Status Update (Selesai Nonton)
├── Katalog Anime
│   ├── Browse & Search Anime
│   ├── Detail Halaman Anime
│   └── Rating & Review
├── Interaksi Komunitas
│   ├── Komentar di Halaman Anime (Realtime)
│   ├── Live Chat Ruangan per Anime
│   └── Like & Reply Komentar
├── Feed Aktivitas
│   ├── Feed Global (Semua User)
│   └── Feed Teman (Following)
└── Notifikasi Realtime
    ├── Notifikasi Komentar
    ├── Notifikasi Like
    └── Notifikasi Status Teman
```

---

## 3. SPESIFIKASI FITUR DETAIL

### 3.1 MODUL AUTENTIKASI & PROFIL

#### 3.1.1 Registrasi & Login

**User Stories:**
- Sebagai pengguna baru, saya ingin mendaftar menggunakan email & password agar bisa mengakses semua fitur
- Sebagai pengguna, saya ingin login dengan akun Google agar proses masuk lebih cepat
- Sebagai pengguna, saya ingin reset password jika lupa agar bisa mengakses kembali akun saya

**Acceptance Criteria:**
- Form registrasi: username (unik), email, password (min 8 karakter)
- Validasi email real-time (format + ketersediaan username)
- Login dengan Google OAuth 2.0
- Sesi login persisten (auto-login saat buka app)
- Token autentikasi disimpan secara aman menggunakan Firebase Auth

**Spesifikasi Teknis:**
- Firebase Authentication (Email/Password + Google Sign-In)
- Token JWT disimpan di Android Keystore
- Auto-refresh token sebelum expired

---

#### 3.1.2 Profil Pengguna

**User Stories:**
- Sebagai pengguna, saya ingin mengedit foto profil, bio, dan username agar orang lain mengenal saya
- Sebagai pengguna, saya ingin melihat profil orang lain beserta riwayat anime yang sudah mereka tonton
- Sebagai pengguna, saya ingin meng-follow pengguna lain agar aktivitas mereka muncul di feed saya

**Data Profil:**
```
Profil User
├── Avatar (foto profil)
├── Username (unik, max 20 karakter)
├── Display Name
├── Bio (max 150 karakter)
├── Tanggal Bergabung
├── Jumlah Anime Selesai
├── Jumlah Following / Follower
├── Daftar Anime Selesai (publik)
├── Review yang Ditulis
└── Aktivitas Terbaru (Status Updates)
```

**Acceptance Criteria:**
- Upload foto profil dari kamera atau galeri (maks 5MB, format JPG/PNG)
- Halaman profil dapat dilihat publik tanpa login
- Tombol Follow/Unfollow tersedia di halaman profil orang lain
- Jumlah follower/following diperbarui realtime

---

#### 3.1.3 Status Update — "Saya Baru Selesai Nonton"

> Fitur inti: Pengguna dapat memposting status bahwa mereka baru menyelesaikan sebuah anime.

**User Stories:**
- Sebagai pengguna, saya ingin memposting status selesai menonton anime agar teman-teman saya tahu
- Sebagai pengguna, saya ingin menambahkan rating dan komentar singkat pada status saya
- Sebagai pengguna, saya ingin melihat status teman-teman saya di feed

**Format Status Update:**
```
┌─────────────────────────────────────────┐
│ 🎌 [Username] baru selesai menonton!    │
│                                         │
│  [Cover Anime]  Attack on Titan S4      │
│                 ⭐ 9.5 / 10              │
│                                         │
│ "Ending yang luar biasa! Rekomendasi    │
│  banget buat yang belum nonton."        │
│                                         │
│ 💬 12 komentar  ❤️ 45 suka  • 2 jam lalu│
└─────────────────────────────────────────┘
```

**Acceptance Criteria:**
- Pilih anime dari database (search by title)
- Wajib pilih status: "Selesai Ditonton" / "Sedang Ditonton" / "Ingin Ditonton"
- Rating opsional (bintang 1–10)
- Caption opsional (max 280 karakter)
- Status tampil di feed global dan feed follower secara realtime (< 3 detik)
- Status dapat dihapus oleh pemilik
- Notifikasi dikirim ke follower saat status diposting

**Spesifikasi Teknis:**
- Data status disimpan di Firestore collection `status_updates`
- Real-time listener menggunakan Firestore `addSnapshotListener`
- Push notification via Firebase Cloud Messaging (FCM)

---

### 3.2 MODUL KATALOG ANIME

#### 3.2.1 Halaman Utama & Pencarian

**User Stories:**
- Sebagai pengguna, saya ingin melihat daftar anime populer di halaman utama
- Sebagai pengguna, saya ingin mencari anime berdasarkan judul, genre, atau tahun rilis
- Sebagai pengguna, saya ingin memfilter anime berdasarkan status (airing, completed, upcoming)

**Kategori di Halaman Utama:**
- Trending Minggu Ini
- Anime Season Ini (Airing)
- Top Rated All Time
- Baru Ditambahkan
- Rekomendasi untuk Anda

**Sumber Data Anime:**
- Jikan API (MyAnimeList tidak resmi) — gratis, tidak butuh API key
- Endpoint utama: `https://api.jikan.moe/v4/`
- Cache data di Firestore untuk mengurangi request ke API eksternal

**Acceptance Criteria:**
- Lazy loading gambar cover anime (Glide/Coil library)
- Pencarian dengan debounce 300ms (tidak flood request)
- Filter: Genre, Type (TV/Movie/OVA), Status, Rating minimum
- Hasil pencarian muncul dalam < 1 detik (dari cache lokal)

---

#### 3.2.2 Halaman Detail Anime

**Konten Halaman Detail:**
```
Halaman Detail Anime
├── Cover & Info Dasar
│   ├── Judul (JP & EN)
│   ├── Studio, Tahun, Episode
│   ├── Status (Airing/Completed)
│   └── Genre Tags
├── Rating & Skor
│   ├── Skor MAL (dari Jikan)
│   ├── Rating Rata-rata User AniTrack
│   └── Jumlah Review
├── Sinopsis
├── Tombol Aksi User
│   ├── [Tambah ke Daftar ▾] (Selesai/Sedang/Ingin)
│   ├── [Tulis Review]
│   └── [Buka Live Chat]
├── Tab Review Pengguna
│   └── (Realtime — lihat bagian 3.3)
└── Tab Live Chat
    └── (Realtime — lihat bagian 3.4)
```

---

#### 3.2.3 Sistem Review & Rating

**User Stories:**
- Sebagai pengguna, saya ingin menulis review lengkap untuk anime yang sudah saya tonton
- Sebagai pengguna, saya ingin memberi rating dari 1–10 dengan kategori berbeda
- Sebagai pengguna lain, saya ingin melihat review orang lain dan menilai apakah review itu membantu

**Format Review:**
```
Sistem Rating (Breakdown):
├── Story (Cerita)          : ⭐ 1–10
├── Animation (Animasi)     : ⭐ 1–10
├── Sound (OST & Voice)     : ⭐ 1–10
├── Character (Karakter)    : ⭐ 1–10
└── Enjoyment (Kesenangan)  : ⭐ 1–10
    → Skor Total: Rata-rata otomatis

Konten Review:
├── Judul Review (max 100 karakter)
├── Isi Review (min 100, max 3000 karakter)
├── Rekomendasi: Ya / Tidak
└── Spoiler Toggle (blur otomatis jika aktif)
```

**Acceptance Criteria:**
- Satu user hanya boleh 1 review per anime (bisa diedit)
- Review bisa di-like oleh user lain
- Review bisa dilaporkan (report spam/inappropriate)
- Spoiler tag: konten ter-blur, klik untuk membuka
- Sorting review: Terbaru, Terpopuler, Skor Tertinggi
- Review tampil di halaman detail anime realtime setelah disubmit

---

### 3.3 MODUL KOMENTAR REALTIME

**User Stories:**
- Sebagai pengguna, saya ingin meninggalkan komentar di halaman anime
- Sebagai pengguna, saya ingin membalas komentar orang lain (reply/thread)
- Sebagai pengguna, saya ingin melihat komentar baru muncul otomatis tanpa refresh

**Struktur Komentar:**
```
Komentar
├── User Avatar + Username
├── Waktu Posting (relative: "5 menit lalu")
├── Isi Komentar (max 500 karakter)
├── Tombol Like ❤️
├── Tombol Reply 💬
└── Replies (Thread)
    ├── Reply 1
    ├── Reply 2
    └── ... (maks tampil 3, "Lihat semua N balasan")
```

**Fitur Komentar:**
- Komentar baru muncul realtime tanpa refresh halaman (Firestore listener)
- Indikator "N orang sedang melihat" di halaman anime
- Mention pengguna dengan `@username` (autocomplete)
- Emoji picker terintegrasi
- Edit komentar dalam 5 menit setelah posting
- Hapus komentar milik sendiri kapan saja

**Acceptance Criteria:**
- Komentar baru tampil untuk semua pengguna aktif di halaman yang sama dalam < 2 detik
- Pagination: load 20 komentar pertama, scroll ke bawah load 20 berikutnya
- Animasi smooth saat komentar baru masuk (slide-in dari bawah)
- Notifikasi push dikirim ke pemilik komentar jika ada yang reply

**Spesifikasi Teknis:**
```
Firestore Structure:
animes/{animeId}/comments/{commentId}
  ├── userId: string
  ├── username: string
  ├── avatarUrl: string
  ├── content: string
  ├── likeCount: number
  ├── replyCount: number
  ├── createdAt: timestamp
  ├── editedAt: timestamp | null
  └── isDeleted: boolean

animes/{animeId}/comments/{commentId}/replies/{replyId}
  └── (struktur sama dengan komentar)
```

---

### 3.4 MODUL LIVE CHAT REALTIME

> Live Chat adalah ruang diskusi realtime yang terpisah dari komentar review. Didesain seperti chatroom.

**User Stories:**
- Sebagai pengguna, saya ingin bergabung ke room chat untuk mendiskusikan anime secara real-time
- Sebagai pengguna, saya ingin mengirim pesan teks, emoji, dan gambar di chat
- Sebagai pengguna, saya ingin melihat siapa saja yang sedang online di room

**Fitur Live Chat:**

| Fitur | Deskripsi |
|-------|-----------|
| Room per Anime | Setiap anime punya 1 room chat publik |
| Indikator Online | Daftar pengguna aktif di room |
| Pesan Teks | Max 300 karakter per pesan |
| Emoji Reaction | React ke pesan dengan emoji |
| Gambar | Kirim gambar (maks 3MB) |
| Typing Indicator | "username sedang mengetik..." |
| Read Receipt | Tanda pesan telah dibaca |
| Message History | Load 50 pesan terakhir saat masuk |
| Profil Quick View | Tap username → lihat profil singkat |

**UX Chat:**
- Layout seperti WhatsApp: pesan sendiri di kanan (bubble hijau/biru), pesan orang di kiri (bubble abu)
- Timestamp per pesan
- Grouping pesan berturut dari user yang sama (tidak ulang avatar)
- Auto-scroll ke pesan terbaru saat masuk room
- Pull-to-load pesan lebih lama

**Acceptance Criteria:**
- Pesan terkirim dan diterima semua member dalam < 1 detik
- Typing indicator muncul maksimal 3 detik setelah berhenti mengetik
- Riwayat chat tersimpan permanen (tidak dihapus otomatis)
- Moderasi: report pesan, hide pesan yang dilaporkan 5+ kali

**Spesifikasi Teknis:**
```
Firestore Structure:
chat_rooms/{animeId}/messages/{messageId}
  ├── userId: string
  ├── username: string
  ├── avatarUrl: string
  ├── content: string
  ├── type: "text" | "image"
  ├── imageUrl: string | null
  ├── reactions: { emoji: [userId] }
  ├── reportCount: number
  ├── isHidden: boolean
  └── createdAt: timestamp

Presence System:
user_presence/{animeId}/{userId}
  ├── isOnline: boolean
  ├── lastSeen: timestamp
  └── username: string
```

---

### 3.5 MODUL FEED AKTIVITAS

**Tipe Feed:**

1. **Feed Global** — Aktivitas semua pengguna AniTrack
2. **Feed Teman** — Hanya aktivitas pengguna yang di-follow

**Tipe Event di Feed:**
```
Event Jenis:
├── 🎌 [User] selesai menonton [Anime]
├── ✍️  [User] menulis review untuk [Anime]
├── ⭐ [User] memberi rating [X/10] untuk [Anime]
├── 📌 [User] menambahkan [Anime] ke daftar tontonan
└── ❤️  [User] menyukai review [User lain] untuk [Anime]
```

**Acceptance Criteria:**
- Feed diperbarui realtime (Firestore listener)
- Pagination infinite scroll (20 item per halaman)
- User bisa like/komentar langsung dari feed
- Klik pada item feed → navigasi ke halaman anime terkait
- Bisa filter feed berdasarkan tipe event

---

## 4. ARSITEKTUR TEKNIS

### 4.1 Stack Teknologi

| Layer | Teknologi |
|-------|-----------|
| **Bahasa** | Dart |
| **UI Framework** | Flutter |
| **Arsitektur** | Feature-first Clean Architecture |
| **Realtime Database** | Firebase Firestore |
| **Autentikasi** | Firebase Authentication |
| **Storage** | Firebase Storage (gambar) |
| **Push Notification** | Firebase Cloud Messaging (FCM) |
| **API Anime** | Jikan API v4 (MAL wrapper) |
| **Image Loading** | cached_network_image |
| **HTTP Client** | dio |
| **Dependency Injection** | get_it / riverpod |
| **Navigation** | go_router |
| **Local Cache** | hive / shared_preferences |
| **State Management** | Riverpod |

---

### 4.2 Arsitektur Aplikasi (Feature-first Clean Architecture)

```
lib/
├── core/
│   ├── constants/
│   ├── network/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/ (repositories, models, datasources)
│   │   ├── domain/ (entities, usecases, repositories interface)
│   │   └── presentation/ (screens, widgets, providers)
│   ├── anime/
│   ├── social/
│   └── profile/
└── main.dart
```

---

### 4.3 Struktur Firestore Database

```
Firestore Root
│
├── users/{userId}
│   ├── username, displayName, bio, avatarUrl
│   ├── followersCount, followingCount
│   ├── animeCompleted: [animeId]
│   ├── animeWatching: [animeId]
│   ├── animeWatchlist: [animeId]
│   └── createdAt
│
├── user_follows/{userId}/following/{targetUserId}
│   └── followedAt: timestamp
│
├── animes/{animeId}             ← cached dari Jikan API
│   ├── title, synopsis, coverUrl
│   ├── episodes, status, genres
│   ├── malScore, trackRating (rata-rata app)
│   ├── reviewCount, commentCount
│   └── updatedAt
│
├── animes/{animeId}/reviews/{reviewId}
│   ├── userId, username, avatarUrl
│   ├── ratings: {story, animation, sound, character, enjoyment}
│   ├── overallScore, title, content
│   ├── isRecommended, hasSpoiler
│   ├── likeCount, createdAt, editedAt
│   └── isDeleted
│
├── animes/{animeId}/comments/{commentId}
│   └── (lihat bagian 3.3)
│
├── animes/{animeId}/comments/{commentId}/replies/{replyId}
│   └── (lihat bagian 3.3)
│
├── chat_rooms/{animeId}/messages/{messageId}
│   └── (lihat bagian 3.4)
│
├── status_updates/{statusId}
│   ├── userId, username, avatarUrl
│   ├── animeId, animeTitle, animeCoverUrl
│   ├── watchStatus: "completed"|"watching"|"planned"
│   ├── rating: number | null
│   ├── caption: string
│   ├── likeCount, commentCount
│   └── createdAt
│
├── activity_feed/{eventId}
│   ├── type: "completed"|"reviewed"|"rated"|"added"|"liked"
│   ├── userId, username, avatarUrl
│   ├── animeId, animeTitle
│   ├── metadata: {}
│   └── createdAt
│
└── notifications/{userId}/items/{notifId}
    ├── type: "comment"|"reply"|"like"|"follow"|"status"
    ├── fromUserId, fromUsername, fromAvatar
    ├── targetId (animeId/statusId/commentId)
    ├── message: string
    ├── isRead: boolean
    └── createdAt
```

---

### 4.4 Keamanan (Firestore Security Rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // User hanya bisa edit profil sendiri
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }

    // Review: siapa pun bisa baca, hanya pemilik yang bisa edit/hapus
    match /animes/{animeId}/reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }

    // Komentar: user login bisa buat, hanya pemilik yang hapus
    match /animes/{animeId}/comments/{commentId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.userId;
      allow delete: if request.auth.uid == resource.data.userId;
    }

    // Chat: hanya user login yang bisa baca & tulis
    match /chat_rooms/{animeId}/messages/{messageId} {
      allow read, create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }

    // Status Update: publik baca, pemilik hapus
    match /status_updates/{statusId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow delete: if request.auth.uid == resource.data.userId;
    }

    // Notifikasi: hanya pemilik
    match /notifications/{userId}/items/{notifId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## 5. USER FLOW & NAVIGASI

### 5.1 Struktur Navigasi App

```
Bottom Navigation Bar
├── 🏠 Home (Feed & Trending)
├── 🔍 Explore (Search & Browse Anime)
├── ➕ Post Status (Quick Action)
├── 🔔 Notifikasi
└── 👤 Profil Saya
```

### 5.2 User Flow: Post Status Selesai Nonton

```
[Tap ➕] 
    → Pilih Anime (Search / Recently Watched)
    → Pilih Status: ✅ Selesai Ditonton
    → (Opsional) Beri Rating 1–10
    → (Opsional) Tulis Caption
    → [Posting]
    → Muncul di Feed Global & Feed Follower (< 3 detik)
    → Push Notif ke Follower
```

### 5.3 User Flow: Komentar Realtime

```
[Buka Halaman Anime]
    → Tab "Komentar" aktif
    → Firestore listener aktif (komentar baru auto-muncul)
    → [Tap Area Tulis Komentar]
    → Ketik komentar
    → [Kirim]
    → Komentar muncul di semua device yang membuka halaman yang sama
```

### 5.4 User Flow: Live Chat

```
[Buka Halaman Anime]
    → Tap tombol [💬 Live Chat]
    → Masuk ke Room Chat Anime
    → Presence system: nama user muncul di daftar online
    → Load 50 pesan terakhir
    → Ketik & kirim pesan (tampil realtime ke semua member)
    → Typing indicator aktif saat mengetik
    → [Keluar Room] → Presence diperbarui
```

---

## 6. DESAIN UI/UX

### 6.1 Design System

| Elemen | Nilai |
|--------|-------|
| **Primary Color** | `#6C63FF` (Indigo Vibrant) |
| **Secondary Color** | `#FF6B6B` (Coral Red) |
| **Background** | `#0D0D1A` (Dark Navy) |
| **Surface** | `#1A1A2E` (Card Dark) |
| **Text Primary** | `#FFFFFF` |
| **Text Secondary** | `#9E9EBF` |
| **Success** | `#4CAF50` |
| **Warning** | `#FFC107` |
| **Font** | Nunito Sans (Google Fonts) |
| **Border Radius** | 12dp (card), 24dp (button) |

### 6.2 Tema

- **Default:** Dark Mode (sesuai estetika anime community)
- **Opsional:** Light Mode (toggle di settings)
- Material Design 3 (Material You) components

### 6.3 Screen List

| Screen | Deskripsi |
|--------|-----------|
| Splash Screen | Animasi logo AniTrack |
| Onboarding | 3 slide pengenalan fitur (first launch) |
| Login / Register | Form autentikasi |
| Home Feed | Feed aktivitas + Trending anime |
| Explore | Search + Browse + Filter anime |
| Anime Detail | Info + Review + Komentar + Live Chat |
| Write Review | Form rating breakdown + teks review |
| Post Status | Form post "selesai nonton" |
| Live Chat Room | Room chat realtime |
| Profil | Profil user + daftar aktivitas |
| Edit Profil | Form edit bio, foto, username |
| Notifikasi | List notifikasi dengan tanda baca/belum |
| Settings | Tema, notifikasi, privasi, logout |

---

## 7. NOTIFIKASI

### 7.1 Jenis Notifikasi Push (FCM)

| Trigger | Pesan Notifikasi | Target |
|---------|-----------------|--------|
| Ada yang reply komentar saya | "@user membalas komentar Anda di [Anime]" | Pemilik komentar |
| Ada yang like review saya | "@user menyukai review Anda untuk [Anime]" | Pemilik review |
| User yang saya follow posting status | "@user baru selesai menonton [Anime]!" | Semua follower |
| Ada yang follow saya | "@user mulai mengikuti Anda" | User yang di-follow |
| Ada komentar baru di anime yang saya tonton | "Diskusi baru di [Anime]" | Opt-in per anime |

### 7.2 Pengaturan Notifikasi

User dapat mengaktifkan/menonaktifkan:
- Notifikasi reply komentar
- Notifikasi like
- Notifikasi follow baru
- Notifikasi status dari following
- Notifikasi in-app vs push

---

## 8. PERFORMA & KUALITAS

### 8.1 Target Performa

| Metrik | Target |
|--------|--------|
| App startup (cold) | < 3 detik |
| Halaman anime load | < 2 detik |
| Pesan chat terkirim | < 1 detik |
| Komentar baru muncul | < 2 detik |
| Status update di feed | < 3 detik |
| Image load (cover anime) | < 1.5 detik |
| APK Size | < 25 MB |

### 8.2 Strategi Cache

- Cover anime di-cache lokal (Coil disk cache, max 100MB)
- Data anime populer di-cache di Room DB (refresh setiap 24 jam)
- Feed di-cache offline (20 item terakhir)
- Komentar: hanya realtime, tidak di-cache offline

### 8.3 Penanganan Offline

| Skenario | Perilaku |
|----------|----------|
| Buka app tanpa internet | Tampilkan data cache, banner "Mode Offline" |
| Kirim komentar offline | Antri lokal, kirim otomatis saat online |
| Buka halaman anime offline | Load data cache, disable fitur interaktif |
| Kirim chat offline | Tampilkan error, minta coba lagi |

---

## 9. MODERATION & KEAMANAN KONTEN

### 9.1 Mekanisme Moderasi

- **Report System:** User bisa melaporkan komentar, review, atau status yang tidak pantas
- **Auto-hide:** Konten dengan 5+ laporan otomatis disembunyikan pending review
- **Admin Panel:** Dashboard web untuk moderator meninjau laporan
- **Spam Filter:** Rate limiting — max 10 komentar/menit per user
- **Kata Terlarang:** Filter kata kasar bahasa Indonesia dan Inggris

### 9.2 Privasi Data

- Data profil publik (username, bio, daftar anime) dapat dilihat siapa saja
- Opsi akun privat: aktivitas hanya terlihat oleh follower yang disetujui
- Hapus akun: data pengguna dihapus dari Firestore dalam 30 hari
- Tidak ada penjualan data ke pihak ketiga
- Kepatuhan terhadap Peraturan Perlindungan Data Pribadi Indonesia (UU PDP)

---

## 10. ROADMAP PENGEMBANGAN

### Phase 1 — MVP (Bulan 1–2)
- [ ] Setup project Kotlin + Jetpack Compose
- [ ] Firebase integration (Auth, Firestore, Storage, FCM)
- [ ] Autentikasi (Email + Google Sign-In)
- [ ] Integrasi Jikan API (daftar anime, detail, search)
- [ ] Profil pengguna dasar
- [ ] Sistem Review & Rating
- [ ] Komentar Realtime (tanpa reply)

### Phase 2 — Core Social (Bulan 3–4)
- [ ] Live Chat Room per Anime
- [ ] Status Update "Selesai Nonton"
- [ ] Feed Aktivitas Global & Teman
- [ ] Sistem Follow/Following
- [ ] Push Notification (FCM)
- [ ] Reply & Thread Komentar

### Phase 3 — Polish & Growth (Bulan 5–6)
- [ ] Dark/Light Mode toggle
- [ ] Indikator Online & Typing Chat
- [ ] Mention (@username) di komentar/chat
- [ ] Notifikasi in-app
- [ ] Sistem Laporan & Moderasi
- [ ] Halaman Pencarian Lanjutan (filter genre)
- [ ] Optimasi performa & offline support

### Phase 4 — Future Features (Bulan 7+)
- [ ] List Anime Kolaborasi (antar user)
- [ ] Spoiler Tag di review
- [ ] Anime Season Calendar
- [ ] Leaderboard reviewer terpopuler
- [ ] Widget Android (status teman terbaru)
- [ ] Versi Tablet

---

## 11. DEPENDENCY & LIBRARY (build.gradle)

```kotlin
// build.gradle.kts (Module: app)

dependencies {
    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.05.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.2.0")

    // Hilt (DI)
    implementation("com.google.dagger:hilt-android:2.51")
    kapt("com.google.dagger:hilt-compiler:2.51")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Image Loading
    implementation("io.coil-kt.coil3:coil-compose:3.0.0")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.0.0")

    // Local Cache
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    // ViewModel + Lifecycle
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")

    // DataStore (Preferences)
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Paging 3
    implementation("androidx.paging:paging-compose:3.3.0")

    // Lottie Animation
    implementation("com.airbnb.android:lottie-compose:6.4.0")

    // Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
}
```

---

## 12. PROMPT PENGEMBANGAN (untuk Developer / AI Coding Assistant)

Gunakan prompt berikut saat bekerja dengan AI Coding Assistant (Cursor, GitHub Copilot, dsb.):

---

### PROMPT MASTER — Setup Proyek AniTrack

```
Saya sedang membangun aplikasi Android bernama "AniTrack" menggunakan:
- Kotlin + Jetpack Compose
- MVVM + Clean Architecture
- Firebase Firestore (realtime database)
- Firebase Auth (email + Google)
- Firebase Storage + FCM
- Hilt untuk dependency injection
- Retrofit untuk Jikan API
- Coil untuk image loading
- Room untuk local cache

Fitur utama:
1. Review & Rating anime (dengan rating breakdown: Story, Animation, Sound, Character, Enjoyment)
2. Komentar realtime dengan thread/reply menggunakan Firestore addSnapshotListener
3. Live Chat room per anime dengan typing indicator dan online presence
4. Status Update "Selesai Menonton" yang muncul di feed realtime
5. Follow/Follower system dengan activity feed

Struktur package:
com.anitrack
├── core/         (utils, extensions, constants)
├── data/         (repositories, datasources, models)
│   ├── local/    (Room DB)
│   └── remote/   (Firestore, Retrofit, Firebase)
├── domain/       (use cases, domain models, interfaces)
└── presentation/ (screens, viewmodels, UI state)
    ├── home/
    ├── anime/
    ├── chat/
    ├── profile/
    └── notification/

Tolong [TASK SPESIFIK DI SINI] mengikuti arsitektur dan teknologi di atas.
```

---

### PROMPT KOMENTAR REALTIME

```
Buatkan implementasi komentar realtime untuk aplikasi AniTrack Android (Kotlin + Compose).

Requirements:
- Gunakan Firebase Firestore collection: animes/{animeId}/comments/{commentId}
- Field komentar: userId, username, avatarUrl, content, likeCount, replyCount, createdAt, isDeleted
- Gunakan addSnapshotListener untuk subscribe perubahan realtime
- UI: LazyColumn dengan item animasi slide-in saat komentar baru masuk
- Komponen input di bagian bawah dengan tombol send
- Handle loading state, error state, dan empty state
- Pagination: load 20 komentar pertama, scroll ke atas load lebih banyak
- ViewModel menggunakan StateFlow
- Repository pattern dengan interface di domain layer

Ikuti Clean Architecture: Screen → ViewModel → UseCase → Repository → Firestore DataSource
```

---

### PROMPT LIVE CHAT

```
Buatkan Live Chat Room untuk AniTrack Android (Kotlin + Compose + Firebase Firestore).

Requirements:
- Collection: chat_rooms/{animeId}/messages/{messageId}
- Presence system: user_presence/{animeId}/{userId} (isOnline, lastSeen, username)
- Typing indicator: update field isTyping di presence document
- Message types: "text" dan "image"
- UI layout: bubble chat (pesan sendiri kanan, orang lain kiri)
- Auto-scroll ke pesan terbaru
- Load 50 pesan terakhir saat masuk room
- Pull-to-load pesan lebih lama (orderBy createdAt descending, limit 50)
- Emoji reaction: Map<String, List<String>> (emoji → [userId])
- Saat user keluar room/destroy composable: update isOnline = false

Sertakan: ChatViewModel, ChatRepository, ChatScreen Composable, MessageBubble Component
```

---

### PROMPT STATUS UPDATE

```
Buatkan fitur "Post Status Selesai Nonton" untuk AniTrack Android (Kotlin + Compose + Firestore).

Requirements:
- Collection: status_updates/{statusId} (global)
- Field: userId, username, avatarUrl, animeId, animeTitle, animeCoverUrl,
         watchStatus (completed/watching/planned), rating (nullable), caption, 
         likeCount, commentCount, createdAt
- Screen PostStatusScreen:
  1. Search anime (Retrofit → Jikan API /anime?q=)
  2. Pilih watch status dari dropdown
  3. Rating slider (1–10, optional)
  4. Caption text field (max 280 char, counter)
  5. Tombol Post
- Setelah post: tulis ke Firestore status_updates + tambah ke activity_feed
- Kirim FCM notification ke semua follower via Firebase Cloud Functions
- Tampilkan di Home Feed menggunakan Firestore Query orderBy(createdAt, DESC) limit(20)

Sertakan: PostStatusViewModel, StatusRepository, PostStatusScreen, FeedItem Composable
```

---

### PROMPT PROFIL & FOLLOWING

```
Buatkan sistem Profil dan Follow/Following untuk AniTrack Android (Kotlin + Compose + Firestore).

Requirements:
- users/{userId}: username, displayName, bio, avatarUrl, followersCount, followingCount,
                  animeCompleted[], animeWatching[], animeWatchlist[], createdAt
- user_follows/{userId}/following/{targetUserId}: followedAt
- Untuk follow: gunakan Firestore batch write (update followersCount target, tambah doc di subcollection)
- ProfileScreen: tampilkan avatar, bio, stat (anime selesai, following, follower), 
                 TabRow (Status Updates | Reviews | Lists)
- Tombol Follow/Unfollow di profil orang lain
- Avatar upload: ambil dari kamera/galeri → compress → upload ke Firebase Storage → update Firestore
- Edit profil: username (validasi unik), displayName, bio

Sertakan: ProfileViewModel, ProfileRepository, ProfileScreen, EditProfileScreen
```

---

## 13. ESTIMASI EFFORT (Story Points)

| Fitur | Estimasi | Prioritas |
|-------|----------|-----------|
| Setup Proyek + Firebase | 3 SP | P0 |
| Autentikasi (Email + Google) | 5 SP | P0 |
| Katalog Anime (Jikan API) | 5 SP | P0 |
| Halaman Detail Anime | 4 SP | P0 |
| Review & Rating | 8 SP | P0 |
| Komentar Realtime | 8 SP | P0 |
| Live Chat Room | 10 SP | P1 |
| Status Update | 6 SP | P1 |
| Feed Aktivitas | 7 SP | P1 |
| Follow/Following | 5 SP | P1 |
| Push Notification (FCM) | 6 SP | P1 |
| Profil & Edit Profil | 5 SP | P1 |
| Sistem Laporan & Moderasi | 6 SP | P2 |
| Offline Support | 4 SP | P2 |
| Dark/Light Mode | 2 SP | P2 |
| **Total** | **84 SP** | |

*Estimasi: 1 developer → ~4–5 bulan. 2 developer → ~2.5–3 bulan.*

---

## 14. TESTING PLAN

### Unit Tests
- ViewModel logic (StateFlow, use cases)
- Repository functions (mock Firestore)
- Utility functions (date formatting, validation)

### Integration Tests
- Firebase Auth flow
- Firestore read/write operations
- Retrofit API calls (Jikan)

### UI Tests (Espresso / Compose Testing)
- Login flow end-to-end
- Post status dan verifikasi muncul di feed
- Kirim komentar dan verifikasi muncul realtime
- Navigasi antar screen

### Performance Tests
- Scroll performa pada LazyColumn 100+ item
- Memory leak check dengan LeakCanary
- Network request profiling dengan OkHttp EventListener

---

*Dokumen ini adalah PRD hidup — akan diperbarui seiring perkembangan proyek.*

---
**Dibuat untuk:** AniTrack Android App  
**Versi PRD:** 1.0  
**Terakhir Diperbarui:** Juni 2026
