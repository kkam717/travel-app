#!/bin/bash

# Script to recapture specific screenshots that didn't work properly
# IMPORTANT: Make sure the Travel App is running and visible in the simulator before starting

SCREENSHOT_DIR="/Users/kiankamshad/Travel App/screenshots"

take_screenshot() {
    local path=$1
    local filename=$2
    local full_path="$SCREENSHOT_DIR/$path"
    mkdir -p "$full_path"
    
    echo "⏳ Waiting 2 seconds for screen to stabilize..."
    sleep 2
    
    xcrun simctl io booted screenshot "$full_path/$filename.png"
    
    if [ -f "$full_path/$filename.png" ]; then
        echo "✓ Screenshot saved: $path/$filename.png"
    else
        echo "✗ ERROR: Screenshot failed to save!"
    fi
}

check_app_running() {
    echo ""
    echo "⚠️  IMPORTANT: Make sure the Travel App is running and visible in the simulator!"
    echo "   If you see the iPhone home screen, open the Travel App first."
    echo ""
    read -p "Is the Travel App currently visible in the simulator? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please open the Travel App in the simulator and run this script again."
        exit 1
    fi
}

echo "=========================================="
echo "Recapture Screenshots"
echo "=========================================="
echo ""

# Check if app is running
check_app_running

# Delete existing screenshots for these features
echo "🗑️  Cleaning up old screenshots..."
rm -rf "$SCREENSHOT_DIR/05-create-itinerary"
rm -rf "$SCREENSHOT_DIR/10-author-profile"
rm -rf "$SCREENSHOT_DIR/11-city-detail"
rm -rf "$SCREENSHOT_DIR/12-my-trips"
rm -rf "$SCREENSHOT_DIR/14-likes"
rm -rf "$SCREENSHOT_DIR/15-translation"
rm -rf "$SCREENSHOT_DIR/16-qr-code"
rm -rf "$SCREENSHOT_DIR/17-settings"
rm -rf "$SCREENSHOT_DIR/18-share"
echo "✅ Cleanup complete"
echo ""
echo "📱 Instructions:"
echo "   1. Navigate to the screen described"
echo "   2. Make sure the app screen is fully visible (not home screen)"
echo "   3. Press Enter to capture"
echo ""

# 1. Create New Trip (Create Itinerary)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 CREATE ITINERARY - Step 1: Start Form"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Tap the FAB (+) button, show Step 1 form with trip name field"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step1-start" "01-step1-form"

echo ""
echo "📸 CREATE ITINERARY - Step 2: Destinations"
echo "Action: Fill trip name, tap Next, show Step 2 (destinations search)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step2-destinations" "01-step2-destinations"

echo ""
echo "📸 CREATE ITINERARY - Step 3: Assign Days"
echo "Action: Add destinations, tap Next, show Step 3 (assign days to destinations)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step3-assign-days" "01-step3-days"

echo ""
echo "📸 CREATE ITINERARY - Step 4: Trip Map"
echo "Action: Assign days, tap Next, show Step 4 (trip map view)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step4-map" "01-step4-map"

echo ""
echo "📸 CREATE ITINERARY - Step 5: Add Details/Venues"
echo "Action: Tap Next, show Step 5 (add details/venues for each day)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step5-details" "01-step5-venues"

echo ""
echo "📸 CREATE ITINERARY - Step 6: Review"
echo "Action: Add details, tap Next, show Step 6 (review all trip details)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step6-review" "01-step6-review"

echo ""
echo "📸 CREATE ITINERARY - Step 7: Save"
echo "Action: Tap Next/Save, show Step 7 (final save confirmation or success)"
read -p "Press Enter when ready to capture..."
take_screenshot "05-create-itinerary/step7-save" "01-step7-save"

# 2. Author Profile
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 AUTHOR PROFILE - Profile Screen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to Home feed, tap on another user's name/avatar"
read -p "Press Enter when ready to capture..."
take_screenshot "10-author-profile" "01-author-profile"

echo ""
echo "📸 AUTHOR PROFILE - Follow Button"
echo "Action: Show the Follow/Following button clearly"
read -p "Press Enter when ready to capture..."
take_screenshot "10-author-profile" "02-follow-button"

# 3. City Detail
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 CITY DETAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to Profile > Countries (or tap on a city from itinerary)"
read -p "Press Enter when ready to capture..."
take_screenshot "11-city-detail" "01-city-detail"

# 4. My Trips
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 MY TRIPS - Own Profile Trips"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to Profile > Trips (your own trips)"
read -p "Press Enter when ready to capture..."
take_screenshot "12-my-trips/own" "01-my-trips"

echo ""
echo "📸 MY TRIPS - Author Trips"
echo "Action: Navigate to an author profile > Trips (their trips)"
read -p "Press Enter when ready to capture..."
take_screenshot "12-my-trips/author" "01-author-trips"

# 5. Likes
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 LIKES - Before Like (Outline Icon)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to an itinerary detail (someone else's post), show thumbs up outline"
read -p "Press Enter when ready to capture..."
take_screenshot "14-likes" "01-before-like"

echo ""
echo "📸 LIKES - After Like (Filled Icon)"
echo "Action: Tap the like button, show filled thumbs up icon and like count"
read -p "Press Enter when ready to capture..."
take_screenshot "14-likes" "02-after-like"

# 6. Translation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 TRANSLATION - Translate Button"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Find content in a different language, show the translate button"
read -p "Press Enter when ready to capture..."
take_screenshot "15-translation" "01-translate-button"

echo ""
echo "📸 TRANSLATION - Translated Content"
echo "Action: Tap translate, show the translated content"
read -p "Press Enter when ready to capture..."
take_screenshot "15-translation" "02-translated-content"

# 7. QR Code
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 QR CODE - My Code Tab"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to Profile > QR Code icon (top left), show My Code tab"
read -p "Press Enter when ready to capture..."
take_screenshot "16-qr-code/my-code" "01-my-code"

echo ""
echo "📸 QR CODE - Scan Tab"
echo "Action: Tap Scan tab, show QR scanner screen"
read -p "Press Enter when ready to capture..."
take_screenshot "16-qr-code/scan" "01-scan-screen"

# 8. Settings
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 SETTINGS - Main Screen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to Profile > Settings icon (top right)"
read -p "Press Enter when ready to capture..."
take_screenshot "17-settings" "01-settings-screen"

echo ""
echo "📸 SETTINGS - Appearance Section"
echo "Action: Scroll to or tap Appearance section, show appearance options"
read -p "Press Enter when ready to capture..."
take_screenshot "17-settings/appearance" "01-appearance"

echo ""
echo "📸 SETTINGS - Language Section"
echo "Action: Scroll to or tap Language section, show language options"
read -p "Press Enter when ready to capture..."
take_screenshot "17-settings/language" "01-language"

# 9. Share
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📸 SHARE - Itinerary Share Sheet"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Action: Navigate to an itinerary detail, tap share button, show iOS share sheet"
read -p "Press Enter when ready to capture..."
take_screenshot "18-share/itinerary" "01-share-sheet"

echo ""
echo "📸 SHARE - Profile Share Sheet"
echo "Action: Navigate to Profile > QR Code, tap share, show share sheet"
read -p "Press Enter when ready to capture..."
take_screenshot "18-share/profile" "01-share-sheet"

echo ""
echo "✅ All screenshots recaptured!"
echo ""
echo "💡 Tip: If screenshots show the home screen, make sure:"
echo "   1. The Travel App is running and visible"
echo "   2. The simulator window is active/focused"
echo "   3. You wait a moment after navigating before pressing Enter"
