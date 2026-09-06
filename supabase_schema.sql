-- ==============================================================================
-- ANILIVE SUPABASE DATABASE SCHEMA & REALTIME SETUP
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 2. PROFILES TABLE (sinkron dengan Supabase auth.users)
create table if not exists public.profiles (
  id text primary key,
  username text not null,
  display_name text,
  avatar_url text,
  banner_url text,
  bio text,
  birth_date date,
  followers_count int default 0,
  following_count int default 0,
  anime_completed_count int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. STATUS UPDATES (HOME FEED)
create table if not exists public.status_updates (
  id text primary key default gen_random_uuid()::text,
  user_id text not null,
  username text not null,
  avatar_url text,
  anime_id int not null,
  anime_title text not null,
  anime_cover_url text default '',
  watch_status text default 'completed',
  rating numeric(3,1),
  caption text default '',
  like_count int default 0,
  comment_count int default 0,
  liked_by text[] default '{}',
  created_at timestamptz default now()
);

-- 4. STATUS COMMENTS
create table if not exists public.status_comments (
  id text primary key default gen_random_uuid()::text,
  status_id text not null references public.status_updates(id) on delete cascade,
  user_id text not null,
  username text not null,
  avatar_url text,
  text text not null,
  created_at timestamptz default now()
);

-- 5. FRIENDSHIPS (SISTEM PERTEMANAN)
create table if not exists public.friendships (
  id text primary key default gen_random_uuid()::text,
  user_a text not null,
  user_b text not null,
  requester_id text not null,
  status text not null default 'pending', -- 'pending' | 'accepted' | 'rejected'
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_a, user_b)
);

-- 6. DIRECT MESSAGES (CHAT 1-ON-1 SESAMA TEMAN)
create table if not exists public.direct_messages (
  id text primary key default gen_random_uuid()::text,
  sender_id text not null,
  receiver_id text not null,
  content text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- 7. NOTIFICATIONS
create table if not exists public.notifications (
  id text primary key default gen_random_uuid()::text,
  recipient_user_id text not null,
  actor_id text not null,
  actor_username text not null,
  actor_avatar_url text,
  type text not null, -- 'friend_request' | 'friend_accepted' | 'love' | 'comment'
  title text not null,
  body text not null,
  reference_id text,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- 8. LIVE CHAT MESSAGES (ROOM CHAT ANIME)
create table if not exists public.live_chat_messages (
  id text primary key default gen_random_uuid()::text,
  anime_id int not null,
  user_id text not null,
  username text not null,
  avatar_url text,
  message text not null,
  created_at timestamptz default now()
);

-- 9. REVIEWS
create table if not exists public.reviews (
  id text primary key default gen_random_uuid()::text,
  anime_id int not null,
  user_id text not null,
  username text not null,
  user_avatar_url text,
  anime_title text default '',
  anime_cover_url text default '',
  rating numeric(3,1) not null,
  content text not null,
  likes_count int default 0,
  created_at timestamptz default now()
);

-- Pastikan kolom anime_title dan anime_cover_url ada jika tabel sudah terbuat sebelumnya
alter table public.reviews add column if not exists anime_title text default '';
alter table public.reviews add column if not exists anime_cover_url text default '';
alter table public.reviews add column if not exists watch_status text default 'completed';
alter table public.reviews add column if not exists watched_episodes int default 0;
alter table public.reviews add column if not exists total_episodes int;
alter table public.reviews add column if not exists is_completed boolean default true;
alter table public.status_updates add column if not exists watched_episodes int default 0;
alter table public.status_updates add column if not exists total_episodes int;

-- 10. CACHED ANIMES (DATABASE CLOUD UNTUK DATA ANIME HASIL SCRAPING)
create table if not exists public.cached_animes (
  id int primary key,
  title text not null,
  title_english text,
  title_japanese text,
  synopsis text,
  image_url text default '',
  score numeric(3,2),
  episodes int,
  status text,
  genres text[] default '{}',
  year int,
  format text,
  trailer_url text,
  characters jsonb default '[]',
  opening_themes text[] default '{}',
  ending_themes text[] default '{}',
  streaming_platforms text[] default '{}',
  studios text[] default '{}',
  full_data jsonb,
  updated_at timestamptz default now()
);

-- 11. FOLLOWS (SISTEM PERIKUTAN USER REALTIME)
create table if not exists public.follows (
  id text primary key default gen_random_uuid()::text,
  follower_id text not null,
  following_id text not null,
  created_at timestamptz default now(),
  unique(follower_id, following_id)
);

-- ==============================================================================
-- INDEXES UNTUK PERFORMA TINGGI (ANTI-LAG)
-- ==============================================================================
create index if not exists idx_follows_pair on public.follows(follower_id, following_id);
create index if not exists idx_cached_animes_score on public.cached_animes(score desc nulls last);
create index if not exists idx_cached_animes_title on public.cached_animes(title);
create index if not exists idx_status_updates_created on public.status_updates(created_at desc);
create index if not exists idx_status_comments_status on public.status_comments(status_id, created_at asc);
create index if not exists idx_friendships_users on public.friendships(user_a, user_b);
create index if not exists idx_direct_messages_pair on public.direct_messages(sender_id, receiver_id, created_at asc);
create index if not exists idx_notifications_recipient on public.notifications(recipient_user_id, created_at desc);
create index if not exists idx_live_chat_anime on public.live_chat_messages(anime_id, created_at asc);
create index if not exists idx_reviews_user on public.reviews(user_id, created_at desc);

-- ==============================================================================
-- ENABLE SUPABASE REALTIME REPLICATION (LIVE FEED, CHAT, NOTIFIKASI)
-- ==============================================================================
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'status_updates') then
    alter publication supabase_realtime add table public.status_updates;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'status_comments') then
    alter publication supabase_realtime add table public.status_comments;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'friendships') then
    alter publication supabase_realtime add table public.friendships;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'direct_messages') then
    alter publication supabase_realtime add table public.direct_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_chat_messages') then
    alter publication supabase_realtime add table public.live_chat_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reviews') then
    alter publication supabase_realtime add table public.reviews;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles') then
    alter publication supabase_realtime add table public.profiles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'follows') then
    alter publication supabase_realtime add table public.follows;
  end if;
