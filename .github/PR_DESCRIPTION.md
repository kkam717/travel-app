<!--
  PR Title format: DT-XXXX: Description of Ticket
  Suggested title: feat: Home feed, social following, and onboarding fixes
-->

## Description of changes made
<!-- Describe the changes in this PR -->

- **Home feed**: New Home screen with Instagram-like feed showing trips from people you follow plus your own trips. Includes "Welcome back!" header, stats cards (Countries, Trips, Followers), and itinerary cards with bookmark, author, description, duration, and locations.

- **Social following**: Added `follows` table and migration 003. Users can follow/unfollow others from author profile screens. Followed users' public and friends itineraries appear in the feed.

- **Onboarding fixes**: "Save & Continue" on travel preferences now works reliably (travel mode optional, brief delay before navigation to avoid redirect race).

- **Navigation**: Home added as first tab in bottom nav. Default route after onboarding is now `/home` instead of `/search`.

- **Developer sign-in**: Added quick sign-in button on welcome screen for development.

- **Author discovery**: Tappable author names on Search and Home feed cards to view profiles and follow.


## Screenshot of changes
<!-- Add a screenshot if needed -->

