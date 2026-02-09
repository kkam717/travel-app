-- ============================================================
-- TEST DATA: 24 PUBLIC ITINERARIES (4 per profile) + STOPS
-- Itinerary IDs: cccc0000-0000-0000-0000-000000000025 .. 000048 (does not overwrite 000001..000024)
-- Stop IDs: gen_random_uuid()
-- transport_transitions: length = days_count - 1 per itinerary; ferry → boat.
-- Uses IDs 000025..000048 so existing 000001..000024 are unchanged.
-- ============================================================

-- ============================================================
-- PROFILE 1: Amelia Carter (London)
-- ============================================================

INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000025',
  '11111111-1111-1111-1111-111111111111',
  'Paris Long Weekend: Museums, Bistros & Late Bars',
  'France',
  4,
  ARRAY['Culture','Food','Nightlife'],
  'standard',
  'public',
  true,
  '2024-05-09',
  '2024-05-12',
  1200,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 1, 0, 'Paris', 'location', NULL, NULL, 48.8566, 2.3522, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 1, 1, 'Le Marais', 'venue', 'experience', NULL, 48.8590, 2.3626, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 1, 2, 'Chez Janou', 'venue', 'restaurant', NULL, 48.8570, 2.3660, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 2, 0, 'Louvre Museum', 'venue', 'experience', NULL, 48.8606, 2.3376, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 2, 1, 'Seine River Walk (Pont Neuf)', 'venue', 'experience', NULL, 48.8572, 2.3410, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 2, 2, 'Le Comptoir du Relais', 'venue', 'restaurant', NULL, 48.8533, 2.3366, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 3, 0, 'Montmartre', 'venue', 'experience', NULL, 48.8867, 2.3431, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 3, 1, 'Sacré-Cœur Basilica', 'venue', 'experience', NULL, 48.8867, 2.3431, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 3, 2, 'Experimental Cocktail Club', 'venue', 'experience', NULL, 48.8654, 2.3497, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000025', 4, 0, 'Hôtel Regina Louvre', 'venue', 'hotel', NULL, 48.8639, 2.3320, 4);

-- Trip 2 (Amelia): Amsterdam → Rotterdam, 5 days, 4 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000026',
  '11111111-1111-1111-1111-111111111111',
  'Amsterdam to Rotterdam: Canals, Modern Art & Clubs',
  'Netherlands',
  5,
  ARRAY['Culture','Food','Nightlife'],
  'standard',
  'public',
  false,
  2024,
  9,
  NULL,
  950,
  '[{"type":"train","description":"Intercity Amsterdam Centraal → Rotterdam Centraal (~40 min)"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 1, 0, 'Amsterdam', 'location', NULL, NULL, 52.3676, 4.9041, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 1, 1, 'Rijksmuseum', 'venue', 'experience', NULL, 52.3600, 4.8852, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 1, 2, 'Foodhallen', 'venue', 'restaurant', NULL, 52.3663, 4.8703, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 2, 0, 'Jordaan', 'venue', 'experience', NULL, 52.3732, 4.8813, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 2, 1, 'De School (night)', 'venue', 'experience', NULL, 52.3702, 4.8550, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 3, 0, 'Rotterdam', 'location', NULL, NULL, 51.9244, 4.4777, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 3, 1, 'Markthal', 'venue', 'restaurant', NULL, 51.9202, 4.4876, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 4, 0, 'Kunsthal Rotterdam', 'venue', 'experience', NULL, 51.9103, 4.4730, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 4, 1, 'Witte de Withstraat', 'venue', 'experience', NULL, 51.9147, 4.4771, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000026', 5, 0, 'Mainport Hotel Rotterdam', 'venue', 'hotel', NULL, 51.9067, 4.4866, 4);

-- Trip 3 (Amelia): Edinburgh, 3 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000027',
  '11111111-1111-1111-1111-111111111111',
  'Edinburgh: Old Town Pubs & Castle Views',
  'United Kingdom',
  3,
  ARRAY['Culture','Food','Nightlife'],
  'standard',
  'public',
  NULL,
  '[{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 1, 0, 'Edinburgh', 'location', NULL, NULL, 55.9533, -3.1883, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 1, 1, 'Royal Mile', 'venue', 'experience', NULL, 55.9509, -3.1863, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 1, 2, 'Oink (Hog Roast)', 'venue', 'restaurant', NULL, 55.9521, -3.1905, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 2, 0, 'Edinburgh Castle', 'venue', 'experience', NULL, 55.9486, -3.1999, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 2, 1, 'The Scotch Whisky Experience', 'venue', 'experience', NULL, 55.9473, -3.2021, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 2, 2, 'The Devil''s Advocate', 'venue', 'restaurant', NULL, 55.9512, -3.1845, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 3, 0, 'Arthur''s Seat', 'venue', 'experience', NULL, 55.9440, -3.1619, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000027', 3, 1, 'Panda & Sons (speakeasy)', 'venue', 'experience', NULL, 55.9554, -3.2006, 5);

