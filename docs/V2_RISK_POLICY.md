# A-Trade Bot V2 — Central Risk Policy

## Research profile
- Reference demo equity: USD 500. This is a test assumption only; the EA reads live demo equity.
- Default per-trade risk budget: 1.0% of equity.
- Configurable hard per-trade ceiling: 2.0% maximum.
- Combined open stop-risk ceiling: 3.0% of equity.
- Daily equity-loss pause: 4.0%.
- Weekly equity-loss pause: 6.0%.
- Peak-to-current-equity pause: 8.0%.
- Emergency new-signal halt: 10.0%.

At USD 500, the default 1% budget is approximately USD 5 and the configured 2% ceiling is USD 10. Actual cash risk depends on current equity and the broker's symbol contract specifications.

## Minimum-volume rule
The engine uses OrderCalcProfit to estimate loss at the planned stop and rounds volume down to the broker volume step. If the broker minimum volume would exceed the budget, the candidate is rejected. It must never round up to minimum volume, increase risk to force a trade, or change the strategy stop merely to fit a lot size.

## Portfolio rule
Before reporting a candidate as eligible, V2 sums stop-risk for existing positions with its magic number. A position without a stop-loss, or whose risk cannot be calculated, blocks new candidates. The candidate is rejected if existing stop-risk plus candidate stop-risk would exceed the configured portfolio ceiling.

This is a first safety layer only. The present signal-only prototype does not place orders and therefore does not yet implement pending-order risk reservations, execution-time price rechecks, or trade-server confirmation.

## Loss controls
Daily and weekly baselines are stored as terminal global variables, and peak equity is tracked by account + magic number. These controls pause new signal processing; they do not close existing positions. Restart, terminal-global-variable cleanup, broker server-time boundaries, deposits/withdrawals, and manual trading need dedicated tests before execution is enabled.

## Important limitations
- Spread filter is disabled when InpMaxSpreadPoints is zero. Calibrate separate thresholds for gold and each FX symbol before execution.
- Commission, swap, slippage, gaps, and execution-price changes can increase realized loss beyond the estimate.
- Risk estimates are not guarantees.
- No martingale, grid, averaging down, or loss-recovery sizing is included.
- Execution is not implemented in this version. The InpExecutionEnabled input is informational only and cannot turn trading on.

## Validation requirements
1. Confirm exact broker symbols and contract specifications in Exness demo MT5.
2. Compare OrderCalcProfit results with manual examples for both buy and sell on every symbol.
3. Test min volume, volume step, stop level, freeze level, and unusual tick-value conditions.
4. Test aggregate open risk, missing SL, multiple positions, and restart/reset behavior.
5. Compile and backtest in desktop MetaEditor/MT5. Do not infer compile success from source creation.
