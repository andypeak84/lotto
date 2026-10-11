-- Draw Room: Prediction Test upgrade
-- Run once in Supabase → SQL Editor (project draw-room).

-- Bonus picks: UK Lotto = 1 bonus ball (1-59), EuroMillions = 2 Lucky Stars (1-12)
alter table public.predictions add column if not exists bonus int[] not null default '{}';
alter table public.results     add column if not exists bonus int[] not null default '{}';

-- A prediction must be for a real draw day and be made before 19:30 UK time on that day.
create or replace function public.predictions_enforce_lock()
returns trigger language plpgsql set search_path = public as $$
declare dow int := extract(isodow from new.target_date);
begin
  if new.game = 'lotto' and dow not in (3,6) then
    raise exception 'UK Lotto draws are on Wednesdays and Saturdays';
  elsif new.game = 'euro' and dow not in (2,5) then
    raise exception 'EuroMillions draws are on Tuesdays and Fridays';
  end if;
  if (new.target_date + time '19:30') at time zone 'Europe/London' <= now() then
    raise exception 'Predictions for this draw are closed';
  end if;
  if tg_op = 'UPDATE' and (old.target_date + time '19:30') at time zone 'Europe/London' <= now() then
    raise exception 'This prediction is already locked';
  end if;
  return new;
end $$;

drop trigger if exists predictions_lock on public.predictions;
create trigger predictions_lock before insert or update on public.predictions
for each row execute function public.predictions_enforce_lock();

-- Users can withdraw their own prediction only while it is still open.
drop policy if exists "users can delete their own open prediction" on public.predictions;
create policy "users can delete their own open prediction" on public.predictions
for delete using (user_id = auth.uid() and (target_date + time '19:30') at time zone 'Europe/London' > now());

-- Admin can correct an already-entered result (upsert needs UPDATE).
drop policy if exists "only the admin account can correct results" on public.results;
create policy "only the admin account can correct results" on public.results
for update using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin))
with check (entered_by = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));
