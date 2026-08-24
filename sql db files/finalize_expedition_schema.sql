-- FINALIZE EXPEDITION SCHEMA
-- Adds high-fidelity metadata columns to public.trips and public.bookings.

DO $$ 
BEGIN
    -- 1. TRIPS TABLE UPDATES (Images, inclusions, coordinates, etc.)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='trips') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='images') THEN
            ALTER TABLE public.trips ADD COLUMN images TEXT[] DEFAULT '{}';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='inclusions') THEN
            ALTER TABLE public.trips ADD COLUMN inclusions TEXT[] DEFAULT '{}';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='exclusions') THEN
            ALTER TABLE public.trips ADD COLUMN exclusions TEXT[] DEFAULT '{}';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='carry_list') THEN
            ALTER TABLE public.trips ADD COLUMN carry_list TEXT[] DEFAULT '{}';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='latitude') THEN
            ALTER TABLE public.trips ADD COLUMN latitude NUMERIC DEFAULT 30.7333;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='longitude') THEN
            ALTER TABLE public.trips ADD COLUMN longitude NUMERIC DEFAULT 76.7794;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='peak_elevation') THEN
            ALTER TABLE public.trips ADD COLUMN peak_elevation TEXT DEFAULT 'N/A';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='trail_type') THEN
            ALTER TABLE public.trips ADD COLUMN trail_type TEXT DEFAULT 'Mixed';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trips' AND column_name='orientation') THEN
            ALTER TABLE public.trips ADD COLUMN orientation TEXT DEFAULT 'North';
        END IF;
    END IF;

    -- 2. BOOKINGS TABLE UPDATES (Lead Traveler, Aadhar, Address, Sharing, Special Requests)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='bookings') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='hiker_name') THEN
            ALTER TABLE public.bookings ADD COLUMN hiker_name TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='hiker_number') THEN
            ALTER TABLE public.bookings ADD COLUMN hiker_number TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='hiker_email') THEN
            ALTER TABLE public.bookings ADD COLUMN hiker_email TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='hiker_pax') THEN
            ALTER TABLE public.bookings ADD COLUMN hiker_pax INTEGER DEFAULT 1;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='trip_name') THEN
            ALTER TABLE public.bookings ADD COLUMN trip_name TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='is_leader') THEN
            ALTER TABLE public.bookings ADD COLUMN is_leader BOOLEAN DEFAULT FALSE;
        END IF;

        -- Aadhar Number (12 digits)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='aadhar_no') THEN
            ALTER TABLE public.bookings ADD COLUMN aadhar_no TEXT;
        END IF;

        -- Residential Address
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='address') THEN
            ALTER TABLE public.bookings ADD COLUMN address TEXT;
        END IF;

        -- Age & Gender
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='age') THEN
            ALTER TABLE public.bookings ADD COLUMN age INTEGER;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='gender') THEN
            ALTER TABLE public.bookings ADD COLUMN gender TEXT DEFAULT 'Male';
        END IF;

        -- Accommodation Preferences & Couple Sharing
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='travel_type') THEN
            ALTER TABLE public.bookings ADD COLUMN travel_type TEXT DEFAULT 'Solo / Standard';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='tent_sharing') THEN
            ALTER TABLE public.bookings ADD COLUMN tent_sharing BOOLEAN DEFAULT FALSE;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='room_sharing') THEN
            ALTER TABLE public.bookings ADD COLUMN room_sharing BOOLEAN DEFAULT FALSE;
        END IF;

        -- Special Requirements / Dietary / Medical Notes
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='special_requests') THEN
            ALTER TABLE public.bookings ADD COLUMN special_requests TEXT;
        END IF;
    END IF;

END $$;

-- 3. TRIP PACKAGES TABLE (Tiered Pricing)
CREATE TABLE IF NOT EXISTS public.trip_packages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    description TEXT,
    inclusions TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. APP SETTINGS TABLE (Global Dispatch Routing & Dynamic Configuration)
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public_view_settings" ON public.app_settings;
CREATE POLICY "public_view_settings" ON public.app_settings FOR SELECT USING (true);
DROP POLICY IF EXISTS "admin_manage_settings" ON public.app_settings;
CREATE POLICY "admin_manage_settings" ON public.app_settings FOR ALL USING (true);

INSERT INTO public.app_settings (key, value)
VALUES 
    ('admin_dispatch_email', 'mussafirr1@gmail.com'),
    ('admin_dispatch_phone', '919756399115')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