-- Trip 4 (Amelia): Vienna, 5 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000028',
  '11111111-1111-1111-1111-111111111111',
  'Vienna Winter Elegance: Opera, Cafés & Cocktails',
  'Austria',
  5,
  ARRAY['Culture','Food','Nightlife','Relax'],
  'luxury',
  'public',
  false,
  2025,
  NULL,
  'winter',
  2600,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 1, 0, 'Vienna', 'location', NULL, NULL, 48.2082, 16.3738, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 1, 1, 'Hotel Sacher Wien', 'venue', 'hotel', NULL, 48.2039, 16.3686, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 1, 2, 'Café Central', 'venue', 'restaurant', NULL, 48.2100, 16.3656, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 2, 0, 'Kunsthistorisches Museum', 'venue', 'experience', NULL, 48.2030, 16.3616, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 3, 0, 'Vienna State Opera', 'venue', 'experience', NULL, 48.2030, 16.3695, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 4, 0, 'Naschmarkt', 'venue', 'experience', NULL, 48.1989, 16.3616, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 4, 1, 'Loos American Bar', 'venue', 'experience', NULL, 48.2091, 16.3703, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000028', 5, 0, 'Schönbrunn Palace', 'venue', 'experience', NULL, 48.1845, 16.3122, 5);

-- ============================================================
-- PROFILE 2: Kenji Nakamura (Tokyo)
-- ============================================================

-- Trip 1 (Kenji): Tokyo, 6 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000029',
  '22222222-2222-2222-2222-222222222222',
  'Tokyo After Dark + Sushi By Day',
  'Japan',
  6,
  ARRAY['Food','Culture','Nightlife'],
  'standard',
  'public',
  true,
  '2024-10-10',
  '2024-10-15',
  1400,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 1, 0, 'Tokyo', 'location', NULL, NULL, 35.6762, 139.6503, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 1, 1, 'Senso-ji', 'venue', 'experience', NULL, 35.7148, 139.7967, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 1, 2, 'Asakusa Menchi', 'venue', 'restaurant', NULL, 35.7129, 139.7964, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 2, 0, 'Tsukiji Outer Market', 'venue', 'experience', NULL, 35.6655, 139.7708, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 2, 1, 'Sushi Dai (Toyosu area)', 'venue', 'restaurant', NULL, 35.6457, 139.7852, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 3, 0, 'Meiji Jingu', 'venue', 'experience', NULL, 35.6764, 139.6993, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 3, 1, 'Harajuku (Takeshita St.)', 'venue', 'experience', NULL, 35.6702, 139.7026, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 4, 0, 'Shinjuku Golden Gai', 'venue', 'experience', NULL, 35.6937, 139.7046, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 4, 1, 'Omoide Yokocho', 'venue', 'restaurant', NULL, 35.6940, 139.7006, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 5, 0, 'Roppongi Hills Mori Art Museum', 'venue', 'experience', NULL, 35.6605, 139.7292, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000029', 6, 0, 'Hotel Gracery Shinjuku', 'venue', 'hotel', NULL, 35.6942, 139.7015, 4);

-- Trip 2 (Kenji): Kyoto + Osaka, 5 days, 4 segments (train, train, unknown, unknown)
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000030',
  '22222222-2222-2222-2222-222222222222',
  'Kyoto + Osaka Street Food Sprint',
  'Japan',
  5,
  ARRAY['Food','Culture','Nightlife'],
  'budget',
  'public',
  false,
  2025,
  3,
  650,
  '[{"type":"train","description":"Shinkansen to Kyoto"},{"type":"train","description":"Local train Kyoto → Osaka"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 1, 0, 'Kyoto', 'location', NULL, NULL, 35.0116, 135.7681, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 1, 1, 'Fushimi Inari Taisha', 'venue', 'experience', NULL, 34.9671, 135.7727, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 2, 0, 'Nishiki Market', 'venue', 'experience', NULL, 35.0046, 135.7642, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 2, 1, 'Ippudo Nishikikoji', 'venue', 'restaurant', NULL, 35.0053, 135.7655, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 3, 0, 'Osaka', 'location', NULL, NULL, 34.6937, 135.5023, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 3, 1, 'Dotonbori', 'venue', 'experience', NULL, 34.6687, 135.5012, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 3, 2, 'Takoyaki Wanaka', 'venue', 'restaurant', NULL, 34.6689, 135.5051, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 4, 0, 'Umeda Sky Building', 'venue', 'experience', NULL, 34.7053, 135.4905, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 4, 1, 'Hozenji Yokocho (bars)', 'venue', 'experience', NULL, 34.6681, 135.5030, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000030', 5, 0, 'Capsule Hotel ASTIL Dotonbori', 'venue', 'hotel', NULL, 34.6689, 135.5019, 3);

