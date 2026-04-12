Completed items are prefixed with `[Fixed]`. Untagged items are still open.

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








[Fixed] 2. Certain areas of the app dont allow the user to close the open keyboard by tapping on the screen. This should always be possible, closing the keyboard is a necessity for proper operational use, i will describe all areas that need to be addressed with this issue. Need to also allow users to swipe the keyboard down to dismiss as well
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

[Fixed] 6. Bottom bar marker view - marker setting new sheet - needs UI adjusting to fit rest of the app, Done button color is wrong, X close button is wrong not glass effect

[Fixed] 7. In Marker placement mode - marker detail view - on adding setup description/note or alert description, analysis description, question in question marker, poll question and answers, news link or description, reaction description, personal description - the bottom bar tab section appears above keyboard when the keyboard shows to type, this cant happen, also need to remove the done button appearing above keyboard, user will be able to close by tapping externally or dragging the keyboard down.

[Fixed] 8. In marker placement mode if i switch to reaction marker then switch to a different marker to place the reaction emoji stays on chart and follows the new marker placement, needs to be removed on switch

[Fixed] 9. About section in user setting need the app icon changed to app icon now used

[Fixed] 10. Contact support section in user settings needs work, textboxes need to conform to other uses within the app to match the UI, when selecting one to open the keyboard the bottom footer section moves above the keyboard which is off putting, category section need to be made smaller and nicer UI

[Fixed] 11. In switch guild section need to remove the Guild actions text at the bottom  and make the footer UI better with full opaque footer up to footer border, at the moment there is a small gap showing the background through due to the text.

[Fixed] 12. In create guild section bottom footer section shows above keyboard with all textboxes, 

[Fixed] 13. On reporting a user need to change button to show user was reported.

[Fixed] 14. Reporting popup sheet needs UI to match rest of the app

[Fixed] 15. Need notification on friend request sent showing waiting for response - on notification click go to user profile. 

[Fixed] 16. In sign up section for create your account, choose your username, final touches - when keyboard opens on any of the textboxes there the footer with continue button appear above the keyboard, needs to stay where it is at the bottom - also occurs in verification section when selecting the code textboxes.

[Fixed] 17. In the user signup verification section when selecting the token/code textboxes they dont show they are selected.

[Fixed] 18. In the user signup verification section the continue without verifying button needs text to be dark

[Fixed] 19. In main app when unverified - on opening the verify your email sheet it shows a double close in top right - Done button and x close button, need to remove the done button, also the footer shows above the keybaord when opening, this needs to be stopped and show no selection on the textbox to signify its been selected

[Fixed] 20. When user enters signin section via email the footer section shows above the keyboard on opening, this needs to be stopped, same for the reset your password section on any text box and for creating a new password section - any textbox

[Fixed] 21. In light grey theme a couple of things - all chat interfaces the pattern in background needs dulling down too bright. Also pattern in user profiles background section needs dulling down. And the pattern in the main chart is still a little too bright. Text in the symbol info box in bottom bar symbol detail view needs to be made dark - currently white.

22. [Fixed] Light theme needs some adjustment - Looking at bottom bar etc... there are still white text and icons over light backgrounds, this contrast is bad, should all be dark grey/black. Pattern in dm, chatroom chat is too dark.

[Fixed] 23. APNs need to use the app icon logo

[Fixed] 24. All elements in the admin and potentially the moderator section including but not limited to the report, create chatroom, create event etc... sections need the header and footer parts of each section to be fully opaque like rest of app, needs to equate to all themes.

[Fixed] 25. Need to add a beta welcome screen like the tutorial section, but appears before the tutorial section, maybe make it appear in auth welcome view, so the first thing beta testers see, describing to them the reasoning behind the beta testing, anything they need to know, explain the process for the future - future plans, how to submit thoughts and issues in the new beta contact form we will create in number 26. Need to be able to turn this off in admin settings for the app

[Fixed] 26. Create a beta tester contact form that appears as a option in the left drawer under the statistics button. It should open a sheet, that can allow users to submit feedback, information, bug reports etc...These reports need to go to a new table or area for me to review - needs to fit in with the look and ui of the app/themes. Need to be able to turn this off when beta is done in the admin app settings


27. APN notification needs app logo still not fixed

