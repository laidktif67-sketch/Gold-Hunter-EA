//+------------------------------------------------------------------+
//| A-Trade Bot V2 - Unified research and signal engine               |
//| Signal-only build: no orders are sent, modified, or closed.       |
//+------------------------------------------------------------------+
#property strict
#property version   "2.00"
#property description "Unified Gold Hunter + A-Trade multi-symbol research EA."

// ========================= USER PROFILE ===========================
input string          InpSymbols                 = "XAUUSD,EURUSD,GBPUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe         = PERIOD_M15;
input ENUM_TIMEFRAMES InpGoldTrendTimeframe      = PERIOD_H1;
input int             InpFastEMA                 = 20;
input int             InpSlowEMA                 = 50;
input int             InpRSIPeriod               = 14;
input int             InpATRPeriod               = 14;
input double          InpCurrencyBuyRSIMin       = 52.0;
input double          InpCurrencySellRSIMax      = 48.0;
input double          InpGoldBuyRSIMin            = 48.0;
input double          InpGoldBuyRSIMax            = 68.0;
input double          InpGoldSellRSIMin           = 32.0;
input double          InpGoldSellRSIMax           = 52.0;
input double          InpATRStopMultiplier        = 2.0;
input double          InpGoldATRStopMultiplier    = 1.5;
input double          InpRewardRisk               = 2.0;

// ========================= CENTRAL RISK ===========================
input double          InpRiskPerTradePct          = 1.0;
input double          InpMaxRiskPerTradePct       = 2.0;
input double          InpMaxPortfolioRiskPct      = 3.0;
input int             InpMaxPositions             = 3;
input double          InpMaxDailyLossPct          = 4.0;
input double          InpMaxWeeklyLossPct         = 6.0;
input double          InpPauseDrawdownPct         = 8.0;
input double          InpEmergencyDrawdownPct     = 10.0;

// ========================= SAFETY / DIAGNOSTICS ===================
input int             InpMaxSpreadPoints          = 0; // 0 = report only; calibrate separately per symbol
input int             InpSlippagePoints           = 20;
input ulong           InpMagic                    = 26112302;
input int             InpScanSeconds              = 10;
input bool            InpExecutionEnabled         = false; // Reserved. This version never executes orders.

string   g_symbols[];
datetime g_last_bar[];
int      g_fast_signal[];
int      g_slow_signal[];
int      g_rsi_signal[];
int      g_atr_signal[];
int      g_fast_gold_trend[];
int      g_slow_gold_trend[];
bool     g_halted = false;
string   g_gv_prefix = "";
double   g_cycle_reserved_risk = 0.0;

//+------------------------------------------------------------------+
string TrimText(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

//+------------------------------------------------------------------+
bool IsGold(const string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   return (StringFind(upper, "XAUUSD") >= 0);
}

//+------------------------------------------------------------------+
int VolumePrecision(const double step)
{
   for(int d = 0; d <= 8; d++)
      if(MathAbs(step - NormalizeDouble(step, d)) < 0.00000001)
         return d;
   return 8;
}

//+------------------------------------------------------------------+
bool ReadValue(const int handle, const int shift, double &value)
{
   if(handle == INVALID_HANDLE) return false;
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1) return false;
   value = buffer[0];
   return true;
}

//+------------------------------------------------------------------+
bool ReadRates(const string symbol, const ENUM_TIMEFRAMES timeframe,
               const int count, MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);
   return (CopyRates(symbol, timeframe, 0, count, rates) >= count);
}

