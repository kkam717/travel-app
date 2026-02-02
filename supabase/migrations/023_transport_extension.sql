-- =========================================================
-- EXTENSION: Multi-city/country trips + transport_transitions (JSONB)
-- Tables: itineraries, itinerary_stops
-- Uses existing itinerary UUIDs aaaa...001 etc. and author_ids from 022_seed_test_data
--
-- Assumption: itineraries table has transport_transitions column (021_itinerary_transport_transitions)
-- =========================================================

-- ---------------------------------------------------------
-- A) Update 6 existing itineraries to be multi-city/country
--    + add transport_transitions JSONB
-- ---------------------------------------------------------

-- 1) aaaa...001 — Weekend in Paris -> Paris → London → Edinburgh (5 days)
UPDATE itineraries
SET
  title = 'Paris → London → Edinburgh (5 days)',
  destination = 'France / United Kingdom',
  days_count = 5,
  style_tags = ARRAY['Culture','Food'],
  mode = 'standard',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"train","description":"Eurostar Paris Gare du Nord to London St Pancras"},
    {"type":"unknown"},
    {"type":"train","description":"LNER London King''s Cross to Edinburgh Waverley"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000001';

-- 2) aaaa...003 — Tokyo Essentials -> Tokyo → Kyoto → Osaka (7 days)
UPDATE itineraries
SET
  title = 'Tokyo → Kyoto → Osaka (7 days)',
  destination = 'Japan',
  days_count = 7,
  style_tags = ARRAY['Food','Culture','Nightlife'],
  mode = 'standard',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"train","description":"Shinkansen Tokyo to Kyoto"},
    {"type":"unknown"},
    {"type":"train","description":"JR Kyoto to Osaka"},
    {"type":"unknown"},
    {"type":"unknown"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000003';

-- 3) aaaa...005 — Milan to Lake Como Escape -> Milan → Como → Lugano (5 days)
UPDATE itineraries
SET
  title = 'Milan → Lake Como → Lugano (5 days)',
  destination = 'Italy / Switzerland',
  days_count = 5,
  style_tags = ARRAY['Culture','Relax'],
  mode = 'luxury',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"train","description":"Milan Centrale to Como S. Giovanni"},
    {"type":"unknown"},
    {"type":"train","description":"Como S. Giovanni to Lugano (SBB)"},
    {"type":"unknown"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000005';

-- 4) aaaa...008 — Mexico City Street Food Week -> Mexico City → Puebla → Oaxaca (8 days)
UPDATE itineraries
SET
  title = 'Mexico City → Puebla → Oaxaca (8 days)',
  destination = 'Mexico',
  days_count = 8,
  style_tags = ARRAY['Food','Culture','Nightlife'],
  mode = 'budget',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"unknown"},
    {"type":"bus","description":"ADO bus Mexico City to Puebla"},
    {"type":"unknown"},
    {"type":"plane","description":"Flight Puebla (via MEX) to Oaxaca (short hop)"},
    {"type":"unknown"},
    {"type":"unknown"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000008';

-- 5) aaaa...012 — Andalusia Road Trip -> Seville → Córdoba → Granada → Málaga (8 days)
UPDATE itineraries
SET
  title = 'Andalusia: Seville → Córdoba → Granada → Málaga (8 days)',
  destination = 'Spain',
  days_count = 8,
  style_tags = ARRAY['Culture','Food','Adventure'],
  mode = 'budget',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"unknown"},
    {"type":"train","description":"Renfe Seville Santa Justa to Córdoba"},
    {"type":"unknown"},
    {"type":"train","description":"Renfe Córdoba to Granada"},
    {"type":"unknown"},
    {"type":"bus","description":"ALSA Granada to Málaga"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000012';

-- 6) aaaa...016 — Lisbon + Sintra Explorer -> Porto → Lisbon → Sintra (7 days)
UPDATE itineraries
SET
  title = 'Porto → Lisbon → Sintra (7 days)',
  destination = 'Portugal',
  days_count = 7,
  style_tags = ARRAY['Culture','Food','Adventure'],
  mode = 'budget',
  visibility = 'public',
  transport_transitions = '[
    {"type":"unknown"},
    {"type":"train","description":"Alfa Pendular Porto Campanhã to Lisboa Oriente"},
    {"type":"unknown"},
    {"type":"train","description":"CP train Lisbon Rossio to Sintra"},
    {"type":"unknown"},
    {"type":"train","description":"CP train Sintra to Lisbon Rossio"},
    {"type":"unknown"}
  ]'::jsonb
