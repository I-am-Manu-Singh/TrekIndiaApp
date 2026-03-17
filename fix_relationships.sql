-- 1. Ensure Foreign Key Relationships
ALTER TABLE public.bookings 
DROP CONSTRAINT IF EXISTS bookings_user_id_fkey,
ADD CONSTRAINT bookings_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 2. Broadcasts Table for Admin Messages
CREATE TABLE IF NOT EXISTS public.broadcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.profiles(id),
    target_group_id UUID REFERENCES public.trek_groups(id), -- NULL means "All Groups"
    content TEXT NOT NULL,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Enable RLS for Broadcasts
ALTER TABLE public.broadcasts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read broadcasts" ON public.broadcasts
    FOR SELECT USING (true);

CREATE POLICY "Admins can create broadcasts" ON public.broadcasts
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- 4. Ensure Rental Tracking Joins
ALTER TABLE public.user_rentals
DROP CONSTRAINT IF EXISTS user_rentals_user_id_fkey,
ADD CONSTRAINT user_rentals_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