-- Trip 3 (Kenji): Tokyo → Hakone, 4 days, 3 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000031',
  '22222222-2222-2222-2222-222222222222',
  'Spring Onsen Escape: Tokyo to Hakone',
  'Japan',
  4,
  ARRAY['Relax','Culture','Food'],
  'luxury',
  'public',
  false,
  2025,
  'spring',
  2200,
  '[{"type":"train","description":"Romancecar Shinjuku → Hakone-Yumoto"},{"type":"train","description":"Hakone → Tokyo return"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 1, 0, 'Tokyo', 'location', NULL, NULL, 35.6762, 139.6503, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 1, 1, 'Ginza', 'venue', 'experience', NULL, 35.6721, 139.7708, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 1, 2, 'Sukiyabashi Jiro (Ginza area)', 'venue', 'restaurant', NULL, 35.6732, 139.7636, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 2, 0, 'Hakone', 'location', NULL, NULL, 35.2324, 139.1069, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 2, 1, 'Hakone Open-Air Museum', 'venue', 'experience', NULL, 35.2432, 139.0501, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 3, 0, 'Lake Ashi (Cruise)', 'venue', 'experience', NULL, 35.2067, 139.0257, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 3, 1, 'Gora Kadan (ryokan)', 'venue', 'hotel', NULL, 35.2476, 139.0468, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000031', 4, 0, 'TeamLab Borderless (Azabudai Hills)', 'venue', 'experience', NULL, 35.6629, 139.7453, 5);

-- Trip 4 (Kenji): Seoul, 3 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000032',
  '22222222-2222-2222-2222-222222222222',
  'Seoul Weekend: BBQ, Palaces & Hongdae Nights',
  'South Korea',
  3,
  ARRAY['Food','Culture','Nightlife'],
  'standard',
  'public',
  NULL,
  '[{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 1, 0, 'Seoul', 'location', NULL, NULL, 37.5665, 126.9780, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 1, 1, 'Gyeongbokgung Palace', 'venue', 'experience', NULL, 37.5796, 126.9770, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 1, 2, 'Tosokchon Samgyetang', 'venue', 'restaurant', NULL, 37.5781, 126.9723, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 2, 0, 'Bukchon Hanok Village', 'venue', 'experience', NULL, 37.5826, 126.9830, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 2, 1, 'Myeongdong Street Food', 'venue', 'restaurant', NULL, 37.5637, 126.9863, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 2, 2, 'Hongdae (night)', 'venue', 'experience', NULL, 37.5563, 126.9220, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 3, 0, 'Hotel28 Myeongdong', 'venue', 'hotel', NULL, 37.5632, 126.9846, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000032', 3, 1, 'Namsan Seoul Tower', 'venue', 'experience', NULL, 37.5512, 126.9882, 4);

-- ============================================================
-- PROFILE 3: Sofia Moretti (Milan)
-- ============================================================

-- Trip 1 (Sofia): Milan → Como → Bellagio, 6 days; ferry → boat
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000033',
  '33333333-3333-3333-3333-333333333333',
  'Milan to Lake Como: Design, Dining & Lakeside Calm',
  'Italy',
  6,
  ARRAY['Culture','Food','Relax'],
  'luxury',
  'public',
  true,
  '2024-06-01',
  '2024-06-06',
  4200,
  '[{"type":"train","description":"Milano Centrale → Como S. Giovanni (~40 min)"},{"type":"boat","description":"Como → Bellagio ferry"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 1, 0, 'Milan', 'location', NULL, NULL, 45.4642, 9.1900, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 1, 1, 'Duomo di Milano', 'venue', 'experience', NULL, 45.4642, 9.1916, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 1, 2, 'Galleria Vittorio Emanuele II', 'venue', 'experience', NULL, 45.4659, 9.1900, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 2, 0, 'Pinacoteca di Brera', 'venue', 'experience', NULL, 45.4719, 9.1881, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 2, 1, 'Ratanà', 'venue', 'restaurant', NULL, 45.4832, 9.1876, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 3, 0, 'Como', 'location', NULL, NULL, 45.8081, 9.0852, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 3, 1, 'Villa Olmo', 'venue', 'experience', NULL, 45.8114, 9.0674, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 4, 0, 'Bellagio', 'location', NULL, NULL, 45.9871, 9.2614, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 4, 1, 'Grand Hotel Villa Serbelloni', 'venue', 'hotel', NULL, 45.9849, 9.2579, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 5, 0, 'Villa del Balbianello', 'venue', 'experience', NULL, 45.9731, 9.1966, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000033', 6, 0, 'Il Luogo di Aimo e Nadia', 'venue', 'restaurant', NULL, 45.4686, 9.1677, 5);

