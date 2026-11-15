# Moments feature: install notes

## Files
- `supabase/migrations/20261201000000_swifs_moments.sql` - run in the SQL Editor first.
- `lib/model/moment_models.dart` - data classes.
- `lib/supabase/supabase_moments_repository.dart` - all Supabase calls for Moments.
- `lib/ui/page/moments/moments_page.dart` - the screen (story row, capsules, explore grid).
- `lib/ui/page/moments/story_viewer_page.dart` - full-screen tap-through viewer.
- `lib/ui/page/moments/story_composer_page.dart` - create a photo or text Moment.
- `lib/ui/page/moments/capsule_page.dart` - swipe deck for capsules and explore tiles.
- `lib/ui/page/moments/moments_widgets.dart` - shared widgets.
- `lib/ui/page/common/sidebar.dart` - full sidebar, with Moments enabled and wired up.

## Steps
1. Run the migration in Supabase.
2. Copy the `lib/` files into the project, replacing `sidebar.dart`.
3. `flutter pub get` (no new packages; uses existing google_fonts, image_picker, supabase_flutter, lucide_icons_flutter).
4. `flutter analyze`, then run on a device.

## Things to check
- `photo_rotation` is treated as degrees. Confirm this matches what your story editor saves.
- Trending capsules fall back to hashtags from recent posts because nothing fills `trending_tags` yet.
- Stories only appear for people you follow and yourself, because of the existing RLS policy.
- Fonts use Mulish, matching the rest of the app. The style prompt named Plus Jakarta Sans; change `momentTitle` and `momentMuted` in `moments_widgets.dart` if you want that instead.

## Not included yet
- "Nearby" filter (stories have a `place` column, but explore is post-based).
- Highlight collections and "Add Yours" prompt chains.
- Wiring the "View Moments" entry in the profile menu.
