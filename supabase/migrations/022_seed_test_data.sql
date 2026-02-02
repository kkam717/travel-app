-- =========================================================
-- Travel Itinerary App — Test Data (Supabase / Postgres)
-- Creates 6 test users in auth, profiles, 18 public itineraries, stops
--
-- Test users (email / password):
--   seed-amelia@travel-app.dev, seed-kenji@travel-app.dev, ... / TestPassword123!
--
-- Run: supabase db push  (or paste in Supabase Dashboard SQL Editor)
-- =========================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Get instance_id from existing auth user, or use default for fresh DB
DO $$
DECLARE
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
  v_user_id uuid;
  v_email text;
  v_name text;
  v_travel_mode text;
  v_current_city text;
  v_visited_countries text[];
  v_travel_styles text[];
  v_users jsonb := '[
    {"id":"11111111-1111-1111-1111-111111111111","email":"seed-amelia@travel-app.dev","name":"Amelia Carter","current_city":"London","visited_countries":["GB","FR","ES","IT","US"],"travel_styles":["Culture","Food","Nightlife"],"travel_mode":"standard"},
    {"id":"22222222-2222-2222-2222-222222222222","email":"seed-kenji@travel-app.dev","name":"Kenji Nakamura","current_city":"Tokyo","visited_countries":["JP","KR","TW","TH","SG"],"travel_styles":["Food","Culture","Nightlife"],"travel_mode":"standard"},
    {"id":"33333333-3333-3333-3333-333333333333","email":"seed-sofia@travel-app.dev","name":"Sofia Moretti","current_city":"Milan","visited_countries":["IT","FR","CH","AT","DE"],"travel_styles":["Culture","Relax","Food"],"travel_mode":"luxury"},
    {"id":"44444444-4444-4444-4444-444444444444","email":"seed-ethan@travel-app.dev","name":"Ethan Brooks","current_city":"New York","visited_countries":["US","CA","MX","GB","PT"],"travel_styles":["Adventure","Food","Nightlife"],"travel_mode":"budget"},
    {"id":"55555555-5555-5555-5555-555555555555","email":"seed-nina@travel-app.dev","name":"Nina Larsen","current_city":"Copenhagen","visited_countries":["DK","SE","NO","DE","NL"],"travel_styles":["Nature","Culture","Relax"],"travel_mode":"standard"},
    {"id":"66666666-6666-6666-6666-666666666666","email":"seed-mateo@travel-app.dev","name":"Mateo Alvarez","current_city":"Barcelona","visited_countries":["ES","FR","PT","MA","US"],"travel_styles":["Food","Culture","Relax"],"travel_mode":"budget"}
  ]'::jsonb;
  v_user jsonb;
BEGIN
  SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000';
  END IF;

  FOR v_user IN SELECT * FROM jsonb_array_elements(v_users)
  LOOP
    v_user_id := (v_user->>'id')::uuid;
    v_email := v_user->>'email';
    v_name := v_user->>'name';
    v_current_city := v_user->>'current_city';
    v_travel_mode := v_user->>'travel_mode';
    v_visited_countries := ARRAY(SELECT jsonb_array_elements_text(v_user->'visited_countries'));
    v_travel_styles := ARRAY(SELECT jsonb_array_elements_text(v_user->'travel_styles'));

    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) VALUES (
      v_user_id,
      v_instance_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt('TestPassword123!', extensions.gen_salt('bf')),
      NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('name', v_name),
      NOW(),
      NOW()
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      v_user_id,
      v_user_id,
      format('{"sub":"%s","email":"%s"}', v_user_id, v_email)::jsonb,
      'email',
      v_user_id::text,
      NOW(),
      NOW(),
      NOW()
    ) ON CONFLICT DO NOTHING;

    UPDATE profiles SET
      name = v_name,
      current_city = v_current_city,
      visited_countries = v_visited_countries,
      travel_styles = v_travel_styles,
      travel_mode = v_travel_mode,
      onboarding_complete = TRUE,
      updated_at = NOW()
    WHERE id = v_user_id;
  END LOOP;
END $$;

