# 🏔️ Trek India: Battalion Booking & Logistics Terminal

**Trek India** is a high-performance, logistics-driven Flutter application designed to revolutionize the Himalayan trekking experience. Built with a tactical "Command & Control" design aesthetic, it provides a seamless interface for trekkers, a robust management panel for admins, and specialized terminals for field employees.

---

## 🛠️ Tactical Tech-Stack
The application is engineered for absolute reliability and real-time field intelligence:

- **Frontend Core:** [Flutter](https://flutter.dev) (Dart) - For high-fidelity cross-platform deployment.
- **Backend Hub:** [Supabase](https://supabase.com) - Leveraging PostgreSQL for mission-critical data, Row-Level Security (RLS) for battalion-grade protection, and Real-time syncing.
- **Strategic UI:** [Animate Do](https://pub.dev/packages/animate_do) & [Cached Network Image](https://pub.dev/packages/cached_network_image) - For a premium, fluid, and optimized tactical interface.
- **Field Reporting:** [PDF](https://pub.dev/packages/pdf) & [Printing](https://pub.dev/packages/printing) - Generating on-the-go itineraries and field dossiers.

---

## 👤 User-Tier Feature Matrix

### 1. 🥾 Trekker Terminal (User)
*The primary interface for the field hiker, focused on mission discovery and identity.*

- **Mission Intelligence:** Browse extensive Himalayan trek dossiers with layered itineraries, inclusions, and difficulty ratings.
- **Gear Armory:** Integrated rental system allowing trekkers to book poles, jackets, and safety gear alongside their mission.
- **Tactical Dossier (Profile):** Secure document upload for Passport, Aadhar, and Medical Certificates for HQ mission clearance.
- **Squad Community:** Live blog updates, global leaderboard ranking, and an XP-based progress system.
- **The Wallet:** Real-time visibility into mission credits, booking history, and tactical refunds.

### 2. 🛡️ HQ Command Hub (Admin)
*A centralized administrative fortress for battalion-wide management.*

- **Inventory Command:** Real-time management of Trek nodes and Gear rental stocks.
- **Personnel Registry:** Comprehensive staff tracking including base compensation, attendance metrics, and task delegation.
- **Support Hub:** Unified intelligence center for Enquiries and Complaints, featuring automated AI-context and resolution tracking.
- **Squad Intelligence:** Battalion-level overview of trek groups, participant payment statuses, and staff deployment.
- **Financial Analytics:** Live reporting on estimated revenue, dues pending, and operational payout logs.

### 3. 🗺️ Battalion Staff Terminal (Employee)
*Specialized deployment terminal for trek leaders, guides, and ground staff.*

- **Strategic Feed:** Personalized view of assigned treks, participant counts, and mission dates.
- **Attendance Logistics:** Integrated reporting for "Present", "Leave", and "Off-Duty" status sync with HQ.
- **Task Deployment:** Direct mission checklists and tasks assigned by HQ Commanders.
- **Asset Wallet:** Specialized view of salary breakups, tactical allowances, and payout history.

---

## 🚀 Mission Deployment (Getting Started)

### Battalion Prerequisites
- Flutter SDK (v3.13+)
- Dart SDK (v3.0+)
- Supabase Project URL & Anonymous Key

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
   Apply the provided SQL migrations (`master_supabase_setup.sql` and `hq_dossier_sync.sql`) to your Supabase SQL Editor to establish the battalion schema.

4. **Launch Application:**
   ```bash
   flutter run
   ```

---

## 🛡️ Security Protocols
The application utilizes **Supabase Row Level Security (RLS)** to enforce sector-based access:
- **Admin Tier:** Absolute global visibility and mutation rights.
- **Employee Tier:** Visibility limited to assigned mission deployments and personal financial telemetry.
- **User Tier:** Vision restricted to self-dossier, public treks, and authorized squad bookings.

---

## 📡 Deployment Logs & v1.4.x Updates
- **v1.4.5:** Consolidated Enquiries & Complaints into "Support Hub".
- **v1.4.6:** Standardized Profile Documentation (`medical_certificate_url`).
- **v1.4.7:** Hardened field logistics with constrained bottom-sheet UI.

**Trek India - Scaling the Himalayas with Technology.**
