# Public Wanted List and Store Demand Analytics

An independent, brand-neutral tool for a record store. Customers can anonymously submit wanted Album or CD releases. Company staff sign in to a private dashboard with separate Analytics and Wanted List tabs. The Wanted List groups matching artist, title, year, and format, shows request counts, and lets staff mark requests fulfilled. Fulfilled requests remain stored and included in analytics but are hidden from the Wanted List by default. The Analytics tab shows popular artists, release-year and monthly trends, filters, and CSV export. Customer submissions are not shown publicly.

This version uses no CAPTCHA and no Edge Function. The public webpage inserts directly into Supabase under a restricted row-level security policy. A hidden honeypot can catch simple form bots, but it cannot stop direct API spam. Review unusual demand before using it to guide purchasing.

## Data captured

- Release year
- Format: Album or CD
- Artist or group
- Album title
- Submission timestamp (automatic)
- Fulfilled flag (company staff only; does not delete request data)

No customer name, email, or other personal information is collected. “Album Name” is represented as **Artist or group**, alongside **Album title**.

## Set up Supabase

1. In the company's Supabase project, open **SQL Editor → New query**.
2. For a new setup, paste all of `wanted-list.sql` and click **Run**.
3. If the app is already installed, run this migration once to add fulfillment tracking and allow authorized staff to update it:

   ```sql
   alter table public.wanted_items
     add column if not exists fulfilled boolean not null default false;

   grant update (fulfilled) on public.wanted_items to authenticated;
   grant insert (release_year, format, album_title, artist_name) on public.wanted_items to anon;

   drop policy if exists "Analysts can update fulfillment" on public.wanted_items;
   create policy "Analysts can update fulfillment"
     on public.wanted_items for update
     to authenticated
     using ((select public.is_wanted_analyst()))
     with check ((select public.is_wanted_analyst()));
   ```

   If the customer form reports `permission denied for table wanted_items`, run the `column-scoped `GRANT INSERT` statement above and recreate the public insert policy; the public form submits only year, format, artist, and title.

4. In **Authentication → Users**, create an email-and-password account for each administrator. Disable public signup in Supabase Auth settings. The Wanted List dashboard uses this Supabase Auth account; your GitHub sign-in for the Supabase Dashboard is separate.
5. Authorize each administrator by running this SQL for the exact account email:

   ```sql
   insert into public.wanted_analysts (user_id, email)
   select id, email from auth.users where email = 'buyer@yourstore.com'
   on conflict (user_id) do update set email = excluded.email;
   ```

6. Host `index.html` for customer submissions and `analytics.html` for staff. The customer page links to the administrator dashboard. Supabase stores the data; these HTML files need a web host.
7. At the dashboard login, use the same email and password from the administrator account. Only accounts listed in `wanted_analysts` can view request data and update fulfillment status.

## Access and data handling

- Public customers can submit requests but cannot list or read wanted items.
- Only authenticated analysts can read requests and update the `fulfilled` flag.
- Marking a grouped release fulfilled updates its existing submission rows. It does not delete them.
- Analytics continues to include fulfilled requests. The Wanted List hides fulfilled releases by default; use **Show fulfilled items** to review or unmark them.
- Direct anonymous inserts are enabled so the page does not need an Edge Function. Because this endpoint is public, automated submissions may still get through despite the hidden honeypot.
