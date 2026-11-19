# Gold Hunter EA — Risk Calculator (Prototype)

## Current behavior

The EA includes an informational position-size estimate. It does not send, modify, or close trades and does not place a stop-loss.

The estimate uses:
- Current account equity (not the original deposit).
- The configured risk percentage (default: 0.5%).
- A hypothetical stop distance in broker points (default: 1000 points; configurable).
- The broker's XAUUSD point, tick size, loss tick value, and volume min/max/step.

The volume is rounded down to the broker's volume step. If the minimum permitted volume would exceed the risk budget, the calculator returns no suggested volume rather than rounding up.

## Safety limits

- Default risk budget: 0.5% of equity.
- Configurable maximum: 1.0%; the current code rejects values above 1.0%.
- The stop distance is only a calculation assumption. It is not an actual stop-loss order.
- Spread, slippage, commissions, swaps, gaps, and execution differences can make real losses larger than the estimate.
- Tick-value fields and contract specifications must be verified on the user's Exness demo symbol before relying on any estimate.

## Inputs

- `InpRiskPercent`: selected equity risk percentage (default 0.5).
- `InpMaxRiskPercent`: hard ceiling (default 1.0; code also rejects a ceiling above 1.0).
- `InpStopDistancePoints`: hypothetical stop distance in broker points (default 1000).

## Required validation before any live use

1. Compile in MetaEditor and resolve all compiler warnings/errors.
2. Confirm the exact broker symbol is `XAUUSD`.
3. Compare the EA's logged point, tick size, tick value, volume minimum, maximum, and step with the Exness contract specification.
4. Independently calculate several sample positions and compare the results.
5. Backtest and demo-forward-test with realistic spread, commission, slippage, and stop behavior.
6. Design and test actual entry, stop-loss, take-profit, and exit rules separately.

**Status:** research prototype only. Not compiled or backtested in this development session. Do not use it to make live trading decisions.
