# WordPress Hosting & Integration Guide
## For trekwithmussafirr (https://wordpress.com/sites/trekwithmussafirr.com)

This guide walks you through hosting and integrating your Flutter Web application (`trekwithmussafirr`) with a WordPress site.

---

## 1. Overview of Options

Since Flutter Web generates a Single Page Application (SPA) compiled to HTML, JS, and CSS, it cannot run directly *inside* the WordPress PHP rendering engine as a plugin. Instead, you have two primary, professional methods to host and link them.

### Option A: Subdomain Hosting (Recommended)
You host the Flutter Web app on a dedicated subdomain (e.g., `app.trekwithmussafirr.com` or `book.trekwithmussafirr.com`) and point your WordPress primary site (`trekwithmussafirr.com`) navigation links to it.
* **Pros**: Best performance, full screen real-estate, SEO-friendly marketing pages on WordPress with highly interactive app pages on the subdomain.
* **Cons**: Requires configuring a subdomain in your DNS manager.

### Option B: Embedding via iframe
You host the Flutter Web app on a hosting provider (like Firebase Hosting, Netlify, or Vercel) and embed it inside a WordPress page using an `<iframe>`.
* **Pros**: Keeps the user inside the main WordPress domain frame.
* **Cons**: Slower load times, mobile layout zooming issues, and scroll hijacking.

---

## 2. Option A: Step-by-Step Subdomain Hosting (Firebase + Cloudflare/GoDaddy)

### Step 2.1: Build the Flutter Web App
Compile the production bundle of your Flutter Web application:
```bash
flutter build web --release --base-href "/"
```
This outputs all web assets to the `build/web/` directory.

### Step 2.2: Choose a Free Static Hosting Provider (e.g., Firebase Hosting)
Firebase Hosting is highly secure, fast, and completely free for standard traffic.
1. Install Firebase CLI (if not already done):
   ```bash
   npm install -g firebase-tools
   ```
2. Initialize Firebase in the project root:
   ```bash
   firebase init hosting
   ```
   * Choose your active Supabase/Firebase project.
   * Specify `build/web` as your public directory.
   * Configure as a single-page app (write all URLs to `/index.html`): **Yes**.
3. Deploy the web app:
   ```bash
   firebase deploy --only hosting
   ```

### Step 2.3: Connect Your WordPress Custom Subdomain
1. Go to your domain provider (e.g., GoDaddy, Cloudflare, or WordPress.com Domain Manager if purchased through WordPress).
2. Add a new **CNAME Record**:
   * **Host/Name**: `app` (for `app.trekwithmussafirr.com`) or `book` (for `book.trekwithmussafirr.com`)
   * **Value/Points to**: Your Firebase Hosting URL (e.g., `trekwithmussafirr.web.app`)
   * **TTL**: `Automatic` or `1 Hour`
3. In the Firebase Console (Hosting section), click **Add Custom Domain** and enter `app.trekwithmussafirr.com`. Firebase will automatically provision an SSL certificate for you.

---

## 3. Option B: Embedding inside WordPress via iframe

If you prefer to embed the entire booking app directly inside a page on `https://trekwithmussafirr.com`:

1. Host the Flutter Web app on Firebase Hosting as described above (e.g., at `https://trekwithmussafirr.web.app`).
2. Log in to your WordPress dashboard at `https://wordpress.com/sites/trekwithmussafirr.com`.
3. Create a new page (e.g., "Book a Trek").
4. Add a **Custom HTML Block** inside the block editor.
5. Paste the following optimized iframe code:
   ```html
   <iframe 
     src="https://trekwithmussafirr.web.app" 
     style="width:100%; height:800px; border:none; overflow:hidden;" 
     scrolling="yes"
     allow="geolocation; camera; microphone"
     title="TrekWithMussafirr Booking App">
   </iframe>
   ```
6. Publish the page.

---

## 4. Email Notification Setup for Rewards System

As part of the secure rewards system, points adjustments and credit transactions are written to the `public.reward_emails_queue` table in Supabase. To trigger actual email dispatches:

1. **Supabase Database Webhook**:
   Set up a database webhook in the Supabase Dashboard (`Database` -> `Webhooks`) that triggers on `INSERT` to the `reward_emails_queue` table.
2. **Edge Function**:
   Create a Supabase Edge Function that receives the webhook payload, retrieves the recipient email and body, and sends the email using a delivery provider (e.g., **Resend**, **SendGrid**, or **Mailgun**):
   ```typescript
   // supabase/functions/send-rewards-email/index.ts
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
   
   serve(async (req) => {
     const { record } = await req.json()
     
     // Send email using Resend API
     const response = await fetch("https://api.resend.com/emails", {
       method: "POST",
       headers: {
         "Content-Type": "application/json",
         "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`
       },
       body: JSON.stringify({
         from: "TrekWithMussafirr <no-reply@trekwithmussafirr.com>",
         to: [record.recipient_email],
         subject: record.subject,
         text: record.body
       })
     })
     
     return new Response(JSON.stringify({ success: response.ok }), { status: 200 })
   })
   ```
