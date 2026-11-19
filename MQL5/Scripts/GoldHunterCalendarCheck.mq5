//+------------------------------------------------------------------+
//| GoldHunterCalendarCheck.mq5                                      |
//| Diagnostic only: reads the native MT5 USD economic calendar.    |
//| SAFETY: This script NEVER sends, modifies, or closes orders.     |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs
#property version "0.10"
#property description "Gold Hunter - MT5 USD calendar diagnostic only"

input int InpDaysAhead = 7;

string ShowValue(const bool available,const double value)
{
   if(!available)
      return "N/A";
   return DoubleToString(value,4);
}

void OnStart()
{
   if(InpDaysAhead < 1 || InpDaysAhead > 30)
   {
      Print("GH CALENDAR ERROR: InpDaysAhead must be between 1 and 30.");
      return;
   }

   datetime server_now = TimeTradeServer();
   if(server_now <= 0)
   {
      Print("GH CALENDAR ERROR: Trade-server time is unavailable. Error=",GetLastError());
      return;
   }

   datetime date_from = server_now - 60;
   datetime date_to = server_now + (datetime)(InpDaysAhead * 86400);

   MqlCalendarValue values[];
   ResetLastError();
   int count = CalendarValueHistory(values,date_from,date_to,NULL,"USD");

   if(count < 0)
   {
      int error_code = GetLastError();
      PrintFormat("GH CALENDAR ERROR: CalendarValueHistory failed. Error=%d. No 'no-news' assumption is allowed.",error_code);
      return;
   }

   Print("==================================================");
   Print("Gold Hunter calendar diagnostic - READ ONLY");
   Print("Server time: ",TimeToString(server_now,TIME_DATE|TIME_SECONDS));
   Print("Query window: ",TimeToString(date_from,TIME_DATE|TIME_MINUTES),
         " -> ",TimeToString(date_to,TIME_DATE|TIME_MINUTES));
   Print("Currency filter: USD | Records returned: ",count);
   Print("==================================================");

   if(count == 0)
   {
      Print("GH CALENDAR WARNING: No USD records returned for this range. Verify calendar availability in the terminal; this is not proof that no news exists.");
      return;
   }

   for(int i=0; i<count; i++)
   {
      MqlCalendarEvent event_info;
      ResetLastError();
      if(!CalendarEventById(values[i].event_id,event_info))
      {
         PrintFormat("GH CALENDAR WARNING: Could not resolve event_id=%I64u. Error=%d",
                     values[i].event_id,GetLastError());
         continue;
      }

      string actual = ShowValue(values[i].HasActualValue(),values[i].GetActualValue());
      string forecast = ShowValue(values[i].HasForecastValue(),values[i].GetForecastValue());
      string previous = ShowValue(values[i].HasPreviousValue(),values[i].GetPreviousValue());
      string revised = ShowValue(values[i].HasRevisedValue(),values[i].GetRevisedValue());

      PrintFormat("EVENT | %s | %s | importance=%s | event_id=%I64u | value_id=%I64u",
                  TimeToString(values[i].time,TIME_DATE|TIME_MINUTES),
                  event_info.name,
                  EnumToString((ENUM_CALENDAR_EVENT_IMPORTANCE)event_info.importance),
                  values[i].event_id,
                  values[i].id);
      PrintFormat("VALUES | actual=%s | forecast=%s | previous=%s | revised_previous=%s | period=%s",
                  actual,forecast,previous,revised,
                  TimeToString(values[i].period,TIME_DATE));
   }

   Print("==================================================");
   Print("Diagnostic finished. No orders were placed or modified.");
   Print("Calendar timestamps above use MT5 trade-server time.");
   Print("==================================================");
}
