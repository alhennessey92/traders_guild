this log eventually went correctly to the marker but the chart went weird looking as it was loaded - 📍 MarkerNavigationObserver: Detected pending navigation to DOGE/USD
📍 MarkerNavigationObserver: Starting navigation after drawer close delay
🎯 === MARKER NAVIGATION START ===
🎯 Target: DOGE/USD | Timeframe: 1m | Timestamp: 2026-05-01 17:33:00 +0000
🎯 Chart width: 393.0
🎯 Current: ATOM/USD | 5m
🎯 Needs symbol change: true
🎯 Needs timeframe change: true
🔍 Looking for symbol: DOGE/USD
🔍 Found in globalSymbols
✅ Found symbol: DOGE/USD - calling setSymbol
📡 [WS] Unsubscribed: ["market:ticks:49675dc8-4ede-4ffa-9117-e985b3d8c638", "market:candles:49675dc8-4ede-4ffa-9117-e985b3d8c638:5m"] owner=chart
📡 [Chart] Unsubscribed from market data
📡 [WS] Subscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m"] owner=chart
📡 [Chart] Subscribed to market data: market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c, market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m
✅ Setting timeframe to: 1m
📡 [WS] Unsubscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m"] owner=chart
📡 [Chart] Unsubscribed from market data
📡 [WS] Subscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:1m"] owner=chart
📡 [Chart] Subscribed to market data: market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c, market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:1m
🎯 Waiting for target timeframe data to arrive...
🎯 Waiting for candle count to stabilize...
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-data?timeframe=1m&candle_limit=500&continuous_time=true
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-data?timeframe=1m&candle_limit=500&continuous_time=true
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
🌐 [chart] POST /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-chat
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-04-30T08:20:00.000Z&end_time=2026-05-01T17:35:00.000Z
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-04-30T08:20:00.000Z&end_time=2026-05-01T17:35:00.000Z
🎯 After wait - finding candle for timestamp 2026-05-01 17:33:00 +0000
🎯 Current symbol after wait: DOGE/USD
🎯 Current timeframe after wait: 1m
🎯 Candle count: 400
🎯 Current panOffset after: -6195.5
🎯 === MARKER NAVIGATION COMPLETE ===
📥 Status: 200
📥 Response: {"id":"202e622f-284c-42ac-b591-46e8e285d1d1","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","symbol_ticker":"DOGE/USD","guild_name":"Beta 1","last_message":null,"last_activity":"2026-04-28T19:55:46.836946Z","last_activity_formatted":"2d ago","unread_count":0,"active_user_count":1,"is_muted":false,"is_pinned":false,"can_send_messages":true}
📡 [WS] Subscribed: ["chart_chat:202e622f-284c-42ac-b591-46e8e285d1d1"] owner=chart_chat
🌐 [chart] GET /chart/chart-chats/202E622F-284C-42AC-B591-46E8E285D1D1/messages?limit=50
📥 Status: 200
📥 Response: {"symbol":{"id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","ticker":"DOGE/USD","display_name":"Dogecoin / US Dollar","asset_class":"crypto","exchange":"CRYPTO","tick_size":0.0001,"lot_size":1.0,"decimal_places":5,"is_active":true,"icon_name":null,"icon_url":null,"primary_color":"#3B82F6","secondary_color":"#6B7280","current_price":0.1087,"price_formatted":"0.10870","change_24h":0.003,"change_percent_24h":2.8382,"change_formatted":"+0.00 (+2.84%)","is_up":true,"high_24h":0.1106,"low_24h":0.1054,"volume_24h":1126687608.0,"volume_formatted":"1.1B","in_personal_watchlist":null,"in_guild_watchlist":null,"is_requested_for_guild":null,"active_market_provider":"binance","is_supported_by_active_provider":true,"is_market_open":true,"market_status_updated_at":"2026-05-01T17:34:00Z","activity_badges":["Hot"]},"timeframe":"1m","candles":[{"timestamp":"2026-05-01T09:16:00Z","timestamp_formatted":"2026-05-01 09:16","open":0.1083,"high":0.1083,"low":0.1079,"close":0.108,"volume":4006493.0,"volume_formatte
📥 Status: 200
📥 Status: 200
📥 Response: {"messages":[],"has_more":false,"next_cursor":null}
📥 Response: {"symbol":{"id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","ticker":"DOGE/USD","display_name":"Dogecoin / US Dollar","asset_class":"crypto","exchange":"CRYPTO","tick_size":0.0001,"lot_size":1.0,"decimal_places":5,"is_active":true,"icon_name":null,"icon_url":null,"primary_color":"#3B82F6","secondary_color":"#6B7280","current_price":0.1087,"price_formatted":"0.10870","change_24h":0.003,"change_percent_24h":2.8382,"change_formatted":"+0.00 (+2.84%)","is_up":true,"high_24h":0.1106,"low_24h":0.1054,"volume_24h":1126687608.0,"volume_formatted":"1.1B","in_personal_watchlist":null,"in_guild_watchlist":null,"is_requested_for_guild":null,"active_market_provider":"binance","is_supported_by_active_provider":true,"is_market_open":true,"market_status_updated_at":"2026-05-01T17:34:00Z","activity_badges":["Hot"]},"timeframe":"1m","candles":[{"timestamp":"2026-05-01T09:16:00Z","timestamp_formatted":"2026-05-01 09:16","open":0.1083,"high":0.1083,"low":0.1079,"close":0.108,"volume":4006493.0,"volume_formatte
🌐 [chart] POST /chart/chart-chats/202E622F-284C-42AC-B591-46E8E285D1D1/mark-read
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📥 Status: 204
📥 Response: 
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-05-01T09:16:00.000Z&end_time=2026-05-01T17:35:00.000Z
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-05-01T09:16:00.000Z&end_time=2026-05-01T17:35:00.000Z
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers



this one went to a area on chart and marker view mode but no marker on chart, was the oldest marker shown so not sure what happened - 📍 MarkerNavigationObserver: Detected pending navigation to DOGE/USD
📍 MarkerNavigationObserver: Starting navigation after drawer close delay
🎯 === MARKER NAVIGATION START ===
🎯 Target: DOGE/USD | Timeframe: 1m | Timestamp: 2026-05-01 02:58:00 +0000
🎯 Chart width: 393.0
🎯 Current: BTC/USD | 5m
🎯 Needs symbol change: true
🎯 Needs timeframe change: true
🔍 Looking for symbol: DOGE/USD
🔍 Found in globalSymbols
✅ Found symbol: DOGE/USD - calling setSymbol
📡 [WS] Unsubscribed: ["market:ticks:d457e2b6-9fd7-48d5-827f-5d6243214050", "market:candles:d457e2b6-9fd7-48d5-827f-5d6243214050:5m"] owner=chart
📡 [Chart] Unsubscribed from market data
📡 [WS] Subscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m"] owner=chart
📡 [Chart] Subscribed to market data: market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c, market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m
✅ Setting timeframe to: 1m
📡 [WS] Unsubscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:5m"] owner=chart
📡 [Chart] Unsubscribed from market data
📡 [WS] Subscribed: ["market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c", "market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:1m"] owner=chart
📡 [Chart] Subscribed to market data: market:ticks:1ecc1c73-5e5a-4e86-8910-60db4530065c, market:candles:1ecc1c73-5e5a-4e86-8910-60db4530065c:1m
🎯 Waiting for target timeframe data to arrive...
🎯 Waiting for candle count to stabilize...
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-data?timeframe=1m&candle_limit=500&continuous_time=true
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-data?timeframe=1m&candle_limit=500&continuous_time=true
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
🌐 [chart] POST /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/chart-chat
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-04-30T08:20:00.000Z&end_time=2026-05-01T17:35:00.000Z
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-04-30T08:20:00.000Z&end_time=2026-05-01T17:35:00.000Z
📥 Status: 200
📥 Response: {"id":"202e622f-284c-42ac-b591-46e8e285d1d1","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","symbol_ticker":"DOGE/USD","guild_name":"Beta 1","last_message":null,"last_activity":"2026-04-28T19:55:46.836946Z","last_activity_formatted":"2d ago","unread_count":0,"active_user_count":1,"is_muted":false,"is_pinned":false,"can_send_messages":true}
🌐 [chart] GET /chart/chart-chats/202E622F-284C-42AC-B591-46E8E285D1D1/messages?limit=50
🎯 After wait - finding candle for timestamp 2026-05-01 02:58:00 +0000
🎯 Current symbol after wait: DOGE/USD
🎯 Current timeframe after wait: 1m
🎯 Candle count: 403
🎯 Current panOffset after: -3395.5
🎯 === MARKER NAVIGATION COMPLETE ===
📥 Status: 200
📥 Response: {"symbol":{"id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","ticker":"DOGE/USD","display_name":"Dogecoin / US Dollar","asset_class":"crypto","exchange":"CRYPTO","tick_size":0.0001,"lot_size":1.0,"decimal_places":5,"is_active":true,"icon_name":null,"icon_url":null,"primary_color":"#3B82F6","secondary_color":"#6B7280","current_price":0.109,"price_formatted":"0.10900","change_24h":0.0033,"change_percent_24h":3.122,"change_formatted":"+0.00 (+3.12%)","is_up":true,"high_24h":0.1106,"low_24h":0.1054,"volume_24h":1126839811.0,"volume_formatted":"1.1B","in_personal_watchlist":null,"in_guild_watchlist":null,"is_requested_for_guild":null,"active_market_provider":"binance","is_supported_by_active_provider":true,"is_market_open":true,"market_status_updated_at":"2026-05-01T17:37:00Z","activity_badges":["Hot"]},"timeframe":"1m","candles":[{"timestamp":"2026-05-01T09:19:00Z","timestamp_formatted":"2026-05-01 09:19","open":0.108,"high":0.108,"low":0.108,"close":0.108,"volume":246631.0,"volume_formatted":"2
📥 Status: 200
📥 Response: {"messages":[],"has_more":false,"next_cursor":null}
🌐 [chart] POST /chart/chart-chats/202E622F-284C-42AC-B591-46E8E285D1D1/mark-read
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-05-01T09:19:00.000Z&end_time=2026-05-01T17:38:00.000Z
🌐 [chart] GET /chart/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/candles?timeframe=1m&limit=1000&end_time=2026-05-01T09:19:00.000Z&continuous_time=true
📥 Status: 200
📥 Response: {"symbol":{"id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","ticker":"DOGE/USD","display_name":"Dogecoin / US Dollar","asset_class":"crypto","exchange":"CRYPTO","tick_size":0.0001,"lot_size":1.0,"decimal_places":5,"is_active":true,"icon_name":null,"icon_url":null,"primary_color":"#3B82F6","secondary_color":"#6B7280","current_price":0.109,"price_formatted":"0.10900","change_24h":0.0033,"change_percent_24h":3.122,"change_formatted":"+0.00 (+3.12%)","is_up":true,"high_24h":0.1106,"low_24h":0.1054,"volume_24h":1126839811.0,"volume_formatted":"1.1B","in_personal_watchlist":null,"in_guild_watchlist":null,"is_requested_for_guild":null,"active_market_provider":"binance","is_supported_by_active_provider":true,"is_market_open":true,"market_status_updated_at":"2026-05-01T17:37:00Z","activity_badges":["Hot"]},"timeframe":"1m","candles":[{"timestamp":"2026-05-01T09:19:00Z","timestamp_formatted":"2026-05-01 09:19","open":0.108,"high":0.108,"low":0.108,"close":0.108,"volume":246631.0,"volume_formatted":"2
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-05-01T09:19:00.000Z&end_time=2026-05-01T17:38:00.000Z
📥 Status: 204
📥 Response: 
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📥 Status: 200
📥 Response: {"candles":[{"timestamp":"2026-05-01T00:59:00Z","timestamp_formatted":"2026-05-01 00:59","open":0.1074,"high":0.1076,"low":0.1074,"close":0.1076,"volume":4060822.0,"volume_formatted":"4.1M","is_gap_fill":false},{"timestamp":"2026-05-01T01:00:00Z","timestamp_formatted":"2026-05-01 01:00","open":0.1076,"high":0.1077,"low":0.1075,"close":0.1077,"volume":1785649.0,"volume_formatted":"1.8M","is_gap_fill":false},{"timestamp":"2026-05-01T01:01:00Z","timestamp_formatted":"2026-05-01 01:01","open":0.1077,"high":0.1078,"low":0.1077,"close":0.1078,"volume":891951.0,"volume_formatted":"892.0K","is_gap_fill":false},{"timestamp":"2026-05-01T01:02:00Z","timestamp_formatted":"2026-05-01 01:02","open":0.1078,"high":0.1078,"low":0.1078,"close":0.1078,"volume":488621.0,"volume_formatted":"488.6K","is_gap_fill":false},{"timestamp":"2026-05-01T01:03:00Z","timestamp_formatted":"2026-05-01 01:03","open":0.1078,"high":0.1079,"low":0.1078,"close":0.1079,"volume":642586.0,"volume_formatted":"642.6K","is_gap_fil
📥 Status: 200
📥 Response: {"markers":[{"id":"50d81969-356f-488f-9b78-7e1a48977f0d","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"d2075664-ae35-46c6-b22c-74a4b1e3cd00","role":"member","reputation":393,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:38.005974Z","muted_until":null,"suspended_until":null,"user_id":"118267ac-6f0b-4bda-be85-3413ca47d1f5","username":"ava_kline","display_name":"Ava Kline","avatar_url":null,"is_online":false,"global_reputation":412,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T17:33:00Z","timeframe":"1m","price":0.1087,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10870. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T17:34:01.040323Z","created
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
🌐 [chart] GET /chart/guilds/7190B2F8-CB9A-4665-97CF-46E938CEE8E9/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/markers?timeframe=1m&limit=100&start_time=2026-05-01T00:59:00.000Z&end_time=2026-05-01T09:19:00.000Z
📥 Status: 200
📥 Response: {"markers":[{"id":"fb1d14cf-dc94-4597-bf49-c69be785b347","symbol_id":"1ecc1c73-5e5a-4e86-8910-60db4530065c","guild_id":"7190b2f8-cb9a-4665-97cf-46e938cee8e9","author":{"membership_id":"f47089be-307f-4543-baf4-41cf072bde8b","role":"member","reputation":583,"accuracy_rate":0.0,"contribution_score":0,"date_joined":"2026-04-26T08:45:37.979679Z","muted_until":null,"suspended_until":null,"user_id":"3158f06d-3b6f-4bb1-80ec-f30b43761e54","username":"maya_cho","display_name":"Maya Cho","avatar_url":null,"is_online":false,"global_reputation":613,"is_friend":false,"friendship_status":null,"is_blocked":false,"is_blocked_by":false},"candle_timestamp":"2026-05-01T02:58:00Z","timeframe":"1m","price":0.1086,"intent":"analysis","title":"DOGE/USD 1m context","note":"DOGE/USD is holding above the prior 1m close around 0.10860. Watching whether the next rotation confirms the level or fades back into the prior range.","visibility":"guild","confidence":4,"created_at":"2026-05-01T02:59:00.978024Z","created_a
📡 [WS] Unsubscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
📡 [WS] Subscribed: ["guild:7190b2f8-cb9a-4665-97cf-46e938cee8e9:markers"] owner=markers
🌐 [chart] GET /chart/symbols/1ECC1C73-5E5A-4E86-8910-60DB4530065C/candles?timeframe=1m&limit=1000&end_time=2026-05-01T00:59:00.000Z&continuous_time=true
📥 Status: 200
📥 Response: {"candles":[{"timestamp":"2026-05-01T00:59:00Z","timestamp_formatted":"2026-05-01 00:59","open":0.1074,"high":0.1074,"low":0.1074,"close":0.1074,"volume":0.0,"volume_formatted":"0","is_gap_fill":true},{"timestamp":"2026-05-01T01:00:00Z","timestamp_formatted":"2026-05-01 01:00","open":0.1074,"high":0.1074,"low":0.1074,"close":0.1074,"volume":0.0,"volume_formatted":"0","is_gap_fill":true},{"timestamp":"2026-05-01T01:01:00Z","timestamp_formatted":"2026-05-01 01:01","open":0.1074,"high":0.1074,"low":0.1074,"close":0.1074,"volume":0.0,"volume_formatted":"0","is_gap_fill":true},{"timestamp":"2026-05-01T01:02:00Z","timestamp_formatted":"2026-05-01 01:02","open":0.1074,"high":0.1074,"low":0.1074,"close":0.1074,"volume":0.0,"volume_formatted":"0","is_gap_fill":true},{"timestamp":"2026-05-01T01:03:00Z","timestamp_formatted":"2026-05-01 01:03","open":0.1074,"high":0.1074,"low":0.1074,"close":0.1074,"volume":0.0,"volume_formatted":"0","is_gap_fill":true},{"timestamp":"2026-05-01T01:04:00Z","timest