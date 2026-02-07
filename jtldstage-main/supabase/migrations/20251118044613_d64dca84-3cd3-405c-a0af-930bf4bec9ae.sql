-- Fix RLS policy for anonymous project creation
-- The policy needs to be PERMISSIVE (not RESTRICTIVE) to allow anonymous inserts

DROP POLICY IF EXISTS "Anyone can insert projects" ON projects;

CREATE POLICY "Anyone can insert projects" 
  ON projects 
  FOR INSERT 
  TO authenticated, anon
  WITH CHECK (true);