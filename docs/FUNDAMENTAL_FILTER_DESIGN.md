# Gold Hunter EA — Fundamental Filter Design (v0.40 proposal)

## Status and safety boundary

This is a design document only. The current EA remains v0.31 and signal-only. No news provider is connected, no live calendar is read, and no trading execution is enabled. Do not describe this design as implemented or tested.

The purpose of a future fundamental layer is to add context to the existing M15/H1 technical candidates for XAUUSD. It must not turn a headline into an automatic buy or sell instruction.

## 1. Data-source decision

Preferred first route to investigate: the native MT5 Economic Calendar API in MQL5. Official documentation lists CalendarValueHistory, CalendarValueById, CalendarEventByCurrency and related functions. The calendar uses trade-server time, not the user's local time. Actual, forecast, previous and revised-previous values are available through MqlCalendarValue when populated.

Before implementation, verify calendar coverage and runtime availability in the exact Exness MT5 desktop environment, including event coverage, USD filters, importance values, timestamps, actual/forecast/previous fields, historical availability and Strategy Tester behaviour.

Alternative: an external calendar provider, but only after verifying its documented API, permission for automated access, stability, timestamps/timezone definitions, actual/forecast/previous values, revision handling and freshness policy. Any WebRequest domain must be explicitly allow-listed in desktop MT5. Do not hard-code an arbitrary URL or scrape an unverified website.

No external provider is selected by this document.

## 2. Events to monitor

Prioritise USD events likely to move gold:

- Tier 1: FOMC rate decision and statement, Fed press conference, US CPI and Core CPI, US Employment Situation / Nonfarm Payrolls, core PCE inflation.
- Tier 2: PCE, GDP, ISM Manufacturing/Services, retail sales, jobless claims and major Fed speeches.
- Other events should be configurable and must not silently be treated as high impact.

The event list and importance mapping must be configurable. A calendar label alone is not a directional signal.

## 3. Directional interpretation (potential bias only)

For a future event-analysis module, compare Actual with Forecast and Previous, and retain any revised Previous value. Evaluate the surprise relative to consensus and the broader macro context:

- Stronger-than-expected US data can support USD/yields and may pressure gold, all else equal.
- Weaker-than-expected data can weigh on USD/yields and may support gold, all else equal.
- Hotter inflation can increase expectations of tighter Fed policy; softer inflation can do the opposite.
- FOMC language, forward guidance, revisions, market positioning and the initial price/yield reaction can reverse or complicate these simple relationships.

Represent the result as potential_gold_bias = BULLISH | BEARISH | NEUTRAL | MIXED | UNKNOWN, with a confidence/quality flag and a short reason. This is contextual information, not a prediction or trade instruction. Never infer direction from the event name alone. If actual data is not yet published, do not fabricate an outcome.

## 4. News protection window

Provide configurable minutes before and after Tier 1 events. Initial proposal for demo evaluation only: block new candidates 30 minutes before and 30 minutes after a Tier 1 release; these values are not validated as optimal. Tier 2 windows should be separately configurable.

Use one canonical timestamp basis internally and convert calendar timestamps explicitly. Since the native MQL5 calendar uses trade-server time, document and test the broker server offset and daylight-saving transitions. Do not compare unlabelled local times.

A protection window should suppress new signal candidates; it must not close or modify positions. The current v0.31 does not manage positions.

## 5. Fail-safe and freshness

The fundamental layer must expose explicit states such as READY, HIGH_IMPACT_WINDOW, DATA_MISSING, DATA_STALE, SOURCE_ERROR and TIME_UNCERTAIN.

- Missing, stale, malformed or unavailable calendar data must never be interpreted as “no upcoming news”.
- Default fail-safe behaviour: block new candidates until valid data is restored.
- Any permissive fallback must be an explicit user setting with a prominent warning and logs; it must not be the default.
- Define and enforce a maximum data age; log provider timestamp and last successful update.
- Deduplicate events and handle cancellations, reschedules and revised values.

## 6. Candidate decision flow

1. Validate symbol and technical indicator data.
2. Validate calendar source status and data freshness.
3. If source state is not READY, block the new candidate and log the exact reason.
4. If within a configured protection window, block the new candidate.
5. Otherwise, allow the existing technical logic to emit a candidate and attach the fundamental bias as context.
6. A directional disagreement between technical signal and fundamental bias should be logged and may optionally require additional confirmation; it must not be silently overridden by a headline.

