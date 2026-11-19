#property copyright "Gold Hunter EA"
#property version   "0.1.0"
#property strict
#property description "Gold Hunter EA - diagnostic scaffold; no trading"

#include "Include/GH_Config.mqh"
#include "Include/GH_Logger.mqh"

datetime g_last_bar_time = 0;

int OnInit()
{
   if(InpRiskPercent <= 0.0 ||
      InpDailyLossLimitPercent <= 0.0 ||
      InpWeeklyLossLimitPercent <= 0.0 ||
      InpMaxDrawdownPercent <= 0.0)
   {
      GH_Log("Invalid risk configuration. Initialization rejected.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_last_bar_time = iTime(_Symbol, _Period, 0);
   GH_Log("Initialized. Symbol=" + _Symbol +
          ", timeframe=" + EnumToString(_Period) +
          ", trading switch=" + (InpEnableTrading ? "true" : "false"));
   GH_Log("Scaffold mode: order execution is not implemented.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   GH_Log("Deinitialized. Reason=" + IntegerToString(reason));
}

void OnTick()
{
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time <= 0 || current_bar_time == g_last_bar_time)
      return;

   g_last_bar_time = current_bar_time;
   GH_Log("New bar detected. No trading action is available in scaffold.");
}
