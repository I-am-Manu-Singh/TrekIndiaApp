-- 1. Fix Blogs Insert Policy
DROP POLICY IF EXISTS "Anyone can insert blogs" ON public.blogs;
CREATE POLICY "Anyone can insert blogs" ON public.blogs
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND (role = 'admin' OR EXISTS (SELECT 1 FROM public.bookings WHERE user_id = auth.uid()))
        )
    );

-- 2. Ensure author_id is correctly set
ALTER TABLE public.blogs ALTER COLUMN author_id SET DEFAULT auth.uid();
