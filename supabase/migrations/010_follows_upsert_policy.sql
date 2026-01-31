-- Add UPDATE policy for follows table (required for upsert ON CONFLICT DO UPDATE)
-- Without this, follow operations fail when the row already exists
DROP POLICY IF EXISTS "Users can update own follow relationships" ON follows;
CREATE POLICY "Users can update own follow relationships"
  ON follows FOR UPDATE
  TO authenticated
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);
