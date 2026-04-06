[Fixed] 1. Need to address certain views/cards in the UI that are showing the background through and due to them showing information/text this sometimes makes it hard to read if there is a pattern in the background, due to this i feel we need to increase the opacity slightly more to contrast the background. Being clear the areas i describe are the sub views/cards themselves, never change any main backgrounds or patterns in this fix. Mostly these will apply to all themes - dark, mid-grey, light-grey. The below applies to all themes. With the light grey theme though - all disclosures and sub views (not a main background) can be made slightly darker as appearing a bit too light

    - Right drawer chatroom settings sheet - list item backgrounds (Mute conversation, block user, report user, delete conversation)
    - Right drawer DM settings sheet - list item backgrounds (Mute conversation, block user, report user, delete conversation)
    - Bottom bar symbol detail section - symbol details disclosure, symbol details info box, timeframe box, watchlist disclosure, watchlist symbol list items, watchlist search textbox
    - Bottom bar components view - all list items
    - Bottom bar marker view  - add marker section - all marker list views and all marker list views need the pattern in their background removed as already present in background view
    -Bottom bar marker view - markers - all list items
    - Bottom bar marker view - Analysis - all sub view items
    -Bottom bar marker view - marker setting new sheet - all sub view items
    - Main chart - Chart Settings popup sheet - all sub views (grid lines, candle colors etc...)
    - Marker view mode - bottom bar marker detail view - all sub views and disclosures except the header view.
    - Marker view mode - bottom bar marker components view - all sub views
    - Marker view mode - bottom bar marker chat - header section needs full opacity like footer section 
    - Marker view mode - bottom bar - tab footer section holding tab buttons needs to be full opaque, even when bottom bar is closed
    - Marker placement mode - bottom bar marker detail view - all sub views
    - Marker placement mode - bottom bar add components view - all sub views
    - User profile - overview, markers, awards and activity sub views - all of the list items etc... that appear in each of them tab sections 
    - Switch guild - guild list items
    - Discover guild - guild list items
    - Discover guild - view specific guild - all sub view items 
    - Create a guild - all sub view items
    - Another user profile - overview, markers, awards - all sub view and list view items
    - Not sure if already covered but other user profile - chat interface - settings section - all sub views - mute, block, report, delete buttons
    - User signup - how traders guild works section - all sub views
    - user signup - select trading interests - main selection box
    - User signup - choose guild - all guild list view items
    - user signup - final touches - all sub views
    - user signin - reset your password
    - user signin - main section - any textbox
    - user signin - create a new password
    - Auth section - Select your guild - guild list item








2. Certain areas of the app dont allow the user to close the open keyboard by tapping on the screen. This should always be possible, closing the keyboard is a necessity for proper operational use, i will describe all areas that need to be addressed with this issue. Need to also allow users to swipe the keyboard down to dismiss as well
    - Left Draawer Watchlist search box
    - Right drawer main search box
    - Bottom bar symbol detail view - watchlist search, need to close on external tap and drag
    - Marker view mode - marker chat keyboard doesnt disappear on external tap
    - Marker placement mode - marker detail view - on adding setup description/note or alert description, analysis description, question in question marker, poll question and answers, news link or description, reaction description, personal description - cant close keyboard on swipe down or external click
    - Help Center in User settings search box
    - User settings - all textboxes in - Edit profile, change email, change password, 
    - Create a guild - all textboxes
    - All textboxes in User signup section - create your account, select username, add more profile settings - all textboxes here cant close keyboard on click.
    


[Fixed] 3. In chat interfaces when pressing the + button the option box appears which is good, but also shows a background box behind the main grey box, this needs removing or hiding

[Fixed] 4. Lets remove the search functionality in the chatroom sheet, its not necessary and confusing for users

[Fixed] 5. In the bottom bar symbol detail view the watchlist search section hides the search box on keyboard open, so need to allow more scroll down to see the box when typing etc...

6. Bottom bar marker view - marker setting new sheet - needs UI adjusting to fit rest of the app, Done button color is wrong, X close button is wrong not glass effect

[Fixed] 7. In Marker placement mode - marker detail view - on adding setup description/note or alert description, analysis description, question in question marker, poll question and answers, news link or description, reaction description, personal description - the bottom bar tab section appears above keyboard when the keyboard shows to type, this cant happen, also need to remove the done button appearing above keyboard, user will be able to close by tapping externally or dragging the keyboard down.

[Fixed] 8. In marker placement mode if i switch to reaction marker then switch to a different marker to place the reaction emoji stays on chart and follows the new marker placement, needs to be removed on switch

[Fixed] 9. About section in user setting need the app icon changed to app icon now used

10. Contact support section in user settings needs work, textboxes need to conform to other uses within the app to match the UI, when selecting one to open the keyboard the bottom footer section moves above the keyboard which is off putting, category section need to be made smaller and nicer UI

[Fixed] 11. In switch guild section need to remove the Guild actions text at the bottom  and make the footer UI better with full opaque footer up to footer border, at the moment there is a small gap showing the background through due to the text.

[Fixed] 12. In create guild section bottom footer section shows above keyboard with all textboxes, 

13. On reporting a user need to change button to show user was reported.

[Fixed] 14. Reporting popup sheet needs UI to match rest of the app

15. Need notification on friend request sent showing waiting for response - on notification click go to user profile. 

[Fixed] 16. In sign up section for create your account, choose your username, final touches - when keyboard opens on any of the textboxes there the footer with continue button appear above the keyboard, needs to stay where it is at the bottom - also occurs in verification section when selecting the code textboxes.

[Fixed] 17. In the user signup verification section when selecting the token/code textboxes they dont show they are selected.

[Fixed] 18. In the user signup verification section the continue without verifying button needs text to be dark

[Fixed] 19. In main app when unverified - on opening the verify your email sheet it shows a double close in top right - Done button and x close button, need to remove the done button, also the footer shows above the keybaord when opening, this needs to be stopped and show no selection on the textbox to signify its been selected

[Fixed] 20. When user enters signin section via email the footer section shows above the keyboard on opening, this needs to be stopped, same for the reset your password section on any text box and for creating a new password section - any textbox

[Fixed] 21. In light grey theme a couple of things - all chat interfaces the pattern in background needs dulling down too bright. Also pattern in user profiles background section needs dulling down. And the pattern in the main chart is still a little too bright. Text in the symbol info box in bottom bar symbol detail view needs to be made dark - currently white.
