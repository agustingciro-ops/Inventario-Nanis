-- Catálogo de productos (TikTok Shop) + fotos para el buscador del sistema de tickets
-- Bucket de Storage: fotos-de-productos (lectura pública para poder mostrar y copiar las fotos)

insert into storage.buckets (id, name, public)
values ('fotos-de-productos', 'fotos-de-productos', true)
on conflict (id) do update set public = true;

drop policy if exists "fotos_subir"      on storage.objects;
drop policy if exists "fotos_actualizar" on storage.objects;
drop policy if exists "fotos_borrar"     on storage.objects;
create policy "fotos_subir"      on storage.objects for insert to authenticated with check (bucket_id = 'fotos-de-productos');
create policy "fotos_actualizar" on storage.objects for update to authenticated using (bucket_id = 'fotos-de-productos') with check (bucket_id = 'fotos-de-productos');
create policy "fotos_borrar"     on storage.objects for delete to authenticated using (bucket_id = 'fotos-de-productos');

-- Un producto de TikTok (modelo). id = product_id de TikTok
create table if not exists public.productos (
  id           text primary key,
  modelo       text not null,          -- nombre corto: "SOL", "Mireya", "W68"
  nombre       text not null,          -- título completo en TikTok
  tipo         text not null default 'Sandalia',  -- Sandalia / Tenis
  altura       text not null default '',          -- Flat, 3 cm, 6 cm, 12 cm, 14 cm, 15 cm…
  activo       boolean not null default true,
  actualizado  timestamptz not null default now()
);

-- Una foto por color de cada producto
create table if not exists public.producto_colores (
  producto_id  text not null references public.productos(id) on delete cascade,
  color        text not null,          -- "Único" cuando el producto no tiene variante de color
  foto         text not null default '',  -- ruta dentro del bucket fotos-de-productos
  foto_origen  text not null default '',  -- uri de la imagen en TikTok (para saber si cambió)
  primary key (producto_id, color)
);

-- Inventario por variante (color + talla + altura)
create table if not exists public.producto_skus (
  sku_id       text primary key,
  producto_id  text not null references public.productos(id) on delete cascade,
  color        text not null default 'Único',
  talla        text not null default '',
  altura       text not null default '',
  stock        integer not null default 0
);
create index if not exists producto_skus_prod_idx on public.producto_skus(producto_id);

alter table public.productos        enable row level security;
alter table public.producto_colores enable row level security;
alter table public.producto_skus    enable row level security;

do $$
declare t text;
begin
  foreach t in array array['productos','producto_colores','producto_skus'] loop
    execute format('drop policy if exists "%s_leer" on public.%I', t, t);
    execute format('drop policy if exists "%s_escribir" on public.%I', t, t);
    execute format('create policy "%s_leer" on public.%I for select to authenticated using (true)', t, t);
    execute format('create policy "%s_escribir" on public.%I for all to authenticated using (true) with check (true)', t, t);
  end loop;
end $$;
