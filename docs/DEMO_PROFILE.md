# Demo Account Profile — Exness

Status: planning profile only. This file does not enable trading.

## Confirmed test environment
- Broker: Exness
- Platform: MetaTrader 5
- Account type: Demo
- Starting balance supplied by the user: USD 500
- Intended instrument: Gold (XAUUSD; exact broker symbol suffix must be read from MT5)
- Runtime constraint: the Android MT5 app cannot run Expert Advisors. Compilation and EA execution require desktop MT5/MetaEditor on Windows or a compatible Windows VPS.

## Risk policy for the prototype
- Initial development and signal validation: no orders; signal-only mode.
- Initial risk target for later demo execution: 0.5%–1.0% of equity per trade.
- Requested 3.0% risk is a hard configurable ceiling for a later test phase, not the starting default and not an automatic increase after a short winning streak.
- On USD 500 equity, 0.5% = USD 2.50, 1.0% = USD 5.00, and 3.0% = USD 15.00 planned cash risk before commissions, slippage, gaps, and execution effects.
- Every order must have a broker-valid stop loss. Position size must be calculated from stop distance, tick size, tick value, contract size, volume step, and account currency.
- Reject a trade if the broker's minimum volume would exceed the cash-risk budget.
- No martingale, grid recovery, or averaging down.
- Trading remains disabled by default until code review, Strategy Tester validation, and demo forward testing are complete.

## Broker data still required
Before sizing or execution is implemented, read these properties from the exact Exness demo symbol in MT5: symbol name, digits, tick size, tick value, contract size, minimum/maximum volume, volume step, stops level, freeze level, and current spread. Do not assume all Exness account types or symbol suffixes share identical specifications.

## Acceptance gates before considering 3%
1. Signal logic and risk calculations reviewed.
2. Backtests include realistic spread, commission, swaps where applicable, and slippage assumptions.
3. Out-of-sample results reviewed; drawdown and losing streaks are documented.
4. Demo forward test completed with no critical execution or protection defects.
5. 3% remains an optional maximum setting; it is not a promise of profitability.

## Important
A USD 500 demo balance is a test parameter, not evidence that the strategy is profitable or suitable for a live account. No live trading is authorized by this profile.