28. Reputation earned on setup tracked should be relative to risk reward, timeframe, capped to a min and max, so it adjusts on the tp and sl position

29. Synthetic users not posting on other timeframes only 1 min and need more often, left over night and only one set of markers were placed and time went nearly 10 hours and still no more, plus none on any other timeframes, need to make much more activity - want to simulate an active app


30. Candle data only goes back specific amount, looking now for some reason the 5 min goes back to 9am yesterdam and 1 min goes back to 9 am today but havent reset any data, been running for a week, there should be no limit to past data, as user goes back a certain amount should keep re loading past candles/markers etc...

31. Gesture control in timeframes - i.e. pinching for x axis zoom on chart and sliding on y axis like with the main chart

32. Each timeframe needs its own x axis relative to itself - when two time frames stacked, the top timeframe doesnt have a x axis relative to itself so hard to determine its current time

33. When 2 timeframes active the chart buttons at bottom which should sit above the timeframe are slightly below the top timeframe by a small amount, fine with 1 active timeframe but issue with 2

34. Not sure if issue with no 30 but when clicking markers in left drawer they are not being shown and y axis sometimes get hidden, no way to get out of this so have to restart app, but some of these candles are older than the 9 am so maybe that is it. So maybe address no 30 and we will see about this after. just created new marker and went straight to it from left drawer





[Fixed] 35. Markers need a better resolved info in list view at the moment don’t display a lot such as in profile marker view

[Fixed] 36. In chat interfaces the bottom message input section needs to sit lower as the lowest  / newest message actually sits under the message input section a little, used to sit lower in the device, currently a large gap between bottom of device and start of message input section

[Fixed] 37. When adding multiple items like images, files, markers etc... need to group together in a single message bubble. This includes when markers are added with images etc as well all contained in one message bubble

38. App feels laggy when opening bottom bar especially and sometimes when panning around. Left and right drawers open smoothly so they aren’t a problem. But mainly when opening the bottom bar section its not smooth, like theres small delays in it opening and closing

[Fixed] 39. Need to check all options work in message detail like delete, edit, reply etc. options should be different for users own message - can’t reply or add emoji etc… noticed certain actions don’t work like delete. Shouldn’t be able to delete other users message 

[Fixed] 40. User accuracy in leaderboard appears in final section but not guild as says need 10 predictions

[Fixed] 41. Need to show guild in global leaderboard list view items so user knows which guild they ar epart of as its a global section across all guilds

[Fixed] 42. Admin section current guild watchlist remove search and add search as tab with box in there and list all symbols underneath with no entry in search

[Fixed] 43. Guild settings needs to be guild details as more of a details section 

[Fixed] 44. Admin section - invite members - search section is weird with wrong background and placement. Should also show relevant users on no search entry like maybe those in other guilds to the admin

[Fixed] 45. Gestures still not working right in timeframe - y axis pan scale not working, should be able to pan up and down on the y axis to change candle height like the main chart and the pinch on timeframe chart is making it go wild rather than controlled, smooth, steady zoom in and out like the main chart

[Fixed] 46. Bottom chart buttons still semi hidden with 2 or more timeframes same for normal indicator panels. Ok with just one panel active, and Ok when bottom panel is open and second panel is open, but soon as that closes the chart buttons fall behind top panel slightly. Don’t maintain their normal spacing to top of panel

[Fixed] 47. Crosshair white x axis time indicator still sitting too high in x axis. Getting cutoff by bottom of timeframe x axis or panel when active

[Fixed] 48. Candle data still not being paginated in as user pans back in time, 5 min went back to friday which i think is correct, but 1min only went back to 4.40am today, so needs checking

[Fixed] 49. Synthetic user marker system is still not great, they are placing markers but usually in clusters in small time and then nothing for a while, needs to be more consistent and realistic




50. [Fixed] Timeframe panel opposite vertical panning and y axis scaling doesn’t adjust the y axis prices

51. [Fixed] Keep getting can’t update leaderboard when refreshing must be issue with backend

52. Panning around on chart feels laggy when in marker placement and view mode. Ok on standard chart viewing not sure if we are performing a lot of work in background causing this 

53. [Fixed] Timeframe panel changes background when spotlight not in view, this isn’t necessary can remain in its state as when the spotlight slider is in view

