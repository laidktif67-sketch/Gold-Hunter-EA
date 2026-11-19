# Gold Hunter EA — Demo Test Plan

## Current build

- EA version: 0.31
- Instrument: Exness demo gold symbol confirmed by the user as `XAUUSD`
- Signal timeframe: M15
- Trend confirmation timeframe: H1
- Indicators: EMA 20/50, RSI 14, ATR 14
- Risk budget configured: 3% of equity (informational estimate only)
- Planned stop: ATR × 1.5
- Planned target: 2R
- Execution: DISABLED — this build does not send, modify, or close orders.

## Important limitation

This is a signal-and-risk-planning prototype, not an automated trading system. The displayed stop-loss and take-profit are calculated reference prices only. They are not broker-side orders. A 3% risk budget on a $500 demo balance is approximately $15 before costs and calculation differences; 3% is an aggressive setting and is not a guarantee or a safe-risk recommendation.

## Test environment

A Windows computer or Windows VPS with MetaTrader 5 Desktop and MetaEditor is required to compile and run an MQL5 Expert Advisor. MetaTrader 5 on Android can monitor the account, but it cannot compile or host this EA.

1. Use only the Exness demo account.
2. In MT5 Market Watch, confirm the broker's exact gold symbol. This build expects a symbol containing `XAUUSD`; a suffix such as `XAUUSDm` may pass the name check if that is the broker's actual symbol.
3. Open MetaEditor, compile `GoldHunterEA.mq5`, and record the compiler result. Do not assume it compiles until this step is completed.
4. Attach the EA to an XAUUSD M15 chart. Keep automated trading disabled; this build has no order execution code in any case.
5. Confirm the Experts log reports version 0.31, the intended symbol, M15/H1 timeframes, and signal-only mode.

## Observation procedure

- Observe at least 30 completed M15 bars before drawing conclusions; preferably collect 2–4 weeks of varied market conditions.
- Record each BUY CANDIDATE, SELL CANDIDATE, NO SIGNAL, spread rejection, and risk-calculation warning.
- For each candidate, record timestamp, spread, RSI, ATR, planned SL/TP, suggested volume, risk budget, and estimated loss from the Experts log.
- Verify manually that BUY candidates have bullish EMA alignment on M15 and H1, a bullish last-closed M15 candle, and RSI inside 48–68.
- Verify manually that SELL candidates have bearish EMA alignment on M15 and H1, a bearish last-closed M15 candle, and RSI inside 32–52.
- Check that the suggested volume is zero/not suggested when the broker minimum lot would exceed the selected risk budget.
- Compare the printed point, tick size/value, volume minimum/maximum/step, and spread with the symbol specification shown by the broker.

## Pass/fail checklist

- [ ] MetaEditor compilation completes with 0 errors; record warnings separately.
- [ ] EA initializes on the exact broker gold symbol.
- [ ] A new evaluation occurs only once per new M15 bar.
- [ ] Indicator values are taken from the last closed candle, not the forming candle.
- [ ] Candidate direction and RSI range match the rules above.
- [ ] Planned SL and TP are on the correct side of the reference close for BUY and SELL.
- [ ] Estimated loss does not exceed the calculated risk budget, allowing for broker costs and model limitations.
- [ ] No order is opened, modified, or closed; execution remains disabled.
- [ ] No repeated initialization, invalid-handle, missing-history, or calculation errors appear in the Experts log.

## Results log template

| Date/time | Symbol | Signal | Spread (points) | RSI | ATR | Planned SL | Planned TP | Volume estimate | Risk budget | Notes |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| | | | | | | | | | | |

## Before any future execution feature

Do not add order placement until compilation is confirmed, the signal log has been reviewed, position sizing has been independently checked against broker-calculated loss (for example with `OrderCalcProfit`), and a separate demo-only execution test plan has been approved. Never treat a successful compile or a few signals as evidence of profitability.