WHERE id = 'aaaa0000-0000-0000-0000-000000000016';


-- ---------------------------------------------------------
-- B) Replace/extend stops for those itineraries
--    (delete existing stops for those itinerary ids, then insert new ordered stops)
-- ---------------------------------------------------------
DELETE FROM itinerary_stops
WHERE itinerary_id IN (
  'aaaa0000-0000-0000-0000-000000000001',
  'aaaa0000-0000-0000-0000-000000000003',
  'aaaa0000-0000-0000-0000-000000000005',
  'aaaa0000-0000-0000-0000-000000000008',
  'aaaa0000-0000-0000-0000-000000000012',
  'aaaa0000-0000-0000-0000-000000000016'
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, lat, lng)
VALUES
  -- =====================================================
  -- aaaa...001 Paris → London → Edinburgh (5 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 0, 'Paris',               'location', NULL,         48.8566,  2.3522),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 1, 'Louvre Museum',       'venue',    'experience', 48.8606,  2.3376),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 1, 2, 'Le Jules Verne',      'venue',    'restaurant', 48.8583,  2.2945),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 2, 0, 'Paris',               'location', NULL,         48.8566,  2.3522),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 2, 1, 'Montmartre',          'venue',    'experience', 48.8867,  2.3431),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 3, 0, 'London',              'location', NULL,         51.5074, -0.1278),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 3, 1, 'British Museum',      'venue',    'experience', 51.5194, -0.1270),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 3, 2, 'Borough Market',      'venue',    'experience', 51.5055, -0.0910),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 4, 0, 'London',              'location', NULL,         51.5074, -0.1278),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 4, 1, 'Tate Modern',         'venue',    'experience', 51.5076, -0.0994),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 5, 0, 'Edinburgh',           'location', NULL,         55.9533, -3.1883),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000001', 5, 1, 'Edinburgh Castle',    'venue',    'experience', 55.9486, -3.1999),

  -- =====================================================
  -- aaaa...003 Tokyo → Kyoto → Osaka (7 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 1, 0, 'Tokyo',               'location', NULL,         35.6762, 139.6503),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 1, 1, 'Senso-ji Temple',     'venue',    'experience', 35.7148, 139.7967),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 2, 0, 'Tokyo',               'location', NULL,         35.6762, 139.6503),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 2, 1, 'Shibuya Crossing',    'venue',    'experience', 35.6595, 139.7005),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 3, 0, 'Kyoto',               'location', NULL,         35.0116, 135.7681),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 3, 1, 'Fushimi Inari Taisha','venue',    'experience', 34.9671, 135.7727),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 4, 0, 'Kyoto',               'location', NULL,         35.0116, 135.7681),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 4, 1, 'Arashiyama Bamboo Grove','venue',  'experience', 35.0170, 135.6730),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 5, 0, 'Osaka',               'location', NULL,         34.6937, 135.5023),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 5, 1, 'Dotonbori',           'venue',    'experience', 34.6687, 135.5016),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 6, 0, 'Osaka',               'location', NULL,         34.6937, 135.5023),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 6, 1, 'Osaka Castle',        'venue',    'experience', 34.6873, 135.5259),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 7, 0, 'Osaka',               'location', NULL,         34.6937, 135.5023),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000003', 7, 1, 'Ichiran Dotonbori',   'venue',    'restaurant', 34.6688, 135.5015),

  -- =====================================================
  -- aaaa...005 Milan → Lake Como → Lugano (5 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 1, 0, 'Milan',               'location', NULL,         45.4642,  9.1900),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 1, 1, 'Duomo di Milano',     'venue',    'experience', 45.4641,  9.1919),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 2, 0, 'Milan',               'location', NULL,         45.4642,  9.1900),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 2, 1, 'Pinacoteca di Brera', 'venue',    'experience', 45.4719,  9.1884),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 3, 0, 'Como',                'location', NULL,         45.8081,  9.0852),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 3, 1, 'Villa Olmo',          'venue',    'experience', 45.8105,  9.0746),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 4, 0, 'Lugano',              'location', NULL,         46.0037,  8.9511),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 4, 1, 'Parco Ciani',         'venue',    'experience', 46.0047,  8.9534),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 5, 0, 'Lugano',              'location', NULL,         46.0037,  8.9511),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000005', 5, 1, 'Splendide Royal',     'venue',    'hotel',      45.9982,  8.9552),

  -- =====================================================
  -- aaaa...008 Mexico City → Puebla → Oaxaca (8 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 1, 0, 'Mexico City',         'location', NULL,         19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 1, 1, 'Zócalo',              'venue',    'experience', 19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 2, 0, 'Mexico City',         'location', NULL,         19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 2, 1, 'Museo Frida Kahlo',   'venue',    'experience', 19.3550, -99.1620),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 3, 0, 'Mexico City',         'location', NULL,         19.4326, -99.1332),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 3, 1, 'Taquería Orinoco',    'venue',    'restaurant', 19.4256, -99.1679),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 4, 0, 'Puebla',              'location', NULL,         19.0414, -98.2063),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 4, 1, 'Zócalo de Puebla',    'venue',    'experience', 19.0433, -98.1980),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 5, 0, 'Puebla',              'location', NULL,         19.0414, -98.2063),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 5, 1, 'El Mural de los Poblanos','venue','restaurant', 19.0444, -98.1986),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 6, 0, 'Oaxaca',              'location', NULL,         17.0732, -96.7266),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 6, 1, 'Templo de Santo Domingo de Guzmán','venue','experience',17.0710,-96.7260),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 7, 0, 'Oaxaca',              'location', NULL,         17.0732, -96.7266),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 7, 1, 'Mercado 20 de Noviembre','venue','experience',  17.0708, -96.7243),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 8, 0, 'Oaxaca',              'location', NULL,         17.0732, -96.7266),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000008', 8, 1, 'Casa Oaxaca',         'venue',    'restaurant', 17.0716, -96.7253),

  -- =====================================================
  -- aaaa...012 Andalusia: Seville → Córdoba → Granada → Málaga (8 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 1, 0, 'Seville',             'location', NULL,         37.3891, -5.9845),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 1, 1, 'Real Alcázar of Seville','venue', 'experience', 37.3831, -5.9903),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 2, 0, 'Seville',             'location', NULL,         37.3891, -5.9845),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 2, 1, 'Seville Cathedral',   'venue',    'experience', 37.3861, -5.9923),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 3, 0, 'Córdoba',             'location', NULL,         37.8882, -4.7794),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 3, 1, 'Mezquita-Catedral',   'venue',    'experience', 37.8790, -4.7796),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 4, 0, 'Córdoba',             'location', NULL,         37.8882, -4.7794),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 4, 1, 'Puente Romano',       'venue',    'experience', 37.8750, -4.7791),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 5, 0, 'Granada',             'location', NULL,         37.1773, -3.5986),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 5, 1, 'Alhambra',            'venue',    'experience', 37.1761, -3.5881),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 6, 0, 'Granada',             'location', NULL,         37.1773, -3.5986),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 6, 1, 'Mirador de San Nicolás','venue',   'experience', 37.1836, -3.5920),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 7, 0, 'Málaga',              'location', NULL,         36.7213, -4.4214),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 7, 1, 'Museo Picasso Málaga','venue',    'experience', 36.7212, -4.4180),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 8, 0, 'Málaga',              'location', NULL,         36.7213, -4.4214),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000012', 8, 1, 'Mercado Central de Atarazanas','venue','experience',36.7217,-4.4240),

  -- =====================================================
  -- aaaa...016 Porto → Lisbon → Sintra (7 days)
  -- =====================================================
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 1, 0, 'Porto',               'location', NULL,         41.1579, -8.6291),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 1, 1, 'Ribeira',             'venue',    'experience', 41.1406, -8.6110),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 2, 0, 'Porto',               'location', NULL,         41.1579, -8.6291),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 2, 1, 'Livraria Lello',      'venue',    'experience', 41.1466, -8.6147),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 3, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 3, 1, 'Belém Tower',         'venue',    'experience', 38.6916, -9.2150),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 4, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 4, 1, 'Time Out Market Lisboa','venue',  'experience', 38.7077, -9.1456),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 5, 0, 'Sintra',              'location', NULL,         38.8029, -9.3817),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 5, 1, 'Pena Palace',         'venue',    'experience', 38.7876, -9.3904),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 6, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 6, 1, 'Alfama',              'venue',    'experience', 38.7110, -9.1291),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 7, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000016', 7, 1, 'Pastéis de Belém',    'venue',    'restaurant', 38.6979, -9.2067);


