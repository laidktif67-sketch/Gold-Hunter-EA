# GoldHunterEA

Copy the `GoldHunterEA` folder into the terminal's `MQL5/Experts/` directory, preserving the `Include` subfolder. Open `GoldHunterEA.mq5` in MetaEditor and compile.

The current EA is a diagnostic shell only. It does not submit, modify, or close orders. `InpEnableTrading` defaults to false and is not yet connected to an execution engine.

Recommended first test: attach to an XAUUSD chart on a demo terminal and confirm that initialization and new-bar messages appear in the Experts log.