//+------------------------------------------------------------------+
//| Broker-aware cash risk estimate using OrderCalcProfit.           |
//| Rounds down only; never rounds up to the broker minimum volume.   |
//+------------------------------------------------------------------+
bool CalculateVolumeForRisk(const string symbol, const ENUM_ORDER_TYPE type,
                            const double entry, const double stop,
                            const double risk_money, double &volume,
                            double &estimated_loss)
{
   volume = 0.0;
   estimated_loss = 0.0;
   double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(min_volume <= 0.0 || max_volume < min_volume || step <= 0.0 ||
      risk_money <= 0.0 || entry <= 0.0 || stop <= 0.0)
      return false;

   double one_lot_profit = 0.0;
   ResetLastError();
   if(!OrderCalcProfit(type, symbol, 1.0, entry, stop, one_lot_profit))
   {
      Print("V2 RISK ERROR | OrderCalcProfit failed | ", symbol,
            " | error=", GetLastError());
      return false;
   }

   double loss_per_lot = MathAbs(one_lot_profit);
   if(loss_per_lot <= 0.0) return false;
   double raw_volume = risk_money / loss_per_lot;
   if(raw_volume + 1e-10 < min_volume)
      return true; // Valid calculation, but minimum volume breaches budget.

   double capped = MathMin(raw_volume, max_volume);
   double steps = MathFloor((capped + 1e-10) / step);
   volume = NormalizeDouble(steps * step, VolumePrecision(step));
   if(volume < min_volume)
   {
      volume = 0.0;
      return true;
   }

   double actual_profit = 0.0;
   if(!OrderCalcProfit(type, symbol, volume, entry, stop, actual_profit))
   {
      volume = 0.0;
      return false;
   }
   estimated_loss = MathAbs(actual_profit);
   if(estimated_loss > risk_money + 0.01)
   {
      volume = 0.0;
      estimated_loss = 0.0;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Sum current stop-risk for positions opened with this EA magic.   |
//| Positions without an SL are treated as unknown/high risk and     |
//| block new entries rather than being silently ignored.             |
//+------------------------------------------------------------------+
bool CalculateOpenPortfolioRisk(double &risk_money)
{
   risk_money = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
      {
         Print("V2 BLOCK | Existing EA position has no stop-loss: ", symbol);
         return false;
      }

      ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ENUM_ORDER_TYPE calc_type =
         (pos_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double pnl_at_sl = 0.0;
      if(!OrderCalcProfit(calc_type, symbol, volume, open_price, sl, pnl_at_sl))
      {
         Print("V2 BLOCK | Cannot calculate open risk for ", symbol,
               " | error=", GetLastError());
         return false;
      }
      risk_money += MathMax(0.0, -pnl_at_sl);
   }
   return true;
}

//+------------------------------------------------------------------+
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
bool HasPositionForSymbol(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
int DateKey(const datetime value)
{
   MqlDateTime d;
   TimeToStruct(value, d);
   return d.year * 10000 + d.mon * 100 + d.day;
}

//+------------------------------------------------------------------+
//| ISO week key: year + ISO week number, calculated from Thursday.  |
//+------------------------------------------------------------------+
int ISOWeekKey(const datetime value)
{
   MqlDateTime d;
   TimeToStruct(value, d);
   int weekday = d.day_of_week;
   if(weekday == 0) weekday = 7;
   datetime thursday = value + (4 - weekday) * 86400;
   MqlDateTime td;
   TimeToStruct(thursday, td);
   MqlDateTime jan4;
   jan4.year = td.year; jan4.mon = 1; jan4.day = 4;
   jan4.hour = 0; jan4.min = 0; jan4.sec = 0;
   datetime jan4_time = StructToTime(jan4);
   MqlDateTime j;
   TimeToStruct(jan4_time, j);
   int jan4_weekday = j.day_of_week;
   if(jan4_weekday == 0) jan4_weekday = 7;
   datetime week1_monday = jan4_time - (jan4_weekday - 1) * 86400;
   int week_number = (int)((thursday - week1_monday) / (7 * 86400)) + 1;
   return td.year * 100 + week_number;
}

//+------------------------------------------------------------------+
double GetOrCreateBaseline(const string key, const double equity)
{
   if(!GlobalVariableCheck(key)) GlobalVariableSet(key, equity);
   return GlobalVariableGet(key);
}

//+------------------------------------------------------------------+
bool RiskGuardsAllowSignals()
{
   datetime now = TimeCurrent();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return false;

   string day_key = g_gv_prefix + "day_" + IntegerToString(DateKey(now));
   string week_key = g_gv_prefix + "week_" + IntegerToString(ISOWeekKey(now));
   string peak_key = g_gv_prefix + "peak";

   double day_base = GetOrCreateBaseline(day_key, equity);
   double week_base = GetOrCreateBaseline(week_key, equity);
   double peak = GetOrCreateBaseline(peak_key, equity);
   if(equity > peak)
   {
      peak = equity;
      GlobalVariableSet(peak_key, peak);
   }

   if(day_base > 0.0 && equity <= day_base * (1.0 - InpMaxDailyLossPct / 100.0))
   {
      Print("V2 PAUSE | Daily equity loss limit reached.");
      return false;
   }
   if(week_base > 0.0 && equity <= week_base * (1.0 - InpMaxWeeklyLossPct / 100.0))
   {
      Print("V2 PAUSE | Weekly equity loss limit reached.");
      return false;
   }
   if(peak > 0.0 && equity <= peak * (1.0 - InpEmergencyDrawdownPct / 100.0))
   {
      g_halted = true;
      GlobalVariableSet(g_gv_prefix + "emergency_halt", 1.0);
      Print("V2 HALT | Emergency peak-to-equity drawdown reached. Persistent halt set; manual review and explicit reset required.");
      return false;
   }
   if(peak > 0.0 && equity <= peak * (1.0 - InpPauseDrawdownPct / 100.0))
   {
      Print("V2 PAUSE | Peak drawdown pause reached.");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool IsNewSignalBar(const int index)
{
   datetime bar_time = iTime(g_symbols[index], InpSignalTimeframe, 0);
   if(bar_time <= 0 || bar_time == g_last_bar[index]) return false;
   g_last_bar[index] = bar_time;
   return true;
}

//+------------------------------------------------------------------+
void LogCandidate(const int index, const bool is_buy, const double atr,
                  const double entry, const double point, const int digits,
                  const double spread_points)
{
   string symbol = g_symbols[index];
   double stop_multiplier = (IsGold(symbol) ?
                             InpGoldATRStopMultiplier : InpATRStopMultiplier);
   double stop_distance = atr * stop_multiplier;
   double min_stop = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   stop_distance = MathMax(stop_distance, min_stop + 2.0 * point);

   double sl = (is_buy ? entry - stop_distance : entry + stop_distance);
   double tp = (is_buy ? entry + stop_distance * InpRewardRisk :
                         entry - stop_distance * InpRewardRisk);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_budget = equity * InpRiskPerTradePct / 100.0;
   double max_trade_budget = equity * InpMaxRiskPerTradePct / 100.0;
   if(InpRiskPerTradePct > InpMaxRiskPerTradePct ||
      InpRiskPerTradePct <= 0.0 || risk_budget > max_trade_budget)
   {
      Print("V2 REJECT | Invalid per-trade risk configuration.");
      return;
   }

   double volume = 0.0, estimated_loss = 0.0;
   ENUM_ORDER_TYPE order_type = (is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!CalculateVolumeForRisk(symbol, order_type, entry, sl,
                              risk_budget, volume, estimated_loss))
   {
      Print("V2 REJECT | Risk sizing failed for ", symbol);
      return;
   }
   if(volume <= 0.0)
   {
      Print("V2 REJECT | Minimum broker lot exceeds risk budget | ", symbol,
            " | budget=", DoubleToString(risk_budget, 2),
            " | min lot=", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 4));
      return;
   }

   double open_risk = 0.0;
   if(!CalculateOpenPortfolioRisk(open_risk))
   {
      Print("V2 REJECT | Existing portfolio risk could not be verified.");
      return;
   }
   double portfolio_cap = equity * InpMaxPortfolioRiskPct / 100.0;
   if(open_risk + g_cycle_reserved_risk + estimated_loss > portfolio_cap + 0.01)
   {
      Print("V2 REJECT | Portfolio stop-risk cap would be exceeded | open=",
            DoubleToString(open_risk, 2), " | candidate=",
            DoubleToString(estimated_loss, 2), " | cap=",
            DoubleToString(portfolio_cap, 2));
      return;
   }

   string strategy = (IsGold(symbol) ? "GOLD_M15_H1" : "CURRENCY_M15_CROSSOVER");
   Print("V2 CANDIDATE | Strategy=", strategy,
         " | Side=", (is_buy ? "BUY" : "SELL"),
         " | Symbol=", symbol,
         " | Entry reference=", DoubleToString(entry, digits),
         " | Planned SL=", DoubleToString(sl, digits),
         " | Planned TP=", DoubleToString(tp, digits),
         " | ATR=", DoubleToString(atr, digits),
         " | Stop distance=", DoubleToString(stop_distance / point, 1), " points",
         " | Volume estimate=", DoubleToString(volume,
            VolumePrecision(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP))),
         " | Risk budget=", DoubleToString(risk_budget, 2),
         " | Estimated stop loss=", DoubleToString(estimated_loss, 2),
         " | Open portfolio risk=", DoubleToString(open_risk, 2),
         " | Spread(points)=", DoubleToString(spread_points, 1),
         " | EXECUTION=DISABLED");\n   // Reserve this candidate during the current scan cycle so later symbols\n   // cannot each consume the same remaining portfolio risk budget.\n   g_cycle_reserved_risk += estimated_loss;
}

//+------------------------------------------------------------------+
void EvaluateSymbol(const int index)
{
   string symbol = g_symbols[index];
   if(!SymbolSelect(symbol, true) || !IsNewSignalBar(index)) return;
   if(HasPositionForSymbol(symbol)) return;
   if(CountOurPositions() >= InpMaxPositions) return;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || tick.ask <= 0.0 || tick.bid <= 0.0) return;

   double spread_points = (tick.ask - tick.bid) / point;
   if(InpMaxSpreadPoints > 0 && spread_points > InpMaxSpreadPoints)
   {
      Print("V2 REJECT | Spread filter | ", symbol,
            " | spread=", DoubleToString(spread_points, 1),
            " | max=", InpMaxSpreadPoints);
      return;
   }

   double fast1, fast2, slow1, slow2, rsi1, atr1;
   if(!ReadValue(g_fast_signal[index], 1, fast1) ||
      !ReadValue(g_fast_signal[index], 2, fast2) ||
      !ReadValue(g_slow_signal[index], 1, slow1) ||
      !ReadValue(g_slow_signal[index], 2, slow2) ||
      !ReadValue(g_rsi_signal[index], 1, rsi1) ||
      !ReadValue(g_atr_signal[index], 1, atr1) || atr1 <= 0.0)
      return;

   bool buy_signal = false;
   bool sell_signal = false;

   if(IsGold(symbol))
   {
      double fast_h1, slow_h1;
      MqlRates m15[];
      if(!ReadValue(g_fast_gold_trend[index], 1, fast_h1) ||
         !ReadValue(g_slow_gold_trend[index], 1, slow_h1) ||
         !ReadRates(symbol, InpSignalTimeframe, 3, m15))
         return;

      bool bullish_candle = (m15[1].close > m15[1].open);
      bool bearish_candle = (m15[1].close < m15[1].open);
      bool bullish = (fast1 > slow1 && fast_h1 > slow_h1 && bullish_candle);
      bool bearish = (fast1 < slow1 && fast_h1 < slow_h1 && bearish_candle);

      buy_signal = bullish && rsi1 >= InpGoldBuyRSIMin && rsi1 <= InpGoldBuyRSIMax;
      sell_signal = bearish && rsi1 >= InpGoldSellRSIMin && rsi1 <= InpGoldSellRSIMax;
   }
   else
   {
      buy_signal = (fast2 <= slow2 && fast1 > slow1 && rsi1 >= InpCurrencyBuyRSIMin);
      sell_signal = (fast2 >= slow2 && fast1 < slow1 && rsi1 <= InpCurrencySellRSIMax);
   }

   if(!buy_signal && !sell_signal) return;
   double entry = (buy_signal ? tick.ask : tick.bid);
   LogCandidate(index, buy_signal, atr1, entry, point, digits, spread_points);
}

//+------------------------------------------------------------------+
void ReleaseAllIndicators()
{
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      if(g_fast_signal[i] != INVALID_HANDLE) IndicatorRelease(g_fast_signal[i]);
      if(g_slow_signal[i] != INVALID_HANDLE) IndicatorRelease(g_slow_signal[i]);
      if(g_rsi_signal[i] != INVALID_HANDLE) IndicatorRelease(g_rsi_signal[i]);
      if(g_atr_signal[i] != INVALID_HANDLE) IndicatorRelease(g_atr_signal[i]);
      if(g_fast_gold_trend[i] != INVALID_HANDLE) IndicatorRelease(g_fast_gold_trend[i]);
      if(g_slow_gold_trend[i] != INVALID_HANDLE) IndicatorRelease(g_slow_gold_trend[i]);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastEMA <= 0 || InpSlowEMA <= InpFastEMA ||
      InpRSIPeriod <= 0 || InpATRPeriod <= 0 ||
      InpRiskPerTradePct <= 0.0 ||
      InpMaxRiskPerTradePct < InpRiskPerTradePct ||
      InpMaxRiskPerTradePct > 2.0 ||
      InpMaxPortfolioRiskPct <= 0.0 ||
      InpMaxDailyLossPct <= 0.0 || InpMaxWeeklyLossPct <= 0.0 ||
      InpPauseDrawdownPct <= 0.0 ||
      InpEmergencyDrawdownPct <= InpPauseDrawdownPct ||
      InpRewardRisk <= 0.0 || InpATRStopMultiplier <= 0.0 ||
      InpGoldATRStopMultiplier <= 0.0 || InpMaxPositions < 1)
   {
      Print("V2 INIT ERROR | Invalid inputs. Per-trade risk ceiling cannot exceed 2%.");
      return INIT_PARAMETERS_INCORRECT;
   }

   string raw[];
   int n = StringSplit(InpSymbols, ',', raw);
   if(n <= 0) return INIT_FAILED;

   ArrayResize(g_symbols, 0);
   for(int i = 0; i < n; i++)
   {
      string symbol = TrimText(raw[i]);
      if(symbol == "") continue;
      int size = ArraySize(g_symbols) + 1;
      ArrayResize(g_symbols, size);
      g_symbols[size - 1] = symbol;
   }
   int total = ArraySize(g_symbols);
   if(total <= 0) return INIT_FAILED;

   ArrayResize(g_last_bar, total);
   ArrayResize(g_fast_signal, total);
   ArrayResize(g_slow_signal, total);
   ArrayResize(g_rsi_signal, total);
   ArrayResize(g_atr_signal, total);
   ArrayResize(g_fast_gold_trend, total);
   ArrayResize(g_slow_gold_trend, total);

   // Initialize every handle before any failure path can release them.
   for(int i = 0; i < total; i++)
   {
      g_last_bar[i] = 0;
      g_fast_signal[i] = INVALID_HANDLE;
      g_slow_signal[i] = INVALID_HANDLE;
      g_rsi_signal[i] = INVALID_HANDLE;
      g_atr_signal[i] = INVALID_HANDLE;
      g_fast_gold_trend[i] = INVALID_HANDLE;
      g_slow_gold_trend[i] = INVALID_HANDLE;
   }

   for(int i = 0; i < total; i++)
   {
      string symbol = g_symbols[i];
      if(!SymbolSelect(symbol, true))
      {
         Print("V2 INIT ERROR | Cannot select exact broker symbol: ", symbol);
         ReleaseAllIndicators();
         return INIT_FAILED;
      }
      g_fast_signal[i] = iMA(symbol, InpSignalTimeframe, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_slow_signal[i] = iMA(symbol, InpSignalTimeframe, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_rsi_signal[i] = iRSI(symbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
      g_atr_signal[i] = iATR(symbol, InpSignalTimeframe, InpATRPeriod);
      if(IsGold(symbol))
      {
         g_fast_gold_trend[i] = iMA(symbol, InpGoldTrendTimeframe,
                                    InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
         g_slow_gold_trend[i] = iMA(symbol, InpGoldTrendTimeframe,
                                    InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      }

      if(g_fast_signal[i] == INVALID_HANDLE ||
         g_slow_signal[i] == INVALID_HANDLE ||
         g_rsi_signal[i] == INVALID_HANDLE ||
         g_atr_signal[i] == INVALID_HANDLE ||
         (IsGold(symbol) &&
          (g_fast_gold_trend[i] == INVALID_HANDLE ||
           g_slow_gold_trend[i] == INVALID_HANDLE)))
      {
         Print("V2 INIT ERROR | Indicator initialization failed: ", symbol,
               " | error=", GetLastError());
         ReleaseAllIndicators();
         return INIT_FAILED;
      }
   }

   g_gv_prefix = "ATRV2_" +
      IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
      IntegerToString((long)InpMagic) + "_";

   if(GlobalVariableCheck(g_gv_prefix + "emergency_halt") &&
      GlobalVariableGet(g_gv_prefix + "emergency_halt") > 0.5)
   {
      g_halted = true;
      Print("V2 HALT | Persistent emergency halt already exists. Remove the terminal global variable ",
            g_gv_prefix, "emergency_halt only after manual review.");
   }

   EventSetTimer(MathMax(2, InpScanSeconds));
   Print("==================================================");
   Print("A-Trade Bot V2 initialized in SIGNAL-ONLY mode.");
   Print("Symbols=", InpSymbols, " | Signal TF=", EnumToString(InpSignalTimeframe),
         " | Gold trend TF=", EnumToString(InpGoldTrendTimeframe));
   Print("Risk per trade=", DoubleToString(InpRiskPerTradePct, 2),
         "% | hard ceiling=", DoubleToString(InpMaxRiskPerTradePct, 2),
         "% | portfolio open-risk ceiling=",
         DoubleToString(InpMaxPortfolioRiskPct, 2), "%");
   Print("Reference test equity is user-configured in demo account; no fixed balance is assumed.");
   Print("ExecutionEnabled input=", (InpExecutionEnabled ? "true" : "false"),
         " | SAFETY OVERRIDE: execution code is not implemented in this version.");
   Print("No orders will be sent, modified, or closed.");
   Print("==================================================");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseAllIndicators();
   Print("A-Trade Bot V2 stopped. Reason=", reason);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_halted) return;
   if(!RiskGuardsAllowSignals()) return;
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      if(g_halted) break;
      EvaluateSymbol(i);
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Multi-symbol scans are timer-driven; no order execution exists.
}
//+------------------------------------------------------------------+
