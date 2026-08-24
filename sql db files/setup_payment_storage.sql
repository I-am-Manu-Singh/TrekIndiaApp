-- ==============================================================================
-- SUPABASE STORAGE SETUP: PAYMENT PROOFS BUCKET & POLICIES
-- ==============================================================================

-- 1. Create the storage bucket for payment screenshots if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment_proofs', 'payment_proofs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop any previous conflicting policies for payment_proofs
DROP POLICY IF EXISTS "Public View Payment Proofs" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Upload Payment Proofs" ON storage.objects;
DROP POLICY IF EXISTS "Users Update Own Payment Proofs" ON storage.objects;
DROP POLICY IF EXISTS "Admins Full Control Payment Proofs" ON storage.objects;

-- 3. Policy: Anyone (and Admins) can view/read payment screenshots
CREATE POLICY "Public View Payment Proofs"
ON storage.objects FOR SELECT
USING (bucket_id = 'payment_proofs');

-- 4. Policy: Authenticated users can upload their payment screenshots
CREATE POLICY "Authenticated Users Upload Payment Proofs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'payment_proofs');

-- 5. Policy: Authenticated users can update/replace their uploaded screenshots
CREATE POLICY "Users Update Own Payment Proofs"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'payment_proofs');

-- 6. Policy: Admins have full delete/management access over payment proofs
CREATE POLICY "Admins Full Control Payment Proofs"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'payment_proofs' AND 
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);
