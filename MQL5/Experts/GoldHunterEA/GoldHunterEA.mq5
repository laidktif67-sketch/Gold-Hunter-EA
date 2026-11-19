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
      InpSellRSIMin >= InpSellRSIMax)
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
