# Test Plan

## Compile and static checks
- Compile in MetaEditor with zero errors and review all warnings.
- Verify all includes resolve from the documented folder layout.
- Confirm the default configuration cannot send orders.

## Data validation
- Test XAUUSD and broker suffix variants.
- Validate digits, point, tick size/value, contract size, volume min/max/step, stops level, freeze level, and trading sessions.
- Test missing bars, history loading, reconnects, and symbol changes.

## Strategy Tester
- Use real ticks where available.
- Include variable spread, commission, swaps/administrative costs where represented, and slippage assumptions.
- Separate in-sample, validation, and out-of-sample periods.
- Test trending, ranging, high-volatility, and news-shock periods.
- Avoid optimizing excessive parameters.

## Risk tests
- Minimum lot larger than risk budget must reject.
- Invalid tick value or stop distance must reject.
- Daily/weekly/drawdown locks must block entries.
- Spread and margin filters must block entries.
- Restart behavior must not erase a protection lock.

## Forward test
- Run on an Exness demo account first.
- Compare requested versus filled price, volume, stop placement, commission, and actual costs.
- Keep a journal of every signal and rejected setup.
- No live deployment until the user reviews results and explicitly authorizes it.
