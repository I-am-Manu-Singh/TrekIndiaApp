-- Final improvements for Profile and Community
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Update RLS to ensure users can read their own profiles and admins can read all
DROP POLICY IF EXISTS "Profiles are readable by everyone" ON profiles;
CREATE POLICY "Profiles are readable by everyone" ON profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Ensure reviews rating is FLOAT if we want half stars, or keep as INT and we cast in app
-- Based on the error, it's currently INT. Let's change it to NUMERIC for better precision.
ALTER TABLE reviews ALTER COLUMN rating TYPE NUMERIC;

-- Blog upvotes and comments RLS
DROP POLICY IF EXISTS "Anyone can view blog upvotes" ON blog_upvotes;
CREATE POLICY "Anyone can view blog upvotes" ON blog_upvotes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can toggle upvotes" ON blog_upvotes;
CREATE POLICY "Users can toggle upvotes" ON blog_upvotes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own upvote" ON blog_upvotes FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Comments are readable by everyone" ON blog_comments;
CREATE POLICY "Comments are readable by everyone" ON blog_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can post comments" ON blog_comments;
CREATE POLICY "Users can post comments" ON blog_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Complete Payment/Refund placeholders logic
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id),
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL, -- 'Payment', 'Refund'
    status TEXT DEFAULT 'Completed',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can see their own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can see all transactions" ON transactions FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