-- -----------------------------------
-- Public itineraries (18 total)
-- -----------------------------------
INSERT INTO itineraries (id, author_id, title, destination, days_count, style_tags, mode, visibility)
VALUES
  ('aaaa0000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Weekend in Paris',                 'France',          3,  ARRAY['Culture','Food'],                'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'London Museums + Food Crawl',     'United Kingdom',  4,  ARRAY['Culture','Food'],                'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'Tokyo Essentials',                'Japan',           5,  ARRAY['Food','Culture','Nightlife'],     'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'Kyoto Temples + Nature',          'Japan',           4,  ARRAY['Culture','Nature','Relax'],       'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 'Milan to Lake Como Escape',       'Italy',           4,  ARRAY['Culture','Relax'],               'luxury',   'public'),
  ('aaaa0000-0000-0000-0000-000000000006', '33333333-3333-3333-3333-333333333333', 'Rome Classics in 5 Days',         'Italy',           5,  ARRAY['Culture','Food'],                'luxury',   'public'),
  ('aaaa0000-0000-0000-0000-000000000007', '44444444-4444-4444-4444-444444444444', 'NYC on a Budget',                 'USA',             4,  ARRAY['Culture','Food','Nightlife'],     'budget',  'public'),
  ('aaaa0000-0000-0000-0000-000000000008', '44444444-4444-4444-4444-444444444444', 'Mexico City Street Food Week',    'Mexico',          7,  ARRAY['Food','Culture','Nightlife'],     'budget',  'public'),
  ('aaaa0000-0000-0000-0000-000000000009', '55555555-5555-5555-5555-555555555555', 'Copenhagen Design + Cafés',       'Denmark',         3,  ARRAY['Culture','Relax','Food'],         'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000010', '55555555-5555-5555-5555-555555555555', 'Oslo + Fjord Nature Break',       'Norway',          5,  ARRAY['Nature','Adventure','Relax'],     'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000011', '66666666-6666-6666-6666-666666666666', 'Barcelona Tapas + Beaches',       'Spain',           4,  ARRAY['Food','Relax','Nightlife'],       'budget',  'public'),
  ('aaaa0000-0000-0000-0000-000000000012', '66666666-6666-6666-6666-666666666666', 'Andalusia Road Trip',             'Spain',           8,  ARRAY['Culture','Food','Adventure'],     'budget',  'public'),
  ('aaaa0000-0000-0000-0000-000000000013', '11111111-1111-1111-1111-111111111111', 'Amsterdam Long Weekend',          'Netherlands',     3,  ARRAY['Culture','Nightlife','Food'],     'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000014', '22222222-2222-2222-2222-222222222222', 'Seoul Highlights',                'South Korea',     5,  ARRAY['Food','Culture','Nightlife'],     'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000015', '33333333-3333-3333-3333-333333333333', 'Swiss Alps Luxury Reset',         'Switzerland',     6,  ARRAY['Nature','Relax'],                 'luxury',  'public'),
  ('aaaa0000-0000-0000-0000-000000000016', '44444444-4444-4444-4444-444444444444', 'Lisbon + Sintra Explorer',        'Portugal',        5,  ARRAY['Culture','Food','Adventure'],     'budget',  'public'),
  ('aaaa0000-0000-0000-0000-000000000017', '55555555-5555-5555-5555-555555555555', 'Berlin Art + Nightlife',          'Germany',         4,  ARRAY['Culture','Nightlife','Food'],     'standard', 'public'),
  ('aaaa0000-0000-0000-0000-000000000018', '66666666-6666-6666-6666-666666666666', 'Morocco: Marrakech to Desert',    'Morocco',        10,  ARRAY['Culture','Adventure','Food'],     'standard', 'public')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- Itinerary stops (3–8 stops per itinerary)
