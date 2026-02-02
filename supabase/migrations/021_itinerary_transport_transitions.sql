-- Optional: transport type per transition (between consecutive location stops)
-- Stored as JSONB array of strings: ["plane","train","car",...]
-- Index i = transport between location i and i+1
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS transport_transitions JSONB;
