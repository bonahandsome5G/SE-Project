do $$
begin
  create type public.user_role as enum ('citizen', 'dishub', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.report_status as enum (
    'pending',
    'queued',
    'accepted',
    'rejected',
    'in_progress',
    'resolved',
    'suspected_spam'
  );
exception
  when duplicate_object then null;
end $$;

alter table if exists public.profiles
  add column if not exists full_name text,
  add column if not exists role public.user_role default 'citizen',
  add column if not exists is_blocked boolean default false,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.categories
  add column if not exists description text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now();

insert into public.categories (id, name, description)
values
  (1, 'Jalan Berlubang', 'Kerusakan permukaan jalan yang berisiko bagi pengguna jalan'),
  (2, 'Lampu Jalan Mati', 'Penerangan jalan umum tidak berfungsi'),
  (3, 'Rambu Rusak', 'Rambu lalu lintas rusak, hilang, atau tidak terlihat'),
  (4, 'Trotoar Rusak', 'Trotoar retak, berlubang, atau tidak aman dilalui'),
  (5, 'Kemacetan/Penghalang Jalan', 'Hambatan jalan yang perlu ditindaklanjuti'),
  (6, 'Drainase Tersumbat', 'Saluran air tersumbat atau rusak sehingga mengganggu jalan'),
  (7, 'Lampu Lalu Lintas Rusak', 'Traffic light mati, error, atau tidak sinkron'),
  (8, 'Marka Jalan Pudar', 'Marka jalan tidak terlihat jelas atau perlu pengecatan ulang'),
  (9, 'Jembatan/Pagar Pengaman Rusak', 'Kerusakan jembatan kecil, guardrail, atau pagar pengaman jalan'),
  (10, 'Lainnya', 'Masalah infrastruktur jalan lain yang belum masuk kategori utama')
on conflict (id) do update
set name = excluded.name,
    description = excluded.description;

alter table if exists public.reports
  alter column user_id set not null,
  alter column category_id set not null,
  alter column description set not null,
  alter column photo_url set not null,
  alter column latitude set not null,
  alter column longitude set not null,
  add column if not exists is_suspected_spam boolean not null default false,
  add column if not exists submitted_outside_office_hours boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  alter table public.reports
    alter column status type public.report_status
    using replace(status::text, 'suspected spam', 'suspected_spam')::public.report_status;
exception
  when undefined_column then
    alter table public.reports add column status public.report_status not null default 'pending';
  when datatype_mismatch then
    alter table public.reports add column if not exists status public.report_status not null default 'pending';
end $$;

create table if not exists public.report_status_updates (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  status public.report_status not null,
  note text,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.report_reviews (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.reports(id) on delete cascade,
  spam_score double precision,
  spam_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  blocked_by uuid references public.profiles(id),
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists reports_user_id_idx on public.reports(user_id);
create index if not exists reports_category_id_idx on public.reports(category_id);
create index if not exists reports_status_idx on public.reports(status);
create index if not exists reports_is_suspected_spam_idx on public.reports(is_suspected_spam);
create index if not exists report_status_updates_report_id_idx on public.report_status_updates(report_id);
create index if not exists report_status_updates_updated_by_idx on public.report_status_updates(updated_by);
create index if not exists report_reviews_reviewed_by_idx on public.report_reviews(reviewed_by);
create index if not exists user_blocks_user_id_idx on public.user_blocks(user_id);
create index if not exists notification_tokens_user_id_idx on public.notification_tokens(user_id);

create or replace function public.current_user_role()
returns public.user_role
language sql
security definer
set search_path = public
stable
as $$
  select role
  from public.profiles
  where id = auth.uid()
$$;

create or replace function public.current_user_is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.current_user_role() in ('admin', 'dishub'), false)
$$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.reports enable row level security;
alter table public.report_status_updates enable row level security;
alter table public.report_reviews enable row level security;
alter table public.user_blocks enable row level security;
alter table public.notification_tokens enable row level security;

drop policy if exists "profiles_select_own_or_staff" on public.profiles;
create policy "profiles_select_own_or_staff"
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.current_user_is_staff());

drop policy if exists "profiles_update_own_basic_data" on public.profiles;
create policy "profiles_update_own_basic_data"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "profiles_staff_update" on public.profiles;
create policy "profiles_staff_update"
on public.profiles
for update
to authenticated
using (public.current_user_is_staff())
with check (public.current_user_is_staff());

drop policy if exists "categories_read_authenticated" on public.categories;
create policy "categories_read_authenticated"
on public.categories
for select
to authenticated
using (is_active = true or public.current_user_is_staff());

drop policy if exists "categories_staff_write" on public.categories;
create policy "categories_staff_write"
on public.categories
for all
to authenticated
using (public.current_user_is_staff())
with check (public.current_user_is_staff());

drop policy if exists "reports_select_own_or_staff" on public.reports;
create policy "reports_select_own_or_staff"
on public.reports
for select
to authenticated
using (user_id = auth.uid() or public.current_user_is_staff());

drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
on public.reports
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "reports_staff_update" on public.reports;
create policy "reports_staff_update"
on public.reports
for update
to authenticated
using (public.current_user_is_staff())
with check (public.current_user_is_staff());

drop policy if exists "report_status_updates_select_related" on public.report_status_updates;
create policy "report_status_updates_select_related"
on public.report_status_updates
for select
to authenticated
using (
  public.current_user_is_staff()
  or exists (
    select 1
    from public.reports
    where reports.id = report_status_updates.report_id
      and reports.user_id = auth.uid()
  )
);

drop policy if exists "report_status_updates_staff_insert" on public.report_status_updates;
create policy "report_status_updates_staff_insert"
on public.report_status_updates
for insert
to authenticated
with check (public.current_user_is_staff());

drop policy if exists "report_reviews_staff_all" on public.report_reviews;
create policy "report_reviews_staff_all"
on public.report_reviews
for all
to authenticated
using (public.current_user_is_staff())
with check (public.current_user_is_staff());

drop policy if exists "user_blocks_staff_all" on public.user_blocks;
create policy "user_blocks_staff_all"
on public.user_blocks
for all
to authenticated
using (public.current_user_is_staff())
with check (public.current_user_is_staff());

drop policy if exists "notification_tokens_own_all" on public.notification_tokens;
create policy "notification_tokens_own_all"
on public.notification_tokens
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "notification_tokens_staff_select" on public.notification_tokens;
create policy "notification_tokens_staff_select"
on public.notification_tokens
for select
to authenticated
using (public.current_user_is_staff());
