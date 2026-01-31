-- Seed test data: 5 profiles with 4 itineraries each (2 private, 2 public)
-- Requires pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. Create 5 auth users (password: password123 for all)
-- =============================================================================
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  uuid_generate_v4(),
  'authenticated',
  'authenticated',
  'test' || n || '@example.com',
  crypt('password123', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  format('{"name": "%s"}', (ARRAY['Alice Chen', 'Marcus Rivera', 'Sofia Patel', 'James Okonkwo', 'Emma Lindqvist'])[n])::jsonb,
  NOW(),
  NOW()
FROM generate_series(1, 5) AS n;

-- =============================================================================
-- 2. Create auth.identities so users can log in
-- =============================================================================
INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  uuid_generate_v4(),
  id,
  id,
  format('{"sub": "%s", "email": "%s"}', id, email)::jsonb,
  'email',
  NOW(),
  NOW(),
  NOW()
FROM auth.users
WHERE email LIKE 'test%@example.com';

-- =============================================================================
-- 3. Update profiles (created by trigger) with onboarding complete
-- =============================================================================
UPDATE profiles
SET onboarding_complete = true, updated_at = NOW()
WHERE id IN (SELECT id FROM auth.users WHERE email LIKE 'test%@example.com');

-- =============================================================================
-- 4. Insert itineraries (4 per profile: 2 private, 2 public)
-- =============================================================================
INSERT INTO itineraries (id, author_id, title, destination, days_count, mode, visibility, created_at, updated_at)
SELECT
  uuid_generate_v4(),
  p.id,
  titles.title,
  titles.destination,
  titles.days_count,
  titles.mode,
  titles.visibility,
  NOW(),
  NOW()
FROM profiles p
CROSS JOIN LATERAL (
  VALUES
    ('Weekend in Paris', 'France', 3, 'standard', 'public'),
    ('Tokyo Adventure', 'Japan', 7, 'standard', 'public'),
    ('Secret Getaway', 'Italy', 5, 'luxury', 'private'),
    ('Budget Barcelona', 'Spain', 4, 'budget', 'private')
) AS titles(title, destination, days_count, mode, visibility)
WHERE p.id IN (SELECT id FROM auth.users WHERE email LIKE 'test%@example.com');

-- =============================================================================
-- 5. Insert itinerary_stops (locations + venues per day, matched to destination)
-- =============================================================================
INSERT INTO itinerary_stops (itinerary_id, position, day, name, category, stop_type, lat, lng, created_at)
SELECT
  sub.id,
  sub.row_num,
  sub.day,
  sub.name,
  sub.category,
  sub.stop_type,
  sub.lat,
  sub.lng,
  NOW()
FROM (
  SELECT i.id, s.day, s.pos, s.name, s.category, s.stop_type, s.lat, s.lng,
    row_number() OVER (PARTITION BY i.id ORDER BY s.day, s.pos) AS row_num
  FROM itineraries i
  JOIN (
    VALUES
      ('France', 1, 1, 'Paris', 'location', 'location', 48.8566, 2.3522),
      ('France', 1, 2, 'Eiffel Tower', 'attraction', 'venue', 48.8584, 2.2945),
      ('France', 2, 1, 'Le Jules Verne', 'restaurant', 'venue', 48.8584, 2.2945),
      ('Japan', 1, 1, 'Tokyo', 'location', 'location', 35.6762, 139.6503),
      ('Japan', 2, 1, 'Shibuya', 'location', 'location', 35.6595, 139.7004),
      ('Japan', 2, 2, 'Ichiran Ramen', 'restaurant', 'venue', 35.6595, 139.7004),
      ('Italy', 1, 1, 'Rome', 'location', 'location', 41.9028, 12.4964),
      ('Italy', 2, 1, 'Colosseum', 'attraction', 'venue', 41.8902, 12.4922),
      ('Spain', 1, 1, 'Barcelona', 'location', 'location', 41.3851, 2.1734),
      ('Spain', 2, 1, 'La Sagrada Familia', 'attraction', 'venue', 41.4036, 2.1744)
  ) AS s(dest, day, pos, name, category, stop_type, lat, lng)
  ON i.destination = s.dest
  WHERE i.author_id IN (SELECT id FROM auth.users WHERE email LIKE 'test%@example.com')
) sub;
