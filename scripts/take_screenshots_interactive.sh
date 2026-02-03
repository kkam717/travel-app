#!/bin/bash

# Interactive screenshot capture script
# This script takes screenshots as you navigate through the app

SCREENSHOT_DIR="/Users/kiankamshad/Travel App/screenshots"
SIMULATOR_ID="9193318A-EA83-4F8B-9888-BA0F9FBA1179"

take_screenshot() {
    local path=$1
    local filename=$2
    local full_path="$SCREENSHOT_DIR/$path"
    mkdir -p "$full_path"
    xcrun simctl io booted screenshot "$full_path/$filename.png"
    echo "✓ Screenshot saved: $path/$filename.png"
}

echo "=========================================="
echo "Travel App Screenshot Capture"
echo "=========================================="
echo ""
echo "Instructions:"
echo "1. Navigate to the screen described"
echo "2. Press Enter to capture screenshot"
echo "3. Continue to next step"
echo ""
read -p "Press Enter when ready to start..."

# 01. Welcome Screen
echo ""
echo "=== 01. FIRST-TIME USER FLOW ==="
echo "📸 Step 1/54: Welcome Screen"
read -p "Navigate to Welcome screen, then press Enter..."
take_screenshot "01-first-time-user" "01-welcome-screen"

# Sign Up
echo "📸 Step 2/54: Sign Up Form"
read -p "Tap 'Sign up' button, then press Enter..."
take_screenshot "01-first-time-user/sign-up" "01-sign-up-form"

echo "📸 Step 3/54: Sign Up - Filled"
read -p "Enter email: test4@123.com, password: Test123!, then press Enter..."
take_screenshot "01-first-time-user/sign-up" "02-sign-up-filled"

echo "📸 Step 4/54: Onboarding Step 1 - Name"
read -p "After sign up, enter name in onboarding, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step1-name" "01-name-input"

echo "📸 Step 5/54: Onboarding Step 2 - Countries"
read -p "Select countries, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step2-countries" "01-countries-selection"

echo "📸 Step 6/54: Onboarding Step 3 - Preferences"
read -p "Select travel styles and mode, then press Enter..."
take_screenshot "01-first-time-user/onboarding/step3-preferences" "01-preferences-selection"

# Sign Out and Sign In
echo ""
echo "=== 02. RETURNING USER FLOW ==="
echo "📸 Step 7/54: Sign Out"
read -p "Sign out from profile (Settings > Sign out), then press Enter..."
take_screenshot "02-returning-user" "01-sign-out"

echo "📸 Step 8/54: Sign In Form"
read -p "Tap 'Sign in' button, then press Enter..."
take_screenshot "02-returning-user/sign-in" "01-sign-in-form"

echo "📸 Step 9/54: Sign In - Filled"
read -p "Enter email: marble717@gmail.com, password: Marble17!, then press Enter..."
take_screenshot "02-returning-user/sign-in" "02-sign-in-filled"

# Main Shell
echo ""
echo "=== 03. MAIN SHELL NAVIGATION ==="
echo "📸 Step 10/54: Home Tab"
read -p "After sign in, navigate to Home tab, then press Enter..."
take_screenshot "03-main-shell/home" "01-home-tab"

echo "📸 Step 11/54: Search Tab"
read -p "Navigate to Search tab, then press Enter..."
take_screenshot "03-main-shell/search" "01-search-tab"

echo "📸 Step 12/54: Saved Tab"
read -p "Navigate to Saved tab, then press Enter..."
take_screenshot "03-main-shell/saved" "01-saved-tab"

echo "📸 Step 13/54: Profile Tab"
read -p "Navigate to Profile tab, then press Enter..."
take_screenshot "03-main-shell/profile" "01-profile-tab"

# Home Feed
echo ""
echo "=== 04. HOME FEED FLOW ==="
echo "📸 Step 14/54: For You Tab"
read -p "Navigate to Home > For You tab, then press Enter..."
take_screenshot "04-home-feed/for-you" "01-for-you-feed"

echo "📸 Step 15/54: Following Tab"
read -p "Navigate to Home > Following tab, then press Enter..."
take_screenshot "04-home-feed/following" "01-following-feed"

