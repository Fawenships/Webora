-- Webora : schéma Supabase (à coller dans SQL Editor puis Run)

-- 1. Sites : un site appartient à un seul utilisateur
create table public.sites (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null default 'Mon activité',
  template text not null,
  category text not null check (category in ('boutique','restaurant','salon')),
  subdomain text unique check (subdomain ~ '^[a-z0-9-]{3,30}$'),
  published boolean not null default false,
  content jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
create trigger sites_touch before update on public.sites
  for each row execute function public.touch_updated_at();

-- 2. Abonnements : lecture seule côté client (pas de changement de plan par l'utilisateur)
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users(id) on delete cascade,
  plan text not null default 'basique' check (plan in ('basique','pro','promax')),
  starts_at timestamptz not null default now(),
  free_until timestamptz,
  ends_at timestamptz not null default now() + interval '3 months'
);

-- Chaque nouveau compte reçoit le plan Basique, 3 mois, 1er mois offert
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.subscriptions (owner, plan, free_until)
  values (new.id, 'basique', now() + interval '1 month');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3. Sécurité par ligne (RLS)
alter table public.sites enable row level security;
alter table public.subscriptions enable row level security;

create policy "sites_owner_all" on public.sites for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
create policy "sites_public_read" on public.sites for select to anon, authenticated
  using (published);
create policy "subs_owner_read" on public.subscriptions for select to authenticated
  using (owner = auth.uid());

-- 4. Images : bucket public, 2 Mo, images seulement (pas de SVG), dossier = id de l'utilisateur
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media','media', true, 2097152, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do nothing;

create policy "media_read" on storage.objects for select using (bucket_id = 'media');
create policy "media_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