end $$;

-- REPLICA IDENTITY FULL (Wajib agar seluruh kolom payload terkirim pada event UPDATE / DELETE Realtime)
alter table public.profiles replica identity full;
alter table public.status_updates replica identity full;
alter table public.status_comments replica identity full;
alter table public.friendships replica identity full;
alter table public.direct_messages replica identity full;
alter table public.notifications replica identity full;
alter table public.live_chat_messages replica identity full;
alter table public.reviews replica identity full;
alter table public.follows replica identity full;

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
alter table public.profiles enable row level security;
alter table public.status_updates enable row level security;
alter table public.status_comments enable row level security;
alter table public.friendships enable row level security;
alter table public.direct_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.live_chat_messages enable row level security;
alter table public.reviews enable row level security;
alter table public.follows enable row level security;

-- Public Read & Insert/Update Policies (Permissive for AnimeLive community app)
drop policy if exists "Allow read all profiles" on public.profiles;
create policy "Allow read all profiles" on public.profiles for select using (true);

drop policy if exists "Allow update own profile" on public.profiles;
create policy "Allow update own profile" on public.profiles for all using (true);

drop policy if exists "Allow all follows" on public.follows;
create policy "Allow all follows" on public.follows for all using (true);

drop policy if exists "Allow read all status_updates" on public.status_updates;
create policy "Allow read all status_updates" on public.status_updates for select using (true);

drop policy if exists "Allow all status_updates mutations" on public.status_updates;
create policy "Allow all status_updates mutations" on public.status_updates for all using (true);

drop policy if exists "Allow read all status_comments" on public.status_comments;
create policy "Allow read all status_comments" on public.status_comments for select using (true);

drop policy if exists "Allow all status_comments mutations" on public.status_comments;
create policy "Allow all status_comments mutations" on public.status_comments for all using (true);

drop policy if exists "Allow all friendships" on public.friendships;
create policy "Allow all friendships" on public.friendships for all using (true);

drop policy if exists "Allow all direct_messages" on public.direct_messages;
create policy "Allow all direct_messages" on public.direct_messages for all using (true);

drop policy if exists "Allow all notifications" on public.notifications;
create policy "Allow all notifications" on public.notifications for all using (true);

drop policy if exists "Allow all live_chat" on public.live_chat_messages;
create policy "Allow all live_chat" on public.live_chat_messages for all using (true);

drop policy if exists "Allow all reviews" on public.reviews;
create policy "Allow all reviews" on public.reviews for all using (true);

alter table public.cached_animes enable row level security;
drop policy if exists "Allow read all cached_animes" on public.cached_animes;
create policy "Allow read all cached_animes" on public.cached_animes for select using (true);
drop policy if exists "Allow all cached_animes mutations" on public.cached_animes;
create policy "Allow all cached_animes mutations" on public.cached_animes for all using (true);

-- ==============================================================================
-- 10. TRIGGER AUTO-CREATE / SYNC PROFILE DARI GOOGLE / EMAIL AUTH
-- ==============================================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (
    id,
    username,
    display_name,
    avatar_url,
    created_at,
    updated_at
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'username',
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'picture',
      ''
    ),
    now(),
    now()
  )
  on conflict (id) do update set
    avatar_url = case 
      when excluded.avatar_url <> '' then excluded.avatar_url 
      else public.profiles.avatar_url 
    end,
    updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

-- Pasang trigger di auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

