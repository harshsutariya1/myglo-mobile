-- 1. Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Clean up old architecture (WARNING: Drops existing tables)
DROP TABLE IF EXISTS public.likes CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;
DROP TABLE IF EXISTS public.services CASCADE;
DROP TABLE IF EXISTS public.provider_details CASCADE;
DROP TABLE IF EXISTS public.businesses CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.all_users CASCADE;
DROP VIEW IF EXISTS public.public_profiles CASCADE;
DROP FUNCTION IF EXISTS public.register_user_role CASCADE;
DROP FUNCTION IF EXISTS public.update_onboarding_details CASCADE;

-- ==========================================
-- IDENTITY & PROFILES
-- ==========================================

-- 3. Create Unified profiles table
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    role TEXT CHECK (role IN ('customer', 'provider')) NOT NULL,
    first_name TEXT,
    last_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT,
    profile_pic TEXT,
    is_email_public BOOLEAN DEFAULT false,
    is_phone_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own profile" ON public.profiles FOR ALL USING (auth.uid() = id);

-- 4. Create public_profiles VIEW
CREATE VIEW public.public_profiles AS
SELECT 
    id, 
    role, 
    first_name, 
    last_name, 
    profile_pic, 
    created_at, 
    updated_at,
    CASE WHEN is_email_public THEN email ELSE NULL END AS email,
    CASE WHEN is_phone_public THEN phone_number ELSE NULL END AS phone_number
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

-- 5. Create provider_details extension table
CREATE TABLE public.provider_details (
    id UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
    provider_name TEXT, 
    address_text TEXT,
    coordinates GEOGRAPHY(POINT, 4326),
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.provider_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Provider details viewable by everyone" ON public.provider_details FOR SELECT USING (true);
CREATE POLICY "Providers can manage own details" ON public.provider_details FOR ALL USING (auth.uid() = id);

-- ==========================================
-- SERVICES & CONTENT (POSTS)
-- ==========================================

-- 6. Create services table
CREATE TABLE public.services (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    provider_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2),
    duration_minutes INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_services_provider_id ON public.services(provider_id);
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Services viewable by everyone" ON public.services FOR SELECT USING (true);
CREATE POLICY "Providers manage their own services" ON public.services FOR ALL USING (auth.uid() = provider_id);

-- 7. Create posts table
CREATE TABLE public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    media_urls TEXT[] NOT NULL,
    caption TEXT,
    service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
    tagged_provider_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    tag_status TEXT CHECK (tag_status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_posts_author_id ON public.posts(author_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- ** FIX #1: Make sensitive columns immutable to clients **
REVOKE UPDATE (author_id, likes_count, comments_count) ON public.posts FROM authenticated, anon;

CREATE POLICY "Posts visibility" ON public.posts FOR SELECT USING (
    tag_status = 'approved' OR auth.uid() = author_id OR auth.uid() = tagged_provider_id
);
CREATE POLICY "Users can create posts" ON public.posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors and Tagged Providers can update posts" ON public.posts FOR UPDATE USING (
    auth.uid() = author_id OR auth.uid() = tagged_provider_id
);
CREATE POLICY "Authors can delete own posts" ON public.posts FOR DELETE USING (auth.uid() = author_id);

-- Auto-approve posts that don't have a tagged provider
CREATE OR REPLACE FUNCTION set_default_post_status() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tagged_provider_id IS NULL THEN
        NEW.tag_status := 'approved';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_post_insert_set_status
BEFORE INSERT ON public.posts
FOR EACH ROW EXECUTE FUNCTION set_default_post_status();

-- ** FIX #2: Use OLD values to determine role safely **
CREATE OR REPLACE FUNCTION enforce_post_update_rules() RETURNS TRIGGER AS $$
BEGIN
    -- Use OLD to determine the actor's role — NEW is attacker-controlled.
    IF auth.uid() = OLD.author_id THEN
        IF NEW.tagged_provider_id IS DISTINCT FROM OLD.tagged_provider_id THEN
            IF NEW.tagged_provider_id IS NULL THEN
                NEW.tag_status := 'approved';
            ELSE
                NEW.tag_status := 'pending';
            END IF;
        ELSIF NEW.tag_status IS DISTINCT FROM OLD.tag_status AND NEW.tagged_provider_id IS NOT NULL THEN
            RAISE EXCEPTION 'Authors cannot manually approve or reject tags.';
        END IF;

    ELSIF auth.uid() = OLD.tagged_provider_id THEN
        IF NEW.caption IS DISTINCT FROM OLD.caption OR
           NEW.media_urls IS DISTINCT FROM OLD.media_urls OR
           NEW.service_id IS DISTINCT FROM OLD.service_id OR
           NEW.tagged_provider_id IS DISTINCT FROM OLD.tagged_provider_id THEN
            RAISE EXCEPTION 'Tagged providers can only update the tag status.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_post_update_enforce_rules
BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION enforce_post_update_rules();

-- ==========================================
-- ENGAGEMENT (LIKES & COMMENTS) & TRIGGERS
-- ==========================================

-- 8. Create likes table
CREATE TABLE public.likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(post_id, user_id)
);

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes viewable by everyone" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Users can manage own likes" ON public.likes FOR ALL USING (auth.uid() = user_id);

-- 9. Create comments table
CREATE TABLE public.comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comments viewable by everyone" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Users can manage own comments" ON public.comments FOR ALL USING (auth.uid() = author_id);

-- Count Triggers
CREATE OR REPLACE FUNCTION update_post_likes_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_like_change
AFTER INSERT OR DELETE ON public.likes
FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

CREATE OR REPLACE FUNCTION update_post_comments_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_comment_change
AFTER INSERT OR DELETE ON public.comments
FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

-- ==========================================
-- SECURE RPC ENDPOINTS
-- ==========================================

CREATE OR REPLACE FUNCTION public.register_user_role(p_id UUID, p_email TEXT, p_role TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF auth.uid() != p_id THEN RAISE EXCEPTION 'Not authorized'; END IF;
    IF p_role NOT IN ('customer', 'provider') THEN RAISE EXCEPTION 'Invalid role'; END IF;

    INSERT INTO public.profiles (id, email, role) VALUES (p_id, p_email, p_role)
    ON CONFLICT (id) DO NOTHING;

    IF p_role = 'provider' THEN
        INSERT INTO public.provider_details (id) VALUES (p_id) ON CONFLICT (id) DO NOTHING;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_onboarding_details(
    p_id UUID, p_role TEXT, p_first_name TEXT, p_last_name TEXT, 
    p_phone TEXT, p_profile_pic TEXT, p_provider_name TEXT DEFAULT NULL,
    p_address_text TEXT DEFAULT NULL, p_longitude DOUBLE PRECISION DEFAULT NULL, p_latitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF auth.uid() != p_id THEN RAISE EXCEPTION 'Not authorized'; END IF;

    UPDATE public.profiles
    SET first_name = p_first_name, last_name = p_last_name, phone_number = p_phone, profile_pic = p_profile_pic, updated_at = now()
    WHERE id = p_id;

    IF p_role = 'provider' THEN
        UPDATE public.provider_details
        SET provider_name = p_provider_name, address_text = p_address_text,
            coordinates = CASE WHEN p_longitude IS NOT NULL AND p_latitude IS NOT NULL 
                THEN ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography 
                ELSE coordinates END,
            updated_at = now()
        WHERE id = p_id;
    END IF;
END;
$$;