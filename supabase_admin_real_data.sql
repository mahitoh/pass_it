-- Pass It admin analytics + real user identity queries
-- Run in Supabase SQL Editor as project owner.

begin;

-- Ensure role and points defaults exist.
alter table if exists public.profiles
  add column if not exists user_type text default 'student';

alter table if exists public.profiles
  add column if not exists points_balance integer default 0;

-- Helpful indexes for dashboard queries.
create index if not exists idx_profiles_user_type on public.profiles(user_type);
create index if not exists idx_paper_uploads_uploader_id on public.paper_uploads(uploader_id);
create index if not exists idx_paper_uploads_status on public.paper_uploads(status);

-- Institutions table (real admin-managed data, no mocks).
create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  status text not null default 'verified',
  created_at timestamptz not null default now()
);

create index if not exists idx_institutions_name on public.institutions(name);

alter table public.institutions enable row level security;

drop policy if exists "Institutions are readable by authenticated users" on public.institutions;
create policy "Institutions are readable by authenticated users"
on public.institutions
for select
to authenticated
using (true);

drop policy if exists "Only admins can insert institutions" on public.institutions;
create policy "Only admins can insert institutions"
on public.institutions
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.user_type, 'student')) in ('admin', 'super_admin', 'moderator')
  )
);

drop policy if exists "Only admins can delete institutions" on public.institutions;
create policy "Only admins can delete institutions"
on public.institutions
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.user_type, 'student')) in ('admin', 'super_admin', 'moderator')
  )
);

-- RPC 1: real user list with name + email + role + points.
create or replace function public.admin_list_users()
returns table (
  id uuid,
  full_name text,
  email text,
  user_type text,
  points_balance integer,
  created_at timestamptz
)
language sql
security definer
set search_path = public, auth
as $$
  select
    p.id,
    nullif(trim(p.full_name), '') as full_name,
    u.email,
    coalesce(nullif(trim(p.user_type), ''), 'student') as user_type,
    coalesce(p.points_balance, 0) as points_balance,
    u.created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  order by u.created_at desc;
$$;

-- RPC 2: aggregate usage stats for admin dashboard.
create or replace function public.admin_usage_stats()
returns table (
  total_users integer,
  total_uploads integer,
  approved_uploads integer,
  pending_uploads integer,
  rejected_uploads integer,
  total_views bigint,
  total_downloads bigint,
  active_uploaders integer
)
language sql
security definer
set search_path = public
as $$
  with uploads as (
    select
      uploader_id,
      status,
      coalesce(
        nullif(to_jsonb(pu)->>'views', '')::bigint,
        nullif(to_jsonb(pu)->>'view_count', '')::bigint,
        nullif(to_jsonb(pu)->>'reads', '')::bigint,
        0
      ) as views,
      coalesce(
        nullif(to_jsonb(pu)->>'downloads', '')::bigint,
        nullif(to_jsonb(pu)->>'download_count', '')::bigint,
        0
      ) as downloads
    from public.paper_uploads pu
  )
  select
    (select count(*)::int from public.profiles) as total_users,
    count(*)::int as total_uploads,
    count(*) filter (where status = 'approved')::int as approved_uploads,
    count(*) filter (where status = 'pending')::int as pending_uploads,
    count(*) filter (where status = 'rejected')::int as rejected_uploads,
    coalesce(sum(views), 0)::bigint as total_views,
    coalesce(sum(downloads), 0)::bigint as total_downloads,
    count(distinct uploader_id)::int as active_uploaders
  from uploads;
$$;

revoke all on function public.admin_list_users() from public;
revoke all on function public.admin_usage_stats() from public;

grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_usage_stats() to authenticated;

commit;

-- Optional diagnostics you can run after setup:
-- 1) Check user rows and emails
-- select * from public.admin_list_users() limit 50;

-- 2) Check dashboard totals
-- select * from public.admin_usage_stats();

-- 3) Quick institution usage snapshot
-- select
--   institution,
--   count(*) as uploads,
--   count(distinct uploader_id) as contributors,
--   sum(coalesce(views, 0)) as views,
--   sum(coalesce(downloads, 0)) as downloads
-- from public.paper_uploads
-- group by institution
-- order by uploads desc;
