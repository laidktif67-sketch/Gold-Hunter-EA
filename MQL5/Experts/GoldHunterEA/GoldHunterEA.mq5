//+------------------------------------------------------------------+
//| GoldHunterEA.mq5                                                 |
//| Phase 4: M15 candle confirmation + ATR risk planning (signal-only)                     |
//| SAFETY: This version NEVER sends, modifies, or closes orders.    |
//+------------------------------------------------------------------+
#property strict
#property version   "0.31"
#property description "Gold Hunter EA - active signal-only research prototype"

input string          InpSymbol            = "XAUUSD";    // Confirmed Exness demo symbol
input ENUM_TIMEFRAMES InpSignalTimeframe   = PERIOD_M15;   // More frequent signal scan
input ENUM_TIMEFRAMES InpTrendTimeframe    = PERIOD_H1;    // Trend confirmation
input int             InpFastEMAPeriod     = 20;
input int             InpSlowEMAPeriod     = 50;
input int             InpRSIPeriod         = 14;
input double          InpBuyRSIMin         = 48.0;
input double          InpBuyRSIMax         = 68.0;
input double          InpSellRSIMin        = 32.0;
input double          InpSellRSIMax        = 52.0;
input int             InpMaxSpreadPoints   = 0;            // 0 = report only; no spread filter
input bool            InpRequireGoldSymbol = true;

// Risk calculator only. These values do NOT place or manage a stop-loss.
input double          InpRiskPercent        = 3.0;          // Account equity risk budget (%)
input double          InpMaxRiskPercent     = 3.0;          // Hard ceiling selected for this demo profile
input int             InpATRPeriod          = 14;           // ATR period on signal timeframe
input double          InpATRStopMultiplier = 1.5;           // Stop distance = ATR x multiplier
input double          InpRewardRiskRatio    = 2.0;           // Target distance = stop distance x R:R

int g_fast_signal = INVALID_HANDLE;
int g_slow_signal = INVALID_HANDLE;
int g_fast_trend  = INVALID_HANDLE;
int g_slow_trend  = INVALID_HANDLE;
int g_rsi         = INVALID_HANDLE;
int g_atr         = INVALID_HANDLE;
string g_symbol;
datetime g_last_bar = 0;

bool IsGoldSymbol(const string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   return (StringFind(upper, "XAUUSD") >= 0);
}

int VolumeDigits(const double step)
{
   for(int digits = 0; digits <= 8; digits++)
      if(MathAbs(step - NormalizeDouble(step, digits)) < 0.00000001)
         return digits;
   return 8;
}

// Estimates position size from broker contract specifications.
// It does not submit an order and does not place a stop-loss.
bool CalculateRiskVolume(const double stop_distance_points, double &volume, double &risk_money, double &estimated_loss)
{
   volume = 0.0;
   risk_money = 0.0;
   estimated_loss = 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);

   double volume_min = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   if(equity <= 0.0 || point <= 0.0 || tick_size <= 0.0 ||
      tick_value <= 0.0 || volume_min <= 0.0 ||
      volume_max < volume_min || volume_step <= 0.0 ||
      stop_distance_points <= 0.0)
      return false;

   risk_money = equity * InpRiskPercent / 100.0;
   double stop_price_distance = stop_distance_points * point;
   double loss_per_lot = (stop_price_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0.0)
      return false;

   double raw_volume = risk_money / loss_per_lot;
   if(raw_volume < volume_min)
      return true; // Safe outcome: minimum lot would exceed the risk budget.

   double capped_volume = MathMin(raw_volume, volume_max);
   volume = MathFloor(capped_volume / volume_step + 0.000000001) * volume_step;
   volume = NormalizeDouble(volume, VolumeDigits(volume_step));

   if(volume < volume_min)
   {
      volume = 0.0;
      return true;
   }

   estimated_loss = volume * loss_per_lot;
   return true;
}

bool ReadClosedValue(const int handle, double &value)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 1, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return true;
}