54. [Fixed] For setup marker once it’s resolved the chart info box doesn’t need to display the price position slider with to and sl can simply display result of marker like sl hit, risk reward, rep gain etc… 

55. [Fixed] For any new user mid grey theme as default


56. [Fixed] Sometimes when removing a horizontal line like resistance gets stuck in a state, flashes in chart info box and in the bottom bar active section and cant remove it unless close app fully. Just tested and hapened again with trendline after deleting 3 other drawings

57. When adding a annotation make the text box simpler on chart and allow to wrap text underneath when user enters new line

58. [Fixed] Adjusting the timeframe panel height adjusts the candle height with it, should stay fixed, only thing that affects candle height in the timeframe panel is by sliding in the y axis

59. [Fixed] When indicator panel is active x axis is great with good distance from x axis on main chart to bottom of indicator panel, but when closing the indicator panel the x axis time text jumps up slightly almost touching the bottom of the indicator panel, need to make sure that there is still a gap, like when open. Fine for timeframe panels so not sure of the difference




60. [Fixed] Indicator panels need looking at they are still not behaving correctly. For some reason there’s a few bugs with it now and can happen when 1 or 2 active. Closing the panel causes the x axis times to jump up slightly removing the small gap in between. Sometimes when activating the panel the header is missing - have to swipe around a bit before it appears. When 2 are active closing the bottom causes the closed header to move below the main x axis. When viewing a marker and returning the header can sometimes disappear and it all looks a bit messed up. Timeframe panels are perfect so not sure how they differ maybe compare and see


61. [Fixed] Bottom chart buttons sitting at different heights to top of panels depending on the configuration need to make them follow the top of the top most panel

62. [Fixed] Need to add ability to report marker in general disclosure

63. [Fixed] When reporting anything should send notification to both parties to see it was done.

64. [Fixed] When reporting chat message should add report icon reaction to offending message




65. [Fixed] Mods should have ability to deal with reports in the pending section, provide certain buttons for action

66. [Fixed] report number appearing under x close on top right of manage reports

67. [Fixed] In create announcment and event, on keyboard show the footer section with buttons is appearing above keyboard and cant dismiss keyboard by tapping screen or swiping down

68. [Fixed] In event and announcement list view where there is a new event/announcement show a blue circle in place of the right chevron, once viewed show the chevron instead

69. [Fixed] In create announcement and event allow mods/admins to select a icon to display out of a pre arranged set, just some icons to desimilar them

70. [Fixed]Important or featured events/announcements need a special icon or make their icon colored to differentiate

71. [Fixed] Invite members need a their header being one color/look, different between top header and search area

72. [Fixed] Need to make tp hit coloring as blue to match price label coloring and make tracking coloring green, need to make sure we differentiate between them properly - red/SL, green/entry/tracking, blue/TP. Make sure all references of these across the app match this coloring we pick

73. Sometimes when viewing markers everythign appears correct but the actual marker icon doesnt appear on chart, the vertical line is there but not the icon

74. [Fixed] Deleted messages should be removed instantly from chat or add a deleted reaction icon

75. [Fixed] Adjust reaction icons for chat to be more of the general/normal reactions / emojis users would submit

76. [Fixed] Double check the market closure areas in symbol detailview in bottom bar, said oanda was closed as was 23.22 on friday evening but said market closes in 37mins, should be closed at 22.00

77. [Fixed] Chart setting button - change bullish color doesnt seem to work

78. [Fixed] Looking in left drawer markers section - by symbol and all sub tabs showing no markers yet 60 in live feed etc... should be populated and manual refresh should work

79. [Fixed] Remove the cancel and done buttons in marker settings, dont need it already have the x/close in top right

80. [Fixed] Change emoji selection in emoji marker placement mode to be circular in picker not rectangular to match more of a marker look






81. [Fixed] Send notification to respective users on report resolution

82. [Fixed] In report details for resolving change close button on top left to standard x button we use on top right

83. [Fixed] Make report actions buttons better looking and more in keeping with rest of app

84. Admin section - guild details allow to edit and adjust quesitons asked for closed guild

85. [Fixed] Certain search boxes look different across the app - standard look should be how they are in right drawer, bottom bar watchlist search etc... but noticed certain search bars like in admin section guild watchlist search is different 

