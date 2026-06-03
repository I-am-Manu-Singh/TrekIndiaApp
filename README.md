# 🏔️ Trip India: Expedition HQ & Tactical Logistics

**Trip India** is a premium, high-performance logistics and mission-management platform designed for Himalayan expeditions. Engineered with a tactical "Command & Control" aesthetic, it bridges the gap between field explorers, ground battalion (staff), and HQ commanders (admins).

---

## 🛠️ High-Fidelity Tech-Stack
The application is built for absolute reliability in low-connectivity high-altitude environments:

- **Frontend Core:** [Flutter](https://flutter.dev) (Dart) - Optimized for high-fidelity cross-platform deployment.
- **Backend Hub:** [Supabase](https://supabase.com) - Utilizing PostgreSQL for mission-critical data, Row-Level Security (RLS) for data integrity, and Real-time sync for field communications.
- **Design System:** **GlassShimmer Framework** - A custom-built universal skeleton loading system for a premium, responsive user experience.
- **Strategic UI:** [Animate Do](https://pub.dev/packages/animate_do) & [Google Fonts](https://fonts.google.com/) - Featuring the "Outfit" typography for a modern, sharp interface.
- **Intelligence Layer:** Integrated **AI Guide** for automated trek assistance and mission briefing.

---

## 👤 Feature Matrix: The Three Terminals

### 1. 🥾 Explorer Terminal (User)
*The primary interface for field hikers, focused on mission discovery and achievement.*

- **Mission Discovery:** High-fidelity trek dossiers with day-wise itineraries, difficulty telemetry, and immersive visual previews.
- **AI Guide:** Real-time intelligent assistant for gear advice, safety protocols, and trek-specific information.
- **Tactical Gear Rental:** Integrated shop for booking mission-essential equipment (jackets, poles, shoes) with size-specific tracking.
- **Digital Credentials:** Auto-generated **Trip Certificates** and mission dossiers upon successful completion.
- **Squad Blogs & Community:** Social interaction hub for sharing field reports and viewing global leaderboard rankings.
- **Live Wallet:** Real-time visibility into mission credits, booking status, and tactical refund tracking.

### 2. 🛡️ HQ Command Hub (Admin)
*A centralized administrative fortress for fleet-wide logistics and financial oversight.*

- **Revenue Command:** Real-time financial dashboard with revenue forecasting, pending dues tracking, and operational expense logs.
- **Staff Operations:** Full lifecycle management of guides and trek leaders, including attendance sync, salary breakups, and task delegation.
- **Unified Support Hub:** Centralized intelligence for user enquiries and complaints, featuring priority levels and resolution history.
- **Inventory Logistics:** Live stock tracking for gear rentals and expedition slot management.
- **Broadcast Engine:** Global announcement system for sending urgent weather alerts or mission updates to the entire battalion.

### 3. 🗺️ Battalion Staff Terminal (Employee)
*Specialized deployment terminal for trek leaders and guides.*

- **Mission Feed:** Personalized view of assigned expeditions, participant counts, and deployment dates.
- **Attendance 2.0:** Integrated "One-Tap" reporting for presence, leaves, and off-duty status synced directly to HQ.
- **Task Management:** Real-time task board for checklists assigned by HQ commanders (e.g., "Check gear stocks", "Brief hikers").
- **Asset Wallet:** Specialized view for tracking salary distributions, field allowances, and deployment history.

---

## 🚀 Mission Deployment (Setup)

### Prerequisites
- Flutter SDK (v3.13+)
- Supabase Project (URL & Anon Key)
- Google Fonts & Cached Network Image dependencies

### Tactical Setup
1. **Clone the Sector Repository:**
   ```bash
   git clone https://github.com/I-am-Manu-Singh/TrekIndiaApp.git
   cd TrekBookingApp
   ```

2. **Establish Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Database Synchronization:**
   Apply the provided SQL migrations in the following order to establish the expedition schema:
   - `master_supabase_setup.sql` (Core Schema)
   - `modern_trip_inventory.sql` (Logistics)
   - `seed_universal_packages.sql` (Initial Data)

4. **Launch Application:**
   ```bash
   flutter run
   ```

---

## 🛡️ Security & Protocol
The platform utilizes **Row Level Security (RLS)** to enforce strict data silos:
- **Admin Tier:** Full global read/write access.
- **Employee Tier:** Access limited to assigned missions and personal financial telemetry.
- **User Tier:** Vision restricted to personal bookings, public expeditions, and authorized profile data.

---

## 📡 Version Logs & Tactical Updates
- **v1.5.0:** Migrated branding from "Trek" to **Trip/Expedition India**.
- **v1.5.2:** Implemented the **Universal GlassShimmer** architecture for loading states.
- **v1.5.5:** Deployed the **Finance Hub** for advanced administrative revenue tracking.
- **v1.5.8:** Added **AI Guide** and **Digital Certificate** generation systems.

**Trip India - Scaling the Himalayas with Technology.**
