#!/bin/bash

# Screenshot capture script for Travel App
# This script launches the app and provides instructions for manual navigation
# Screenshots are captured using xcrun simctl

SIMULATOR_ID="9193318A-EA83-4F8B-9888-BA0F9FBA1179"
SCREENSHOT_DIR="/Users/kiankamshad/Travel App/screenshots"

# Function to take screenshot
take_screenshot() {
    local path=$1
    local filename=$2
    xcrun simctl io booted screenshot "$SCREENSHOT_DIR/$path/$filename.png"
    echo "Screenshot saved: $path/$filename.png"
    sleep 2
}

echo "Starting screenshot capture process..."
echo "Make sure the simulator is running and the app is launched"
echo "Press Enter after each navigation step to capture screenshot"
read -p "Press Enter when ready to start..."

# Launch app
echo "Launching app..."
flutter run -d $SIMULATOR_ID &
APP_PID=$!
sleep 15

echo ""
echo "=== 01. FIRST-TIME USER FLOW ==="
echo "1. Welcome Screen"
read -p "Navigate to Welcome screen, then press Enter..."
take_screenshot "01-first-time-user" "01-welcome-screen"

echo "2. Sign Up Screen"
read -p "Tap 'Sign up', then press Enter..."
take_screenshot "01-first-time-user/sign-up" "01-sign-up-form"

echo "3. Sign Up - Enter credentials"
read -p "Enter email: test4@123.com, password: Test123!, then press Enter..."
take_screenshot "01-first-time-user/sign-up" "02-sign-up-filled"

echo "4. Onboarding Step 1 - Name"
read -p "After sign up, enter name in onboarding, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step1-name" "01-name-input"

echo "5. Onboarding Step 2 - Countries"
read -p "Select countries, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step2-countries" "01-countries-selection"

echo "6. Onboarding Step 3 - Preferences"
read -p "Select travel styles and mode, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step3-preferences" "01-preferences-selection"

echo ""
echo "=== 02. RETURNING USER FLOW ==="
echo "7. Sign Out"
read -p "Sign out from profile, then press Enter..."
take_screenshot "02-returning-user" "01-sign-out"

echo "8. Sign In Screen"
read -p "Tap 'Sign in', then press Enter..."
take_screenshot "02-returning-user/sign-in" "01-sign-in-form"

echo "9. Sign In - Enter credentials"
read -p "Enter email: marble717@gmail.com, password: Marble17!, then press Enter..."
take_screenshot "02-returning-user/sign-in" "02-sign-in-filled"

echo ""
echo "=== 03. MAIN SHELL NAVIGATION ==="
echo "10. Home Tab"
read -p "After sign in, navigate to Home tab, then press Enter..."
take_screenshot "03-main-shell/home" "01-home-tab"

echo "11. Search Tab"
read -p "Navigate to Search tab, then press Enter..."
take_screenshot "03-main-shell/search" "01-search-tab"

echo "12. Saved Tab"
read -p "Navigate to Saved tab, then press Enter..."
take_screenshot "03-main-shell/saved" "01-saved-tab"

echo "13. Profile Tab"
read -p "Navigate to Profile tab, then press Enter..."
take_screenshot "03-main-shell/profile" "01-profile-tab"

echo ""
echo "=== 04. HOME FEED FLOW ==="
echo "14. For You Tab"
read -p "Navigate to Home > For You tab, then press Enter..."
take_screenshot "04-home-feed/for-you" "01-for-you-feed"

echo "15. Following Tab"
read -p "Navigate to Home > Following tab, then press Enter..."
take_screenshot "04-home-feed/following" "01-following-feed"

echo "16. Feed Card - Like Button"
read -p "Show a feed card with like button visible, then press Enter..."
take_screenshot "04-home-feed" "01-feed-card-with-likes"

echo "17. Feed Card - Translate Button"
read -p "Show a feed card with translate button (if available), then press Enter..."
take_screenshot "04-home-feed" "02-feed-card-translate"

echo ""
echo "=== 05. CREATE ITINERARY FLOW ==="
echo "18. Step 1 - Start New Trip"
read -p "Tap FAB, then fill Step 1 (title, destination, mode, visibility), then press Enter..."
take_screenshot "05-create-itinerary/step1-start" "01-step1-form"

echo "19. Step 2 - Add Destinations"
read -p "Add destinations, then press Enter..."
take_screenshot "05-create-itinerary/step2-destinations" "01-step2-destinations"

echo "20. Step 3 - Assign Days"
read -p "Assign days to destinations, then press Enter..."
take_screenshot "05-create-itinerary/step3-assign-days" "01-step3-days"

echo "21. Step 4 - Trip Map"
read -p "View trip map preview, then press Enter..."
take_screenshot "05-create-itinerary/step4-map" "01-step4-map"

echo "22. Step 5 - Add Details"
read -p "Add venues to destinations, then press Enter..."
take_screenshot "05-create-itinerary/step5-details" "01-step5-venues"

echo "23. Step 6 - Review Trip"
read -p "Review trip summary, then press Enter..."
take_screenshot "05-create-itinerary/step6-review" "01-step6-review"

echo "24. Step 7 - Save Trip"
read -p "Save trip (or show save button), then press Enter..."
take_screenshot "05-create-itinerary/step7-save" "01-step7-save"

echo ""
echo "=== 06. ITINERARY DETAIL ==="
echo "25. Itinerary Detail Screen"
read -p "Open an itinerary detail screen, then press Enter..."
take_screenshot "06-itinerary-detail" "01-itinerary-detail"

