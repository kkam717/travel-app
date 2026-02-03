#!/bin/bash

# Script to capture missing screenshots manually using xcrun simctl
# Run this after the integration test to capture screenshots that weren't automated

SCREENSHOT_DIR="/Users/kiankamshad/Travel App/screenshots"

take_screenshot() {
    local path=$1
    local filename=$2
    local full_path="$SCREENSHOT_DIR/$path"
    mkdir -p "$full_path"
    xcrun simctl io booted screenshot "$full_path/$filename.png"
    echo "✓ Screenshot saved: $path/$filename.png"
}

echo "=========================================="
echo "Capture Missing Screenshots"
echo "=========================================="
echo ""
echo "Make sure the app is running and navigate to each screen"
echo "Press Enter after navigating to capture screenshot"
echo ""

# Missing screenshots that need manual capture
echo "📸 Settings Screen"
read -p "Navigate to Profile > Settings, then press Enter..."
take_screenshot "17-settings" "01-settings-screen"

echo "📸 Settings - Appearance Section"
read -p "Show appearance options, then press Enter..."
take_screenshot "17-settings/appearance" "01-appearance"

echo "📸 Settings - Language Section"
read -p "Show language options, then press Enter..."
take_screenshot "17-settings/language" "01-language"

echo "📸 QR Code - My Code Tab"
read -p "Navigate to Profile > QR Code > My Code tab, then press Enter..."
take_screenshot "16-qr-code/my-code" "01-my-code"

echo "📸 QR Code - Scan Tab"
read -p "Navigate to QR Code > Scan tab, then press Enter..."
take_screenshot "16-qr-code/scan" "01-scan-screen"

echo "📸 Author Profile"
read -p "Open another user's profile, then press Enter..."
take_screenshot "10-author-profile" "01-author-profile"

echo "📸 Author Profile - Follow Button"
read -p "Show follow/unfollow button, then press Enter..."
take_screenshot "10-author-profile" "02-follow-button"

echo "📸 Author Trips"
read -p "Open author profile > Trips, then press Enter..."
take_screenshot "12-my-trips/author" "01-author-trips"

echo "📸 My Trips (Own)"
read -p "Navigate to Profile > Trips, then press Enter..."
take_screenshot "12-my-trips/own" "01-my-trips"

echo "📸 Followers Screen"
read -p "Navigate to Profile > Followers, then press Enter..."
take_screenshot "13-followers" "01-followers-list"

echo "📸 City Detail Screen"
read -p "Open a city detail screen (from profile), then press Enter..."
take_screenshot "11-city-detail" "01-city-detail"

echo "📸 Create Itinerary - Step 1"
read -p "Tap FAB, show Step 1 form, then press Enter..."
take_screenshot "05-create-itinerary/step1-start" "01-step1-form"

echo "📸 Create Itinerary - Step 2"
read -p "Navigate to Step 2 (destinations), then press Enter..."
take_screenshot "05-create-itinerary/step2-destinations" "01-step2-destinations"

echo "📸 Create Itinerary - Step 3"
read -p "Navigate to Step 3 (assign days), then press Enter..."
take_screenshot "05-create-itinerary/step3-assign-days" "01-step3-days"

echo "📸 Create Itinerary - Step 4"
read -p "Navigate to Step 4 (trip map), then press Enter..."
take_screenshot "05-create-itinerary/step4-map" "01-step4-map"

echo "📸 Create Itinerary - Step 5"
read -p "Navigate to Step 5 (add details/venues), then press Enter..."
take_screenshot "05-create-itinerary/step5-details" "01-step5-venues"

echo "📸 Create Itinerary - Step 6"
read -p "Navigate to Step 6 (review), then press Enter..."
take_screenshot "05-create-itinerary/step6-review" "01-step6-review"

echo "📸 Create Itinerary - Step 7"
read -p "Navigate to Step 7 (save), then press Enter..."
take_screenshot "05-create-itinerary/step7-save" "01-step7-save"

echo "📸 Translation Button"
read -p "Show translate button on content in different language, then press Enter..."
take_screenshot "15-translation" "01-translate-button"

echo "📸 Translated Content"
read -p "Tap translate, show translated content, then press Enter..."
take_screenshot "15-translation" "02-translated-content"

echo "📸 Share Itinerary"
read -p "Tap share on itinerary detail, show share sheet, then press Enter..."
take_screenshot "18-share/itinerary" "01-share-sheet"

echo "📸 Share Profile"
read -p "Tap share on profile QR, show share sheet, then press Enter..."
take_screenshot "18-share/profile" "01-share-sheet"

echo "📸 Like Action - After"
read -p "Show an itinerary after liking (filled thumb), then press Enter..."
take_screenshot "14-likes" "02-after-like"

echo ""
echo "✅ All missing screenshots captured!"
