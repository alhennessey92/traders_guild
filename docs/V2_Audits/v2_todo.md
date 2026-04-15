1. [Fixed] Still not happy about how the keyboard dismisses in create announcement, create events and search for symbols in watchlist section in bottom bar symbol detail view. Need to be able to scroll on screen, but should dismiss keyboard by either tapping outside or swiping the keyboard down. We do this correctly for message input in all chat interfaces, so should copy same functionality

2. [Fixed] Create announcement and events still need a solid footer at bottom for cancel/post buttons, but needs to extend fully to bottom of screen - remove the cancel button as well at the bottom already have close button at the top

3. [Fixing] Need to address the annotations
Text input needs to just be the text on the chart. Need to allow sizing of text and make sure where we place it is where it stays. Keeps moving to latest candle after refresh for some reason should stay where user leaves it

4. [Fixed] Need to adjust the emoji annotation. On selection give it handles like zone where you can resize it by dragging them. Make sure always appears behind candles, components and markers. Again needs to stay in place, keeps moving to latest candle in refresh. Tie this into emoji selection panel on chart update No 9

5. Shouldn’t be allowed to edit setup marker being tracked once placed

6. [Fixed] Adjust keyboard in bottom bar for searching for symbols. Need to allow further scrolling down past the search box to view results with the keyboard still on show.

7. Potentially move watchlist sub tabs down under watchlist name to see all options in bottom bar symbol detail view

8. Perhaps editing message in chat interfaces should reopen it in bottom section again rather than seperate pop sheet

9. [Fixed] Emoji picker on chart for drawings/annotations is too high and stops interaction on chart, so cant move the chart, need to be able to move the chart and when selecting the emoji move it independently. Also the picker needs to be less high - reduce the height a bit, but obviously make the content scrollable

10. [Fixed] In guild details in admin panel, if user switches guild privacy to invite only for guild, show options for questions required and make it a requirement to fill at least one quesiton out before it is saved

11. On guild invitation request notification - on click in notification go to view guild info view like in join guild

12. [Fixed] Change event detail view to show list of attending users rather than the no attending at the top, could do it under the description

13. [Fixed] Adapt the event to allow users to select location of the event such as a certain symbol or a chatroom. This way when the reminder notification shows it takes the user to that location. Also when open a button appears in the event view "Go to Event" and take them to the location - at the moment just says location is Guild Hall which is irrelevant in the app

14. Last few updates to light grey theme

15. [Fixed] Still need the create annoucnement and events fixed in terms of footer and making the icon selection more professional looking 

16. Need to double check APNs only work for logged in used and not other user. Noticed getting event reminders for event on logged in user but another guild to current one. Was unable to go to that event so need to switch etc... This needs a full audit as part of the APN current user review. Making it work across guilds for logged in user - merge into no 12 and 13 as part of group update

17. Allow chart settings to allow users to toggle solid candles vs semi transparent candles like the default bullish candles are

18. Audit the synthetic users section for use in beta/production environemnt
    - reduce no of synthetic users
    - Make the synthetic users full validated users with proper accounts etc...
    - Seed a good no of markers
    - Make the realtime marker placement more frequent, better constructed so the app never looks boring/empty. The synthetic users need to work independently for adding markers
    - Place markers across all symbols and timeframes


- Emoji annotation when placed starts in latest candle, needs to be center of users screen relevant, same for text annotation

- Emoji and text annotation dont stay fixed to candle when zooming horizontally

19. Prepare for Beta Launch!