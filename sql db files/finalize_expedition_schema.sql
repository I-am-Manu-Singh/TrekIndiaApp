-- FINALIZE EXPEDITION SCHEMA
-- Adds high-fidelity metadata columns to public.treks and ensures bookings/packages are synchronized.

DO $$ 
BEGIN
    -- 1. TREKS TABLE UPDATES
    -- Images Gallery
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='images') THEN
        ALTER TABLE public.treks ADD COLUMN images TEXT[] DEFAULT '{}';
    END IF;

    -- Inclusions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='inclusions') THEN
        ALTER TABLE public.treks ADD COLUMN inclusions TEXT[] DEFAULT '{}';
    END IF;

    -- Exclusions
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='exclusions') THEN
        ALTER TABLE public.treks ADD COLUMN exclusions TEXT[] DEFAULT '{}';
    END IF;

    -- Carry List
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='carry_list') THEN
        ALTER TABLE public.treks ADD COLUMN carry_list TEXT[] DEFAULT '{}';
    END IF;

    -- Coordinates
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='latitude') THEN
        ALTER TABLE public.treks ADD COLUMN latitude NUMERIC DEFAULT 30.7333;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='longitude') THEN
        ALTER TABLE public.treks ADD COLUMN longitude NUMERIC DEFAULT 76.7794;
    END IF;

    -- Physical Specs
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='peak_elevation') THEN
        ALTER TABLE public.treks ADD COLUMN peak_elevation TEXT DEFAULT 'N/A';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='trail_type') THEN
        ALTER TABLE public.treks ADD COLUMN trail_type TEXT DEFAULT 'Mixed';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='treks' AND column_name='orientation') THEN
        ALTER TABLE public.treks ADD COLUMN orientation TEXT DEFAULT 'North';
    END IF;

    -- 2. BOOKINGS TABLE UPDATES (For Lead/Guest Tracking)
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

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='trek_name') THEN
        ALTER TABLE public.bookings ADD COLUMN trek_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='is_leader') THEN
        ALTER TABLE public.bookings ADD COLUMN is_leader BOOLEAN DEFAULT FALSE;
    END IF;

END $$;

-- 3. TREK PACKAGES TABLE (Required for Tiered Pricing)
CREATE TABLE IF NOT EXISTS public.trek_packages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trek_id UUID REFERENCES public.treks(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    description TEXT,
    inclusions TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure RLS for packages
ALTER TABLE public.trek_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public_view_packages" ON public.trek_packages;
CREATE POLICY "public_view_packages" ON public.trek_packages FOR SELECT USING (true);
DROP POLICY IF EXISTS "admin_manage_packages" ON public.trek_packages;
CREATE POLICY "admin_manage_packages" ON public.trek_packages FOR ALL USING (true);

