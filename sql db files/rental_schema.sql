-- ==========================================
-- trekwithmussafirr: Rental Tracking Schema
-- ==========================================

-- 1. Create User Rentals table to track gear issued to hikers
CREATE TABLE IF NOT EXISTS public.user_rentals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    gear_id UUID REFERENCES public.gears(id) ON DELETE SET NULL,
    issue_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    return_date TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'issued' CHECK (status IN ('issued', 'returned')),
    total_price DECIMAL(10,2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Enable RLS
ALTER TABLE public.user_rentals ENABLE ROW LEVEL SECURITY;

-- 3. Simple Policies
CREATE POLICY "Admins can manage all user_rentals" ON public.user_rentals
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Users can view their own rentals" ON public.user_rentals
    FOR SELECT USING (auth.uid() = user_id);
