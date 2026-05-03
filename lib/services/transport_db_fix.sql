-- Transport Bookings Table
CREATE TABLE IF NOT EXISTS public.transport_bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    transport_name TEXT NOT NULL,
    transport_type TEXT NOT NULL, -- 'bus' or 'train'
    from_location TEXT NOT NULL,
    to_location TEXT NOT NULL,
    travel_date DATE NOT NULL,
    price NUMERIC NOT NULL,
    hiker_name TEXT NOT NULL,
    hiker_age INTEGER,
    seat_preference TEXT,
    status TEXT DEFAULT 'Confirmed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.transport_bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own transport bookings" ON public.transport_bookings;
CREATE POLICY "Users can view own transport bookings" ON public.transport_bookings FOR SELECT USING (auth.uid() = user_id);
