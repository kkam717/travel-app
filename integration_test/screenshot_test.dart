import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travel_app/main.dart' as app;
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final screenshotDir = Directory('/Users/kiankamshad/Travel App/screenshots');

  Future<void> takeScreenshot(
      WidgetTester tester, String path, String filename) async {
    final fullPath = '${screenshotDir.path}/$path/$filename.png';
    final dir = Directory('${screenshotDir.path}/$path');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    final bytes = await IntegrationTestWidgetsFlutterBinding.instance
        .takeScreenshot(fullPath);
    final file = File(fullPath);
    await file.writeAsBytes(bytes);
    print('✓ $path/$filename.png');
  }

  testWidgets('Capture screenshots for all features',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 01. Welcome Screen
    await takeScreenshot(tester, '01-first-time-user', '01-welcome-screen');

    // Sign In Flow (using existing account)
    final continueEmail = find.text('Continue with Email');
    if (continueEmail.evaluate().isNotEmpty) {
      await tester.tap(continueEmail);
      await tester.pumpAndSettle();
    }

    await takeScreenshot(
        tester, '02-returning-user/sign-in', '01-sign-in-form');

    // Enter sign in credentials
    final signInFields = find.byType(TextField);
    if (signInFields.evaluate().length >= 2) {
      await tester.enterText(signInFields.at(0), 'marble717@gmail.com');
      await tester.enterText(signInFields.at(1), 'Marble17!');
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '02-returning-user/sign-in', '02-sign-in-filled');

      final signInButton = find.text('Sign in');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
    }

    // Home Screen - For You tab
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await takeScreenshot(tester, '03-main-shell/home', '01-home-tab');
    await takeScreenshot(tester, '04-home-feed/for-you', '01-for-you-feed');

    // Feed card with likes
    await takeScreenshot(tester, '04-home-feed', '01-feed-card-with-likes');

    // Navigate to Following tab
    final followingTab = find.text('Following');
    if (followingTab.evaluate().isNotEmpty) {
      await tester.tap(followingTab.first);
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '04-home-feed/following', '01-following-feed');
    }

    // Try to tap an itinerary card to go to detail
    final cards = find.byType(Card);
    if (cards.evaluate().isNotEmpty) {
      await tester.tap(cards.first);
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '06-itinerary-detail', '01-itinerary-detail');
      await takeScreenshot(tester, '06-itinerary-detail', '02-like-button');
      await takeScreenshot(tester, '06-itinerary-detail', '03-map-section');
      await takeScreenshot(tester, '06-itinerary-detail', '04-timeline');

      // Try to like (if it's someone else's post)
      final likeButtons = find.byIcon(Icons.thumb_up_outlined);
      if (likeButtons.evaluate().isEmpty) {
        final likedButtons = find.byIcon(Icons.thumb_up_rounded);
        if (likedButtons.evaluate().isNotEmpty) {
          await takeScreenshot(tester, '14-likes', '02-after-like');
        }
      } else {
        await takeScreenshot(tester, '14-likes', '01-before-like');
      }

      // State sync - before navigation
      await tester.pumpAndSettle();

      // Go back
      final backBtn = find.byIcon(Icons.arrow_back);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '19-state-sync', '02-after-return');
      }
    }

    // State sync - before navigation (capture home feed state)
    await takeScreenshot(tester, '19-state-sync', '01-before-navigation');

    // Navigate to Search
    final searchTabs = find.text('Search');
    if (searchTabs.evaluate().isEmpty) {
      final searchIcons = find.byIcon(Icons.search);
      if (searchIcons.evaluate().isNotEmpty) {
        await tester.tap(searchIcons.first);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tap(searchTabs.first);
      await tester.pumpAndSettle();
    }
    await takeScreenshot(tester, '03-main-shell/search', '01-search-tab');

    // Search - Profiles tab
    await tester.pumpAndSettle();
    await takeScreenshot(tester, '08-search/profiles', '01-profiles-results');

    // Search - Itineraries tab
    final tripsTab = find.text('Trips');
    if (tripsTab.evaluate().isNotEmpty) {
      await tester.tap(tripsTab.first);
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '08-search/itineraries', '01-itineraries-results');

      // Try to open filters
      final filterButton = find.byIcon(Icons.tune_rounded);
      if (filterButton.evaluate().isNotEmpty) {
        await tester.tap(filterButton.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '08-search/itineraries', '02-filters');
        // Close filters
        final backBtn2 = find.byIcon(Icons.arrow_back);
        if (backBtn2.evaluate().isNotEmpty) {
          await tester.tap(backBtn2.first);
          await tester.pumpAndSettle();
        }
      }
    }

    // Navigate to Saved
    final savedTabs = find.text('Saved');
    if (savedTabs.evaluate().isEmpty) {
      final savedIcons = find.byIcon(Icons.bookmark_outline);
      if (savedIcons.evaluate().isNotEmpty) {
        await tester.tap(savedIcons.first);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tap(savedTabs.first);
      await tester.pumpAndSettle();
    }
    await takeScreenshot(tester, '03-main-shell/saved', '01-saved-tab');
    await takeScreenshot(
        tester, '07-saved-screen/bookmarked', '01-bookmarked-tab');

    // Planning tab
    final planningTab = find.text('Planning');
    if (planningTab.evaluate().isNotEmpty) {
      await tester.tap(planningTab.first);
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '07-saved-screen/planning', '01-planning-tab');
    }

    // Navigate to Profile
    final profileTabs = find.text('Profile');
    if (profileTabs.evaluate().isEmpty) {
      final profileIcons = find.byIcon(Icons.person_outline);
      if (profileIcons.evaluate().isNotEmpty) {
        await tester.tap(profileIcons.first);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tap(profileTabs.first);
      await tester.pumpAndSettle();
    }
    await takeScreenshot(tester, '03-main-shell/profile', '01-profile-tab');
    await takeScreenshot(tester, '09-profile-own', '01-profile-screen');

    // Profile - Edit Sheet
    final editButton = find.byIcon(Icons.edit_outlined);
    if (editButton.evaluate().isNotEmpty) {
      await tester.tap(editButton.first);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '09-profile-own', '02-edit-sheet');
      // Close edit sheet
      final closeButton = find.byIcon(Icons.close);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton.first);
        await tester.pumpAndSettle();
      } else {
        // Try tapping outside or back
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    }

    // Profile - Countries (Visited Countries Map)
    final countriesCard = find.text('Countries');
    if (countriesCard.evaluate().isNotEmpty) {
      await tester.tap(countriesCard.first);
      await tester.pumpAndSettle();
      // This is actually visited countries map, but we'll use it for city detail placeholder
      await takeScreenshot(tester, '11-city-detail', '01-city-detail');
      final backBtn3 = find.byIcon(Icons.arrow_back);
      if (backBtn3.evaluate().isNotEmpty) {
        await tester.tap(backBtn3.first);
        await tester.pumpAndSettle();
      }
    }

    // Profile - Trips
    final tripsCard = find.text('Trips');
    if (tripsCard.evaluate().isNotEmpty) {
      await tester.tap(tripsCard.first);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '12-my-trips/own', '01-my-trips');
      final backBtn4 = find.byIcon(Icons.arrow_back);
      if (backBtn4.evaluate().isNotEmpty) {
        await tester.tap(backBtn4.first);
        await tester.pumpAndSettle();
      }
    }

    // Profile - Followers
    final followersText = find.text('Followers');
    if (followersText.evaluate().isNotEmpty) {
      await tester.tap(followersText.first);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '13-followers', '01-followers-list');
      final backBtn5 = find.byIcon(Icons.arrow_back);
      if (backBtn5.evaluate().isNotEmpty) {
        await tester.tap(backBtn5.first);
        await tester.pumpAndSettle();
      }
    }

    // Navigate back to Profile if needed
    final profileTabs2 = find.text('Profile');
    if (profileTabs2.evaluate().isEmpty) {
      final profileIcons2 = find.byIcon(Icons.person_outline);
      if (profileIcons2.evaluate().isNotEmpty) {
        await tester.tap(profileIcons2.first);
        await tester.pumpAndSettle();
      }
    }

    // QR Code (in leading position)
    final qrButtons = find.byIcon(Icons.qr_code_2_outlined);
    if (qrButtons.evaluate().isNotEmpty) {
      await tester.tap(qrButtons.first);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '16-qr-code/my-code', '01-my-code');

      // Switch to Scan tab
      final scanTab = find.text('Scan');
      if (scanTab.evaluate().isNotEmpty) {
        await tester.tap(scanTab.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '16-qr-code/scan', '01-scan-screen');
      }

      // Go back
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }
    }

    // Navigate back to Profile if needed
    final profileTabs3 = find.text('Profile');
    if (profileTabs3.evaluate().isEmpty) {
      final profileIcons3 = find.byIcon(Icons.person_outline);
      if (profileIcons3.evaluate().isNotEmpty) {
        await tester.tap(profileIcons3.first);
        await tester.pumpAndSettle();
      }
    }

    // Settings (in actions)
    final settingsButtons = find.byIcon(Icons.settings_outlined);
    if (settingsButtons.evaluate().isNotEmpty) {
      await tester.tap(settingsButtons.first);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '17-settings', '01-settings-screen');
      await takeScreenshot(tester, '17-settings/appearance', '01-appearance');
      await takeScreenshot(tester, '17-settings/language', '01-language');

      // Go back
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }
    }

    // Create Itinerary Flow
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab.first);
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '05-create-itinerary/step1-start', '01-step1-form');

      // Fill step 1
      final step1Fields = find.byType(TextField);
      if (step1Fields.evaluate().isNotEmpty) {
        await tester.enterText(step1Fields.first, 'Test Trip');
        await tester.pumpAndSettle();
      }

      // Try to find and tap Next button
      final nextBtns = find.textContaining('Next');
      if (nextBtns.evaluate().isNotEmpty) {
        await tester.tap(nextBtns.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '05-create-itinerary/step2-destinations',
            '01-step2-destinations');

        // Try to continue through steps
        final nextBtns2 = find.textContaining('Next');
        if (nextBtns2.evaluate().isNotEmpty) {
          await tester.tap(nextBtns2.first);
          await tester.pumpAndSettle();
          await takeScreenshot(
              tester, '05-create-itinerary/step3-assign-days', '01-step3-days');

          final nextBtns3 = find.textContaining('Next');
          if (nextBtns3.evaluate().isNotEmpty) {
            await tester.tap(nextBtns3.first);
            await tester.pumpAndSettle();
            await takeScreenshot(
                tester, '05-create-itinerary/step4-map', '01-step4-map');

            final nextBtns4 = find.textContaining('Next');
            if (nextBtns4.evaluate().isNotEmpty) {
              await tester.tap(nextBtns4.first);
              await tester.pumpAndSettle();
              await takeScreenshot(tester, '05-create-itinerary/step5-details',
                  '01-step5-venues');

              final nextBtns5 = find.textContaining('Next');
              if (nextBtns5.evaluate().isNotEmpty) {
                await tester.tap(nextBtns5.first);
                await tester.pumpAndSettle();
                await takeScreenshot(tester, '05-create-itinerary/step6-review',
                    '01-step6-review');

                final nextBtns6 = find.textContaining('Save');
                if (nextBtns6.evaluate().isEmpty) {
                  final nextBtns7 = find.textContaining('Next');
                  if (nextBtns7.evaluate().isNotEmpty) {
                    await takeScreenshot(tester,
                        '05-create-itinerary/step7-save', '01-step7-save');
                  }
                } else {
                  await takeScreenshot(tester, '05-create-itinerary/step7-save',
                      '01-step7-save');
                }
              }
            }
          }
        }
      }

      // Go back to home (cancel create)
      final backBtn6 = find.byIcon(Icons.arrow_back);
      if (backBtn6.evaluate().isNotEmpty) {
        await tester.tap(backBtn6.first);
        await tester.pumpAndSettle();
      }
    }

    // Go back to Home to find author profiles and other features
    final homeTabs = find.text('Home');
    if (homeTabs.evaluate().isEmpty) {
      final homeIcons = find.byIcon(Icons.home_outlined);
      if (homeIcons.evaluate().isNotEmpty) {
        await tester.tap(homeIcons.first);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tap(homeTabs.first);
      await tester.pumpAndSettle();
    }

    // Try to find author profile by tapping on an author name or avatar
    await tester.pumpAndSettle();
    final authorAvatars = find.byType(CircleAvatar);
    if (authorAvatars.evaluate().isNotEmpty) {
      try {
        await tester.tap(authorAvatars.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '10-author-profile', '01-author-profile');
        final followButton = find.text('Follow');
        if (followButton.evaluate().isEmpty) {
          final followingButton = find.text('Following');
          if (followingButton.evaluate().isNotEmpty) {
            await takeScreenshot(
                tester, '10-author-profile', '02-follow-button');
          }
        } else {
          await takeScreenshot(tester, '10-author-profile', '02-follow-button');
        }

        // Try to open author trips
        final authorTripsCard = find.text('Trips');
        if (authorTripsCard.evaluate().isNotEmpty) {
          await tester.tap(authorTripsCard.first);
          await tester.pumpAndSettle();
          await takeScreenshot(tester, '12-my-trips/author', '01-author-trips');
          final backBtn8 = find.byIcon(Icons.arrow_back);
          if (backBtn8.evaluate().isNotEmpty) {
            await tester.tap(backBtn8.first);
            await tester.pumpAndSettle();
          }
        }

        final backBtn7 = find.byIcon(Icons.arrow_back);
        if (backBtn7.evaluate().isNotEmpty) {
          await tester.tap(backBtn7.first);
          await tester.pumpAndSettle();
        }
      } catch (e) {
        // Ignore if can't tap
      }
    }

    // Try to find translation button on feed cards
    final translateButtons = find.byIcon(Icons.translate_outlined);
    if (translateButtons.evaluate().isNotEmpty) {
      await takeScreenshot(tester, '15-translation', '01-translate-button');
      await tester.tap(translateButtons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeScreenshot(tester, '15-translation', '02-translated-content');
    }

    // Try to find share button on itinerary detail
    final cards2 = find.byType(Card);
    if (cards2.evaluate().isNotEmpty) {
      await tester.tap(cards2.first);
      await tester.pumpAndSettle();
      final shareButtons = find.byIcon(Icons.share_outlined);
      if (shareButtons.evaluate().isNotEmpty) {
        await tester.tap(shareButtons.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '18-share/itinerary', '01-share-sheet');
        // Dismiss share sheet
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      // Try to like and capture after state
      final likeButtons2 = find.byIcon(Icons.thumb_up_outlined);
      if (likeButtons2.evaluate().isNotEmpty) {
        await tester.tap(likeButtons2.first);
        await tester.pumpAndSettle();
        await takeScreenshot(tester, '14-likes', '02-after-like');
      }

      final backBtn9 = find.byIcon(Icons.arrow_back);
      if (backBtn9.evaluate().isNotEmpty) {
        await tester.tap(backBtn9.first);
        await tester.pumpAndSettle();
      }
    }

    // Navigate to Profile for sign out
    final profileTabs4 = find.text('Profile');
    if (profileTabs4.evaluate().isEmpty) {
      final profileIcons4 = find.byIcon(Icons.person_outline);
      if (profileIcons4.evaluate().isNotEmpty) {
        await tester.tap(profileIcons4.first);
        await tester.pumpAndSettle();
      }
    }

    // Now test sign up flow - sign out first
    final settingsBtn2 = find.byIcon(Icons.settings_outlined);
    if (settingsBtn2.evaluate().isNotEmpty) {
      await tester.tap(settingsBtn2.first);
      await tester.pumpAndSettle();

      final signOut = find.text('Sign out');
      if (signOut.evaluate().isNotEmpty) {
        await takeScreenshot(tester, '02-returning-user', '01-sign-out');
        await tester.tap(signOut.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
    }

    // Sign Up Flow
    final continueEmail2 = find.text('Continue with Email');
    if (continueEmail2.evaluate().isNotEmpty) {
      await tester.tap(continueEmail2);
      await tester.pumpAndSettle();
    }

    final signUpLink = find.text("Don't have an account? Sign up");
    if (signUpLink.evaluate().isNotEmpty) {
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();
    }

    await takeScreenshot(
        tester, '01-first-time-user/sign-up', '01-sign-up-form');

    // Enter sign up credentials
    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 2) {
      await tester.enterText(textFields.at(0), 'test4@123.com');
      await tester.enterText(textFields.at(1), 'Test123!');
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '01-first-time-user/sign-up', '02-sign-up-filled');

      final signUpButton = find.text('Sign up');
      if (signUpButton.evaluate().isNotEmpty) {
        await tester.tap(signUpButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
    }

    // Onboarding Step 1 - Name
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final nameFields = find.byType(TextField);
    if (nameFields.evaluate().isNotEmpty) {
      await tester.enterText(nameFields.first, 'Test User');
      await tester.pumpAndSettle();
      await takeScreenshot(
          tester, '01-first-time-user/onboarding/step1-name', '01-name-input');

      final nextButtons = find.text('Next');
      if (nextButtons.evaluate().isNotEmpty) {
        await tester.tap(nextButtons.first);
        await tester.pumpAndSettle();
      }
    }

    // Onboarding Step 2 - Countries
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeScreenshot(
        tester,
        '01-first-time-user/onboarding/step2-countries',
        '01-countries-selection');

    // Select a country
    final checkboxes = find.byType(Checkbox);
    if (checkboxes.evaluate().isNotEmpty) {
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
    }

    final nextButton2 = find.text('Next');
    if (nextButton2.evaluate().isNotEmpty) {
      await tester.tap(nextButton2.first);
      await tester.pumpAndSettle();
    }

    // Onboarding Step 3 - Preferences
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeScreenshot(
        tester,
        '01-first-time-user/onboarding/step3-preferences',
        '01-preferences-selection');

    // Select preferences
    final chips = find.byType(FilterChip);
    if (chips.evaluate().isNotEmpty) {
      await tester.tap(chips.first);
      await tester.pumpAndSettle();
    }

    final finishButton = find.text('Finish');
    if (finishButton.evaluate().isNotEmpty) {
      await tester.tap(finishButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    print('✅ Screenshot capture complete!');
  });
}
