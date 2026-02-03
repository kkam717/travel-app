#!/bin/bash

# Final script to capture remaining screenshots
# Make sure Travel App is running and visible in simulator

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
        echo "✗ ERROR: Screenshot failed!"
    fi
}

echo "=========================================="
echo "Capture Final Remaining Screenshots"
echo "=========================================="
echo ""
echo "⚠️  Make sure Travel App is VISIBLE in simulator (not home screen)"
echo ""

# Create Itinerary Steps 2-7
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CREATE ITINERARY - Steps 2-7"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📸 Step 2: Destinations"
echo "Action: Tap FAB, fill trip name, tap Next, show destinations screen"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step2-destinations" "01-step2-destinations"

echo ""
echo "📸 Step 3: Assign Days"
echo "Action: Add destinations, tap Next, show assign days screen"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step3-assign-days" "01-step3-days"

echo ""
echo "📸 Step 4: Trip Map"
echo "Action: Assign days, tap Next, show trip map view"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step4-map" "01-step4-map"

echo ""
echo "📸 Step 5: Add Details/Venues"
echo "Action: Tap Next, show add details/venues screen"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step5-details" "01-step5-venues"

echo ""
echo "📸 Step 6: Review"
echo "Action: Add details, tap Next, show review screen"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step6-review" "01-step6-review"

echo ""
echo "📸 Step 7: Save"
echo "Action: Tap Save/Next, show final save screen"
read -p "Press Enter when ready..."
take_screenshot "05-create-itinerary/step7-save" "01-step7-save"

# Translation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TRANSLATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📸 Translate Button"
echo "Action: Find content in different language, show translate button"
read -p "Press Enter when ready..."
take_screenshot "15-translation" "01-translate-button"

echo ""
echo "📸 Translated Content"
echo "Action: Tap translate button, show translated content"
read -p "Press Enter when ready..."
take_screenshot "15-translation" "02-translated-content"

# Share Profile
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SHARE PROFILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📸 Share Profile/QR"
echo "Action: Go to Profile > QR Code, tap share, show share sheet"
read -p "Press Enter when ready..."
take_screenshot "18-share/profile" "01-share-sheet"

echo ""
echo "✅ All remaining screenshots captured!"
echo ""
echo "Total screenshots now: $(find $SCREENSHOT_DIR -name '*.png' | wc -l | xargs)"
