-- Add declaration_signed to profiles if it's missing
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS declaration_signed BOOLEAN DEFAULT false;

-- Ensure other columns are present for the booking flow
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
