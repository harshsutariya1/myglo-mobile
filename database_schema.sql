-- Database Schema for MyGlo App

-- 1. Create all_users table
CREATE TABLE public.all_users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    role TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT,
    profile_pic TEXT
);

-- Enable RLS for all_users
ALTER TABLE public.all_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all users" ON public.all_users FOR SELECT USING (true);
CREATE POLICY "Users can update their own row" ON public.all_users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert their own row" ON public.all_users FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. Create customers table
CREATE TABLE public.customers (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT,
    profile_pic TEXT
);

-- Enable RLS for customers
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all customers" ON public.customers FOR SELECT USING (true);
CREATE POLICY "Users can update their own customer profile" ON public.customers FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert their own customer profile" ON public.customers FOR INSERT WITH CHECK (auth.uid() = id);


-- 3. Create businesses table
CREATE TABLE public.businesses (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    business_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT,
    profile_pic TEXT
);

-- Enable RLS for businesses
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all businesses" ON public.businesses FOR SELECT USING (true);
CREATE POLICY "Users can update their own business profile" ON public.businesses FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert their own business profile" ON public.businesses FOR INSERT WITH CHECK (auth.uid() = id);


-- 4. Secure RPC to register role and initial data atomically
CREATE OR REPLACE FUNCTION register_user_role(p_id UUID, p_email TEXT, p_role TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Ensure the user is only modifying their own data or is authenticated
    IF auth.uid() != p_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    -- Insert into all_users
    INSERT INTO public.all_users (id, email, role)
    VALUES (p_id, p_email, p_role)
    ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

    -- Insert into specific role table
    IF p_role = 'customer' THEN
        INSERT INTO public.customers (id, email)
        VALUES (p_id, p_email)
        ON CONFLICT (id) DO NOTHING;
    ELSIF p_role = 'business' THEN
        INSERT INTO public.businesses (id, email)
        VALUES (p_id, p_email)
        ON CONFLICT (id) DO NOTHING;
    ELSE
        RAISE EXCEPTION 'Invalid role specified';
    END IF;
END;
$$;


-- 5. Secure RPC to update onboarding details atomically
CREATE OR REPLACE FUNCTION update_onboarding_details(
    p_id UUID, 
    p_role TEXT, 
    p_first_name TEXT, 
    p_last_name TEXT, 
    p_phone TEXT, 
    p_profile_pic TEXT, 
    p_business_name TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Ensure the user is only modifying their own data
    IF auth.uid() != p_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    -- Update all_users
    UPDATE public.all_users
    SET first_name = p_first_name,
        last_name = p_last_name,
        phone_number = p_phone,
        profile_pic = p_profile_pic
    WHERE id = p_id;

    -- Update specific role table
    IF p_role = 'customer' THEN
        UPDATE public.customers
        SET first_name = p_first_name,
            last_name = p_last_name,
            phone_number = p_phone,
            profile_pic = p_profile_pic
        WHERE id = p_id;
    ELSIF p_role = 'business' THEN
        UPDATE public.businesses
        SET first_name = p_first_name,
            last_name = p_last_name,
            business_name = p_business_name,
            phone_number = p_phone,
            profile_pic = p_profile_pic
        WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'Invalid role specified';
    END IF;
END;
$$;


-- 6. Storage Setup for Profile Pictures
-- Note: Execute this in the Supabase Storage SQL Editor or Dashboard
insert into storage.buckets (id, name, public) values ('profile-pics', 'profile-pics', true);
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'profile-pics');
CREATE POLICY "User can upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'profile-pics' AND auth.uid() = owner);
CREATE POLICY "User can update" ON storage.objects FOR UPDATE USING (bucket_id = 'profile-pics' AND auth.uid() = owner);

-- 7. Secure RPC to check if an email already exists in auth.users
CREATE OR REPLACE FUNCTION check_user_exists(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM auth.users WHERE email = p_email);
END;
$$;
