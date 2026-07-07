-- 1. Add the missing columns to the common profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0;

-- 2. Update the public_profiles view so the new columns are visible to the app
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT 
    id, role, first_name, last_name, profile_pic, bio, followers_count, following_count, created_at, updated_at,
    CASE WHEN is_email_public THEN email ELSE NULL END AS email,
    CASE WHEN is_phone_public THEN phone_number ELSE NULL END AS phone_number
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

-- 3. Make the count columns immutable by the client for BOTH INSERT and UPDATE
REVOKE INSERT (followers_count, following_count), UPDATE (followers_count, following_count) ON public.profiles FROM authenticated, anon;

-- 4. [CORRECTED] Patch the posts table counts ONLY (author_id is protected by RLS on insert)
REVOKE INSERT (likes_count, comments_count) ON public.posts FROM authenticated, anon;

-- 5. Create the 'follows' table
CREATE TABLE IF NOT EXISTS public.follows (
    follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id != following_id) -- Prevent users from following themselves
);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Follows are viewable by everyone" ON public.follows FOR SELECT USING (true);
CREATE POLICY "Users can follow others" ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- 6. Create the automated triggers to keep counts accurate
CREATE OR REPLACE FUNCTION update_follow_counts() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment the follower's "following_count"
        UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
        -- Increment the target's "followers_count"
        UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement the follower's "following_count"
        UPDATE public.profiles SET following_count = following_count - 1 WHERE id = OLD.follower_id;
        -- Decrement the target's "followers_count"
        UPDATE public.profiles SET followers_count = followers_count - 1 WHERE id = OLD.following_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop trigger first in case you are re-running this
DROP TRIGGER IF EXISTS on_follow_change ON public.follows;
CREATE TRIGGER on_follow_change
AFTER INSERT OR DELETE ON public.follows
FOR EACH ROW EXECUTE FUNCTION update_follow_counts();

-- Create the post-media storage bucket for feed posts with strict limits
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
    'post-media', 
    'post-media', 
    true, 
    5242880, -- 5MB hard limit (in bytes)
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Setup Security Policies for the bucket (Using unique names, owner_id, and performance optimizations)
CREATE POLICY "Public Access for Post Media" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'post-media');

CREATE POLICY "User can upload to Post Media" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'post-media' AND owner_id = (select auth.uid())::text);

CREATE POLICY "User can update own Post Media" 
ON storage.objects FOR UPDATE 
USING (bucket_id = 'post-media' AND owner_id = (select auth.uid())::text);

CREATE POLICY "User can delete own Post Media" 
ON storage.objects FOR DELETE 
USING (bucket_id = 'post-media' AND owner_id = (select auth.uid())::text);