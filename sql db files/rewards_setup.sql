-- rewards_setup.sql
-- SECURE DATABASE REWARDS SYSTEM FOR trekwithmussafirr

-- 1. Add reward_points column to profiles table if it doesn't exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reward_points INTEGER DEFAULT 0;

-- 2. Create the reward_ledger table for secure, auditable transactions
CREATE TABLE IF NOT EXISTS public.reward_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    booking_id UUID NOT NULL,
    points_changed INTEGER NOT NULL,
    type TEXT CHECK (type IN ('CREDIT', 'DEBIT')) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 3. Create email queue table for reward email notifications
CREATE TABLE IF NOT EXISTS public.reward_emails_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.reward_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_emails_queue ENABLE ROW LEVEL SECURITY;

-- 5. Define Security Policies
-- Admins can do everything on both tables
CREATE POLICY "Admins full control reward_ledger" ON public.reward_ledger
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Users read-only own ledger" ON public.reward_ledger
    FOR SELECT TO authenticated USING (
        user_id = auth.uid()
    );

CREATE POLICY "Admins full control email queue" ON public.reward_emails_queue
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- 6. Trigger Function to automatically credit points on booking payment confirmation
CREATE OR REPLACE FUNCTION public.handle_confirmed_booking_rewards()
RETURNS TRIGGER AS $$
DECLARE
    calculated_points INTEGER;
    user_email TEXT;
    trip_title TEXT;
BEGIN
    -- Only trigger when booking is confirmed paid
    IF (NEW.payment_status = 'Paid' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'Paid')) THEN
        -- Calculate points: 7% of total price
        calculated_points := (NEW.total_price * 0.07)::integer;
        
        IF calculated_points > 0 THEN
            -- 1. Insert ledger record
            INSERT INTO public.reward_ledger (user_id, booking_id, points_changed, type, description)
            VALUES (NEW.user_id, NEW.id, calculated_points, 'CREDIT', 'Earned reward points for booking: ' || NEW.trip_name);
            
            -- 2. Update user profile total points
            UPDATE public.profiles 
            SET reward_points = COALESCE(reward_points, 0) + calculated_points
            WHERE id = NEW.user_id;

            -- 3. Retrieve user email
            SELECT email INTO user_email FROM auth.users WHERE id = NEW.user_id;
            
            -- Fallback if not found in auth.users
            IF user_email IS NULL THEN
                user_email := NEW.hiker_email;
            END IF;

            -- 4. Queue Email Notification
            IF user_email IS NOT NULL THEN
                INSERT INTO public.reward_emails_queue (user_id, recipient_email, subject, body)
                VALUES (
                    NEW.user_id, 
                    user_email,
                    'Congratulations! You earned Reward Points! 🎉',
                    'Hello ' || NEW.hiker_name || ',\n\nWe are excited to inform you that your booking for ' || NEW.trip_name || ' has been confirmed and paid.\n\nWe have credited ' || calculated_points || ' reward points to your trekwithmussafirr wallet for future use!\n\nAdventure awaits!\n\nBest Regards,\nTeam trekwithmussafirr'
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Register the trigger
DROP TRIGGER IF EXISTS trigger_booking_rewards ON public.bookings;
CREATE TRIGGER trigger_booking_rewards
    AFTER UPDATE ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_confirmed_booking_rewards();
