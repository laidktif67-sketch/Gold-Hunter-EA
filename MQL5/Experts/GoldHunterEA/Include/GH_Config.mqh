#ifndef GH_CONFIG_MQH
#define GH_CONFIG_MQH

input bool InpEnableTrading = false;       // Reserved: no order execution in scaffold
input ulong InpMagicSwing = 6111901;
input ulong InpMagicLongTerm = 6111902;
input double InpRiskPercent = 0.50;
input double InpDailyLossLimitPercent = 1.50;
input double InpWeeklyLossLimitPercent = 3.00;
input double InpMaxDrawdownPercent = 8.00;
input int InpMaxSpreadPoints = 80;
input ENUM_TIMEFRAMES InpContextTF = PERIOD_H4;

#endif // GH_CONFIG_MQH