-- ---------------------------------------------------------
-- C) Add 3 new multi-city itineraries with transport_transitions
-- ---------------------------------------------------------

INSERT INTO itineraries (id, author_id, title, destination, days_count, style_tags, mode, visibility, transport_transitions)
VALUES
  ('aaaa0000-0000-0000-0000-000000000019', '66666666-6666-6666-6666-666666666666',
   'Barcelona → Madrid → Lisbon (9 days)', 'Spain / Portugal', 9,
   ARRAY['Food','Culture','Nightlife'], 'budget', 'public',
   '[
      {"type":"unknown"},
      {"type":"train","description":"AVE Barcelona Sants to Madrid Puerta de Atocha"},
      {"type":"unknown"},
      {"type":"unknown"},
      {"type":"train","description":"Overnight / fast train Madrid to Lisbon (via Badajoz)"},
      {"type":"unknown"},
      {"type":"unknown"},
      {"type":"unknown"}
    ]'::jsonb
  ),
  ('aaaa0000-0000-0000-0000-000000000020', '55555555-5555-5555-5555-555555555555',
   'Copenhagen → Malmö → Stockholm (6 days)', 'Denmark / Sweden', 6,
   ARRAY['Culture','Relax','Food'], 'standard', 'public',
   '[
      {"type":"unknown"},
      {"type":"train","description":"Øresundståg Copenhagen to Malmö"},
      {"type":"unknown"},
      {"type":"train","description":"SJ train Malmö to Stockholm Central"},
      {"type":"unknown"}
    ]'::jsonb
  ),
  ('aaaa0000-0000-0000-0000-000000000021', '44444444-4444-4444-4444-444444444444',
   'NYC → Washington DC → Philadelphia (7 days)', 'USA', 7,
   ARRAY['Culture','Food'], 'budget', 'public',
   '[
      {"type":"unknown"},
      {"type":"train","description":"Amtrak Northeast Regional NYC to Washington DC"},
      {"type":"unknown"},
      {"type":"train","description":"Amtrak Washington DC to Philadelphia 30th Street"},
      {"type":"unknown"},
      {"type":"unknown"}
    ]'::jsonb
  )