-- Trip 2 (Sofia): Paris, 4 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000034',
  '33333333-3333-3333-3333-333333333333',
  'Paris Couture & Quiet Corners',
  'France',
  4,
  ARRAY['Culture','Food','Relax'],
  'luxury',
  'public',
  false,
  2025,
  11,
  3800,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 1, 0, 'Paris', 'location', NULL, NULL, 48.8566, 2.3522, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 1, 1, 'Le Bristol Paris', 'venue', 'hotel', NULL, 48.8718, 2.3143, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 1, 2, 'Ladurée (Champs-Élysées)', 'venue', 'restaurant', NULL, 48.8698, 2.3076, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 2, 0, 'Musée d''Orsay', 'venue', 'experience', NULL, 48.8600, 2.3266, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 2, 1, 'Jardin du Luxembourg', 'venue', 'experience', NULL, 48.8462, 2.3372, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 3, 0, 'Le Bon Marché Rive Gauche', 'venue', 'experience', NULL, 48.8519, 2.3234, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 3, 1, 'Septime (area)', 'venue', 'restaurant', NULL, 48.8520, 2.3805, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000034', 4, 0, 'Palais Garnier', 'venue', 'experience', NULL, 48.8719, 2.3316, 5);

-- Trip 3 (Sofia): Rome, 3 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000035',
  '33333333-3333-3333-3333-333333333333',
  'Rome in 72 Hours: Classics + Trastevere',
  'Italy',
  3,
  ARRAY['Culture','Food'],
  'standard',
  'public',
  NULL,
  900,
  '[{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 1, 0, 'Rome', 'location', NULL, NULL, 41.9028, 12.4964, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 1, 1, 'Colosseum', 'venue', 'experience', NULL, 41.8902, 12.4922, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 1, 2, 'Foro Romano', 'venue', 'experience', NULL, 41.8925, 12.4853, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 2, 0, 'Pantheon', 'venue', 'experience', NULL, 41.8986, 12.4769, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 2, 1, 'Roscioli Salumeria con Cucina', 'venue', 'restaurant', NULL, 41.8932, 12.4775, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 3, 0, 'Trastevere', 'venue', 'experience', NULL, 41.8897, 12.4700, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 3, 1, 'Da Enzo al 29', 'venue', 'restaurant', NULL, 41.8876, 12.4731, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000035', 3, 2, 'Hotel de'' Ricci (area)', 'venue', 'hotel', NULL, 41.8961, 12.4732, 4);

-- Trip 4 (Sofia): Florence → Siena, 5 days, 4 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000036',
  '33333333-3333-3333-3333-333333333333',
  'Tuscan Slow Travel: Florence to Siena',
  'Italy',
  5,
  ARRAY['Culture','Relax','Food'],
  'luxury',
  'public',
  false,
  2024,
  'fall',
  3600,
  '[{"type":"car","description":"Private transfer Florence → Siena (~1h 15m)"},{"type":"car","description":"Day trip Siena → Chianti wineries"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 1, 0, 'Florence', 'location', NULL, NULL, 43.7696, 11.2558, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 1, 1, 'Uffizi Gallery', 'venue', 'experience', NULL, 43.7687, 11.2550, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 1, 2, 'Ristorante La Giostra', 'venue', 'restaurant', NULL, 43.7711, 11.2641, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 2, 0, 'Piazzale Michelangelo', 'venue', 'experience', NULL, 43.7629, 11.2656, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 2, 1, 'Four Seasons Hotel Firenze (area)', 'venue', 'hotel', NULL, 43.7811, 11.2690, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 3, 0, 'Siena', 'location', NULL, NULL, 43.3188, 11.3308, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 3, 1, 'Piazza del Campo', 'venue', 'experience', NULL, 43.3186, 11.3313, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 4, 0, 'Chianti (Greve in Chianti)', 'venue', 'experience', NULL, 43.5850, 11.3150, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 4, 1, 'Wine tasting (Chianti winery)', 'venue', 'experience', NULL, 43.5859, 11.3145, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000036', 5, 0, 'Osteria Le Logge', 'venue', 'restaurant', NULL, 43.3182, 11.3337, 5);

-- ============================================================
-- PROFILE 4: Ethan Brooks (New York)
-- ============================================================

