# Risk Policy — Initial Proposal

These are conservative **test parameters**, not a promise that the broker's minimum volume will permit them.

## Initial limits

- Target risk per trade: 0.50% of current equity.
- Daily equity-loss lock: 1.50% from the day's starting equity.
- Weekly equity-loss lock: 3.00% from the week's starting equity.
- Peak-to-valley equity drawdown lock: 8.00% from the recorded high-water mark.
- Maximum concurrent positions: 1 during the first prototype.
- Stop-loss: mandatory and placed with the entry; no unprotected position is allowed.
- Martingale, grid recovery, and loss-chasing: prohibited.

## Position sizing

Risk cash = current equity × risk percentage.

Estimate loss per 1.0 lot from the entry-to-stop distance using the symbol's tick size and tick value. Convert risk cash to volume, then round **down** to the broker volume step. Recalculate estimated loss after rounding.

If the resulting volume is below SYMBOL_VOLUME_MIN, or the minimum volume would exceed the cash-risk budget, reject the trade. Never widen the risk budget to force an order.

## Hard safeguards

Reject entries when:
- trading is disabled, terminal/account trading is unavailable, or data is stale;
- spread exceeds the configured maximum;
- margin check fails or free margin is insufficient;
- stop distance violates broker stop/freeze constraints;
- calculated volume or estimated loss is invalid;
- daily, weekly, or overall drawdown lock is active;
- an equivalent position/order already exists.

A protection lock must not be silently reset by restarting the EA. Persist and validate lock state in a later implementation.

## Long-term mode

Before enabling long-term CFD holding, verify account-specific Exness administrative/holding fees, swap-free eligibility, margin requirements, and liquidation rules in writing. Do not assume swap-free means cost-free.
