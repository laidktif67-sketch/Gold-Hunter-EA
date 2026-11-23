# A-Trade Bot V2 — Strategy Routing Specification

## XAUUSD: Gold Hunter research mode
- Signal timeframe: M15, closed candles only.
- Trend timeframe: H1, closed candle indicator values.
- EMA 20/50 alignment on M15 and H1.
- Last closed M15 candle must agree with direction.
- RSI(14) buy band 48–68; sell band 32–52.
- ATR(14) stop-distance plan: 1.5 × ATR.
- Planned reward/risk: 2.0R.

## EURUSD and GBPUSD: A-Trade research mode
- Signal timeframe: M15, closed candle indicator values.
- EMA 20/50 crossover between the two most recent closed bars.
- RSI(14) confirmation: buy >= 52; sell <= 48.
- ATR(14) stop-distance plan: 2.0 × ATR.
- Planned reward/risk: 2.0R.

## Shared rules
- One strategy route per symbol; XAUUSD is not simultaneously evaluated by the FX crossover module.
- No new candidate if the EA already has a position on that symbol.
- Maximum number of EA positions is configurable (default 3).
- The central risk manager calculates suggested volume from actual broker contract data and rejects an entry if minimum volume breaches the budget.
- All signal decisions use closed-bar indicator values.
- The current V2 implementation logs candidate reference prices and risk estimates only. It never submits orders.

## Research caveat
These rules combine useful components from two prototypes; the combination has not been shown to have a statistical edge. Each symbol and strategy must be tested independently, then as a portfolio, with realistic trading costs and out-of-sample data.
