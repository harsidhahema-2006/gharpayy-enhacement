-- Create a new bucket for property images
insert into storage.buckets (id, name, public) values ('property_images', 'property_images', true)
on conflict (id) do nothing;

-- Storage Policies
-- 1. Allow public to view images
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'property_images' );

-- 2. Allow owners to upload their own property images
create policy "Owners can upload property images"
on storage.objects for insert
with check (
  bucket_id = 'property_images' AND
  (public.get_user_role() = 'owner' OR public.get_user_role() = 'admin')
);

-- 3. Allow owners to delete their own property images
create policy "Owners can delete property images"
on storage.objects for delete
using (
  bucket_id = 'property_images' AND
  (public.get_user_role() = 'owner' OR public.get_user_role() = 'admin')
);
