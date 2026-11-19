# Strategy Specification — Version 0

## Strategy modes

### Swing
- Context timeframe: H4.
- Setup timeframe: H1.
- Trigger timeframe: M15.
- Prototype filters: EMA trend alignment, RSI regime, ATR volatility, and confirmed swing structure.
- Entries require a closed-bar confirmation; no intrabar repainting signals.

### Long-term
- Context timeframe: D1 (weekly context may be added after validation).
- Setup timeframe: H4.
- Trigger timeframe: H1.
- Prototype objective: participate only after a confirmed structural recovery, not by blindly buying a falling market.
- Scale-ins are out of scope for the first version.

## Signal contract

Each candidate signal must include:
- strategy identifier;
- direction;
- proposed entry reference;
- protective stop price;
- rationale / filter results;
- signal timestamp and source timeframe;
- invalidation condition.

## Scoring

A future score may rank signal quality, but a score is not a win probability. No score can override risk checks. Elliott Wave and ICT/SMC concepts will be introduced only when their rules can be defined objectively and tested without hindsight.

## Version 0 behavior

Signal-only. No orders are sent. A signal must be logged with a clear rejection reason when any required condition is missing.