echo "📸 Step 16/54: Feed Card with Likes"
read -p "Show a feed card with like button visible, then press Enter..."
take_screenshot "04-home-feed" "01-feed-card-with-likes"

# Create Itinerary
echo ""
echo "=== 05. CREATE ITINERARY FLOW ==="
echo "📸 Step 17/54: Step 1 - Start New Trip"
read -p "Tap FAB, fill Step 1 (title, destination, mode, visibility), then press Enter..."
take_screenshot "05-create-itinerary/step1-start" "01-step1-form"

echo "📸 Step 18/54: Step 2 - Add Destinations"
read -p "Add destinations, then press Enter..."
take_screenshot "05-create-itinerary/step2-destinations" "01-step2-destinations"

echo "📸 Step 19/54: Step 3 - Assign Days"
read -p "Assign days to destinations, then press Enter..."
take_screenshot "05-create-itinerary/step3-assign-days" "01-step3-days"

echo "📸 Step 20/54: Step 4 - Trip Map"
read -p "View trip map preview, then press Enter..."
take_screenshot "05-create-itinerary/step4-map" "01-step4-map"

echo "📸 Step 21/54: Step 5 - Add Details"
read -p "Add venues to destinations, then press Enter..."
take_screenshot "05-create-itinerary/step5-details" "01-step5-venues"

echo "📸 Step 22/54: Step 6 - Review Trip"
read -p "Review trip summary, then press Enter..."
take_screenshot "05-create-itinerary/step6-review" "01-step6-review"

echo "📸 Step 23/54: Step 7 - Save Trip"
read -p "Save trip (or show save button), then press Enter..."
take_screenshot "05-create-itinerary/step7-save" "01-step7-save"

# Itinerary Detail
echo ""
echo "=== 06. ITINERARY DETAIL ==="
echo "📸 Step 24/54: Itinerary Detail Screen"
read -p "Open an itinerary detail screen, then press Enter..."
take_screenshot "06-itinerary-detail" "01-itinerary-detail"

echo "📸 Step 25/54: Like Button on Detail"
read -p "Show like button on itinerary detail (others' post), then press Enter..."
take_screenshot "06-itinerary-detail" "02-like-button"

echo "📸 Step 26/54: Map Section"
read -p "Show map section, then press Enter..."
take_screenshot "06-itinerary-detail" "03-map-section"

echo "📸 Step 27/54: Timeline"
read -p "Show stops timeline, then press Enter..."
take_screenshot "06-itinerary-detail" "04-timeline"

# Saved Screen
echo ""
echo "=== 07. SAVED SCREEN ==="
echo "📸 Step 28/54: Bookmarked Tab"
read -p "Navigate to Saved > Bookmarked tab, then press Enter..."
take_screenshot "07-saved-screen/bookmarked" "01-bookmarked-tab"

echo "📸 Step 29/54: Planning Tab"
read -p "Navigate to Saved > Planning tab, then press Enter..."
take_screenshot "07-saved-screen/planning" "01-planning-tab"

# Search
echo ""
echo "=== 08. SEARCH ==="
echo "📸 Step 30/54: Profiles Tab"
read -p "Navigate to Search > Profiles tab, enter query, then press Enter..."
take_screenshot "08-search/profiles" "01-profiles-results"

echo "📸 Step 31/54: Itineraries Tab"
read -p "Navigate to Search > Itineraries tab, enter query, then press Enter..."
take_screenshot "08-search/itineraries" "01-itineraries-results"

echo "📸 Step 32/54: Search Filters"
read -p "Open filters (days, styles, mode), then press Enter..."
take_screenshot "08-search/itineraries" "02-filters"

# Profile
echo ""
echo "=== 09. PROFILE (OWN) ==="
echo "📸 Step 33/54: Profile Screen"
read -p "Navigate to own Profile screen, then press Enter..."
take_screenshot "09-profile-own" "01-profile-screen"

echo "📸 Step 34/54: Edit Sheet"
read -p "Open edit sheet (name, city, etc.), then press Enter..."
take_screenshot "09-profile-own" "02-edit-sheet"

