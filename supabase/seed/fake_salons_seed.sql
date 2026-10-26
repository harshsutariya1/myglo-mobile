-- Fake Gold Coast salons for testing.
--
-- Every salon, owner and phone number here is invented. Phone numbers come
-- from ACMA's range reserved for fiction (0491 570 xxx - 0491 579 xxx), so they
-- never reach a real person. Addresses are suburb-level only, with the map pin
-- placed at a random spot near the suburb centre.
--
-- Every seeded account is marked so fake_salons_cleanup.sql can remove it:
--   * email ends in @seed.myglo.test
--   * auth.users.raw_user_meta_data ->> 'seed' = 'fake_salons'
--
-- Accounts get an unknown random password: they cannot be signed in to.
-- Run as the postgres role (SQL editor). Safe to re-run: it does nothing if
-- seeded salons already exist.

DO $$
DECLARE
    v_salon   record;
    v_id      uuid;
    v_lat     double precision;
    v_lng     double precision;
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email LIKE '%@seed.myglo.test') THEN
        RAISE NOTICE 'Seeded salons already exist; run fake_salons_cleanup.sql first to re-seed.';
        RETURN;
    END IF;

    CREATE TEMP TABLE seed_suburbs (suburb text, postcode text, lat double precision, lng double precision) ON COMMIT DROP;
    -- Centres sit a little inland on coastal suburbs so the random jitter stays on land.
    INSERT INTO seed_suburbs VALUES
        ('Southport',        '4215', -27.9670, 153.4000),
        ('Surfers Paradise', '4217', -28.0000, 153.4240),
        ('Broadbeach',       '4218', -28.0330, 153.4270),
        ('Mermaid Beach',    '4218', -28.0480, 153.4320),
        ('Burleigh Heads',   '4220', -28.0900, 153.4430),
        ('Palm Beach',       '4221', -28.1140, 153.4580),
        ('Currumbin Waters', '4223', -28.1500, 153.4700),
        ('Tugun',            '4224', -28.1450, 153.4900),
        ('Coolangatta',      '4225', -28.1710, 153.5280),
        ('Robina',           '4226', -28.0780, 153.3850),
        ('Varsity Lakes',    '4227', -28.0880, 153.4120),
        ('Mudgeeraba',       '4213', -28.0820, 153.3640),
        ('Carrara',          '4211', -28.0200, 153.3650),
        ('Nerang',           '4211', -27.9940, 153.3360),
        ('Ashmore',          '4214', -27.9880, 153.3760),
        ('Benowa',           '4217', -28.0050, 153.3880),
        ('Labrador',         '4215', -27.9440, 153.3950),
        ('Runaway Bay',      '4216', -27.9130, 153.3920),
        ('Helensvale',       '4212', -27.9180, 153.3330),
        ('Hope Island',      '4212', -27.8700, 153.3550),
        ('Upper Coomera',    '4209', -27.8730, 153.3000),
        ('Pimpama',          '4209', -27.8180, 153.3000);

    CREATE TEMP TABLE seed_salons (n int, salon text, kind text, first_name text, last_name text, phone text, bio text) ON COMMIT DROP;
    INSERT INTO seed_salons VALUES
        ( 1, 'Lumen & Lather Hair Studio', 'hair',    'Tessa',   'Marlowe',   '0491570156', 'Colour-focused hair studio known for soft balayage and lived-in blondes. Relaxed vibe, great coffee.'),
        ( 2, 'Tidewater Tress Co.',        'hair',    'Ruby',    'Calloway',  '0491570157', 'Cuts, colour and blow-waves for every hair type. We love a big transformation.'),
        ( 3, 'Velvet Wattle Hair',         'hair',    'Imogen',  'Hartley',   '0491570158', 'Boutique two-chair salon specialising in curly cuts and vivid colour.'),
        ( 4, 'Driftwood Barber Room',      'barber',  'Declan',  'Ashby',     '0491570159', 'Classic and modern barbering. Skin fades, beard sculpting and hot towel shaves.'),
        ( 5, 'Sharp Tide Barbers',         'barber',  'Mateo',   'Kerrigan',  '0491570110', 'Walk-ins welcome, bookings preferred. Clean fades and sharp lines since day one.'),
        ( 6, 'Mango Moon Nails',           'nails',   'Lily',    'Tran',      '0491570313', 'Gel, BIAB and nail art in a bright, friendly space. Hygiene is our top priority.'),
        ( 7, 'Coral Polish Nail Lounge',   'nails',   'Sienna',  'Okafor',    '0491570737', 'Luxury manicures and pedicures with massage chairs and a tropical playlist.'),
        ( 8, 'Gilded Gum Lash Lounge',     'lashes',  'Chloe',   'Westbrook', '0491571266', 'Lash extensions, lifts and brow lamination by certified technicians.'),
        ( 9, 'Bluebottle Brow Bar',        'lashes',  'Ava',     'Pennington','0491571491', 'Brows are our obsession: shaping, tinting, lamination and henna brows.'),
        (10, 'Fernleaf Beauty Bar',        'beauty',  'Grace',   'Holloway',  '0491571804', 'All-round beauty clinic for waxing, tinting, facials and spray tans.'),
        (11, 'Pandanus Skin Studio',       'skin',    'Nadia',   'Castellano','0491572549', 'Results-driven skin treatments: peels, microneedling and LED therapy.'),
        (12, 'Seaglass Skin & Body',       'skin',    'Harper',  'Lindqvist', '0491572665', 'Calming facials and body treatments using Australian botanical products.'),
        (13, 'Frangipani Day Spa',         'massage', 'Mia',     'Delacroix', '0491572983', 'Escape for an hour. Remedial, relaxation and hot stone massage plus facials.'),
        (14, 'Hinterland Hands Massage',   'massage', 'Oliver',  'Branson',   '0491573770', 'Remedial and sports massage for tight muscles and active lifestyles.'),
        (15, 'Golden Hour Makeup Co.',     'makeup',  'Zara',    'Whitfield', '0491573087', 'Bridal and event makeup artist. Studio appointments or we come to you.'),
        (16, 'Paper Daisy Bridal Beauty',  'makeup',  'Eloise',  'Fairbairn', '0491574118', 'Soft, glowing bridal makeup and hair styling for the whole party.'),
        (17, 'Saltbush Hair & Beauty',     'multi',   'Jasmine', 'Rowntree',  '0491574632', 'Your local one-stop salon for hair, brows, lashes and nails.'),
        (18, 'Lagoon Lane Salon',          'multi',   'Freya',   'Montague',  '0491575254', 'Family-friendly salon doing everything from kids cuts to full colour.'),
        (19, 'Pebble & Pearl Studio',      'hair',    'Willow',  'Ainsworth', '0491575789', 'Precision cutting and blonde specialists. Extensions by consultation.'),
        (20, 'Kingfisher Grooming Co.',    'barber',  'Hugo',    'Sandoval',  '0491576398', 'Modern grooming for men and boys. Cuts, beards and scalp treatments.');

    -- kind, category, name, description, price (AUD), minutes
    CREATE TEMP TABLE seed_services (kind text, category text, name text, description text, price numeric, minutes int) ON COMMIT DROP;
    INSERT INTO seed_services VALUES
        ('hair',    'Hair',           'Women''s cut & blow-dry',    'Consultation, wash, precision cut and blow-dry finish.',               85,  60),
        ('hair',    'Hair',           'Men''s cut',                  'Scissor or clipper cut with wash and style.',                            45,  30),
        ('hair',    'Hair',           'Blow-dry & style',            'Wash and a bouncy or sleek blow-dry.',                                   55,  45),
        ('hair',    'Hair',           'Root colour touch-up',        'Permanent colour on regrowth up to 3 cm.',                               95,  90),
        ('hair',    'Hair',           'Half head foils',             'Foil highlights through the top and sides, toner included.',            165, 120),
        ('hair',    'Hair',           'Balayage',                    'Hand-painted lightening with toner and blow-dry.',                     260, 180),
        ('hair',    'Hair',           'Keratin smoothing treatment', 'Frizz-reducing treatment lasting up to 3 months.',                     280, 150),
        ('hair',    'Hair',           'Kids cut (under 12)',         'Quick, fun cut for little ones.',                                        30,  30),
        ('barber',  'Barbering',      'Skin fade',                   'Fade down to the skin, styled finish.',                                  45,  40),
        ('barber',  'Barbering',      'Classic scissor cut',         'Traditional scissor cut and style.',                                     40,  30),
        ('barber',  'Barbering',      'Beard trim & shape',          'Clipper and razor beard shaping with line-up.',                          25,  20),
        ('barber',  'Barbering',      'Cut & beard combo',           'Any haircut plus a full beard trim.',                                    60,  50),
        ('barber',  'Barbering',      'Hot towel shave',             'Traditional straight razor shave with hot towels.',                      45,  30),
        ('barber',  'Barbering',      'Kids cut (under 12)',         'Clipper or scissor cut for kids.',                                       28,  25),
        ('nails',   'Nails',          'Gel manicure',                'Shape, cuticle care and gel colour.',                                    50,  45),
        ('nails',   'Nails',          'BIAB overlay',                'Builder gel on natural nails for strength.',                             65,  60),
        ('nails',   'Nails',          'Acrylic full set',            'Acrylic extensions with gel colour.',                                    80,  75),
        ('nails',   'Nails',          'Gel pedicure',                'Soak, scrub, cuticle care and gel colour.',                              60,  60),
        ('nails',   'Nails',          'Nail art (per set)',          'Hand-painted designs, chrome or French.',                                20,  20),
        ('nails',   'Nails',          'Gel removal',                 'Gentle soak-off and nail tidy.',                                         20,  20),
        ('lashes',  'Lashes',         'Classic lash full set',       'One extension per natural lash for a natural look.',                   120,  90),
        ('lashes',  'Lashes',         'Volume lash full set',        'Handmade fans for a fuller, fluffier look.',                           160, 120),
        ('lashes',  'Lashes',         'Lash infill (2 weeks)',       'Infill within 14 days of your last set.',                               70,  60),
        ('lashes',  'Lashes',         'Lash lift & tint',            'Curl and tint your natural lashes.',                                     85,  60),
        ('lashes',  'Brows',          'Brow shape & tint',           'Wax, tweeze and tint to suit your face.',                                45,  30),
        ('lashes',  'Brows',          'Brow lamination',             'Brushed-up brows with shape and tint.',                                  85,  50),
        ('beauty',  'Waxing',         'Brow wax',                    'Clean shape with wax and tweeze.',                                       22,  15),
        ('beauty',  'Waxing',         'Full leg wax',                'Hot or strip wax from ankle to thigh.',                                  65,  45),
        ('beauty',  'Waxing',         'Brazilian wax',               'Hot wax, gentle on sensitive skin.',                                     60,  30),
        ('beauty',  'Waxing',         'Underarm wax',                'Quick hot wax.',                                                         20,  15),
        ('beauty',  'Tanning',        'Spray tan',                   'Custom-mixed organic spray tan.',                                        45,  20),
        ('beauty',  'Skin',           'Express facial',              'Cleanse, exfoliate, mask and hydrate.',                                  70,  30),
        ('beauty',  'Brows',          'Brow & lash tint',            'Tint for brows and lashes.',                                             40,  30),
        ('skin',    'Skin',           'Signature facial',            'Customised facial with extractions and massage.',                      130,  60),
        ('skin',    'Skin',           'Chemical peel',               'Resurfacing peel matched to your skin concerns.',                      150,  45),
        ('skin',    'Skin',           'Microneedling',               'Collagen induction for texture and scarring.',                         280,  75),
        ('skin',    'Skin',           'LED light therapy',           'Red and blue light to calm and repair skin.',                            60,  30),
        ('skin',    'Skin',           'Dermaplaning',                'Removes fluff and dead skin for a smooth finish.',                       95,  45),
        ('skin',    'Skin',           'Skin consultation',           'Skin analysis and a home-care plan.',                                    40,  30),
        ('massage', 'Massage',        'Relaxation massage (60 min)', 'Full-body flowing massage.',                                           110,  60),
        ('massage', 'Massage',        'Remedial massage (60 min)',   'Targeted deep tissue work on problem areas.',                          120,  60),
        ('massage', 'Massage',        'Remedial massage (90 min)',   'Extended remedial session.',                                           165,  90),
        ('massage', 'Massage',        'Hot stone massage',           'Heated basalt stones to melt tension.',                                140,  75),
        ('massage', 'Massage',        'Pregnancy massage',           'Side-lying massage for mums-to-be (2nd trimester+).',                  115,  60),
        ('massage', 'Massage',        'Back, neck & shoulders',      'Quick tension fix for desk workers.',                                    70,  30),
        ('makeup',  'Makeup',         'Event makeup',                'Full glam or soft glam for any occasion. Lashes included.',            120,  60),
        ('makeup',  'Makeup',         'Bridal makeup',               'Long-wear bridal makeup with lashes and touch-up kit.',                220,  90),
        ('makeup',  'Makeup',         'Bridal trial',                'Try your bridal look before the big day.',                             150,  90),
        ('makeup',  'Makeup',         'Formal makeup',               'Glam for formals and graduations.',                                    100,  60),
        ('makeup',  'Hair',           'Hair up-style',               'Braids, buns or Hollywood waves.',                                      95,  60),
        ('makeup',  'Makeup',         'Makeup lesson',               'One-on-one lesson with a personalised routine.',                       130,  90),
        ('multi',   'Hair',           'Women''s cut & blow-dry',    'Wash, cut and blow-dry.',                                                80,  60),
        ('multi',   'Hair',           'Men''s cut',                  'Wash, cut and style.',                                                   40,  30),
        ('multi',   'Hair',           'Global colour',               'All-over permanent colour with blow-dry.',                             140, 120),
        ('multi',   'Brows',          'Brow shape & tint',           'Wax and tint for defined brows.',                                        42,  30),
        ('multi',   'Lashes',         'Lash lift & tint',            'Natural lash curl with tint.',                                           80,  60),
        ('multi',   'Nails',          'Gel manicure',                'Shape, cuticle care and gel colour.',                                    48,  45),
        ('multi',   'Waxing',         'Half leg wax',                'Knee to ankle.',                                                         40,  30);

    FOR v_salon IN
        SELECT s.*, sub.suburb, sub.postcode, sub.lat, sub.lng
        FROM seed_salons s
        JOIN (SELECT *, row_number() OVER (ORDER BY random()) AS rn FROM seed_suburbs) sub ON sub.rn = s.n
        ORDER BY s.n
    LOOP
        v_id  := gen_random_uuid();
        -- About +/- 450 m north-south and +/- 300 m east-west of the suburb centre.
        v_lat := v_salon.lat + (random() - 0.5) * 0.008;
        v_lng := v_salon.lng + (random() - 0.5) * 0.006;

        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
            confirmation_token, recovery_token, email_change_token_new, email_change
        ) VALUES (
            '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
            format('seed-salon-%s@seed.myglo.test', lpad(v_salon.n::text, 2, '0')),
            extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
            now(),
            '{"provider": "email", "providers": ["email"]}'::jsonb,
            jsonb_build_object('seed', 'fake_salons', 'role', 'provider'),
            now(), now(), '', '', '', ''
        );

        INSERT INTO public.profiles (
            id, role, first_name, last_name, email, phone_number,
            is_email_public, is_phone_public, bio, provider_name, address_text, coordinates
        ) VALUES (
            v_id, 'provider', v_salon.first_name, v_salon.last_name,
            format('seed-salon-%s@seed.myglo.test', lpad(v_salon.n::text, 2, '0')),
            v_salon.phone, false, true, v_salon.bio, v_salon.salon,
            format('%s QLD %s', v_salon.suburb, v_salon.postcode),
            public.st_setsrid(public.st_makepoint(v_lng, v_lat), 4326)::public.geography
        );

        -- Prices vary a little between salons and round to the nearest $5.
        INSERT INTO public.services (provider_id, name, description, price, duration_minutes, category)
        SELECT v_id, sv.name, sv.description,
               greatest(5, round(sv.price * (0.85 + random() * 0.35) / 5) * 5),
               sv.minutes, sv.category
        FROM seed_services sv
        WHERE sv.kind = v_salon.kind;

        -- Opening hours (ISO weekday, 1 = Monday). Three patterns so availability differs.
        INSERT INTO public.provider_working_hours (provider_id, weekday, opens_at, closes_at)
        SELECT v_id, d.weekday, d.opens_at, d.closes_at
        FROM (VALUES
            -- Tue-Sat with a late Thursday
            (0, 2, time '09:00', time '17:30'), (0, 3, '09:00', '17:30'), (0, 4, '09:00', '20:00'),
            (0, 5, '09:00', '17:30'), (0, 6, '08:30', '15:00'),
            -- Mon-Fri plus Saturday morning
            (1, 1, '09:00', '17:00'), (1, 2, '09:00', '17:00'), (1, 3, '09:00', '17:00'),
            (1, 4, '09:00', '19:00'), (1, 5, '09:00', '17:00'), (1, 6, '08:00', '13:00'),
            -- Seven days, shorter weekends
            (2, 1, '10:00', '18:00'), (2, 2, '10:00', '18:00'), (2, 3, '10:00', '18:00'),
            (2, 4, '10:00', '20:00'), (2, 5, '10:00', '18:00'), (2, 6, '09:00', '16:00'),
            (2, 7, '10:00', '15:00')
        ) AS d(pattern, weekday, opens_at, closes_at)
        WHERE d.pattern = v_salon.n % 3;

        -- The profiles insert trigger already created default booking settings.
        UPDATE public.provider_booking_settings
        SET requires_approval         = (v_salon.n % 4 = 0),
            slot_interval_minutes     = CASE WHEN v_salon.kind IN ('barber', 'nails') THEN 15 ELSE 30 END,
            buffer_minutes            = CASE WHEN v_salon.kind IN ('massage', 'skin') THEN 15 ELSE 0 END,
            cancellation_window_hours = 24,
            offers_mobile             = (v_salon.kind = 'makeup'),
            travel_radius_km          = CASE WHEN v_salon.kind = 'makeup' THEN 30 END
        WHERE provider_id = v_id;
    END LOOP;
END
$$;
