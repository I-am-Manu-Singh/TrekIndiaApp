-- Add declaration_signed to profiles if missing
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS declaration_signed BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Fix trips table
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS pickup_options JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS base_price NUMERIC DEFAULT 0;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS discounted_price NUMERIC DEFAULT 0;

-- Update existing trips to have some prices if they are zero
UPDATE public.trips SET base_price = price WHERE base_price = 0 AND price IS NOT NULL;
UPDATE public.trips SET discounted_price = base_price * 0.9 WHERE discounted_price = 0 AND base_price > 0;

-- Transport Table
CREATE TABLE IF NOT EXISTS public.transports (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- 'bus' or 'train'
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    departure_time TEXT,
    arrival_time TEXT,
    price NUMERIC NOT NULL,
    seats_available INTEGER DEFAULT 40,
    rating NUMERIC DEFAULT 4.5,
    amenities JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Transports
INSERT INTO public.transports (name, type, origin, destination, departure_time, arrival_time, price, seats_available)
VALUES 
('Zingbus Premium', 'bus', 'Delhi', 'Manali', '08:00 PM', '09:00 AM', 1200, 24),
('HRTC Volvo', 'bus', 'Delhi', 'Shimla', '10:00 PM', '06:00 AM', 950, 18),
('Rajdhani Express', 'train', 'Delhi', 'Chandigarh', '06:00 AM', '09:15 AM', 850, 120),
('Shatabdi Express', 'train', 'Delhi', 'Amritsar', '07:20 AM', '01:05 PM', 1100, 85)
ON CONFLICT DO NOTHING;

-- Transport Bookings Table (already exists from previous turns maybe, but ensuring)
CREATE TABLE IF NOT EXISTS public.transport_bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    transport_name TEXT,
    transport_type TEXT,
    origin TEXT,
    destination TEXT,
    departure_date DATE,
    price NUMERIC,
    hiker_name TEXT,
    hiker_age INTEGER,
    seat_preference TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