void ReleaseIndicators()
{
   if(g_fast_signal != INVALID_HANDLE) IndicatorRelease(g_fast_signal);
   if(g_slow_signal != INVALID_HANDLE) IndicatorRelease(g_slow_signal);
   if(g_fast_trend  != INVALID_HANDLE) IndicatorRelease(g_fast_trend);
   if(g_slow_trend  != INVALID_HANDLE) IndicatorRelease(g_slow_trend);
   if(g_rsi         != INVALID_HANDLE) IndicatorRelease(g_rsi);
   if(g_atr         != INVALID_HANDLE) IndicatorRelease(g_atr);
}

int OnInit()
{
   g_symbol = (InpSymbol == "" ? _Symbol : InpSymbol);

   if(!SymbolSelect(g_symbol, true))
   {
      Print("GH ERROR: Cannot select symbol ", g_symbol,
            ". Check the exact broker symbol in Market Watch.");
      return INIT_FAILED;
   }

   if(InpRequireGoldSymbol && !IsGoldSymbol(g_symbol))
   {
      Print("GH ERROR: Symbol ", g_symbol,
            " does not contain XAUUSD. Set the correct gold symbol or disable the gold-symbol check.");
      return INIT_FAILED;
   }

   if(InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod ||
      InpRSIPeriod <= 0 || InpBuyRSIMin >= InpBuyRSIMax ||
      InpSellRSIMin >= InpSellRSIMax || InpRiskPercent <= 0.0 ||
      InpRiskPercent > InpMaxRiskPercent || InpMaxRiskPercent > 3.0 ||
      InpATRPeriod <= 0 || InpATRStopMultiplier <= 0.0 || InpRewardRiskRatio <= 0.0)
   {
      Print("GH ERROR: Invalid indicator inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_fast_signal = iMA(g_symbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_signal = iMA(g_symbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_fast_trend  = iMA(g_symbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_trend  = iMA(g_symbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_rsi         = iRSI(g_symbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
   g_atr         = iATR(g_symbol, InpSignalTimeframe, InpATRPeriod);

   if(g_fast_signal == INVALID_HANDLE || g_slow_signal == INVALID_HANDLE ||
      g_fast_trend == INVALID_HANDLE || g_slow_trend == INVALID_HANDLE ||
      g_rsi == INVALID_HANDLE || g_atr == INVALID_HANDLE)
   {
      Print("GH ERROR: Indicator initialization failed. Error=", GetLastError());
      ReleaseIndicators();
      return INIT_FAILED;
   }

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);

   Print("==================================================");
   Print("Gold Hunter EA v0.31 initialized in ACTIVE SIGNAL-ONLY mode.");
   Print("Symbol=", g_symbol, " | Digits=", digits,
         " | Point=", DoubleToString(point, digits),
         " | Current spread(points)=", spread);
   Print("Signal TF=", EnumToString(InpSignalTimeframe),
         " | Trend TF=", EnumToString(InpTrendTimeframe));
   Print("Risk calculator: ", DoubleToString(InpRiskPercent, 2),
         "% equity | ATR(", InpATRPeriod, ") stop multiplier=", DoubleToString(InpATRStopMultiplier, 2),
         " | reward/risk=", DoubleToString(InpRewardRiskRatio, 2), " | hard ceiling=3.00%.");
   Print("Risk calculator is informational only; no stop-loss or order is placed.");
   Print("No trading functions are present in this prototype.");
   Print("==================================================");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ReleaseIndicators();
   Print("Gold Hunter EA stopped. Reason=", reason);
}

void OnTick()
{
   datetime current_bar = iTime(g_symbol, InpSignalTimeframe, 0);
   if(current_bar == 0 || current_bar == g_last_bar)
      return;

   g_last_bar = current_bar;

   if(Bars(g_symbol, InpSignalTimeframe) < InpSlowEMAPeriod + 5 ||
      Bars(g_symbol, InpTrendTimeframe) < InpSlowEMAPeriod + 5)
   {
      Print("GH WAIT: Not enough historical bars yet.");
      return;
   }

   double fast_signal, slow_signal, fast_trend, slow_trend, rsi, atr;
   if(!ReadClosedValue(g_fast_signal, fast_signal) ||
      !ReadClosedValue(g_slow_signal, slow_signal) ||
      !ReadClosedValue(g_fast_trend, fast_trend) ||
      !ReadClosedValue(g_slow_trend, slow_trend) ||
      !ReadClosedValue(g_rsi, rsi) || !ReadClosedValue(g_atr, atr))
   {
      Print("GH WAIT: Indicator data not ready. Error=", GetLastError());
      return;
   }

   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   // Require the last CLOSED M15 candle to agree with the trend direction.
   // This confirmation can reduce noisy candidates but does not guarantee results.
   double signal_open = iOpen(g_symbol, InpSignalTimeframe, 1);
   double signal_close = iClose(g_symbol, InpSignalTimeframe, 1);
   bool bullish = (fast_signal > slow_signal && fast_trend > slow_trend &&
                   signal_close > signal_open);
   bool bearish = (fast_signal < slow_signal && fast_trend < slow_trend &&
                   signal_close < signal_open);

   string signal = "NO SIGNAL";
   if(bullish && rsi >= InpBuyRSIMin && rsi <= InpBuyRSIMax)
      signal = "BUY CANDIDATE";
   else if(bearish && rsi >= InpSellRSIMin && rsi <= InpSellRSIMax)
      signal = "SELL CANDIDATE";

   string spread_status = "REPORT ONLY";
   if(InpMaxSpreadPoints > 0)
   {
      if(spread > InpMaxSpreadPoints)
      {
         signal = "REJECTED: SPREAD TOO HIGH";
         spread_status = "FILTERED";
      }
      else
         spread_status = "WITHIN LIMIT";
   }

   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double close_price = signal_close;
   if(atr <= 0.0 || close_price <= 0.0 || point <= 0.0)
   {
      Print("GH WAIT: Invalid ATR, close price, or point size.");
      return;
   }
   double stop_distance_price = atr * InpATRStopMultiplier;
   double stop_distance_points = (point > 0.0 ? stop_distance_price / point : 0.0);
   double stop_loss_price = 0.0, take_profit_price = 0.0;
   if(signal == "BUY CANDIDATE")
   {
      stop_loss_price = NormalizeDouble(close_price - stop_distance_price, digits);
      take_profit_price = NormalizeDouble(close_price + stop_distance_price * InpRewardRiskRatio, digits);
   }
   else if(signal == "SELL CANDIDATE")
   {
      stop_loss_price = NormalizeDouble(close_price + stop_distance_price, digits);
      take_profit_price = NormalizeDouble(close_price - stop_distance_price * InpRewardRiskRatio, digits);
   }

   if(signal == "BUY CANDIDATE" || signal == "SELL CANDIDATE")
   {
      double suggested_volume, risk_budget, estimated_loss;
      if(CalculateRiskVolume(stop_distance_points, suggested_volume, risk_budget, estimated_loss))
      {
         if(suggested_volume > 0.0)
            Print("GH RISK ESTIMATE | Equity risk budget=", DoubleToString(risk_budget, 2),
                  " | Suggested volume=", DoubleToString(suggested_volume, VolumeDigits(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP))),
                  " lots | Estimated loss at planned stop=", DoubleToString(estimated_loss, 2),
                  " | ATR stop distance(points)=", DoubleToString(stop_distance_points, 1));
         else
            Print("GH RISK WARNING | Minimum broker lot would exceed the selected risk budget. No volume suggested.");
      }
      else
         Print("GH RISK ERROR | Cannot calculate safely. Check broker tick/volume specifications.");
   }

   Print("GH ", signal,
         " | Symbol=", g_symbol,
         " | Closed bar=", TimeToString(iTime(g_symbol, InpSignalTimeframe, 1)),
         " | RSI=", DoubleToString(rsi, 2),
         " | EMA signal=", DoubleToString(fast_signal, 5), "/", DoubleToString(slow_signal, 5),
         " | EMA trend=", DoubleToString(fast_trend, 5), "/", DoubleToString(slow_trend, 5),
         " | ATR=", DoubleToString(atr, digits),
         " | Planned SL=", DoubleToString(stop_loss_price, digits),
         " | Planned TP=", DoubleToString(take_profit_price, digits),
         " | Spread(points)=", spread,
         " | Spread check=", spread_status,
         " | EXECUTION=DISABLED");
}
