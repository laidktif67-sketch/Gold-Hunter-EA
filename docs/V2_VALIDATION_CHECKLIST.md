# A-Trade Bot V2 — Validation Checklist

## Source review
- [ ] Confirm exact broker symbol names (suffixes/prefixes included).
- [ ] Confirm M15 and H1 history loads for every configured symbol.
- [ ] Confirm indicator buffers are read from closed candles.
- [ ] Confirm Gold Hunter logic only routes to XAUUSD.
- [ ] Confirm FX crossover logic only routes to non-gold symbols.
- [ ] Confirm no duplicate signal route exists for a symbol.
- [ ] Confirm volume is rounded down and minimum-lot risk violations are rejected.
- [ ] Confirm all calculations use OrderCalcProfit for planned entry-to-stop loss.
- [ ] Confirm a missing SL on any existing EA position blocks new candidates.
- [ ] Confirm aggregate stop-risk cannot exceed the configured portfolio cap.
- [ ] Confirm daily/weekly/peak guard behavior and reset semantics.
- [ ] Confirm spread and slippage settings are appropriate per instrument.

## Build
- [ ] Compile with desktop MetaEditor; record exact build number.
- [ ] Resolve all compiler errors.
- [ ] Review every compiler warning.
- [ ] Do not mark the source as compiled until the actual compiler result is available.

## Risk calculator test matrix
- [ ] XAUUSD BUY and SELL at multiple stop distances.
- [ ] EURUSD BUY and SELL at multiple stop distances.
- [ ] GBPUSD BUY and SELL at multiple stop distances.
- [ ] Minimum lot just within risk budget.
- [ ] Minimum lot just above risk budget (must reject).
- [ ] Volume step rounding.
- [ ] Tick size/value and contract-size variations.
- [ ] Existing position with SL.
- [ ] Existing position without SL (must block).
- [ ] Multiple open positions near portfolio cap.

## Strategy testing
- [ ] Backtest XAUUSD Gold strategy separately.
- [ ] Backtest EURUSD crossover separately.
- [ ] Backtest GBPUSD crossover separately.
- [ ] Test combined portfolio and correlated exposure.
- [ ] Include variable spread, commission, swap, slippage, and realistic execution assumptions.
- [ ] Use in-sample and out-of-sample periods.
- [ ] Record trade count, expectancy, profit factor, max drawdown, average R, and consecutive losses.
- [ ] Do not optimize only for net profit or a single date range.

## Forward demo
- [ ] Only after code review and test gates pass, create a separate demo execution branch/build.
- [ ] Run a demo forward test for 8–12 weeks.
- [ ] Review all rejected signals and execution discrepancies.
- [ ] No live trading is authorized by this checklist.
