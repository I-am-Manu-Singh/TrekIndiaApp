-- Enable public/guest submissions to support_inquiries without requiring authentication
CREATE TABLE IF NOT EXISTS public.support_inquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    admin_reply TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.support_inquiries ENABLE ROW LEVEL SECURITY;

-- 1. Anyone (including anonymous guests without login) can submit an enquiry
DROP POLICY IF EXISTS "Anyone can insert enquiries" ON public.support_inquiries;
CREATE POLICY "Anyone can insert enquiries"
ON public.support_inquiries
FOR INSERT
TO public, anon, authenticated
WITH CHECK (true);

-- 2. Authenticated users can view their own inquiries
DROP POLICY IF EXISTS "Users view own inquiries" ON public.support_inquiries;
CREATE POLICY "Users view own inquiries"
ON public.support_inquiries
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 3. Admins have full access (view, update status, reply)
DROP POLICY IF EXISTS "Admins manage all inquiries" ON public.support_inquiries;
CREATE POLICY "Admins manage all inquiries"
ON public.support_inquiries
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role IN ('admin', 'staff', 'employee')
    )
);
