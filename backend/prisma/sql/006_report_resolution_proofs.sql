create table if not exists public.report_resolution_proofs (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  proof_photo_url text not null,
  note text,
  resolved_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists report_resolution_proofs_report_id_idx
on public.report_resolution_proofs(report_id);

create index if not exists report_resolution_proofs_resolved_by_idx
on public.report_resolution_proofs(resolved_by);

alter table public.report_resolution_proofs enable row level security;

drop policy if exists "report_resolution_proofs_select_related" on public.report_resolution_proofs;
create policy "report_resolution_proofs_select_related"
on public.report_resolution_proofs
for select
to authenticated
using (
  public.current_user_is_staff()
  or exists (
    select 1
    from public.reports
    where reports.id = report_resolution_proofs.report_id
      and reports.user_id = auth.uid()
  )
);

drop policy if exists "report_resolution_proofs_staff_insert" on public.report_resolution_proofs;
create policy "report_resolution_proofs_staff_insert"
on public.report_resolution_proofs
for insert
to authenticated
with check (public.current_user_is_staff());
