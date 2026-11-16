# Public Wanted List and Store Demand Analytics

An independent, brand-neutral tool for a record store. Customers can anonymously submit wanted Album or CD releases. Company staff sign in to a private dashboard with separate Analytics and Wanted List tabs. The Wanted List groups matching artist, title, year, and format, shows request counts, and lets staff mark requests fulfilled. Fulfilled requests remain stored and included in analytics but are hidden from the Wanted List by default. The Analytics tab shows popular artists, release-year and monthly trends, filters, and CSV export. Customer submissions are not shown publicly.

This version uses no CAPTCHA and no Edge Function. The public page submits through a database function that accepts only the four release fields and creates the ID, timestamp, and fulfillment status in the database. A hidden honeypot can catch simple form bots, but public submissions can still be automated. Review unusual demand before using it to guide purchasing.

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
3. If the app is already installed, run the updated `wanted-list.sql` in SQL Editor. It adds fulfillment tracking and the restricted submission function without deleting existing requests. This replaces direct browser inserts; no Supabase Edge Function or CLI deployment is required.

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

- Public customers can submit requests through the database function but cannot list or read wanted items or insert directly into the table.
- Only authenticated analysts can read requests and update the `fulfilled` flag.
- Marking a grouped release fulfilled updates its existing submission rows. It does not delete them.
- Analytics continues to include fulfilled requests. The Wanted List hides fulfilled releases by default; use **Show fulfilled items** to review or unmark them.
- The database function inserts only release year, format, artist, and title. Public users cannot provide IDs, timestamps, or fulfillment status. Automated submissions may still get through despite the hidden honeypot.
