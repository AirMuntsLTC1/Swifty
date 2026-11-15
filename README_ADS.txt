SWIFLY: ADS IN THE HOME FEED
============================

WHAT IT DOES
- An ad appears after every 6 posts in the home feed.
- Each ad shows: advertiser avatar, advertiser name (verified badge if the
  advertiser is verified), "Ad" label with a globe, a "..." menu, an X to hide,
  body text, an image, and a headline with a call-to-action button.
- Tapping the image or button records a click and opens the link (uses the same
  in-app browser setting as the rest of the app).
- The first time an ad is at least half visible, an impression is recorded.
- "Hide ad" (from the X or the menu) hides that ad for you only.
- No placeholder or sample ads. If no campaign is active, the feed shows
  nothing where the ads would go.

WHAT YOU NEED TO KNOW BEFORE LAUNCH
- Ads must be real, paid advertising. This version does NOT take payments.
  Campaigns are created by you in the SQL Editor. Add payments later
  (for example Stripe) if you want advertisers to pay in the app.
- Only use advertisers that are real and whose ads follow your content rules.
- The "verified" tick only appears when advertiser_verified = true. Set it only
  for advertisers you have confirmed.

STEPS
1. Unzip into the project (see the unzip steps you used before).
2. Run the migration in the Supabase SQL Editor:
     supabase/migrations/20261207000000_swifly_ads.sql
3. Run the feed patch from the project root:
     python3 patch_ads.py
4. Build the APK through GitHub Actions.
5. Add a real campaign (SQL Editor). Replace the values in <angle brackets>
   with a real advertiser's details. Ads are shown only when status = 'active':

     insert into public.ad_campaigns
       (advertiser_name, advertiser_handle, advertiser_avatar_url,
        advertiser_verified, headline, body, image_url, cta_label, cta_url,
        status, ends_at)
     values
       ('<Advertiser name>', '<@handle>', '<avatar https url>',
        <true or false>, '<headline>', '<body text>', '<image https url>',
        'Learn more', '<https://landing-page-url>',
        'active', null);

6. To pause an ad: update public.ad_campaigns set status = 'paused' where id = '<id>';
7. To see results:
     select c.headline, e.kind, count(*)
     from public.ad_events e join public.ad_campaigns c on c.id = e.campaign_id
     group by c.headline, e.kind;

NOTES
- Impressions are counted once per ad per time the card loads. A refresh counts
  again.
- The feed does not yet check ad content against your rules automatically.
  Review each campaign before you set it to active.