86. [Fixed] In discover guilds the guild name gets cut short by certain pills like private and joined, this cant happen, name is essential to display full, so they need to go on new line

87. [Fixed] Need to adjust the join guild filter section - language and location need to be dropdown like in other sections that use it and make sure all works as it should

88. [Fixed] Need to add a placeholder at top of each chatroom/dm/marker/symbol chat interface. Not a full message but in the style of the Today text just a simple message saying Welcome to General Chatroom, Please abide by the rules or something professional and equivalent, same for the other chat interfaces. Just stops it looking plain. Could add a link if tapping the rules text part that shows all the standard rules for chatting in traders guild chat interfaces

89. [Fixed] Need to remember if user has selected no face id and tutorial use so dont need to keep showing at beginning of app when been fully closed or removed, getting tutorial showing for a veteran user that would have seen it long before

90. [Fixed] Noticed a request to join a guild from an admin, i accepted on other account and joined fine. Removed and replaced app, notification now shows same look - accept or decline invitation to join, yet i am already a memeber. If i click either button get a failed to accept invite. This shouldnt show anyway.

91. [Fixed] Accept/decline friend request in members section need better buttons. Also should be able to accept from within notification section and the asking users profile. 

92. [Fixed] Noticed current user not always appearing online in their profile/left drawer bottom profile selection button. But do in user list

93. [Fixed] When typing password in auth/email etc... it does a bit of flashing when typing, not sure if because its trying to suggest certain passwrods or what but quite off putting

94. [Fixed] Report section in mod and admin needs ui looking at, quite messy in terms of headers, tabs, report list views, can be greatly improved

95. [Fixed] Bottom footer section in create announcement and event section in mod and admin panel needs looking at, doesnt go all the way to bottom has a large space underneath. Also cant scroll down far enough with keyboard open to select important button. 

96. [Fixed] No 67 still not implemented, cant dismiss keyboard for these sections

97. [Fixed] No 70 still not implemented, no special improtant icon

98. [Fixed] Selected icon for announcement not showing in actual announcement, reverts to standard icon

99. [Fixed] No 78 still not working

100. [Not Fixed] Emoji picker on chart for drawings/annotations is too high and stops interaction on chart, so cant move the chart, need to be able to move the chart and when selecting the emoji move it independently. Also the picker needs to be less high - reduce the height a bit, but obviously make the content scrollable

101. [Fixed] No 80 not fixed was meant to be the emojis in the marker placement mode - reaction selection in bottom bar detail view








102. [Fixed] Still getting an issue of removing a drawing and it not being removed instantly from chart info box, causing it to flash and flash in active section, a few moments later it removes correctly. Its like it gets stuck and cant dismiss from chart. Also noticed the drawing becuase sometimes i cant delete it appears on the latest candle across different accounts, like its getting stuck in the background of the app. For example i have deleted on chart but still appears in chart info box. If i got to active drawings in bottom bar it starts flickering and bugging out

103. [Fixed] In create guild make selection of language and country required

104. in guild details in admin panel if user switches  to invite only for guild, show options for questions required and make it a requirement to fill at least one quesiton out

105. [Fixed] Change important announcement to be a red border on icon rather than star and important announcement pill

106. [Fixed] No 73 still not working - Sometimes when viewing markers everythign appears correct but the actual marker icon doesnt appear on chart, the vertical line is there but not the icon - When selecting a marker from marker section in left drawer get taken to correnct marker and everything appears fine other than the actual marker icon on chart, only vertical line of position

107. [Fixed] Should show pending friend request in friends section in members in left drawer and should show accept/decline in notifications for friend request

108. On guild invitation request - on click in notification go to view guild info like in join guild

109. [Fixed] On viewing report resolved as normal member - when clicking the notification it takes me to manage reports in the moderator panel, which it shouldnt be allowed as they are a normal member - should show a basic view outlining the results of the resolution

110. [Fixed] Due to no 109 should do a check on any admin/mod panel opening that the current user is not a member role otherwise dont show, cant allow users to get access to these kinds of panels

111. [Fixed] Looking in left drawer markers section - by symbol and all sub tabs showing no markers, yet 60 in live feed etc... should be populated and manual refresh should work. Been trying to get this working for a bit now.