-- ------------------------------------------------------------
INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, lat, lng)
VALUES
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 0, 'Paris',                   'location', NULL,        48.8566,  2.3522),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 1, 'Louvre Museum',           'venue',    'experience',48.8606,  2.3376),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 2, 'Le Marais',               'venue',    'experience',48.8590,  2.3626),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 2, 0, 'Eiffel Tower',            'venue',    'experience',48.8584,  2.2945),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 2, 1, 'Le Jules Verne',          'venue',    'restaurant',48.8583,  2.2945),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 3, 0, 'Montmartre',              'venue',    'experience',48.8867,  2.3431),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 1, 0, 'London',                  'location', NULL,        51.5074, -0.1278),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 1, 1, 'British Museum',          'venue',    'experience',51.5194, -0.1270),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 2, 0, 'Borough Market',          'venue',    'experience',51.5055, -0.0910),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 2, 1, 'Padella Borough Market',  'venue',    'restaurant',51.5055, -0.0912),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 3, 0, 'Tate Modern',             'venue',    'experience',51.5076, -0.0994),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000002', 4, 0, 'The Connaught',           'venue',    'hotel',     51.5118, -0.1503),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 1, 0, 'Tokyo',                   'location', NULL,        35.6762, 139.6503),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 1, 1, 'Senso-ji Temple',         'venue',    'experience',35.7148, 139.7967),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 2, 0, 'Tsukiji Outer Market',     'venue',    'experience',35.6655, 139.7708),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 2, 1, 'Sushi Dai',               'venue',    'restaurant',35.6653, 139.7707),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 3, 0, 'Meiji Jingu',             'venue',    'experience',35.6764, 139.6993),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 4, 0, 'Shibuya Crossing',        'venue',    'experience',35.6595, 139.7005),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 5, 0, 'Golden Gai',              'venue',    'experience',35.6954, 139.7040),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000004', 1, 0, 'Kyoto',                   'location', NULL,        35.0116, 135.7681),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000004', 1, 1, 'Fushimi Inari Taisha',    'venue',    'experience',34.9671, 135.7727),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000004', 2, 0, 'Kiyomizu-dera',           'venue',    'experience',34.9949, 135.7850),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000004', 3, 0, 'Arashiyama Bamboo Grove',  'venue',    'experience',35.0170, 135.6730),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000004', 4, 0, 'Gion District',           'venue',    'experience',35.0037, 135.7788),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 1, 0, 'Milan',                   'location', NULL,        45.4642,  9.1900),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 1, 1, 'Duomo di Milano',         'venue',    'experience',45.4641,  9.1919),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 2, 0, 'Galleria Vittorio Emanuele II','venue','experience',45.4660,  9.1900),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 3, 0, 'Como',                    'location', NULL,        45.8081,  9.0852),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 3, 1, 'Villa Olmo',              'venue',    'experience',45.8105,  9.0746),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 4, 0, 'Bellagio',                'location', NULL,        45.9870,  9.2610),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 1, 0, 'Rome',                    'location', NULL,        41.9028, 12.4964),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 1, 1, 'Colosseum',               'venue',    'experience',41.8902, 12.4922),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 2, 0, 'Roman Forum',             'venue',    'experience',41.8925, 12.4853),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 3, 0, 'Vatican Museums',         'venue',    'experience',41.9065, 12.4536),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 4, 0, 'Trastevere',              'venue',    'experience',41.8897, 12.4709),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 4, 1, 'Da Enzo al 29',           'venue',    'restaurant',41.8885, 12.4720),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000006', 5, 0, 'Hotel de Russie',         'venue',    'hotel',     41.9106, 12.4788),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 1, 0, 'New York City',           'location', NULL,        40.7128, -74.0060),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 1, 1, 'Brooklyn Bridge',         'venue',    'experience',40.7061, -73.9969),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 2, 0, 'Central Park',            'venue',    'experience',40.7829, -73.9654),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 3, 0, 'The High Line',           'venue',    'experience',40.7480, -74.0048),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 3, 1, 'Katz''s Delicatessen',    'venue',    'restaurant',40.7222, -73.9874),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000007', 4, 0, 'Times Square',            'venue',    'experience',40.7580, -73.9855),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 1, 0, 'Mexico City',             'location', NULL,        19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 1, 1, 'Zócalo',                  'venue',    'experience',19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 2, 0, 'Museo Frida Kahlo',       'venue',    'experience',19.3550, -99.1620),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 3, 0, 'Mercado de Coyoacán',     'venue',    'experience',19.3494, -99.1610),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 4, 0, 'Taquería Orinoco',        'venue',    'restaurant',19.4256, -99.1679),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 5, 0, 'Castillo de Chapultepec', 'venue',    'experience',19.4204, -99.1819),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 6, 0, 'Roma Norte',              'venue',    'experience',19.4103, -99.1625),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 7, 0, 'Camino Real Polanco',     'venue',    'hotel',     19.4286, -99.1966),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000009', 1, 0, 'Copenhagen',              'location', NULL,        55.6761, 12.5683),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000009', 1, 1, 'Nyhavn',                  'venue',    'experience',55.6798, 12.5916),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000009', 2, 0, 'Tivoli Gardens',          'venue',    'experience',55.6737, 12.5681),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000009', 2, 1, 'Torvehallerne',           'venue',    'experience',55.6836, 12.5717),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000009', 3, 0, 'Noma',                    'venue',    'restaurant',55.6811, 12.6003),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 1, 0, 'Oslo',                    'location', NULL,        59.9139, 10.7522),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 1, 1, 'Vigeland Park',           'venue',    'experience',59.9275, 10.7000),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 2, 0, 'Oslo Opera House',        'venue',    'experience',59.9076, 10.7532),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 3, 0, 'Aker Brygge',             'venue',    'experience',59.9096, 10.7252),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 4, 0, 'Bygdøy Peninsula',        'venue',    'experience',59.9040, 10.6840),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000010', 5, 0, 'Frognerseteren',          'venue',    'experience',59.9819, 10.6763),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 1, 0, 'Barcelona',               'location', NULL,        41.3851,  2.1734),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 1, 1, 'Sagrada Família',         'venue',    'experience',41.4036,  2.1744),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 2, 0, 'Barceloneta Beach',       'venue',    'experience',41.3786,  2.1925),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 3, 0, 'La Boqueria',             'venue',    'experience',41.3817,  2.1715),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 3, 1, 'El Xampanyet',            'venue',    'restaurant',41.3856,  2.1839),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000011', 4, 0, 'Hotel Arts Barcelona',    'venue',    'hotel',     41.3871,  2.1973),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 1, 0, 'Seville',                 'location', NULL,        37.3891, -5.9845),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 1, 1, 'Real Alcázar of Seville', 'venue',    'experience',37.3831, -5.9903),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 3, 0, 'Córdoba',                 'location', NULL,        37.8882, -4.7794),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 3, 1, 'Mezquita-Catedral',       'venue',    'experience',37.8790, -4.7796),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 5, 0, 'Granada',                 'location', NULL,        37.1773, -3.5986),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 5, 1, 'Alhambra',                'venue',    'experience',37.1761, -3.5881),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 7, 0, 'Málaga',                  'location', NULL,        36.7213, -4.4214),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 7, 1, 'Mercado Central de Atarazanas','venue','experience',36.7217, -4.4240),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000013', 1, 0, 'Amsterdam',               'location', NULL,        52.3676,  4.9041),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000013', 1, 1, 'Rijksmuseum',             'venue',    'experience',52.3600,  4.8852),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000013', 2, 0, 'Anne Frank House',        'venue',    'experience',52.3752,  4.8839),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000013', 2, 1, 'De Kas',                  'venue',    'restaurant',52.3602,  4.9187),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000013', 3, 0, 'Jordaan',                 'venue',    'experience',52.3730,  4.8811),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 1, 0, 'Seoul',                   'location', NULL,        37.5665, 126.9780),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 1, 1, 'Gyeongbokgung Palace',    'venue',    'experience',37.5796, 126.9770),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 2, 0, 'Bukchon Hanok Village',   'venue',    'experience',37.5826, 126.9830),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 3, 0, 'Myeongdong',              'venue',    'experience',37.5636, 126.9867),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 4, 0, 'Gwangjang Market',        'venue',    'experience',37.5700, 127.0000),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 4, 1, 'Jinokhwa Halmae Wonjo Dakhanmari','venue','restaurant',37.5704, 127.0016),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000014', 5, 0, 'N Seoul Tower',           'venue',    'experience',37.5512, 126.9882),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 1, 0, 'Zermatt',                 'location', NULL,        46.0207,  7.7491),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 1, 1, 'Matterhorn Glacier Paradise','venue',   'experience',46.0060,  7.7794),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 2, 0, 'Gornergrat',              'venue',    'experience',45.9830,  7.7840),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 3, 0, 'St. Moritz',              'location', NULL,        46.4983,  9.8390),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 4, 0, 'Badrutt''s Palace Hotel', 'venue',    'hotel',     46.4978,  9.8387),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000015', 6, 0, 'Lake St. Moritz',         'venue',    'experience',46.4937,  9.8432),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 1, 0, 'Lisbon',                  'location', NULL,        38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 1, 1, 'Belém Tower',             'venue',    'experience',38.6916, -9.2150),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 2, 0, 'Time Out Market Lisboa',  'venue',    'experience',38.7077, -9.1456),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 3, 0, 'Sintra',                  'location', NULL,        38.8029, -9.3817),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 3, 1, 'Pena Palace',             'venue',    'experience',38.7876, -9.3904),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 4, 0, 'Castelo de São Jorge',    'venue',    'experience',38.7139, -9.1335),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000017', 1, 0, 'Berlin',                  'location', NULL,        52.5200, 13.4050),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000017', 1, 1, 'Brandenburg Gate',        'venue',    'experience',52.5163, 13.3777),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000017', 2, 0, 'East Side Gallery',       'venue',    'experience',52.5050, 13.4396),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000017', 3, 0, 'Pergamon Museum',         'venue',    'experience',52.5212, 13.3969),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000017', 4, 0, 'Berghain',                'venue',    'experience',52.5111, 13.4433),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 1, 0, 'Marrakech',               'location', NULL,        31.6295, -7.9811),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 1, 1, 'Jemaa el-Fnaa',           'venue',    'experience',31.6258, -7.9892),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 2, 0, 'Bahia Palace',            'venue',    'experience',31.6219, -7.9846),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 4, 0, 'Aït Benhaddou',           'venue',    'experience',31.0470, -7.1317),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 6, 0, 'Ouarzazate',              'location', NULL,        30.9335, -6.9370),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 7, 0, 'Merzouga',                'location', NULL,        31.0994, -4.0120),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 8, 0, 'Erg Chebbi Dunes',        'venue',    'experience',31.1236, -4.0196),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000018', 9, 0, 'Riad Kniza',              'venue',    'hotel',     31.6348, -7.9990);
