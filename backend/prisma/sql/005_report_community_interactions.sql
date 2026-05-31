create table if not exists public.report_comments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.report_upvotes (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (report_id, user_id)
);

create table if not exists public.report_flags (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (report_id, user_id)
);

create index if not exists report_comments_report_id_idx on public.report_comments(report_id);
create index if not exists report_comments_user_id_idx on public.report_comments(user_id);
create index if not exists report_upvotes_user_id_idx on public.report_upvotes(user_id);
create index if not exists report_flags_user_id_idx on public.report_flags(user_id);

alter table public.report_comments enable row level security;
alter table public.report_upvotes enable row level security;
alter table public.report_flags enable row level security;

drop policy if exists "report_comments_select_related" on public.report_comments;
create policy "report_comments_select_related"
on public.report_comments
for select
to authenticated
using (
  public.current_user_is_staff()
  or exists (
    select 1
    from public.reports
    where reports.id = report_comments.report_id
      and reports.is_suspected_spam = false
      and reports.status <> 'rejected'
  )
);

drop policy if exists "report_comments_insert_own" on public.report_comments;
create policy "report_comments_insert_own"
on public.report_comments
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "report_upvotes_select_related" on public.report_upvotes;
create policy "report_upvotes_select_related"
on public.report_upvotes
for select
to authenticated
using (
  public.current_user_is_staff()
  or exists (
    select 1
    from public.reports
    where reports.id = report_upvotes.report_id
      and reports.is_suspected_spam = false
      and reports.status <> 'rejected'
  )
);

drop policy if exists "report_upvotes_own_all" on public.report_upvotes;
create policy "report_upvotes_own_all"
on public.report_upvotes
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "report_flags_own_insert" on public.report_flags;
create policy "report_flags_own_insert"
on public.report_flags
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "report_flags_own_or_staff_select" on public.report_flags;
create policy "report_flags_own_or_staff_select"
on public.report_flags
for select
to authenticated
using (user_id = auth.uid() or public.current_user_is_staff());
