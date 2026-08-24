-- 1. Enhance Blogs Table
ALTER TABLE public.blogs 
ADD COLUMN IF NOT EXISTS author_id UUID REFERENCES public.profiles(id) DEFAULT auth.uid(),
ADD COLUMN IF NOT EXISTS upvotes_count INTEGER DEFAULT 0;

-- 2. Blog Upvotes Table (to prevent multiple upvotes from same user)
CREATE TABLE IF NOT EXISTS public.blog_upvotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    blog_id UUID REFERENCES public.blogs(id) ON DELETE CASCADE,
    UNIQUE(user_id, blog_id)
);

-- 3. Blog Comments Table
CREATE TABLE IF NOT EXISTS public.blog_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_id UUID REFERENCES public.blogs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 4. Message Type for Stylized Broadcasts
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_broadcast BOOLEAN DEFAULT false;

-- 5. Row Level Security for Blogs (Author can Edit/Delete)
ALTER TABLE public.blogs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authors can update their own blogs" ON public.blogs;
CREATE POLICY "Authors can update their own blogs" ON public.blogs
    FOR UPDATE USING (auth.uid() = author_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Authors can delete their own blogs" ON public.blogs;
CREATE POLICY "Authors can delete their own blogs" ON public.blogs
    FOR DELETE USING (auth.uid() = author_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- 6. Trigger to automate upvote counting (Optional but recommended)
CREATE OR REPLACE FUNCTION update_blog_upvotes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.blogs SET upvotes_count = upvotes_count + 1 WHERE id = NEW.blog_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.blogs SET upvotes_count = upvotes_count - 1 WHERE id = OLD.blog_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_blog_upvote_count ON public.blog_upvotes;
CREATE TRIGGER tr_blog_upvote_count
AFTER INSERT OR DELETE ON public.blog_upvotes
FOR EACH ROW EXECUTE FUNCTION update_blog_upvotes_count();
