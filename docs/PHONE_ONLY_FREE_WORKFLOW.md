# Gold Hunter EA — Phone-Only and No-Cost Workflow

## Goal

Continue preparing and reviewing Gold Hunter EA from an Android phone without paying for a VPS. This workflow does not claim that an always-on Windows machine is available for free.

## What the Android phone can do

- Open and review the source files in the GitHub repository.
- Track code and documentation changes.
- Manage the Exness demo account and observe prices in MT5 mobile.
- Collect screenshots or terminal logs from a Windows MT5 session when a trusted helper or temporary Windows environment is available.

## What Android MT5 cannot do

The MT5 Android app does not compile MQL5 source files and does not host/run Expert Advisors. Compilation requires MetaEditor on a supported desktop Windows environment. Continuous EA operation requires a suitable running MT5 desktop terminal or Windows VPS.

## No-cost options to investigate

1. **Broker-sponsored VPS eligibility:** Check the broker's Personal Area or ask official support whether a free VPS is currently available for the user's account and region. Read the exact balance, equity, and trading-volume conditions. Do not deposit or trade solely to qualify.
2. **Existing trusted Windows access:** If the user can temporarily use a trusted Windows PC, install the official MT5 terminal, compile the diagnostic script, and run it on a demo account. Do not share account passwords with helpers.
3. **Time-limited cloud trial:** A cloud provider may offer promotional credit or a trial, but availability, payment-card requirements, regional eligibility, Windows licensing, and expiry vary. Treat it as temporary, not as a guaranteed free VPS. Set spending alerts and shut the instance down before any paid period begins.
4. **Continue offline repository work:** If none of the above is available, keep improving and reviewing source and test documentation in GitHub. Do not claim the EA is running or tested.

## Safe first runtime check

The repository includes `MQL5/Scripts/GoldHunterCalendarCheck.mq5`. On Windows MT5:

1. Open MT5 and sign in to the Exness demo account.
2. Open MetaEditor and place the script under `MQL5/Scripts/`.
3. Compile it and record any compiler errors or warnings.
4. Run it from the Navigator > Scripts area while connected to the demo terminal.
5. Inspect the Experts and Journal logs for USD calendar records, server timestamps, and errors.
6. If the calendar query fails or returns no records, do not assume there is no upcoming news. Save the exact log output for diagnosis.

This script is diagnostic only. It does not open, modify, or close trades.

## Credentials and account safety

- Never post an MT5 password, investor password, one-time code, API key, or remote-desktop access code in GitHub issues or chat.
- Use demo credentials only for testing.
- Do not install unknown remote-access apps or accept VPS offers that require sending money to an individual.
- Do not deposit funds or increase trading activity just to meet a VPS promotion condition.

## Current project status

- Technical EA baseline: v0.31, signal-only.
- USD calendar diagnostic script: added, but not compiled or run yet.
- Fundamental filter: design documented; not integrated.
- Automated order execution: absent/disabled.
- Compile, Strategy Tester, and Exness demo validation: pending.

## Next milestone

Obtain a trusted Windows MT5/MetaEditor session at no cost, compile the calendar diagnostic, and verify the Exness demo calendar output. Only then proceed with calendar integration.