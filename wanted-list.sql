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
  fulfilled boolean not null default false,
  customer_name text,
  customer_email text,
  customer_phone text
);
-- Also supports existing installations when this setup script is run again.
alter table public.wanted_items add column if not exists fulfilled boolean not null default false;
alter table public.wanted_items add column if not exists customer_name text;
alter table public.wanted_items add column if not exists customer_email text;
alter table public.wanted_items add column if not exists customer_phone text;
create index if not exists wanted_items_created_at_idx on public.wanted_items (created_at desc);
create index if not exists wanted_items_artist_title_idx on public.wanted_items (artist_name, album_title);

alter table public.wanted_analysts enable row level security;
alter table public.wanted_items enable row level security;
revoke all on public.wanted_analysts from public, anon, authenticated;
revoke all on public.wanted_items from public, anon, authenticated;
grant select on public.wanted_items to authenticated;
grant update (fulfilled) on public.wanted_items to authenticated;
-- Public writes are limited to the database function below, not table INSERT grants.
revoke insert (release_year, format, album_title, artist_name) on table public.wanted_items from public, anon, authenticated;

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
-- Public visitors cannot insert directly through the table API.
drop policy if exists "Public can submit wanted items" on public.wanted_items;

drop function if exists public.submit_public_wanted_item(integer, text, text, text);

create or replace function public.submit_public_wanted_item(
  p_release_year integer,
  p_format text,
  p_artist_name text,
  p_album_title text,
  p_customer_name text,
  p_customer_email text,
  p_customer_phone text
)
returns void
language plpgsql
security definer
set search_path = ''
as $
declare
  v_customer_name text := nullif(pg_catalog.btrim(coalesce(p_customer_name, '')), '');
  v_customer_email text := nullif(pg_catalog.btrim(coalesce(p_customer_email, '')), '');
  v_customer_phone text := nullif(pg_catalog.btrim(coalesce(p_customer_phone, '')), '');
begin
  if p_release_year is null or p_release_year < 1900 or p_release_year > 2100 then
    raise exception 'Release year must be between 1900 and 2100';
  end if;
  if p_format is null or p_format not in ('Album', 'CD') then
    raise exception 'Format must be Album or CD';
  end if;
  if pg_catalog.char_length(pg_catalog.btrim(coalesce(p_artist_name, ''))) not between 1 and 180 then
    raise exception 'Artist or group must be between 1 and 180 characters';
  end if;
  if pg_catalog.char_length(pg_catalog.btrim(coalesce(p_album_title, ''))) not between 1 and 180 then
    raise exception 'Album title must be between 1 and 180 characters';
  end if;

  if v_customer_name is not null and pg_catalog.char_length(v_customer_name) > 160 then
    raise exception 'Name must be 160 characters or fewer';
  end if;
  if v_customer_email is null and v_customer_phone is null then
    raise exception 'Provide an email address or phone number';
  end if;
  if v_customer_email is not null and (pg_catalog.char_length(v_customer_email) > 254 or v_customer_email !~* '^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+
end;
$$;
revoke all on function public.submit_public_wanted_item(integer, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.submit_public_wanted_item(integer, text, text, text, text, text, text) to anon, authenticated;

-- After creating company analyst accounts under Authentication > Users,
-- authorize an exact email using the setup SQL in README.md.
) then
    raise exception 'Enter a valid email address';
  end if;
  if v_customer_phone is not null and (pg_catalog.char_length(v_customer_phone) > 40 or pg_catalog.char_length(pg_catalog.regexp_replace(v_customer_phone, '[^0-9]', '', 'g')) < 7) then
    raise exception 'Enter a valid phone number';
  end if;

  insert into public.wanted_items (release_year, format, artist_name, album_title, fulfilled, customer_name, customer_email, customer_phone)
  values (
    p_release_year::smallint,
    p_format,
    pg_catalog.btrim(p_artist_name),
    pg_catalog.btrim(p_album_title),
    false,
    v_customer_name,
    v_customer_email,
    v_customer_phone
  );
end;
$$;
revoke all on function public.submit_public_wanted_item(integer, text, text, text) from public, anon, authenticated;
grant execute on function public.submit_public_wanted_item(integer, text, text, text) to anon, authenticated;

-- After creating company analyst accounts under Authentication > Users,
-- authorize an exact email using the setup SQL in README.md.
