-- Sistema de tickets Nanis Boutique · estructura de la base de datos (Supabase / PostgreSQL)
-- Pegar completo en Supabase → SQL Editor → Run. Se puede correr una sola vez.

create table if not exists public.tickets (
  id          bigint generated always as identity primary key,   -- TK-0001 = id 1
  name        text not null,
  phone       text not null,
  order_no    text not null default '',
  model       text not null default '',
  size        text not null default '',
  color       text not null default '',
  reason      text not null,
  owner       text not null default 'Carolina',
  follow      date,
  status      text not null default 'Abierto'
              check (status in ('Abierto','En proceso','Esperando al cliente','Solucionado')),
  ref_id      bigint references public.tickets(id),
  created_at  timestamptz not null default now(),
  created_by  text not null default '',
  updated_at  timestamptz not null default now()
);

create table if not exists public.notes (
  id          bigint generated always as identity primary key,
  ticket_id   bigint not null references public.tickets(id),
  by_name     text not null,
  body        text not null,
  sys         boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists notes_ticket_idx on public.notes(ticket_id, created_at);

-- Seguridad: solo usuarias con sesión iniciada. Sin políticas de borrado = nadie borra.
alter table public.tickets enable row level security;
alter table public.notes   enable row level security;

drop policy if exists "tickets_leer"      on public.tickets;
drop policy if exists "tickets_crear"     on public.tickets;
drop policy if exists "tickets_editar"    on public.tickets;
drop policy if exists "notas_leer"        on public.notes;
drop policy if exists "notas_agregar"     on public.notes;

create policy "tickets_leer"   on public.tickets for select to authenticated using (true);
create policy "tickets_crear"  on public.tickets for insert to authenticated with check (status <> 'Solucionado');
-- Un ticket Solucionado queda bloqueado: ya no se puede editar.
create policy "tickets_editar" on public.tickets for update to authenticated using (status <> 'Solucionado') with check (true);

create policy "notas_leer"     on public.notes for select to authenticated using (true);
-- Las notas solo se agregan (no se editan ni se borran) y no se aceptan en tickets solucionados.
create policy "notas_agregar"  on public.notes for insert to authenticated
  with check (exists (select 1 from public.tickets t where t.id = ticket_id and t.status <> 'Solucionado'));

-- Cambios en vivo para todas las que tengan el panel abierto
do $$ begin
  alter publication supabase_realtime add table public.tickets;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notes;
exception when duplicate_object then null; end $$;

-- Autoría por sesión: quien crea el ticket o escribe la nota queda registrado con su correo.
-- La base de datos lo pone sola, así nadie puede firmar a nombre de otra persona.
create or replace function public.set_author() returns trigger
language plpgsql security definer set search_path = public as $$
declare who text := auth.jwt() ->> 'email';
begin
  if who is null then return new; end if;
  if tg_table_name = 'tickets' then
    new.created_by := who;
    if coalesce(new.owner, '') = '' then new.owner := who; end if;
  else
    new.by_name := who;
  end if;
  return new;
end $$;

drop trigger if exists tickets_author on public.tickets;
create trigger tickets_author before insert on public.tickets for each row execute function public.set_author();
drop trigger if exists notes_author on public.notes;
create trigger notes_author before insert on public.notes for each row execute function public.set_author();

alter table public.tickets alter column owner set default '';
