-- ============================================
-- WEBORA — SCHÉMA SUPABASE
-- ============================================

-- ============================================
-- 1. SITES WEBORA
-- ============================================

create table if not exists public.webora_sites (
  id uuid primary key default gen_random_uuid(),

  owner uuid not null
    default auth.uid()
    references auth.users(id)
    on delete cascade,

  name text not null default 'Mon activité',

  template text not null,

  category text not null
    check (category in ('boutique','restaurant','salon')),

  subdomain text unique
    check (
      subdomain is null
      or subdomain ~ '^[a-z0-9-]{3,30}$'
    ),

  published boolean not null default false,

  content jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ============================================
-- 2. FONCTION DE MISE À JOUR
-- ============================================

create or replace function public.webora_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


drop trigger if exists webora_sites_touch
on public.webora_sites;

create trigger webora_sites_touch
before update on public.webora_sites
for each row
execute function public.webora_touch_updated_at();


-- ============================================
-- 3. ABONNEMENTS WEBORA
-- ============================================

create table if not exists public.webora_subscriptions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  plan text not null default 'basique'
    check (plan in ('basique','pro','promax')),

  status text not null default 'active',

  starts_at timestamptz not null default now(),

  free_until timestamptz,

  ends_at timestamptz,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


-- ============================================
-- 4. RLS — SITES
-- ============================================

alter table public.webora_sites
enable row level security;


drop policy if exists "webora_sites_owner_select"
on public.webora_sites;

create policy "webora_sites_owner_select"
on public.webora_sites
for select
to authenticated
using (
  owner = auth.uid()
);


drop policy if exists "webora_sites_owner_insert"
on public.webora_sites;

create policy "webora_sites_owner_insert"
on public.webora_sites
for insert
to authenticated
with check (
  owner = auth.uid()
);


drop policy if exists "webora_sites_owner_update"
on public.webora_sites;

create policy "webora_sites_owner_update"
on public.webora_sites
for update
to authenticated
using (
  owner = auth.uid()
)
with check (
  owner = auth.uid()
);


drop policy if exists "webora_sites_owner_delete"
on public.webora_sites;

create policy "webora_sites_owner_delete"
on public.webora_sites
for delete
to authenticated
using (
  owner = auth.uid()
);


-- Sites publiés visibles par tout le monde

drop policy if exists "webora_sites_public_read"
on public.webora_sites;

create policy "webora_sites_public_read"
on public.webora_sites
for select
to anon, authenticated
using (
  published = true
);


-- ============================================
-- 5. RLS — ABONNEMENTS
-- ============================================

alter table public.webora_subscriptions
enable row level security;


drop policy if exists "webora_subscriptions_owner_read"
on public.webora_subscriptions;

create policy "webora_subscriptions_owner_read"
on public.webora_subscriptions
for select
to authenticated
using (
  user_id = auth.uid()
);


-- ============================================
-- 6. STORAGE WEBORA
-- ============================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'webora-media',
  'webora-media',
  true,
  2097152,
  array[
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif'
  ]
)
on conflict (id) do nothing;


-- ============================================
-- 7. STORAGE — LECTURE PUBLIQUE
-- ============================================

drop policy if exists "webora_media_read"
on storage.objects;

create policy "webora_media_read"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'webora-media'
);


-- ============================================
-- 8. STORAGE — UPLOAD
-- ============================================

drop policy if exists "webora_media_insert"
on storage.objects;

create policy "webora_media_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'webora-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);


-- ============================================
-- 9. STORAGE — MODIFICATION
-- ============================================

drop policy if exists "webora_media_update"
on storage.objects;

create policy "webora_media_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'webora-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);


-- ============================================
-- 10. STORAGE — SUPPRESSION
-- ============================================

drop policy if exists "webora_media_delete"
on storage.objects;

create policy "webora_media_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'webora-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