echo "26. Itinerary Detail - Like Button"
read -p "Show like button on itinerary detail (others' post), then press Enter..."
take_screenshot "06-itinerary-detail" "02-like-button"

echo "27. Itinerary Detail - Map"
read -p "Show map section, then press Enter..."
take_screenshot "06-itinerary-detail" "03-map-section"

echo "28. Itinerary Detail - Timeline"
read -p "Show stops timeline, then press Enter..."
take_screenshot "06-itinerary-detail" "04-timeline"

echo ""
echo "=== 07. SAVED SCREEN ==="
echo "29. Bookmarked Tab"
read -p "Navigate to Saved > Bookmarked tab, then press Enter..."
take_screenshot "07-saved-screen/bookmarked" "01-bookmarked-tab"

echo "30. Planning Tab"
read -p "Navigate to Saved > Planning tab, then press Enter..."
take_screenshot "07-saved-screen/planning" "01-planning-tab"

echo ""
echo "=== 08. SEARCH ==="
echo "31. Profiles Tab"
read -p "Navigate to Search > Profiles tab, enter query, then press Enter..."
take_screenshot "08-search/profiles" "01-profiles-results"

echo "32. Itineraries Tab"
read -p "Navigate to Search > Itineraries tab, enter query, then press Enter..."
take_screenshot "08-search/itineraries" "01-itineraries-results"

echo "33. Search Filters"
read -p "Open filters (days, styles, mode), then press Enter..."
take_screenshot "08-search/itineraries" "02-filters"

echo ""
echo "=== 09. PROFILE (OWN) ==="
echo "34. Profile Screen"
read -p "Navigate to own Profile screen, then press Enter..."
take_screenshot "09-profile-own" "01-profile-screen"

echo "35. Profile - Edit Sheet"
read -p "Open edit sheet (name, city, etc.), then press Enter..."
take_screenshot "09-profile-own" "02-edit-sheet"

echo ""
echo "=== 10. AUTHOR PROFILE ==="
echo "36. Author Profile Screen"
read -p "Open another user's profile, then press Enter..."
take_screenshot "10-author-profile" "01-author-profile"

echo "37. Author Profile - Follow Button"
read -p "Show follow/unfollow button, then press Enter..."
take_screenshot "10-author-profile" "02-follow-button"

echo ""
echo "=== 11. CITY DETAIL ==="
echo "38. City Detail Screen"
read -p "Open a city detail screen, then press Enter..."
take_screenshot "11-city-detail" "01-city-detail"

echo ""
echo "=== 12. MY TRIPS ==="
echo "39. My Trips (Own)"
read -p "Navigate to Profile > Trips, then press Enter..."
take_screenshot "12-my-trips/own" "01-my-trips"

echo "40. Author Trips"
read -p "Open author profile > Trips, then press Enter..."
take_screenshot "12-my-trips/author" "01-author-trips"

echo ""
echo "=== 13. FOLLOWERS ==="
echo "41. Followers Screen"
read -p "Navigate to Profile > Followers, then press Enter..."
take_screenshot "13-followers" "01-followers-list"

echo ""
echo "=== 14. LIKES ==="
echo "42. Like Action - Before"
read -p "Show an itinerary card before liking, then press Enter..."
take_screenshot "14-likes" "01-before-like"

echo "43. Like Action - After"
read -p "Tap like button, show after state, then press Enter..."
take_screenshot "14-likes" "02-after-like"

echo ""
echo "=== 15. TRANSLATION ==="
echo "44. Translation Button"
read -p "Show translate button on content in different language, then press Enter..."
take_screenshot "15-translation" "01-translate-button"

echo "45. Translated Content"
read -p "Tap translate, show translated content, then press Enter..."
take_screenshot "15-translation" "02-translated-content"

echo ""
echo "=== 16. QR CODE ==="
echo "46. My Code Tab"
read -p "Navigate to Profile > QR Code > My Code tab, then press Enter..."
take_screenshot "16-qr-code/my-code" "01-my-code"

echo "47. Scan Tab"
read -p "Navigate to QR Code > Scan tab, then press Enter..."
take_screenshot "16-qr-code/scan" "01-scan-screen"

echo ""
echo "=== 17. SETTINGS ==="
echo "48. Settings Screen"
read -p "Navigate to Profile > Settings, then press Enter..."
take_screenshot "17-settings" "01-settings-screen"

echo "49. Appearance Options"
read -p "Show appearance section (light/dark/system), then press Enter..."
take_screenshot "17-settings/appearance" "01-appearance"

echo "50. Language Options"
read -p "Show language section, then press Enter..."
take_screenshot "17-settings/language" "01-language"

echo ""
echo "=== 18. SHARE ==="
echo "51. Share Itinerary"
read -p "Tap share on itinerary detail, show share sheet, then press Enter..."
take_screenshot "18-share/itinerary" "01-share-sheet"

echo "52. Share Profile"
read -p "Tap share on profile QR, show share sheet, then press Enter..."
take_screenshot "18-share/profile" "01-share-sheet"

echo ""
echo "=== 19. STATE SYNC ==="
echo "53. State Sync - Before Navigation"
read -p "Show home feed before navigating to detail, then press Enter..."
take_screenshot "19-state-sync" "01-before-navigation"

echo "54. State Sync - After Return"
read -p "Like/bookmark on detail, navigate back, show synced state, then press Enter..."
take_screenshot "19-state-sync" "02-after-return"

echo ""
echo "Screenshot capture complete!"
echo "All screenshots saved to: $SCREENSHOT_DIR"