-- Trip 1 (Ethan): Mexico City, 5 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000037',
  '44444444-4444-4444-4444-444444444444',
  'Mexico City Budget Bites + Lucha Night',
  'Mexico',
  5,
  ARRAY['Food','Culture','Nightlife'],
  'budget',
  'public',
  true,
  '2024-08-14',
  '2024-08-18',
  550,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 1, 0, 'Mexico City', 'location', NULL, NULL, 19.4326, -99.1332, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 1, 1, 'Zócalo', 'venue', 'experience', NULL, 19.4326, -99.1332, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 1, 2, 'Taquería Orinoco (Roma Norte area)', 'venue', 'restaurant', NULL, 19.4148, -99.1624, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 2, 0, 'Chapultepec Park', 'venue', 'experience', NULL, 19.4204, -99.1819, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 2, 1, 'Museo Nacional de Antropología', 'venue', 'experience', NULL, 19.4260, -99.1860, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 3, 0, 'La Ciudadela Market', 'venue', 'experience', NULL, 19.4270, -99.1487, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 4, 0, 'Arena México (Lucha Libre)', 'venue', 'experience', NULL, 19.4076, -99.1521, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000037', 5, 0, 'Hostel in Roma Norte (area)', 'venue', 'hotel', NULL, 19.4150, -99.1630, 4);

-- Trip 2 (Ethan): Peru, 6 days, 5 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000038',
  '44444444-4444-4444-4444-444444444444',
  'Peru Trek Lite: Cusco + Machu Picchu on a Budget',
  'Peru',
  6,
  ARRAY['Adventure','Nature','Food'],
  'budget',
  'public',
  false,
  2025,
  7,
  1100,
  '[{"type":"plane","description":"Flight NYC → Lima → Cusco"},{"type":"train","description":"Train Cusco/Poroy → Aguas Calientes"},{"type":"bus","description":"Bus Aguas Calientes → Machu Picchu"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 1, 0, 'Cusco', 'location', NULL, NULL, -13.5319, -71.9675, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 1, 1, 'Plaza de Armas (Cusco)', 'venue', 'experience', NULL, -13.5166, -71.9780, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 2, 0, 'Sacsayhuamán', 'venue', 'experience', NULL, -13.5094, -71.9813, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 2, 1, 'San Pedro Market', 'venue', 'restaurant', NULL, -13.5208, -71.9894, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 3, 0, 'Aguas Calientes (Machu Picchu Pueblo)', 'location', NULL, NULL, -13.1550, -72.5250, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 4, 0, 'Machu Picchu', 'venue', 'experience', NULL, -13.1631, -72.5450, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 5, 0, 'Rainbow Mountain (Vinicunca area)', 'venue', 'experience', NULL, -13.8694, -71.3023, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000038', 6, 0, 'Budget Guesthouse Cusco (area)', 'venue', 'hotel', NULL, -13.5160, -71.9790, 3);

-- Trip 3 (Ethan): NYC, 3 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000039',
  '44444444-4444-4444-4444-444444444444',
  'NYC Weekend: Street Eats + Rooftops',
  'United States',
  3,
  ARRAY['Food','Nightlife','Culture'],
  'standard',
  'public',
  NULL,
  '[{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 1, 0, 'New York City', 'location', NULL, NULL, 40.7128, -74.0060, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 1, 1, 'Chelsea Market', 'venue', 'restaurant', NULL, 40.7424, -74.0060, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 1, 2, 'The High Line', 'venue', 'experience', NULL, 40.7480, -74.0048, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 2, 0, 'Katz''s Delicatessen', 'venue', 'restaurant', NULL, 40.7222, -73.9874, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 2, 1, 'Brooklyn Bridge Park', 'venue', 'experience', NULL, 40.7003, -73.9967, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 2, 2, 'Westlight (rooftop bar)', 'venue', 'experience', NULL, 40.7216, -73.9581, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000039', 3, 0, 'Pod 39 Hotel (area)', 'venue', 'hotel', NULL, 40.7513, -73.9769, 4);

