-- Shows providers the platform commission recorded on each of their
-- bookings. Clients never see it: the commission is settled between Myglo and
-- the provider, and clients pay no booking fee.
--
-- Same view as in the booking engine migration with one column appended
-- (CREATE OR REPLACE VIEW can only add columns at the end). Grants and the
-- security_invoker option carry over.

CREATE OR REPLACE VIEW public.booking_details WITH (security_invoker = true) AS
SELECT
    b.id,
    b.reference,
    b.client_id,
    b.provider_id,
    CASE WHEN b.status = 'pending' AND b.starts_at <= now() THEN 'expired' ELSE b.status END AS status,
    b.starts_at,
    b.ends_at,
    b.time_zone,
    (b.starts_at AT TIME ZONE b.time_zone) AS starts_at_local,
    (b.ends_at AT TIME ZONE b.time_zone) AS ends_at_local,
    b.duration_minutes,
    b.location_type,
    b.address_text,
    b.address,
    b.access_notes,
    public.st_y(b.location::public.geometry) AS latitude,
    public.st_x(b.location::public.geometry) AS longitude,
    b.distance_km,
    b.provider_name,
    pp.profile_pic AS provider_avatar_url,
    b.client_name,
    cp.profile_pic AS client_avatar_url,
    b.client_phone,
    b.client_notes,
    b.subtotal_cents,
    b.total_cents,
    b.currency,
    b.payment_method,
    b.payment_status,
    b.requires_approval,
    b.cancellation_window_hours,
    b.cancellation_fee_percent,
    b.starts_at - make_interval(hours => b.cancellation_window_hours) AS free_cancellation_until,
    b.decline_reason,
    b.responded_at,
    b.cancelled_by,
    b.cancellation_reason,
    b.cancelled_at,
    b.late_cancellation,
    b.cancellation_fee_cents,
    b.completed_at,
    b.created_at,
    b.updated_at,
    COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
                   'service_id', i.service_id,
                   'name', i.service_name,
                   'category', i.category,
                   'duration_minutes', i.duration_minutes,
                   'price_cents', i.price_cents
               ) ORDER BY i.position)
        FROM public.booking_items i
        WHERE i.booking_id = b.id
    ), '[]'::jsonb) AS items,
    -- Provider only; NULL for the client.
    CASE WHEN b.provider_id = (SELECT auth.uid()) THEN b.platform_fee_cents END AS platform_fee_cents
FROM public.bookings b
LEFT JOIN public.public_profiles pp ON pp.id = b.provider_id
LEFT JOIN public.public_profiles cp ON cp.id = b.client_id;