The fundamental module must not add OrderSend, CTrade, order placement, stop modification or position closing. Execution remains disabled.

## 7. Required tests before integration

- Tier 1 event inside the pre-event window and inside the post-event window.
- Event outside the protection window.
- Missing actual value before release; no fabricated bias.
- Actual above/below forecast, including a revised Previous value.
- Mixed or contradictory macro signals produce MIXED or UNKNOWN.
- Stale provider response, network timeout, malformed payload and source outage all fail safely.
- Duplicate, cancelled and rescheduled events.
- UTC conversion, broker server offset and daylight-saving transition boundaries.
- Strategy Tester behaviour when calendar data is unavailable or non-deterministic.

## 8. Acceptance criteria

Do not integrate into the EA until the provider and runtime are verified, test cases pass, logs make every block reason visible, and the module has been reviewed on historical/demo data. Keep v0.31 as the unchanged technical baseline for comparison. Any later version must be compiled in MetaEditor and tested in Strategy Tester and on the Exness demo before being described as operational.

## 9. Current implementation status

| Capability | Status |
|---|---|
| M15/H1 technical candidate logic | Present in v0.31 |
| ATR-based informational risk estimate | Present in v0.31; not an actual stop order |
| Fundamental event calendar | Not implemented |
| Actual/forecast/previous analysis | Not implemented |
| News protection window | Not implemented |
| Automated order execution | Disabled / absent |
| Compile, backtest, Exness demo validation | Not yet performed |


## 10. Important MT5 API constraints verified against official documentation

The native calendar is the preferred candidate, but it has two constraints that affect architecture:

- Calendar functions use trade-server time (TimeTradeServer), including the broker's timezone/DST convention. Do not convert the returned event timestamps as if they were UTC or the phone's local time.
- MQL5 calendar functions are not available in Strategy Tester and return FUNCTION_NOT_ALLOWED (4014) there. Therefore a live-calendar EA cannot be backtested by calling the calendar API directly. For reproducible historical tests, first capture calendar records from an online terminal into a versioned local data file, then make a separate tester data-reader mode. Do not silently bypass the news filter in the tester.

Relevant official references:
- Economic calendar overview: https://www.mql5.com/en/docs/calendar
- CalendarValueHistory: https://www.mql5.com/en/docs/calendar/calendarvaluehistory
- MqlCalendarValue fields: https://www.mql5.com/en/docs/constants/structures/mqlcalendar
- Calendar testing limitations: https://www.mql5.com/en/book/advanced/calendar

## 11. Correct interpretation of calendar fields

Do not confuse event importance with directional impact. The event description (MqlCalendarEvent) contains the event importance classification. The value record (MqlCalendarValue) contains actual, forecast, previous, revised previous and impact_type. The impact_type field describes the potential impact on the currency rate; it is not a substitute for comparing the released number with consensus and does not directly provide a gold BUY/SELL signal.

MqlCalendarValue numeric fields are stored multiplied by 1,000,000. Prefer the structure's HasActualValue / GetActualValue, HasForecastValue / GetForecastValue, HasPreviousValue / GetPreviousValue and HasRevisedValue / GetRevisedValue methods instead of manually reading sentinel values or forgetting the scale. Missing values must remain UNKNOWN.

CalendarValueHistory returns -1 on failure; documented errors include calendar timeout (5401) and insufficient array capacity (5400). Handle these explicitly and fail safely. Do not treat an empty/failed response as proof that there are no upcoming USD events.

## 12. Revised implementation sequence

1. Build a small calendar diagnostic script for MT5 desktop (not an EA trading module). It should query a short future window for USD events, print event name, importance, server-time timestamp, actual/forecast/previous/revised values and error codes, and place no orders.
2. Run it on the user's Exness demo terminal and confirm the calendar is populated and timestamps match the terminal's trade-server clock.
3. Save a deterministic sample dataset for Strategy Tester use; calendar API calls themselves cannot run in the tester.
4. Implement the fail-closed news-window gate using the verified API and clear logs.
5. Add the directional-surprise classifier only after event IDs, units, sign conventions and missing-value behaviour have been validated per indicator.
6. Compile and test in MetaEditor, then run the demo diagnostic and EA in signal-only mode. Keep automated execution disabled.

A phone-only MT5 Android installation cannot compile or run MQL5 Expert Advisors. These diagnostic and compilation steps require MT5 desktop/MetaEditor on Windows or a suitable Windows VPS; the Android phone can monitor the account and view results but is not a substitute for MetaEditor.