-- Trip 4 (Ethan): Iceland, 7 days, 6 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000040',
  '44444444-4444-4444-4444-444444444444',
  'Iceland Winter Budget Loop: Waterfalls & Hot Springs',
  'Iceland',
  7,
  ARRAY['Adventure','Nature','Relax'],
  'budget',
  'public',
  false,
  2024,
  'winter',
  1600,
  '[{"type":"plane","description":"Flight NYC → Keflavík (KEF)"},{"type":"car","description":"Rental car: Reykjavík → Golden Circle → South Coast → Reykjavík"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 1, 0, 'Reykjavík', 'location', NULL, NULL, 64.1466, -21.9426, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 1, 1, 'Hallgrímskirkja', 'venue', 'experience', NULL, 64.1419, -21.9266, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 2, 0, 'Þingvellir National Park', 'venue', 'experience', NULL, 64.2550, -21.1290, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 3, 0, 'Geysir Geothermal Area', 'venue', 'experience', NULL, 64.3121, -20.3024, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 3, 1, 'Gullfoss Falls', 'venue', 'experience', NULL, 64.3270, -20.1218, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 4, 0, 'Seljalandsfoss', 'venue', 'experience', NULL, 63.6156, -19.9896, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 4, 1, 'Skógafoss', 'venue', 'experience', NULL, 63.5321, -19.5114, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 5, 0, 'Reynisfjara Black Sand Beach', 'venue', 'experience', NULL, 63.4050, -19.0440, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 6, 0, 'Blue Lagoon', 'venue', 'experience', NULL, 63.8804, -22.4495, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000040', 7, 0, 'Kex Hostel (area)', 'venue', 'hotel', NULL, 64.1460, -21.9260, 4);

-- ============================================================
-- PROFILE 5: Nina Larsen (Copenhagen)
-- ============================================================

-- Trip 1 (Nina): Norway, 6 days; ferry → boat
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000041',
  '55555555-5555-5555-5555-555555555555',
  'Norway Fjord Calm: Bergen + Flåm',
  'Norway',
  6,
  ARRAY['Nature','Relax','Culture'],
  'standard',
  'public',
  true,
  '2024-07-02',
  '2024-07-07',
  1700,
  '[{"type":"train","description":"Bergen → Voss → Myrdal → Flåm (Norway in a Nutshell segments)"},{"type":"boat","description":"Flåm → Gudvangen fjord cruise"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 1, 0, 'Bergen', 'location', NULL, NULL, 60.3913, 5.3221, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 1, 1, 'Bryggen Hanseatic Wharf', 'venue', 'experience', NULL, 60.3971, 5.3245, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 2, 0, 'Fløibanen Funicular', 'venue', 'experience', NULL, 60.3947, 5.3280, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 3, 0, 'Flåm', 'location', NULL, NULL, 60.8623, 7.1139, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 3, 1, 'Stegastein Viewpoint (Aurland)', 'venue', 'experience', NULL, 60.9190, 7.1860, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 4, 0, 'Nærøyfjord Cruise (Gudvangen area)', 'venue', 'experience', NULL, 60.8798, 6.8442, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 5, 0, 'Flåm Railway Museum', 'venue', 'experience', NULL, 60.8626, 7.1133, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000041', 6, 0, 'Clarion Hotel Admiral (Bergen)', 'venue', 'hotel', NULL, 60.3959, 5.3227, 4);

-- Trip 2 (Nina): Copenhagen → Malmö, 4 days, 3 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000042',
  '55555555-5555-5555-5555-555555555555',
  'Copenhagen + Malmö: Hygge, Design & Slow Cafés',
  'Denmark/Sweden',
  4,
  ARRAY['Culture','Relax','Food'],
  'standard',
  'public',
  false,
  2024,
  4,
  900,
  '[{"type":"train","description":"Øresund train Copenhagen → Malmö C (~35 min)"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 1, 0, 'Copenhagen', 'location', NULL, NULL, 55.6761, 12.5683, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 1, 1, 'Nyhavn', 'venue', 'experience', NULL, 55.6797, 12.5916, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 1, 2, 'Torvehallerne', 'venue', 'restaurant', NULL, 55.6837, 12.5716, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 2, 0, 'Louisiana Museum of Modern Art', 'venue', 'experience', NULL, 55.9691, 12.5433, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 3, 0, 'Malmö', 'location', NULL, NULL, 55.6050, 13.0038, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 3, 1, 'Turning Torso', 'venue', 'experience', NULL, 55.6131, 12.9766, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 3, 2, 'Malmö Saluhall', 'venue', 'restaurant', NULL, 55.6086, 12.9991, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000042', 4, 0, 'Hotel SP34 (Copenhagen area)', 'venue', 'hotel', NULL, 55.6793, 12.5670, 4);

