# Gold Hunter EA — Risk Calculator (Prototype)

## Current behavior

The EA includes an informational position-size estimate and ATR-based planned stop-loss/take-profit price calculations for signal candidates. These are log-only plans: the EA does not send, modify, or close trades and does not place protective orders.

The estimate uses:
- Current account equity (not the original deposit).
- The configured risk percentage (default: 3.0%).
- An ATR-based stop distance: ATR(14) on M15 multiplied by 1.5 by default.
- A planned take-profit distance equal to 2.0 times the stop distance by default.
- The broker's XAUUSD point, tick size, loss tick value, and volume min/max/step.

The volume is rounded down to the broker's volume step. If the minimum permitted volume would exceed the risk budget, the calculator returns no suggested volume rather than rounding up.

## Safety limits

- Default risk budget: 3.0% of equity.
- Hard maximum: 3.0%; the current code rejects any selected risk or ceiling above 3.0%.
- ATR stop and target prices are calculations for review only; they are not actual stop-loss or take-profit orders.
- Spread, slippage, commissions, swaps, gaps, and execution differences can make real losses larger than the estimate.
- Tick-value fields and contract specifications must be verified on the user's Exness demo symbol before relying on any estimate.

## Inputs

- `InpRiskPercent`: selected equity risk percentage (default 3.0; may not exceed 3.0).
- `InpMaxRiskPercent`: hard ceiling (default 3.0; code also rejects a ceiling above 3.0).
- `InpATRPeriod`: ATR period on M15 (default 14).
- `InpATRStopMultiplier`: stop distance multiplier (default 1.5).
- `InpRewardRiskRatio`: planned target-to-stop ratio (default 2.0).

## Active signal profile

- Signal timeframe: M15, checked once per newly opened M15 candle using closed-candle indicator values.
- Trend confirmation timeframe: H1.
- BUY RSI range: 48–68; SELL RSI range: 32–52. These wider bands are intended to surface more candidates, not guarantee profitable entries.
- ATR-based SL/TP prices and risk-based volume estimates are logged for candidate signals only.
- This is still signal-only: it does not open trades, place stop-losses, or manage positions.

## Required validation before any live use

1. Compile in MetaEditor and resolve all compiler warnings/errors.
2. Confirm the exact broker symbol is `XAUUSD`.
3. Compare the EA's logged point, tick size, tick value, volume minimum, maximum, and step with the Exness contract specification.
4. Independently calculate several sample positions and compare the results.
5. Backtest and demo-forward-test with realistic spread, commission, slippage, and stop behavior.
6. Design and test actual entry, stop-loss, take-profit, and exit rules separately.

**Status:** research prototype only. Not compiled or backtested in this development session. Do not use it to make live trading decisions.
