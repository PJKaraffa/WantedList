# Public Wanted List and Store Demand Analytics

An independent, brand-neutral tool for a record store. Customers can anonymously submit wanted Album or CD releases. Company staff sign in to a private dashboard with demand counts, popular releases and artists, release-year and monthly trends, filters, and CSV export. Customer submissions are not shown publicly.

This version does not require CAPTCHA. A hidden honeypot and server-side validation discourage simple automated submissions, but they cannot block all spam. Review unusual demand before using it to guide purchasing.

## Data captured

- Release year
- Format: Album or CD
- Artist or group
- Album title
- Submission timestamp (automatic)

No customer name, email, or other personal information is collected. “Album Name” is represented as **Artist or group**, alongside **Album title**.

## Setup

1. Create a dedicated Supabase project for the company.
2. In Supabase **SQL Editor**, run `wanted-list.sql`.
3. Create company staff accounts in **Authentication → Users**. Disable public signup in Supabase Auth settings; the analytics page has sign-in only.
4. Authorize each analyst. Run this SQL once per staff account, replacing the email with the exact account email:

   ```sql
   insert into public.wanted_analysts (user_id, email)
   select id, email from auth.users where email = 'buyer@yourstore.com'
   on conflict (user_id) do update set email = excluded.email;
   ```

5. Set the company Supabase project URL and public publishable/anon key in both `index.html` and `analytics.html`.
6. From the unzipped `wanted-list` folder, deploy the public submission function using the Supabase CLI:

   ```sh
   npx supabase login
   npx supabase link --project-ref YOUR_PROJECT_REF
   npx supabase functions deploy submit-wanted --no-verify-jwt
   ```

   Supabase supplies the service-role key to the Edge Function automatically; do not add it to the webpages.
7. Host `index.html` as the public customer form and `analytics.html` for staff. Supabase Row Level Security protects the analytics data even if the dashboard URL is known.

## Access controls

- Public visitors can submit release details through the Edge Function.
- Public visitors cannot list or read submitted requests.
- Authenticated users can read requests only when their account is listed in `wanted_analysts`.
- Direct browser inserts are denied. The Edge Function validates submission fields and ignores requests that fill the hidden honeypot field.
