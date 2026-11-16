-- Public Customer Wanted Requests with private company analytics access.
-- Run in the company's Supabase SQL Editor.
create table if not exists public.wanted_analysts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.wanted_items (
  id uuid primary key default gen_random_uuid(),
  release_year smallint not null check (release_year between 1900 and 2100),
  format text not null check (format in ('Album', 'CD')),
  album_title text not null check (char_length(trim(album_title)) between 1 and 180),
  artist_name text not null check (char_length(trim(artist_name)) between 1 and 180),
  created_at timestamptz not null default now(),
  fulfilled boolean not null default false
);
-- Also supports existing installations when this setup script is run again.
alter table public.wanted_items add column if not exists fulfilled boolean not null default false;
create index if not exists wanted_items_created_at_idx on public.wanted_items (created_at desc);
create index if not exists wanted_items_artist_title_idx on public.wanted_items (artist_name, album_title);

alter table public.wanted_analysts enable row level security;
alter table public.wanted_items enable row level security;
revoke all on public.wanted_analysts from anon, authenticated;
revoke all on public.wanted_items from anon, authenticated;
grant select on public.wanted_items to authenticated;
grant update (fulfilled) on public.wanted_items to authenticated;
-- Allow anonymous customers to submit only the four form fields. IDs and timestamps
-- remain database-generated, and public read access stays disabled.
grant insert (release_year, format, album_title, artist_name) on public.wanted_items to anon;

create or replace function public.is_wanted_analyst()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.wanted_analysts a where a.user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_wanted_analyst() from public, anon;
grant execute on function public.is_wanted_analyst() to authenticated;

drop policy if exists "Analysts can read wanted items" on public.wanted_items;
create policy "Analysts can read wanted items"
  on public.wanted_items for select
  to authenticated
  using ((select public.is_wanted_analyst()));

drop policy if exists "Analysts can update fulfillment" on public.wanted_items;
create policy "Analysts can update fulfillment"
  on public.wanted_items for update
  to authenticated
  using ((select public.is_wanted_analyst()))
  with check ((select public.is_wanted_analyst()));
-- Public customers can submit rows but cannot read any submissions. There is no
-- CAPTCHA or Edge Function in this version, so the public insert endpoint can be spammed.
drop policy if exists "Public can submit wanted items" on public.wanted_items;
create policy "Public can submit wanted items"
  on public.wanted_items for insert
  to anon
  with check (true);

-- After creating company analyst accounts under Authentication > Users,
-- authorize an exact email using the setup SQL in README.md.
