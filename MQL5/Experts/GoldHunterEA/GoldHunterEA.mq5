//+------------------------------------------------------------------+
//| GoldHunterEA.mq5                                                 |
//| Phase 2: diagnostics + signal-only prototype                     |
//| SAFETY: This version NEVER sends, modifies, or closes orders.    |
//+------------------------------------------------------------------+
#property strict
#property version   "0.10"
#property description "Gold Hunter EA - signal-only research prototype"

input string          InpSymbol            = "XAUUSD";    // Confirmed Exness demo symbol
input ENUM_TIMEFRAMES InpSignalTimeframe   = PERIOD_H1;    // Signal timeframe
input ENUM_TIMEFRAMES InpTrendTimeframe    = PERIOD_H4;    // Higher-timeframe trend filter
input int             InpFastEMAPeriod     = 20;
input int             InpSlowEMAPeriod     = 50;
input int             InpRSIPeriod         = 14;
input double          InpBuyRSIMin         = 50.0;
input double          InpBuyRSIMax         = 70.0;
input double          InpSellRSIMin        = 30.0;
input double          InpSellRSIMax        = 50.0;
input int             InpMaxSpreadPoints   = 0;            // 0 = report only; no spread filter
input bool            InpRequireGoldSymbol = true;

// Risk calculator only. These values do NOT place or manage a stop-loss.
input double          InpRiskPercent        = 3.0;          // Account equity risk budget (%)
input double          InpMaxRiskPercent     = 5.0;          // Hard safety ceiling for this prototype
input double          InpStopDistancePoints = 1000.0;       // Hypothetical stop distance in broker points

int g_fast_signal = INVALID_HANDLE;
int g_slow_signal = INVALID_HANDLE;
int g_fast_trend  = INVALID_HANDLE;
int g_slow_trend  = INVALID_HANDLE;
int g_rsi         = INVALID_HANDLE;
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
bool CalculateRiskVolume(double &volume, double &risk_money, double &estimated_loss)
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
      InpStopDistancePoints <= 0.0)
      return false;

   risk_money = equity * InpRiskPercent / 100.0;
   double stop_price_distance = InpStopDistancePoints * point;
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
      InpRiskPercent > InpMaxRiskPercent || InpMaxRiskPercent > 5.0 ||
      InpStopDistancePoints <= 0.0)
   {
      Print("GH ERROR: Invalid indicator inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_fast_signal = iMA(g_symbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_signal = iMA(g_symbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_fast_trend  = iMA(g_symbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_trend  = iMA(g_symbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_rsi         = iRSI(g_symbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);

   if(g_fast_signal == INVALID_HANDLE || g_slow_signal == INVALID_HANDLE ||
      g_fast_trend == INVALID_HANDLE || g_slow_trend == INVALID_HANDLE ||
      g_rsi == INVALID_HANDLE)
   {
      Print("GH ERROR: Indicator initialization failed. Error=", GetLastError());
      ReleaseIndicators();
      return INIT_FAILED;
   }

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);

   Print("==================================================");
   Print("Gold Hunter EA v0.10 initialized in SIGNAL-ONLY mode.");
   Print("Symbol=", g_symbol, " | Digits=", digits,
         " | Point=", DoubleToString(point, digits),
         " | Current spread(points)=", spread);
   Print("Signal TF=", EnumToString(InpSignalTimeframe),
         " | Trend TF=", EnumToString(InpTrendTimeframe));
   Print("Risk calculator: ", DoubleToString(InpRiskPercent, 2),
         "% equity | hypothetical stop distance=", DoubleToString(InpStopDistancePoints, 1),
         " points | hard ceiling=5.00%.");
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

   double fast_signal, slow_signal, fast_trend, slow_trend, rsi;
   if(!ReadClosedValue(g_fast_signal, fast_signal) ||
      !ReadClosedValue(g_slow_signal, slow_signal) ||
      !ReadClosedValue(g_fast_trend, fast_trend) ||
      !ReadClosedValue(g_slow_trend, slow_trend) ||
      !ReadClosedValue(g_rsi, rsi))
   {
      Print("GH WAIT: Indicator data not ready. Error=", GetLastError());
      return;
   }

   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   bool bullish = (fast_signal > slow_signal && fast_trend > slow_trend);
   bool bearish = (fast_signal < slow_signal && fast_trend < slow_trend);

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

   double suggested_volume, risk_budget, estimated_loss;
   if(CalculateRiskVolume(suggested_volume, risk_budget, estimated_loss))
   {
      if(suggested_volume > 0.0)
         Print("GH RISK ESTIMATE | Equity risk budget=", DoubleToString(risk_budget, 2),
               " | Suggested volume=", DoubleToString(suggested_volume, VolumeDigits(SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP))),
               " lots | Estimated loss at hypothetical stop=", DoubleToString(estimated_loss, 2),
               " | Stop distance(points)=", DoubleToString(InpStopDistancePoints, 1));
      else
         Print("GH RISK WARNING | Minimum broker lot would exceed the selected risk budget. No volume suggested.");
   }
   else
      Print("GH RISK ERROR | Cannot calculate safely. Check broker tick/volume specifications.");

   Print("GH ", signal,
         " | Symbol=", g_symbol,
         " | Closed bar=", TimeToString(iTime(g_symbol, InpSignalTimeframe, 1)),
         " | RSI=", DoubleToString(rsi, 2),
         " | EMA signal=", DoubleToString(fast_signal, 5), "/", DoubleToString(slow_signal, 5),
         " | EMA trend=", DoubleToString(fast_trend, 5), "/", DoubleToString(slow_trend, 5),
         " | Spread(points)=", spread,
         " | Spread check=", spread_status,
         " | EXECUTION=DISABLED");
}