-- Trip 3 (Nina): Bornholm, 3 days; ferry → boat, already 2 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000043',
  '55555555-5555-5555-5555-555555555555',
  'Bornholm Micro-Escape: Cliffs, Beaches & Smokehouses',
  'Denmark',
  3,
  ARRAY['Nature','Relax','Food'],
  'budget',
  'public',
  NULL,
  450,
  '[{"type":"boat","description":"Ferry Ystad → Rønne (Bornholm)"},{"type":"bus","description":"Local bus around Bornholm"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 1, 0, 'Rønne (Bornholm)', 'location', NULL, NULL, 55.1019, 14.7066, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 1, 1, 'Bornholm Art Museum (area)', 'venue', 'experience', NULL, 55.2090, 14.9140, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 2, 0, 'Hammershus Castle Ruins', 'venue', 'experience', NULL, 55.2730, 14.7580, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 2, 1, 'Opalsøen (hike viewpoint)', 'venue', 'experience', NULL, 55.2740, 14.7410, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 3, 0, 'Dueodde Beach', 'venue', 'experience', NULL, 55.0216, 15.0820, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000043', 3, 1, 'Svaneke Smokehouse (area)', 'venue', 'restaurant', NULL, 55.1368, 15.1437, 4);

-- Trip 4 (Nina): Finland, 4 days; ferry → boat, 3 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000044',
  '55555555-5555-5555-5555-555555555555',
  'Finnish Summer Reset: Helsinki + Sauna Day',
  'Finland',
  4,
  ARRAY['Relax','Culture','Nature'],
  'luxury',
  'public',
  false,
  2025,
  'summer',
  2400,
  '[{"type":"boat","description":"Helsinki harbour ferry to Suomenlinna"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 1, 0, 'Helsinki', 'location', NULL, NULL, 60.1699, 24.9384, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 1, 1, 'Hotel Kämp', 'venue', 'hotel', NULL, 60.1688, 24.9426, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 2, 0, 'Suomenlinna Sea Fortress', 'venue', 'experience', NULL, 60.1456, 24.9886, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 3, 0, 'Löyly Sauna', 'venue', 'experience', NULL, 60.1547, 24.9210, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 3, 1, 'Old Market Hall (Vanha Kauppahalli)', 'venue', 'restaurant', NULL, 60.1677, 24.9537, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000044', 4, 0, 'Nuuksio National Park (area)', 'venue', 'experience', NULL, 60.3230, 24.4950, 4);

-- ============================================================
-- PROFILE 6: Mateo Alvarez (Barcelona)
-- ============================================================

-- Trip 1 (Mateo): Lisbon, 5 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, start_date, end_date, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000045',
  '66666666-6666-6666-6666-666666666666',
  'Lisbon on a Budget: Miradouros, Seafood & Fado',
  'Portugal',
  5,
  ARRAY['Food','Culture','Relax'],
  'budget',
  'public',
  true,
  '2024-09-20',
  '2024-09-24',
  600,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 1, 0, 'Lisbon', 'location', NULL, NULL, 38.7223, -9.1393, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 1, 1, 'Alfama', 'venue', 'experience', NULL, 38.7110, -9.1290, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 1, 2, 'Miradouro de Santa Luzia', 'venue', 'experience', NULL, 38.7114, -9.1283, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 2, 0, 'Time Out Market Lisboa', 'venue', 'restaurant', NULL, 38.7086, -9.1450, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 2, 1, 'LX Factory', 'venue', 'experience', NULL, 38.7036, -9.1782, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 3, 0, 'Belém', 'venue', 'experience', NULL, 38.6977, -9.2052, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 3, 1, 'Pastéis de Belém', 'venue', 'restaurant', NULL, 38.6979, -9.2066, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 4, 0, 'Cais do Sodré (evening)', 'venue', 'experience', NULL, 38.7075, -9.1453, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000045', 5, 0, 'Budget Hotel Baixa (area)', 'venue', 'hotel', NULL, 38.7100, -9.1400, 4);

-- Trip 2 (Mateo): Andalucía, 7 days, 6 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_month, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000046',
  '66666666-6666-6666-6666-666666666666',
  'Andalucía by Train: Tapas, Patios & Palaces',
  'Spain',
  7,
  ARRAY['Food','Culture','Relax'],
  'budget',
  'public',
  false,
  2025,
  5,
  900,
  '[{"type":"train","description":"Seville → Córdoba (~45 min AVE)"},{"type":"train","description":"Córdoba → Granada (~1h 40m)"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 1, 0, 'Seville', 'location', NULL, NULL, 37.3891, -5.9845, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 1, 1, 'Real Alcázar of Seville', 'venue', 'experience', NULL, 37.3831, -5.9910, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 1, 2, 'Las Setas (Metropol Parasol)', 'venue', 'experience', NULL, 37.3930, -5.9913, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 2, 0, 'Triana', 'venue', 'experience', NULL, 37.3823, -6.0030, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 2, 1, 'Tapas Bar (Triana area)', 'venue', 'restaurant', NULL, 37.3828, -6.0050, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 3, 0, 'Córdoba', 'location', NULL, NULL, 37.8882, -4.7794, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 3, 1, 'Mezquita-Catedral de Córdoba', 'venue', 'experience', NULL, 37.8789, -4.7794, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 4, 0, 'Patios of Córdoba (area)', 'venue', 'experience', NULL, 37.8875, -4.7790, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 5, 0, 'Granada', 'location', NULL, NULL, 37.1773, -3.5986, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 5, 1, 'Alhambra', 'venue', 'experience', NULL, 37.1761, -3.5881, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 6, 0, 'Albaicín', 'venue', 'experience', NULL, 37.1825, -3.5935, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 6, 1, 'Mirador de San Nicolás', 'venue', 'experience', NULL, 37.1839, -3.5922, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000046', 7, 0, 'Budget Pension Granada (area)', 'venue', 'hotel', NULL, 37.1768, -3.5995, 3);

