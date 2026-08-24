-- ==========================================================
-- STEP 1: FIX PERMISSIONS (ALLOW APP TO CREATE PROFILE)
-- ==========================================================
-- This allows you to log in and have the app automatically create your 
-- profile record in the 'profiles' table without getting the RLS error.

DROP POLICY IF EXISTS "user_insert_profile" ON public.profiles;
CREATE POLICY "user_insert_profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "user_update_profile" ON public.profiles;
CREATE POLICY "user_update_profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);

-- ==========================================================
-- STEP 2: GRANT ADMIN STATUS (REPLACE EMAIL BELOW)
-- ==========================================================
-- Change 'YOUR_EMAIL_HERE' to the email you used to sign up.

DO $$
BEGIN
    -- This part creates the profile row manually if it doesn't exist yet
    INSERT INTO public.profiles (id, full_name, role)
    SELECT id, 'Admin User', 'admin'
    FROM auth.users 
    WHERE email = 'YOUR_EMAIL_HERE' -- <--- CHANGE THIS PART
    ON CONFLICT (id) DO UPDATE SET role = 'admin';

    -- This part ensures the role is set to admin
    UPDATE public.profiles 
    SET role = 'admin' 
    WHERE id IN (SELECT id FROM auth.users WHERE email = 'YOUR_EMAIL_HERE'); -- <--- CHANGE THIS PART
END $$;

-- ==========================================================
-- STEP 3: ENABLE REALTIME (FOR INSTANT CHAT)
-- ==========================================================
-- Run this if chat isn't refreshing automatically.

alter publication supabase_realtime add table messages;
