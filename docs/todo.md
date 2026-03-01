1. [FIXED] In admin panel, need to review each section and make all UI conform to rest of app, this includes - buttons, textboxes etc... Look to switch/join/create guild section and match to that, all textboxes and buttons should be in unified components to be globally same across app

2. [FIXED] Need to allow users to add/remove and edit chatrooms in admin/owner sections of guild

3. [FIXED] Dont think we need the review sheet with the attachments section in chat, should be able to add caption with the image in box above textbox i.e. if you pull review down to close, it shows selected image behind and allows user to add text which is enough.

4. [FIXED] Need to add a tab in indicator section in bottom sheet showing all active indicators on chart, so users can easily interact with them

5. [FIXED] Need to add marker activiy button in the marker section in bottom sheet, showing all placed markers in the same UI like how activity is shown in users profile. They can see their markers, click them to go to them and see live prediction markers how they are doing.. could add button next to marker settings button

6. [FIXED] Add buttons at bottom of chart allowing users to choose visible makrers on chart, such as friends only, certain markers only etc... currently have a button for markers on or off visibility but feel this could be improved

7. [FIXED] Need to look at marker section, specifically when placing markers - the vertical line needs to appear over any active panels to see where it relates with them - so the vertical line is visible all the way to the bottom x axis. Also the time label on the x axis for the marker is appearing above the x axis, whereas it needs to appear in/over the x axis and display the correct time / day relative to the current timeframe - this is also the same for the label under the marker - it needs to say the name of the marker - not the time or proce, these are already shown in repective bars - the x axis bar showing time for marker needs to appear similar to the crosshair function we provide when long pressing

8. [FIXED] Need to always make sure any usernames appearing in the chart where they place markers always appear behind other markers near them

9. [FIXED] The like icon on the marker could be slightly dimmer, a bit too bright

10. [FIXED] Can we try and include the users avatar in marker detail view and make their name/avatar/ an area around their name clickable to got to their profile

11. [FIXED] When clicking the avatar/username in a chat message get taken to their profile - this is across all chat interfaces

12. [FIXED] RSI Panel needs to show bearish/bullish or oversold/undersold etc in its top row like other panels and show the current value in the right color like other panels - this is the same for cci and volume - need to make sure all panels conform to same look - showing set values for the panel, current value in right color and current state (bearish, bullish, oversold etc...) this is all in the top bar section of the panel

13. [FIXED] In the chat attachment section add option to link a marker user has placed, on click show a panel listing all markers starting with latest, user can click one with a caption and link to it in chat

14. [FIXED] Make sure auth initialisation checks email and username for uniqueness / no blocking etc. Also gather initial language and location for providing correct recommendations for guilds etc... Want to provide guilds with same language at least

15. [FIXED] Make sure when choosing guild in auth that if no other guilds to choose, initially show the onboarding guild as pre selected to join, rather than showing no guilds and showing after pressing submit, make it look cleaner

16. [FIXED] Implement a spam/abuse service monitoring chats/markers for spam, racial, abuse anything not good and auto mute users and report to admin

17. [FIXED] in profile setup in auth provide options for location and language, allowing to change but pre fill with defaults from users device?

18. [FIXED] Marker when placing needs to appear above the vertical dotted line, same for marker name type

19. [FIXED] Toggle buttons in marker types visibility appearing as pure white, needs to look like proper toggle

20. [FIXED] When adding prediction marker on view to add the submit button appears as pure white, so cant see any writing

21. [FIXED] marker visibility and latest buttons in chart need to move to the right up to price y axis

22. [FIXED] Need to provide a symbol detail section in bottom sheet outlinging current symbol information, history, current provider, running hours, highs, lows of the day, week etc. a full detail list, this section can be collapsible - this can show info regarding whether it is bullish or bearish at the moment relevant to global guild analysis

23. [FIXED] Need to display provider name, open/ closed icon in top left symbol section.

24. [FIXED] Need to make sure symbol open / closed status is working and correct, show right icon relevant to symbols status if it is still providing candles at the current time. Currently 3pm on sunday here yet eurusd shows open status which its not its closed, last candle 21.59 on friday evening

25. [FIXED] Need to add more interests in auth to choose from

26. [FIXED] Need to review settings section, amking sure they are all relevant, implemented etc... certain things to add, allow DMs from all users or just friends or no one etc...

27. [FIXED] Colors for tabs in leaderboard need to be unique as you get down the hierarchy, same colors for tabs as top global tab to 2nd stage reputation and accuracy, yet reputation and accuracy in guild is different

28. [FIXED] Need initial notification for user when they join guild, and same for other users in guild need to receive a new member notification.

29. [FIXED] Initial announcment for new guilds etc...or force guild owners to make a initial announcment when creating

30. [FIXED] Need to add a icon set next to provider name in symbol list/watchlist saying things like "Trending", "Hot", "New Markers" etc... so users can see a brief view of interesting symbols, could tie this into notifciations for users on watchlist symbols of activity like "High Activity" etc...

31. For production market ingestion, will need to seed possibly 2-3 years of symbols beforehand so user when viewing monthly have initial data

32. Full audit of x axis timing labels and vertical lines for grid, need to make sure they are consistent with timeframe, are of good pattern so for 1 min should be every 5 mins or 10 mins we display a time, and this needs to take into account zoom amount, it needs to adapt. Also where relevant display the current date or day so users know what day they are looking at etc... and this needs to be done to every timeframe we offer. Sometimes when panning in a specific zoom the times jump around a bit and appear quite sharply on left

33. Regarding symbol data in top left of chart it should be - symbol name   timeframe   open/closed icon
                                                              Provider name
                                                              current price with variation   

34. Change the bottom sheet symbol button - remove the open/closed icon and provider name, replace with symbol category like Forex or Commodity or Stock etc...

35. Have a brief look at the the black background showing behind the bottom sheet tab, it starts from the x axis and should go to bottom of screen but stops towards the bottom of the bottom sheet tab, so there is a small section at very bottom that has no black and shows chart background behind, this black should extend to very bottom