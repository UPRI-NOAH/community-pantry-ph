-- ================================================================
-- Community Pantry Map — Supabase Setup
-- Run this entire file once in: Supabase Dashboard > SQL Editor
-- ================================================================

-- ----------------------------------------------------------------
-- 1. PANTRIES TABLE
-- ----------------------------------------------------------------
create table public.pantries (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  name          text not null check (char_length(name) between 2 and 120),
  lat           double precision not null check (lat between -90 and 90),
  lng           double precision not null check (lng between -180 and 180),
  contact_name  text check (char_length(contact_name) <= 100),
  contact_phone text check (char_length(contact_phone) <= 30),
  url           text check (char_length(url) <= 300),
  photo_path    text,   -- storage key, e.g. <uuid>/photo.jpg
  photo_url     text,   -- full public CDN URL cached here
  approved      boolean not null default false
);

-- Index for future geo bounding-box queries
create index pantries_geo_idx on public.pantries (lat, lng);

-- ----------------------------------------------------------------
-- 2. ROW LEVEL SECURITY
-- ----------------------------------------------------------------
alter table public.pantries enable row level security;

-- Anyone can add a pantry (no account required)
create policy "anon_insert"
  on public.pantries for insert to anon
  with check (true);

-- Anyone can read approved pantries
-- To make all submissions public instantly, remove "where approved = true"
-- and set AUTO_APPROVE: true in config.js
create policy "anon_select_approved"
  on public.pantries for select to anon
  using (approved = true);

-- Authenticated users (managers via Supabase dashboard) can read everything
create policy "auth_select_all"
  on public.pantries for select to authenticated
  using (true);

-- Authenticated users can approve/update rows
create policy "auth_update"
  on public.pantries for update to authenticated
  using (true) with check (true);

-- Authenticated users can delete spam
create policy "auth_delete"
  on public.pantries for delete to authenticated
  using (true);

-- ----------------------------------------------------------------
-- 3. STORAGE BUCKET
-- ----------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('pantry-photos', 'pantry-photos', true)
on conflict (id) do nothing;

-- Anyone can upload photos
create policy "anon_upload_photos"
  on storage.objects for insert to anon
  with check (bucket_id = 'pantry-photos');

-- Public can read photos (bucket is already public, but be explicit)
create policy "public_read_photos"
  on storage.objects for select to public
  using (bucket_id = 'pantry-photos');

-- Authenticated users can delete photos (for removing spam)
create policy "auth_delete_photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'pantry-photos');

-- ----------------------------------------------------------------
-- 4. REALTIME
-- ----------------------------------------------------------------
alter publication supabase_realtime add table public.pantries;

-- ----------------------------------------------------------------
-- DONE. Go to config.js and fill in your SUPABASE_URL and SUPABASE_ANON_KEY.
-- Tip: To quickly approve all pending submissions, run:
--   update public.pantries set approved = true where approved = false;
-- ----------------------------------------------------------------
