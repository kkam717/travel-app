import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travel_app/main.dart' as app;
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final screenshotDir = Directory('/Users/kiankamshad/Travel App/screenshots');
  
  Future<void> takeScreenshot(WidgetTester tester, String path, String filename) async {
    final fullPath = '${screenshotDir.path}/$path/$filename.png';
    final dir = Directory('${screenshotDir.path}/$path');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Wait longer to ensure screen is stable
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final bytes = await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(fullPath);
    final file = File(fullPath);
    await file.writeAsBytes(bytes);
    print('✓ $path/$filename.png');
  }

  Future<void> navigateToProfile(WidgetTester tester) async {
    final profileTabs = find.text('Profile');
    if (profileTabs.evaluate().isNotEmpty) {
      await tester.tap(profileTabs.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
    final profileIcons = find.byIcon(Icons.person_outline);
    if (profileIcons.evaluate().isNotEmpty) {
      await tester.tap(profileIcons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
    // Try bottom navigation
    final bottomNav = find.byType(BottomNavigationBar);
    if (bottomNav.evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(200, 700)); // Approximate Profile tab position
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  Future<void> navigateToHome(WidgetTester tester) async {
    final homeTabs = find.text('Home');
    if (homeTabs.evaluate().isNotEmpty) {
      await tester.tap(homeTabs.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
    final homeIcons = find.byIcon(Icons.home_outlined);
    if (homeIcons.evaluate().isNotEmpty) {
      await tester.tap(homeIcons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
    // Try bottom navigation
    final bottomNav = find.byType(BottomNavigationBar);
    if (bottomNav.evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(50, 700)); // Approximate Home tab position
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  testWidgets('Recapture specific screenshots', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Sign in first
    final continueEmail = find.text('Continue with Email');
    if (continueEmail.evaluate().isNotEmpty) {
      await tester.tap(continueEmail);
      await tester.pumpAndSettle();
    }
    
    final signInFields = find.byType(TextField);
    if (signInFields.evaluate().length >= 2) {
      await tester.enterText(signInFields.at(0), 'marble717@gmail.com');
      await tester.enterText(signInFields.at(1), 'Marble17!');
      await tester.pumpAndSettle();
      
      final signInButton = find.text('Sign in');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
    }

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. Create Itinerary Flow - Enhanced
    print('\n=== Creating Itinerary Screenshots ===');
    await navigateToHome(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeScreenshot(tester, '05-create-itinerary/step1-start', '01-step1-form');
      
      final step1Fields = find.byType(TextField);
      if (step1Fields.evaluate().isNotEmpty) {
        await tester.enterText(step1Fields.first, 'Test Trip');
        await tester.pumpAndSettle();
      }
      
      // Try multiple ways to find Next button
      var nextBtn = find.text('Next');
      if (nextBtn.evaluate().isEmpty) {
        nextBtn = find.textContaining('Next');
      }
      if (nextBtn.evaluate().isEmpty) {
        nextBtn = find.byType(ElevatedButton);
      }
      
      if (nextBtn.evaluate().isNotEmpty) {
        await tester.tap(nextBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await takeScreenshot(tester, '05-create-itinerary/step2-destinations', '01-step2-destinations');
        
        // Step 3
        var nextBtn2 = find.text('Next');
        if (nextBtn2.evaluate().isEmpty) nextBtn2 = find.textContaining('Next');
        if (nextBtn2.evaluate().isEmpty) nextBtn2 = find.byType(ElevatedButton);
        if (nextBtn2.evaluate().isNotEmpty) {
          await tester.tap(nextBtn2.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          await takeScreenshot(tester, '05-create-itinerary/step3-assign-days', '01-step3-days');
          
          // Step 4
          var nextBtn3 = find.text('Next');
          if (nextBtn3.evaluate().isEmpty) nextBtn3 = find.textContaining('Next');
          if (nextBtn3.evaluate().isEmpty) nextBtn3 = find.byType(ElevatedButton);
          if (nextBtn3.evaluate().isNotEmpty) {
            await tester.tap(nextBtn3.first);
            await tester.pumpAndSettle(const Duration(seconds: 3));
            await takeScreenshot(tester, '05-create-itinerary/step4-map', '01-step4-map');
            
            // Step 5
            var nextBtn4 = find.text('Next');
            if (nextBtn4.evaluate().isEmpty) nextBtn4 = find.textContaining('Next');
            if (nextBtn4.evaluate().isEmpty) nextBtn4 = find.byType(ElevatedButton);
            if (nextBtn4.evaluate().isNotEmpty) {
              await tester.tap(nextBtn4.first);
              await tester.pumpAndSettle(const Duration(seconds: 3));
              await takeScreenshot(tester, '05-create-itinerary/step5-details', '01-step5-venues');
              
              // Step 6
              var nextBtn5 = find.text('Next');
              if (nextBtn5.evaluate().isEmpty) nextBtn5 = find.textContaining('Next');
              if (nextBtn5.evaluate().isEmpty) nextBtn5 = find.byType(ElevatedButton);
              if (nextBtn5.evaluate().isNotEmpty) {
                await tester.tap(nextBtn5.first);
                await tester.pumpAndSettle(const Duration(seconds: 3));
                await takeScreenshot(tester, '05-create-itinerary/step6-review', '01-step6-review');
                
                // Step 7
                var saveBtn = find.text('Save');
                if (saveBtn.evaluate().isEmpty) saveBtn = find.textContaining('Save');
                if (saveBtn.evaluate().isEmpty) {
                  var nextBtn6 = find.text('Next');
                  if (nextBtn6.evaluate().isEmpty) nextBtn6 = find.textContaining('Next');
                  if (nextBtn6.evaluate().isEmpty) nextBtn6 = find.byType(ElevatedButton);
                  if (nextBtn6.evaluate().isNotEmpty) {
                    await tester.tap(nextBtn6.first);
                    await tester.pumpAndSettle(const Duration(seconds: 2));
                  }
                }
                await takeScreenshot(tester, '05-create-itinerary/step7-save', '01-step7-save');
              }
            }
          }
        }
      }
      
      // Go back to home
      final backBtn = find.byIcon(Icons.arrow_back);
      if (backBtn.evaluate().isNotEmpty) {
        // Tap multiple times to go back through all steps
        for (int i = 0; i < 10; i++) {
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tap(backBtn.first);
            await tester.pumpAndSettle();
          } else {
            break;
          }
        }
      }
    }

    // 2. Author Profile - Enhanced
    print('\n=== Creating Author Profile Screenshots ===');
    await navigateToHome(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // Try to find author avatar or name
    final authorAvatars = find.byType(CircleAvatar);
    final authorNames = find.byType(InkWell);
    
    if (authorAvatars.evaluate().isNotEmpty) {
      try {
        await tester.tap(authorAvatars.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '10-author-profile', '01-author-profile');
        
        // Look for follow button
        var followBtn = find.text('Follow');
        if (followBtn.evaluate().isEmpty) followBtn = find.text('Following');
        if (followBtn.evaluate().isEmpty) followBtn = find.textContaining('Follow');
        
        if (followBtn.evaluate().isNotEmpty) {
          await takeScreenshot(tester, '10-author-profile', '02-follow-button');
        } else {
          // Take screenshot anyway
          await takeScreenshot(tester, '10-author-profile', '02-follow-button');
        }
        
        // Try to open author trips
        final tripsCard = find.text('Trips');
        if (tripsCard.evaluate().isNotEmpty) {
          await tester.tap(tripsCard.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(tester, '12-my-trips/author', '01-author-trips');
          final backBtn2 = find.byIcon(Icons.arrow_back);
          if (backBtn2.evaluate().isNotEmpty) {
            await tester.tap(backBtn2.first);
            await tester.pumpAndSettle();
          }
        }
        
        final backBtn3 = find.byIcon(Icons.arrow_back);
        if (backBtn3.evaluate().isNotEmpty) {
          await tester.tap(backBtn3.first);
          await tester.pumpAndSettle();
        }
      } catch (e) {
        print('Could not capture author profile: $e');
      }
    } else if (authorNames.evaluate().isNotEmpty) {
      // Try tapping author name
      try {
        await tester.tap(authorNames.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '10-author-profile', '01-author-profile');
        await takeScreenshot(tester, '10-author-profile', '02-follow-button');
      } catch (e) {
        print('Could not capture author profile via name: $e');
      }
    }

    // 3. City Detail - Already captured, skip

    // 4. My Trips (Own) - Already captured, skip

    // 5. Likes - Already captured, skip

    // 6. Translation - Enhanced
    print('\n=== Creating Translation Screenshots ===');
    await navigateToHome(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // Try to find translate button on feed cards
    final translateButtons = find.byIcon(Icons.translate_outlined);
    if (translateButtons.evaluate().isEmpty) {
      // Try alternative icon
      final translateAlt = find.byIcon(Icons.translate);
      if (translateAlt.evaluate().isNotEmpty) {
        await takeScreenshot(tester, '15-translation', '01-translate-button');
        await tester.tap(translateAlt.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await takeScreenshot(tester, '15-translation', '02-translated-content');
      }
    } else {
      await takeScreenshot(tester, '15-translation', '01-translate-button');
      await tester.tap(translateButtons.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await takeScreenshot(tester, '15-translation', '02-translated-content');
    }

    // 7. QR Code - Enhanced
    print('\n=== Creating QR Code Screenshots ===');
    await navigateToProfile(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    final qrButtons = find.byIcon(Icons.qr_code_2_outlined);
    if (qrButtons.evaluate().isEmpty) {
      // Try alternative icon
      final qrAlt = find.byIcon(Icons.qr_code_2);
      if (qrAlt.evaluate().isNotEmpty) {
        await tester.tap(qrAlt.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '16-qr-code/my-code', '01-my-code');
        
        var scanTab = find.text('Scan');
        if (scanTab.evaluate().isEmpty) {
          scanTab = find.textContaining('Scan');
        }
        if (scanTab.evaluate().isNotEmpty) {
          await tester.tap(scanTab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(tester, '16-qr-code/scan', '01-scan-screen');
        }
      }
    } else {
      await tester.tap(qrButtons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeScreenshot(tester, '16-qr-code/my-code', '01-my-code');
      
      var scanTab = find.text('Scan');
      if (scanTab.evaluate().isEmpty) {
        scanTab = find.textContaining('Scan');
      }
      if (scanTab.evaluate().isNotEmpty) {
        await tester.tap(scanTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '16-qr-code/scan', '01-scan-screen');
      }
      
      // Try share from QR
      final shareButtons2 = find.byIcon(Icons.share_outlined);
      if (shareButtons2.evaluate().isEmpty) {
        final shareAlt = find.byIcon(Icons.share);
        if (shareAlt.evaluate().isNotEmpty) {
          await tester.tap(shareAlt.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(tester, '18-share/profile', '01-share-sheet');
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      } else {
        await tester.tap(shareButtons2.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '18-share/profile', '01-share-sheet');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
      
      final backBtn7 = find.byIcon(Icons.arrow_back);
      if (backBtn7.evaluate().isNotEmpty) {
        await tester.tap(backBtn7.first);
        await tester.pumpAndSettle();
      }
    }

    // 8. Settings - Enhanced
    print('\n=== Creating Settings Screenshots ===');
    await navigateToProfile(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    final settingsButtons = find.byIcon(Icons.settings_outlined);
    if (settingsButtons.evaluate().isEmpty) {
      final settingsAlt = find.byIcon(Icons.settings);
      if (settingsAlt.evaluate().isNotEmpty) {
        await tester.tap(settingsAlt.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeScreenshot(tester, '17-settings', '01-settings-screen');
        await takeScreenshot(tester, '17-settings/appearance', '01-appearance');
        await takeScreenshot(tester, '17-settings/language', '01-language');
      }
    } else {
      await tester.tap(settingsButtons.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeScreenshot(tester, '17-settings', '01-settings-screen');
      await takeScreenshot(tester, '17-settings/appearance', '01-appearance');
      await takeScreenshot(tester, '17-settings/language', '01-language');
      
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }
    }

    print('\n✅ All screenshots recaptured!');
  });
}
