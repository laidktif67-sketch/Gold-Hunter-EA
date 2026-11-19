# Architecture

## Runtime flow

1. **Market data** reads only the attached broker symbol and validates bar availability.
2. **Signal engine** evaluates Swing and Long-term candidates independently.
3. **Protection layer** checks trading permissions, spread, session/data health, and account drawdown.
4. **Risk manager** calculates volume from equity, risk percentage, stop distance, tick size/value, volume step, and broker limits.
5. **Execution layer** is the only module permitted to submit or modify orders.
6. **Position manager** manages positions belonging to this EA's magic number and symbol.
7. **Logger** records signal decisions, rejected trades, broker return codes, and protection events.

## Design rules

- Strategy modules return a structured signal; they never place orders.
- Only Execution may call trade operations.
- Execution must require an approved risk result and a valid protective stop.
- A failed or unavailable data read means **no trade**.
- Use symbol properties at runtime; never assume digits, tick value, contract size, minimum lot, lot step, or stop distance.
- Keep Swing and Long-term positions logically separate with distinct magic numbers or strategy identifiers.
- Trading remains disabled until later phases and explicit user configuration.

## Current phase

This repository currently contains documentation and a non-trading EA shell. Strategy logic, order execution, and live trading are not implemented.
