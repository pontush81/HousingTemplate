/*
  # Fix pages table and add initial content

  1. Changes
    - Ensure pages table exists with correct structure
    - Add initial pages with content
    - Update existing pages with slugs

  2. Security
    - No changes to RLS policies
*/

-- Ensure pages table exists with correct structure
CREATE TABLE IF NOT EXISTS pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  content text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert initial pages if they don't exist
INSERT INTO pages (title, content)
SELECT 'Välkommen', '<h1>Välkommen till BRF Gulmåran</h1><p>Här hittar du information om vår bostadsrättsförening.</p>'
WHERE NOT EXISTS (SELECT 1 FROM pages WHERE title = 'Välkommen');

INSERT INTO pages (title, content)
SELECT 'Kontakt', '<h1>Kontakta oss</h1><p>Här hittar du kontaktinformation till styrelsen och andra viktiga kontakter.</p>'
WHERE NOT EXISTS (SELECT 1 FROM pages WHERE title = 'Kontakt');

INSERT INTO pages (title, content)
SELECT 'Om föreningen', '<h1>Om BRF Gulmåran</h1><p>Information om vår bostadsrättsförening, dess historia och verksamhet.</p>'
WHERE NOT EXISTS (SELECT 1 FROM pages WHERE title = 'Om föreningen');

-- Update any pages that might be missing slugs
UPDATE pages SET slug = generate_page_slug(title) WHERE slug IS NULL OR slug = '';