-- profiles had two identical GiST indexes on coordinates: profiles_coordinates_gix
-- (20261003120000_client_favourites_and_nearby_posts) and
-- profiles_coordinates_gist_idx, made outside the migrations and never used.
-- Keeping both doubles the write cost of every location change.

DROP INDEX IF EXISTS public.profiles_coordinates_gist_idx;