# Author Profile
echo ""
echo "=== 10. AUTHOR PROFILE ==="
echo "📸 Step 35/54: Author Profile Screen"
read -p "Open another user's profile, then press Enter..."
take_screenshot "10-author-profile" "01-author-profile"

echo "📸 Step 36/54: Follow Button"
read -p "Show follow/unfollow button, then press Enter..."
take_screenshot "10-author-profile" "02-follow-button"

# City Detail
echo ""
echo "=== 11. CITY DETAIL ==="
echo "📸 Step 37/54: City Detail Screen"
read -p "Open a city detail screen, then press Enter..."
take_screenshot "11-city-detail" "01-city-detail"

# My Trips
echo ""
echo "=== 12. MY TRIPS ==="
echo "📸 Step 38/54: My Trips (Own)"
read -p "Navigate to Profile > Trips, then press Enter..."
take_screenshot "12-my-trips/own" "01-my-trips"

echo "📸 Step 39/54: Author Trips"
read -p "Open author profile > Trips, then press Enter..."
take_screenshot "12-my-trips/author" "01-author-trips"

# Followers
echo ""
echo "=== 13. FOLLOWERS ==="
echo "📸 Step 40/54: Followers Screen"
read -p "Navigate to Profile > Followers, then press Enter..."
take_screenshot "13-followers" "01-followers-list"

# Likes
echo ""
echo "=== 14. LIKES ==="
echo "📸 Step 41/54: Like Action - Before"
read -p "Show an itinerary card before liking, then press Enter..."
take_screenshot "14-likes" "01-before-like"

echo "📸 Step 42/54: Like Action - After"
read -p "Tap like button, show after state, then press Enter..."
take_screenshot "14-likes" "02-after-like"

# Translation
echo ""
echo "=== 15. TRANSLATION ==="
echo "📸 Step 43/54: Translate Button"
read -p "Show translate button on content in different language, then press Enter..."
take_screenshot "15-translation" "01-translate-button"

echo "📸 Step 44/54: Translated Content"
read -p "Tap translate, show translated content, then press Enter..."
take_screenshot "15-translation" "02-translated-content"

# QR Code
echo ""
echo "=== 16. QR CODE ==="
echo "📸 Step 45/54: My Code Tab"
read -p "Navigate to Profile > QR Code > My Code tab, then press Enter..."
take_screenshot "16-qr-code/my-code" "01-my-code"

echo "📸 Step 46/54: Scan Tab"
read -p "Navigate to QR Code > Scan tab, then press Enter..."
take_screenshot "16-qr-code/scan" "01-scan-screen"

# Settings
echo ""
echo "=== 17. SETTINGS ==="
echo "📸 Step 47/54: Settings Screen"
read -p "Navigate to Profile > Settings, then press Enter..."
take_screenshot "17-settings" "01-settings-screen"

echo "📸 Step 48/54: Appearance Options"
read -p "Show appearance section (light/dark/system), then press Enter..."
take_screenshot "17-settings/appearance" "01-appearance"

echo "📸 Step 49/54: Language Options"
read -p "Show language section, then press Enter..."
take_screenshot "17-settings/language" "01-language"

# Share
echo ""
echo "=== 18. SHARE ==="
echo "📸 Step 50/54: Share Itinerary"
read -p "Tap share on itinerary detail, show share sheet, then press Enter..."
take_screenshot "18-share/itinerary" "01-share-sheet"

echo "📸 Step 51/54: Share Profile"
read -p "Tap share on profile QR, show share sheet, then press Enter..."
take_screenshot "18-share/profile" "01-share-sheet"

# State Sync
echo ""
echo "=== 19. STATE SYNC ==="
echo "📸 Step 52/54: State Sync - Before Navigation"
read -p "Show home feed before navigating to detail, then press Enter..."
take_screenshot "19-state-sync" "01-before-navigation"

echo "📸 Step 53/54: State Sync - After Return"
read -p "Like/bookmark on detail, navigate back, show synced state, then press Enter..."
take_screenshot "19-state-sync" "02-after-return"

echo ""
echo "=========================================="
echo "✅ Screenshot capture complete!"
echo "All screenshots saved to: $SCREENSHOT_DIR"
echo "=========================================="
