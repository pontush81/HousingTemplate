/*
  # Fix pages table and policies

  1. Changes
    - Drop and recreate pages table with correct structure
    - Add updated_by and published columns
    - Create trigger for automatic slug generation
    - Update RLS policies

  2. Security
    - Enable RLS
    - Add policies for read/write access
*/

-- First drop existing triggers and functions
DROP TRIGGER IF EXISTS set_page_slug_trigger ON pages;
DROP TRIGGER IF EXISTS set_page_updated_by_trigger ON pages;
DROP FUNCTION IF EXISTS set_page_slug();
DROP FUNCTION IF EXISTS set_page_updated_by();
DROP FUNCTION IF EXISTS generate_page_slug(text);

-- Drop and recreate pages table
DROP TABLE IF EXISTS pages;

CREATE TABLE pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  content text DEFAULT '',
  published boolean NOT NULL DEFAULT true,
  updated_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create function to generate slugs
CREATE OR REPLACE FUNCTION generate_page_slug(title text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  base_slug text;
  final_slug text;
  counter integer := 1;
BEGIN
  -- Convert to lowercase and replace spaces and special characters with hyphens
  base_slug := lower(regexp_replace(title, '[^a-zA-Z0-9\s-åäöÅÄÖ]', '', 'g'));
  base_slug := regexp_replace(base_slug, '\s+', '-', 'g');
  
  -- Handle Swedish characters
  base_slug := replace(replace(replace(replace(replace(replace(
    base_slug,
    'å', 'a'),
    'ä', 'a'),
    'ö', 'o'),
    'Å', 'a'),
    'Ä', 'a'),
    'Ö', 'o'
  );
  
  -- Remove consecutive hyphens
  base_slug := regexp_replace(base_slug, '-+', '-', 'g');
  
  -- Remove leading and trailing hyphens
  base_slug := trim(both '-' from base_slug);
  
  -- Initial attempt with base slug
  final_slug := base_slug;
  
  -- If slug exists, append numbers until we find a unique one
  WHILE EXISTS (SELECT 1 FROM pages WHERE slug = final_slug) LOOP
    counter := counter + 1;
    final_slug := base_slug || '-' || counter;
  END LOOP;
  
  RETURN final_slug;
END;
$$;

-- Create trigger function to set slug
CREATE OR REPLACE FUNCTION set_page_slug()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title OR NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := generate_page_slug(NEW.title);
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger function to set updated_by
CREATE OR REPLACE FUNCTION set_page_updated_by()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$$;

-- Create triggers
CREATE TRIGGER set_page_slug_trigger
  BEFORE INSERT OR UPDATE ON pages
  FOR EACH ROW
  EXECUTE FUNCTION set_page_slug();

CREATE TRIGGER set_page_updated_by_trigger
  BEFORE UPDATE ON pages
  FOR EACH ROW
  EXECUTE FUNCTION set_page_updated_by();

-- Enable RLS
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Anyone can read published pages"
  ON pages
  FOR SELECT
  TO authenticated
  USING (published = true OR EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  ));

CREATE POLICY "Admins can insert pages"
  ON pages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

CREATE POLICY "Admins can update pages"
  ON pages
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete pages"
  ON pages
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Insert default pages
INSERT INTO pages (title, content) VALUES
  ('Välkommen', '<h1>Välkommen till BRF Gulmåran</h1><p>Här hittar du information om vår bostadsrättsförening.</p>'),
  ('Kontakt', '<h1>Kontakta oss</h1><p>Här hittar du kontaktinformation till styrelsen och andra viktiga kontakter.</p>'),
  ('Om föreningen', '<h1>Om BRF Gulmåran</h1><p>Information om vår bostadsrättsförening, dess historia och verksamhet.</p>'),
  ('Regler', '<h1>Föreningens regler</h1><p>Här hittar du information om föreningens regler och riktlinjer.</p>'),
  ('Faciliteter', '<h1>Faciliteter</h1><p>Information om föreningens gemensamma faciliteter och hur du bokar dem.</p>')
ON CONFLICT (slug) DO NOTHING;