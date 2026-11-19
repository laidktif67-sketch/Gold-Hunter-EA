# Gold Hunter EA

Automated XAUUSD Expert Advisor for MetaTrader 5 (MQL5).

> **Status:** Repository scaffold / Phase 0. No live-trading strategy is enabled yet.
> **Safety:** This project is for research and testing. Use Strategy Tester and a demo account first. Never run unattended on a live account until the code, broker contract specifications, costs, and risk controls have been independently validated.

## Project goals

- Two independent strategy modes: Swing and Long-term.
- Multi-timeframe market analysis using broker-provided MT5 data.
- Strict position sizing based on account equity and stop distance.
- Execution safeguards: spread, margin, volume-step, stop-level, and trade-result checks.
- Clear logs explaining every signal, rejection, order, and protection event.
- Reproducible backtests and out-of-sample validation.

## Important operating constraint

The MetaTrader 5 mobile app does **not** run Expert Advisors. The EA must run in desktop MT5 on Windows or on a compatible VPS. A phone can be used to monitor the account, but it is not the EA runtime.

## Initial repository layout

```text
Gold-Hunter-EA/
├── MQL5/
│   ├── Experts/GoldHunterEA/
│   │   ├── GoldHunterEA.mq5
│   │   ├── Include/
│   │   │   ├── GH_Config.mqh
│   │   │   ├── GH_Types.mqh
│   │   │   ├── GH_MarketData.mqh
│   │   │   ├── GH_Signals.mqh
│   │   │   ├── GH_Risk.mqh
│   │   │   ├── GH_Execution.mqh
│   │   │   ├── GH_PositionManager.mqh
│   │   │   ├── GH_Protection.mqh
│   │   │   └── GH_Logger.mqh
│   │   └── README.md
│   └── Indicators/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── RISK_POLICY.md
│   ├── STRATEGY_SPEC.md
│   ├── TEST_PLAN.md
│   └── CHANGELOG.md
├── tests/
│   ├── backtest/
│   └── test-cases/
├── .github/
│   └── ISSUE_TEMPLATE/
├── .gitignore
└── README.md
```

## Development phases

1. **Scaffold:** document architecture, risk policy, interfaces, and test plan.
2. **Data & diagnostics:** validate symbol properties, timeframe data, spread, and broker constraints.
3. **Signal-only prototype:** calculate and log candidate signals without sending orders.
4. **Risk and execution:** add sizing and order handling behind an explicit disabled-by-default switch.
5. **Backtesting:** test realistic costs, variable spreads, slippage, and out-of-sample periods.
6. **Demo forward test:** verify stability and behavior before considering any live use.

## Defaults and safety

- Trading disabled by default.
- No martingale, grid recovery, or averaging down.
- No order if minimum broker volume exceeds the configured cash-risk budget.
- Stop-loss required for every entry.
- Daily and peak-to-valley equity protections are mandatory.
- Strategy modules cannot bypass the central risk manager.
- Long-term holding costs (including any broker administrative fees) must be verified for the specific Exness account before enabling that mode.

## Build

Open MetaEditor from desktop MetaTrader 5, open `MQL5/Experts/GoldHunterEA/GoldHunterEA.mq5`, and compile. The initial scaffold will be added incrementally; it is not yet a trading-ready EA.

## Disclaimer

Trading leveraged CFDs involves substantial risk. Backtest results do not guarantee future performance. The software does not guarantee profits and must not be treated as financial advice.