ON CONFLICT (id) DO UPDATE SET
  author_id = EXCLUDED.author_id,
  title = EXCLUDED.title,
  destination = EXCLUDED.destination,
  days_count = EXCLUDED.days_count,
  style_tags = EXCLUDED.style_tags,
  mode = EXCLUDED.mode,
  visibility = EXCLUDED.visibility,
  transport_transitions = EXCLUDED.transport_transitions,
  updated_at = NOW();

-- Stops for the 3 new itineraries (delete first for idempotency)
DELETE FROM itinerary_stops
WHERE itinerary_id IN (
  'aaaa0000-0000-0000-0000-000000000019',
  'aaaa0000-0000-0000-0000-000000000020',
  'aaaa0000-0000-0000-0000-000000000021'
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, lat, lng)
VALUES
  -- aaaa...019 Barcelona → Madrid → Lisbon (9 days)
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 1, 0, 'Barcelona',           'location', NULL,         41.3851,  2.1734),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 1, 1, 'Sagrada Família',     'venue',    'experience', 41.4036,  2.1744),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 2, 0, 'Barcelona',           'location', NULL,         41.3851,  2.1734),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 2, 1, 'La Boqueria',         'venue',    'experience', 41.3817,  2.1715),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 3, 0, 'Madrid',              'location', NULL,         40.4168, -3.7038),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 3, 1, 'Prado Museum',        'venue',    'experience', 40.4138, -3.6921),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 4, 0, 'Madrid',              'location', NULL,         40.4168, -3.7038),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 4, 1, 'Mercado de San Miguel','venue',   'experience', 40.4155, -3.7084),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 5, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 5, 1, 'Belém Tower',         'venue',    'experience', 38.6916, -9.2150),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 6, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 6, 1, 'Time Out Market Lisboa','venue',  'experience', 38.7077, -9.1456),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 7, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 7, 1, 'Pastéis de Belém',    'venue',    'restaurant', 38.6979, -9.2067),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 8, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 8, 1, 'Alfama',              'venue',    'experience', 38.7110, -9.1291),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 9, 0, 'Lisbon',              'location', NULL,         38.7223, -9.1393),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000019', 9, 1, 'Bairro Alto',         'venue',    'experience', 38.7136, -9.1442),

  -- aaaa...020 Copenhagen → Malmö → Stockholm (6 days)
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 1, 0, 'Copenhagen',          'location', NULL,         55.6761, 12.5683),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 1, 1, 'Nyhavn',              'venue',    'experience', 55.6798, 12.5916),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 2, 0, 'Copenhagen',          'location', NULL,         55.6761, 12.5683),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 2, 1, 'Torvehallerne',       'venue',    'experience', 55.6836, 12.5717),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 3, 0, 'Malmö',               'location', NULL,         55.6050, 13.0038),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 3, 1, 'Turning Torso',       'venue',    'experience', 55.6136, 12.9765),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 4, 0, 'Stockholm',           'location', NULL,         59.3293, 18.0686),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 4, 1, 'Gamla Stan',          'venue',    'experience', 59.3250, 18.0707),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 5, 0, 'Stockholm',           'location', NULL,         59.3293, 18.0686),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 5, 1, 'Vasa Museum',         'venue',    'experience', 59.3270, 18.0916),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 6, 0, 'Stockholm',           'location', NULL,         59.3293, 18.0686),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000020', 6, 1, 'Frantzén',            'venue',    'restaurant', 59.3406, 18.0604),

  -- aaaa...021 NYC → Washington DC → Philadelphia (7 days)
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 1, 0, 'New York City',       'location', NULL,         40.7128, -74.0060),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 1, 1, 'The High Line',       'venue',    'experience', 40.7480, -74.0048),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 2, 0, 'New York City',       'location', NULL,         40.7128, -74.0060),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 2, 1, 'Katz''s Delicatessen','venue',    'restaurant', 40.7222, -73.9874),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 3, 0, 'Washington, DC',      'location', NULL,         38.9072, -77.0369),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 3, 1, 'National Mall',       'venue',    'experience', 38.8895, -77.0353),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 4, 0, 'Washington, DC',      'location', NULL,         38.9072, -77.0369),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 4, 1, 'Lincoln Memorial',    'venue',    'experience', 38.8893, -77.0502),

  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 5, 0, 'Philadelphia',        'location', NULL,         39.9526, -75.1652),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 5, 1, 'Independence Hall',   'venue',    'experience', 39.9489, -75.1500),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 6, 0, 'Philadelphia',        'location', NULL,         39.9526, -75.1652),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 6, 1, 'Reading Terminal Market','venue',  'experience', 39.9533, -75.1593),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 7, 0, 'Philadelphia',        'location', NULL,         39.9526, -75.1652),
  (gen_random_uuid(), 'aaaa0000-0000-0000-0000-000000000021', 7, 1, 'The Rittenhouse Hotel','venue',   'hotel',      39.9489, -75.1721);