-- Trip 3 (Mateo): Marrakech, 4 days
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000047',
  '66666666-6666-6666-6666-666666666666',
  'Marrakech Mini-Break: Souks, Tagines & Hammam',
  'Morocco',
  4,
  ARRAY['Food','Culture','Relax'],
  'standard',
  'public',
  NULL,
  850,
  '[{"type":"unknown"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 1, 0, 'Marrakech', 'location', NULL, NULL, 31.6295, -7.9811, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 1, 1, 'Jemaa el-Fnaa', 'venue', 'experience', NULL, 31.6258, -7.9892, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 1, 2, 'Le Jardin (restaurant)', 'venue', 'restaurant', NULL, 31.6316, -7.9897, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 2, 0, 'Bahia Palace', 'venue', 'experience', NULL, 31.6216, -7.9831, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 2, 1, 'Souk Semmarine', 'venue', 'experience', NULL, 31.6302, -7.9890, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 3, 0, 'Majorelle Garden', 'venue', 'experience', NULL, 31.6417, -7.9926, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 3, 1, 'Hammam (Medina area)', 'venue', 'experience', NULL, 31.6300, -7.9880, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000047', 4, 0, 'Riad (Medina area)', 'venue', 'hotel', NULL, 31.6310, -7.9895, 4);

-- Trip 4 (Mateo): Costa Brava, 5 days, 4 segments
INSERT INTO itineraries
(id, author_id, title, destination, days_count, style_tags, mode, visibility, use_dates, duration_year, duration_season, cost_per_person, transport_transitions)
VALUES (
  'cccc0000-0000-0000-0000-000000000048',
  '66666666-6666-6666-6666-666666666666',
  'Costa Brava Summer: Barcelona to Cadaqués',
  'Spain',
  5,
  ARRAY['Relax','Food','Culture','Nature'],
  'luxury',
  'public',
  false,
  2025,
  'summer',
  2800,
  '[{"type":"car","description":"Drive Barcelona → Cadaqués (~2h 30m)"},{"type":"car","description":"Coastal stops along Costa Brava"},{"type":"unknown"},{"type":"unknown"}]'::jsonb
);

INSERT INTO itinerary_stops (id, itinerary_id, day, position, name, stop_type, category, external_url, lat, lng, rating)
VALUES
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 1, 0, 'Barcelona', 'location', NULL, NULL, 41.3851, 2.1734, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 1, 1, 'Sagrada Família', 'venue', 'experience', NULL, 41.4036, 2.1744, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 1, 2, 'Tickets Bar (area)', 'venue', 'restaurant', NULL, 41.3746, 2.1490, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 2, 0, 'Girona', 'location', NULL, NULL, 41.9794, 2.8214, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 2, 1, 'Old Town Girona', 'venue', 'experience', NULL, 41.9831, 2.8249, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 3, 0, 'Cadaqués', 'location', NULL, NULL, 42.2889, 3.2786, NULL),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 3, 1, 'Casa-Museu Salvador Dalí (Portlligat)', 'venue', 'experience', NULL, 42.2923, 3.2896, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 4, 0, 'Cap de Creus Natural Park (area)', 'venue', 'experience', NULL, 42.3200, 3.3100, 5),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 4, 1, 'Beach time (Cadaqués cove)', 'venue', 'experience', NULL, 42.2881, 3.2776, 4),
  (gen_random_uuid(), 'cccc0000-0000-0000-0000-000000000048', 5, 0, 'Boutique Hotel (Cadaqués area)', 'venue', 'hotel', NULL, 42.2879, 3.2778, 5);

-- ============================================================
-- NOTE: 24 itineraries (000025..000048), 6 profiles. Prerequisite: profiles
-- 11111111-..., 22222222-..., ... 66666666-... must exist.
-- transport_transitions length = days_count - 1 for each; ferry stored as boat.
-- ============================================================
