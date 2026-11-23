# A-Trade Bot V2 — Merge Architecture

## Status
Design baseline only. This document does not enable or execute trades. The original A-Trade V1 source and Gold Hunter v0.31 source remain unchanged. V2 is developed on the dedicated branch `feature/a-trade-goldhunter-v2`.

## Inputs confirmed for the research profile
- Broker/account: Exness Standard demo.
- Test equity reference: USD 500 (a test assumption, not a deposit instruction).
- Instruments: XAUUSD, EURUSD, GBPUSD.
- Signal timeframe: M15.
- Gold trend confirmation: H1.
- Default risk budget: 1.0% of current equity per trade.
- Absolute per-trade ceiling: 2.0% of current equity.
- Broker minimum volume must be read from the live symbol specification; never assume it is always 0.01 for every instrument/account.
- If the minimum legal volume exceeds the cash-risk budget, reject the trade. Never round volume up or tighten/loosen the strategy stop merely to force an entry.

## What is retained from each prototype

### A-Trade V1
Retain as the initial multi-symbol and execution reference:
- Timer-driven scanning of multiple symbols from one EA.
- M15 EMA 20/50 crossover with RSI confirmation.
- ATR-based stop-distance planning and reward/risk target calculation.
- OrderCalcProfit-based position sizing and volume-step rounding down.
- Per-symbol duplicate-position prevention and magic-number filtering.
- Daily, weekly, and peak-equity drawdown guard concepts.
- Explicit rejection when the minimum lot breaches the risk budget.

Do not copy blindly:
- The weekly bucket uses day-of-year divided by seven, not ISO calendar weeks.
- Daily/weekly baselines are terminal global variables and need reset/restart semantics reviewed.
- The current risk guard counts positions but does not calculate aggregate open stop-risk across all symbols.
- The spread filter is disabled when its input is zero; production defaults need symbol-specific calibration.
- Trade return values are logged, but acceptance/rejection handling needs stronger retcode validation.
- The current V1 entry rule is a crossover trigger; it is not evidence of a profitable edge.

### Gold Hunter v0.31
Retain as the XAUUSD research signal module:
- M15 closed-candle evaluation.
- H1 EMA 20/50 trend alignment.
- M15 EMA 20/50 direction, RSI 14 band filter, and closed-candle direction confirmation.
- ATR(14) stop-distance model and 2R target planning.
- Broker tick-size, tick-value, and volume-min/max-step awareness.

Do not copy blindly:
- The existing 3% risk default and 3% hard ceiling are rejected for V2.
- Its current volume calculator is informational only and does not place orders.
- Its planned SL/TP are reference prices, not broker-side protective orders.
- Spread is report-only when the threshold is zero.

## Proposed V2 architecture
1. **Market data layer** — validates exact broker symbol names, quotes, M15/H1 history, point, tick size/value, volume min/max/step, stop level, and spread.
2. **Strategy router** — XAUUSD uses the Gold Hunter M15+H1 candidate logic; EURUSD and GBPUSD use the A-Trade M15 crossover/RSI logic. Each symbol has one assigned strategy by default; no duplicate strategy entries on the same symbol.
3. **Central risk manager** — calculates planned loss with OrderCalcProfit for the actual entry/SL/volume; rounds volume down; includes current open risk and pending orders; rejects trades that exceed per-trade or portfolio limits.
4. **Execution layer** — disabled by default until compilation, independent sizing checks, and strategy tests pass. Every entry must include a broker-side SL and TP where supported; verify the server retcode and resulting position.
5. **Protection layer** — daily/weekly loss pauses, peak-to-valley drawdown pause, emergency halt, spread/slippage checks, and clear reset rules. No martingale, grid, averaging down, or recovery sizing.
6. **Audit logger** — records every candidate, rejection reason, estimated cash risk, symbol properties, order result, and protection event.

## Provisional portfolio guardrails for testing
- Per-trade default: 1.0%; hard ceiling: 2.0%.
- Combined open stop-risk ceiling: 3.0% of equity across all V2 positions.
- Daily loss pause: 4.0%; weekly loss pause: 6.0%.
- Peak-equity drawdown pause: 8.0%; emergency new-entry halt: 10.0%.
- These are provisional test controls, not claims of safety or profitability. They must be stress-tested and may be tightened after observing actual broker execution costs.

## Required implementation and validation gates
1. Implement V2 modules while preserving the signal-only / execution-disabled default.
2. Static review for symbol-specific pip/point assumptions, volume rounding, risk aggregation, order retcodes, and restart/reset behavior.
3. Compile in desktop MetaEditor and resolve all errors; record warnings.
4. Verify XAUUSD, EURUSD, GBPUSD contract specifications from the user's Exness demo terminal.
5. Compare position-size calculations against independent OrderCalcProfit samples for buy and sell, multiple stop distances, and minimum volume.
6. Backtest each symbol/strategy separately and as a portfolio with realistic spread, commission, swap, slippage, and out-of-sample periods.
7. Only after review, enable demo execution on a separate demo-only test profile and forward-test for 8–12 weeks.
8. No live use is part of this work.

## Known environment limitation
The user currently works from Android. MT5 mobile can monitor an account but cannot compile or host MQL5 Expert Advisors. Compilation and EA runtime require desktop MT5/MetaEditor or a compatible VPS.
