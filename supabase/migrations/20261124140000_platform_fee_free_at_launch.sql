-- Launch with no platform fee (decided 2026-11-24): card bookings carry no
-- Myglo commission until an admin raises it in Admin → Platform settings.
--
-- Fees are worked out and stored on each booking when it's paid, so this
-- changes only payments made from now on. The admin audit log records changes
-- made by an admin; this one is recorded here, in the migration history,
-- instead (the log needs an admin's id and none made it).

UPDATE private.platform_settings
SET platform_fee_percent = 0,
    updated_at = now(),
    updated_by = NULL
WHERE id;

DO $$
BEGIN
    IF (SELECT platform_fee_percent FROM private.platform_settings WHERE id) <> 0 THEN
        RAISE EXCEPTION 'platform fee was not set to 0';
    END IF;
END;
$$;
