-- Draw Room: run THIS ONE file in Supabase → SQL Editor. It includes everything from
-- 2026-10-11_prediction_bonus_and_lock.sql plus the admin report pieces. Safe to run more than once.


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


-- 1) SECURITY FIX: the "users can update their own profile" policy lets any
--    signed-in user set is_admin = true on their own row. Block that: only
--    an existing admin (or the database itself) can change is_admin.
create or replace function public.profiles_protect_admin_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_admin is distinct from old.is_admin
     and auth.uid() is not null
     and not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin) then
    raise exception 'Only an admin can change admin status';
  end if;
  return new;
end $$;

drop trigger if exists profiles_protect_admin on public.profiles;
create trigger profiles_protect_admin before update on public.profiles
for each row execute function public.profiles_protect_admin_flag();

-- 2) Admin-only: email addresses for the report (auth.users isn't readable from the browser).
create or replace function public.admin_user_emails()
returns table (id uuid, email text)
language plpgsql security definer set search_path = public, auth as $$
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin) then
    raise exception 'admin only';
  end if;
  return query select u.id, u.email::text from auth.users u;
end $$;

revoke all on function public.admin_user_emails() from public, anon;
grant execute on function public.admin_user_emails() to authenticated;


-- 3) Welcome questions: stored once per player, used in the admin research report.
create table if not exists public.onboarding (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  age_confirmed boolean not null default false,
  game          text check (game in ('lotto','euro','both','neither')),
  frequency     text check (frequency in ('never','occasionally','weekly','every_draw')),
  pick_methods  text[] not null default '{}',
  quiz_answers  int[]  not null default '{}',
  quiz_score    int,
  completed_at  timestamptz not null default now(),
  constraint onboarding_quiz_ok check (
    (quiz_answers = '{}' and quiz_score is null)
    or (array_length(quiz_answers,1) = 8 and quiz_score between 8 and 40)
  )
);
alter table public.onboarding enable row level security;

drop policy if exists "players can read their own onboarding" on public.onboarding;
create policy "players can read their own onboarding" on public.onboarding
for select using (user_id = auth.uid());

drop policy if exists "admins can read all onboarding" on public.onboarding;
create policy "admins can read all onboarding" on public.onboarding
for select using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

drop policy if exists "players can save their own onboarding" on public.onboarding;
create policy "players can save their own onboarding" on public.onboarding
for insert with check (user_id = auth.uid());
