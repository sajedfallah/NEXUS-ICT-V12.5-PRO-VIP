//+------------------------------------------------------------------+
//|                                           NEXUS ICT V12.5 PRO VIP|
//|    Telegram Screenshot + Live Trade Results + Enhanced Alerts    |
//|    7-Step Golden Rules + Anti-Repaint MTF + RTO Mitigation       |
//|    [NEW] Shared Signal Counter + Anti-Drop Telegram Queue        |
//+------------------------------------------------------------------+
#property copyright "Ninja Programmer & AI Assistant"
#property version   "12.50"
#property strict

#include <Trade\Trade.mqh>

enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP,       // خروج با حد سود ثابت (4 مرحله‌ای)
   EXIT_RUNNER_EMA,     // خروج شناور با استفاده از EMA
   EXIT_RUNNER_STRUCT   // خروج شناور بر اساس ساختار (Swing High/Low)
};

enum ENUM_ASSET_TYPE
{
   ASSET_GOLD,
   ASSET_INDEX,
   ASSET_CRYPTO,
   ASSET_FOREX
};

enum ENUM_OPTIMIZATION_PROFILE
{
   PROFILE_AUTO,        // ⚡ هوشمند (تشخیص اتوماتیک بر اساس چارت)
   PROFILE_SCALP_M1_M5, // 🏃 اسکلپ (مناسب M1 و M5)
   PROFILE_DAY_M15_H1,  // ☀️ دی‌تریدینگ (مناسب M15 تا H1)
   PROFILE_SWING_H4_D1, // 🌊 سویینگ (مناسب H4 و D1)
   PROFILE_CUSTOM       // ⚙️ تنظیمات دستی کاربر (Manual)
};

//---------------- تنظیمات ورودی (INPUTS) ----------------//
input group "--- Optimization Presets ---"
input ENUM_OPTIMIZATION_PROFILE InpOptProfile = PROFILE_AUTO; 

input group "--- Auto Trading & Risk ---"
input bool     InpEnableAutoTrade       = true;     
input double   InpFixedLot              = 0.01;     
input double   InpRiskPercent           = 0.01;     
input double   InpCustomBalance         = 0.0;      
input double   InpRR_Ratio              = 2.0;      
input ulong    InpSlippage              = 10;       
input ulong    InpMagicNumber           = 777999;   
input bool     InpOnePositionPerSymbol  = true;     
input int      InpMaxSpreadPoints       = 500;      
input int      InpMaxConsecutiveLosses  = 3;        

input group "--- Break-Even & LTF Confirmation (NEW) ---"
input bool            InpUseBreakEven       = true;        
input double          InpBreakEvenRR        = 1.0;         
input bool            InpUseLTFConfirmation = true;        
input ENUM_TIMEFRAMES InpLTFTimeframe       = PERIOD_M1;   

input group "--- SMC Default Filters (Live Toggleable) ---"
input bool     InpStrictGoldenRule      = true;     
input bool     InpWaitMitigation        = true;     
input bool     InpUseOBConfluence       = true;     
input bool     InpUseInducement         = true;     
input ENUM_TIMEFRAMES InpMTFTimeframe   = PERIOD_M15; 
input int      InpDealingRangeBars      = 60;       

input group "--- Exit Strategy ---"
input ENUM_EXIT_MODE InpExitMode        = EXIT_RUNNER_STRUCT; 

input group "--- Base Logic (Used only if Profile=Custom) ---"
input int      InpPivotLength           = 5;        
input int      InpHistoryBars           = 1500;     
input int      InpMinBarsBetween        = 10;       

input group "--- Daily Drawdown & Killzones ---"
input bool     InpUseDailyLimit         = true;     
input double   InpMaxDailyLossPercent   = 2.0;      
input bool     InpUseKillzones          = true;     
input int      InpStartHour             = 9;        
input int      InpEndHour               = 19;       

input group "--- Telegram VIP Settings ---"
input bool     InpSendTelegram          = true;     
input bool     InpSendTradeResult       = true;     
input string   InpTelegramToken         = "8822248584:AAE-YCu-jAa5DbM34ZH7hjpA28c-eKi8T54"; 
input string   InpTelegramChatID        = "400112107"; 
input bool     InpSendDailyReport       = true;     
input int      InpDailyReportHour       = 23;       
input int      InpDailyReportMinute     = 50;       

input group "--- Clean Chart UI ---"
input bool     InpShowOnlyRecentSignals = true;     
input int      InpMaxVisibleSignals     = 3;        
input int      InpLineLengthBars        = 20;       
input bool     InpShowEntryPrice        = true;     
input bool     InpShowEntryLine         = true;     
input bool     InpShowSLLine            = true;     
input bool     InpShowTPLine            = true;     
input bool     InpShowPanel             = true;     
input bool     InpShowGlassBox          = true;     
input bool     InpUseArrowsInsteadOfText = true;    
input bool     InpShowSignalText        = true;     

//---------------- متغیرهای سراسری (GLOBALS) ----------------//
bool g_tradeEnabled     = false;
bool g_strictMode       = true;     
bool g_useKillzone      = true;
bool g_useDailyLimit    = true;

bool g_useRTO           = true;
bool g_useOB            = true;
bool g_useIDM           = true;

ENUM_EXIT_MODE g_exitMode;

int g_pivotLength       = 5;
int g_minBars           = 10;
string g_assetName      = "";
ENUM_ASSET_TYPE g_assetType = ASSET_FOREX;
int g_maxScore          = 5;

datetime g_lastBarTime         = 0;
datetime g_lastTradeTime       = 0;
datetime g_lastAttemptedSignal = 0; 
int      g_lastSignalCount     = 0;
bool     g_dailyLimitReached   = false;

datetime g_lastAnalysisTime    = 0; 

int g_atrHandle = INVALID_HANDLE;
int g_emaHandle = INVALID_HANDLE;

string g_telegramQueue[]; 
ulong  g_activeTickets[]; 

CTrade m_trade;

//+------------------------------------------------------------------+
//| Struct                                                           |
//+------------------------------------------------------------------+
struct SignalData
{
   int      bar;
   datetime t;
   double   draw_price;
   double   entry_price;
   string   type;
   color    clr;
   double   atr;
   double   sl_price;
   double   tp_price;
   double   lot_size;
   
   bool     rule_sweep;
   bool     rule_choch;
   bool     rule_fvg;
   bool     rule_fib_zone;
   bool     rule_htf_trend;
   bool     rule_mitigation; 
   bool     rule_ob;
   bool     rule_idm;
   
   string   grade;
   int      score;
};

//+------------------------------------------------------------------+
//| Forward Declarations                                             |
//+------------------------------------------------------------------+
void ProcessCalculations();
void ManagePositions();
void DetectAssetAndOptimize(string sym="");
void UpdatePanel();
void CreateInteractivePanel();
void DrawRecentSignals(SignalData &signals[]);
void DrawOneSignal(string base, SignalData &sig);
void DrawLevel(string base, string nameExt, datetime t1, double price, color clr, string label);
void DrawSignalGlassBox(SignalData &sig, bool isEmpty=false);
void ExecuteTrade(SignalData &sig);
void SendTelegramSignal(SignalData &sig);
void SendDailyReportToTelegram();
void ProcessTelegramQueue();
void TrackNewTrade(ulong ticket);
void CheckClosedTradesForResults();
void RecalculateMaxScore();
bool CheckLTFConfirmation(string tradeType);

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "Other TF";
   }
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

double GetNexusATR(int shift)
{
   if(g_atrHandle == INVALID_HANDLE) return 0.0;
   double arr[];
   if(CopyBuffer(g_atrHandle, 0, shift, 1, arr) <= 0) return 0.0;
   return arr[0];
}

double GetNexusEMA(int shift)
{
   if(g_emaHandle == INVALID_HANDLE) return 0.0;
   double arr[];
   if(CopyBuffer(g_emaHandle, 0, shift, 1, arr) <= 0) return 0.0;
   return arr[0];
}

double GetHTFHigh(datetime t, ENUM_TIMEFRAMES tf, int bars) 
{
   int shift = iBarShift(_Symbol, tf, t);
   if (shift < 0) return 0.0;
   double highs[];
   if (CopyHigh(_Symbol, tf, shift + 1, bars, highs) <= 0) return 0.0;
   return highs[ArrayMaximum(highs)];
}

double GetHTFLow(datetime t, ENUM_TIMEFRAMES tf, int bars) 
{
   int shift = iBarShift(_Symbol, tf, t);
   if (shift < 0) return 0.0;
   double lows[];
   if (CopyLow(_Symbol, tf, shift + 1, bars, lows) <= 0) return 0.0;
   return lows[ArrayMinimum(lows)];
}

bool GetHTFTrend(datetime t, ENUM_TIMEFRAMES tf, string type)
{
   int shift = iBarShift(_Symbol, tf, t);
   if (shift < 0) return true;
   double closes[];
   if (CopyClose(_Symbol, tf, shift + 1, 5, closes) <= 0) return true;
   
   if(type == "BUY" && closes[0] > closes[4]) return true;
   if(type == "SELL" && closes[0] < closes[4]) return true;
   return false;
}

bool EnsureHandles()
{
   if(g_atrHandle == INVALID_HANDLE) g_atrHandle = iATR(_Symbol, _Period, 14);
   if(g_emaHandle == INVALID_HANDLE) g_emaHandle = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_atrHandle == INVALID_HANDLE) return false;
   return true;
}

void DeleteObjectsByPrefix(string prefix)
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0) ObjectDelete(0, name);
   }
}

bool IsSpreadAllowed()
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return spread <= InpMaxSpreadPoints;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   }
   return false;
}

void RecalculateMaxScore()
{
   g_maxScore = 5;
   if(g_useOB) g_maxScore++;
   if(g_useIDM) g_maxScore++;
}

//+------------------------------------------------------------------+
//| رابط کاربری تعاملی روی چارت                                      |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
}

void CreateInteractivePanel()
{
   int sx1 = 15;        
   int sx2 = 135;       
   int y = 90;          
   int step = 28;
   int w = 115;         
   int h = 24;          

   CreateButton("BTN_TRADE", g_tradeEnabled ? "TRADE: ON" : "TRADE: OFF", sx1, y, w, h, g_tradeEnabled ? clrLimeGreen : clrTomato);
   CreateButton("BTN_EXIT", g_exitMode == EXIT_FIXED_TP ? "EXIT: FIXED" : "EXIT: STRUCT", sx2, y, w, h, clrDodgerBlue);
   
   y += step;
   CreateButton("BTN_STRICT", g_strictMode ? "STRICT: A+ ONLY" : "STRICT: ALL", sx1, y, w, h, g_strictMode ? clrGold : clrMediumPurple);
   CreateButton("BTN_RTO", g_useRTO ? "RTO: ON" : "RTO: OFF", sx2, y, w, h, g_useRTO ? clrMediumSeaGreen : clrGray);
   
   y += step;
   CreateButton("BTN_OB", g_useOB ? "OB FILTER: ON" : "OB FILTER: OFF", sx1, y, w, h, g_useOB ? clrMediumSeaGreen : clrGray);
   CreateButton("BTN_IDM", g_useIDM ? "IDM FILTER: ON" : "IDM FILTER: OFF", sx2, y, w, h, g_useIDM ? clrMediumSeaGreen : clrGray);
   
   y += step;
   CreateButton("BTN_KILLZONE", g_useKillzone ? "KILLZONE: ON" : "KILLZONE: OFF", sx1, y, w, h, g_useKillzone ? clrLimeGreen : clrTomato);
   CreateButton("BTN_LIMIT", g_useDailyLimit ? "LIMIT: ON" : "LIMIT: OFF", sx2, y, w, h, g_useDailyLimit ? clrLimeGreen : clrTomato);

   y += step;
   CreateButton("BTN_TEST_TG", "📨 TEST TELEGRAM", sx1, y, (w * 2) + 5, h, clrDeepSkyBlue); 
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == "BTN_TRADE")       g_tradeEnabled = !g_tradeEnabled;
   else if(sparam == "BTN_KILLZONE") g_useKillzone = !g_useKillzone;
   else if(sparam == "BTN_LIMIT")  g_useDailyLimit = !g_useDailyLimit;
   else if(sparam == "BTN_STRICT") g_strictMode = !g_strictMode;
   else if(sparam == "BTN_RTO")    g_useRTO = !g_useRTO;
   else if(sparam == "BTN_OB")     g_useOB = !g_useOB;
   else if(sparam == "BTN_IDM")    g_useIDM = !g_useIDM;
   else if(sparam == "BTN_EXIT")
   {
      if(g_exitMode == EXIT_FIXED_TP) g_exitMode = EXIT_RUNNER_EMA;
      else if(g_exitMode == EXIT_RUNNER_EMA) g_exitMode = EXIT_RUNNER_STRUCT;
      else g_exitMode = EXIT_FIXED_TP;
   }
   else if(sparam == "BTN_TEST_TG")
   {
      EnqueueTelegramMessage("🔧 پیام تستی از ربات NEXUS!\n\nاگر این پیام را می‌بینید، اتصال شما به تلگرام کاملاً سالم است. ✅\nدلیل عدم ارسال سیگنال‌ها، سخت‌گیری فیلترهای استراتژی است که اجازه ورود به معامله را نداده است.");
      Print("[NEXUS]: Test Telegram Message Queued.");
   }

   if(StringFind(sparam, "BTN_") >= 0)
   {
      RecalculateMaxScore();
      g_lastAnalysisTime = 0; 
      ProcessCalculations();
      CreateInteractivePanel();
      if(InpShowPanel) UpdatePanel();
      ChartRedraw();
   }
}

void DrawSignalGlassBox(SignalData &sig, bool isEmpty = false)
{
   if(!InpShowGlassBox) return;
   
   string bgName = "NEXUS_GLASS_BG";
   if(ObjectFind(0, bgName) < 0) ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 230);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, isEmpty ? 60 : 190);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   string txtName = "NEXUS_GLASS_TXT";
   if(ObjectFind(0, txtName) < 0) ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);
   
   string txt = "";
   color txtClr = clrWhite;

   if(isEmpty) 
   {
      txt = "💎 ICT GOLDEN RULES 💎\n";
      txt += "-------------------------\n";
      txt += "⏳ Waiting for Setup...\n";
      txtClr = clrSilver;
   }
   else 
   {
      txt = "💎 ICT GOLDEN RULES 💎\n";
      txt += "-------------------------\n";
      txt += "Signal Grade: " + sig.grade + "\n";
      txt += "Position: " + sig.type + (sig.type == "BUY" ? " 🟢" : " 🔴") + "\n";
      txt += "-------------------------\n";
      txt += "1. Liquidity Sweep: " + (sig.rule_sweep ? "✅" : "❌") + "\n";
      txt += "2. CHoCH Body Break: " + (sig.rule_choch ? "✅" : "❌") + "\n";
      txt += "3. FVG Imbalance: " + (sig.rule_fvg ? "✅" : "❌") + "\n";
      txt += "4. Fib Zone (<0.5): " + (sig.rule_fib_zone ? "✅" : "❌") + "\n";
      txt += "5. HTF Trend Match: " + (sig.rule_htf_trend ? "✅" : "❌") + "\n";
      if(g_useOB) txt += "6. OB Confluence: " + (sig.rule_ob ? "✅" : "❌") + "\n";
      if(g_useIDM) txt += "7. IDM Swept: " + (sig.rule_idm ? "✅" : "❌") + "\n";
      if(g_useRTO) txt += "8. RTO Mitigation: " + (sig.rule_mitigation ? "✅" : "⏳") + "\n";
      
      if(sig.grade == "A+") txtClr = clrGold;
      else if(sig.grade == "B") txtClr = clrDeepSkyBlue;
      else txtClr = clrLightGray;
   }
   
   ObjectSetString(0, txtName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, txtName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Courier New");
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Telegram Engine (Advanced Queue & Shared Counter added)          |
//+------------------------------------------------------------------+
string UrlEncode(string text)
{
   string result = "";
   uchar bytes[];
   int len = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);

   for(int i = 0; i < len - 1; i++)
   {
      uchar c = bytes[i];
      if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
         c == '-' || c == '_' || c == '.' || c == '~')
      {
         result += CharToString(c);
      }
      else if(c == ' ') result += "%20";
      else result += StringFormat("%%%02X", c);
   }
   return result;
}

void EnqueueTelegramMessage(string msg)
{
   int size = ArraySize(g_telegramQueue);
   ArrayResize(g_telegramQueue, size + 1);
   g_telegramQueue[size] = msg;
}

void ProcessTelegramQueue()
{
   if(ArraySize(g_telegramQueue) == 0) return;
   
   if(!InpSendTelegram || InpTelegramToken == "" || InpTelegramChatID == "")
   {
      ArrayResize(g_telegramQueue, 0);
      return;
   }

   string msg = g_telegramQueue[0];
   string url = "https://api.telegram.org/bot" + InpTelegramToken + "/sendMessage";
   string postData = "chat_id=" + UrlEncode(InpTelegramChatID) + "&text=" + UrlEncode(msg); 

   char data[]; char result[]; string resultHeaders;
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

   int data_len = StringToCharArray(postData, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(data_len > 0) ArrayResize(data, data_len - 1);

   ResetLastError();
   int response = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
   
   if(response == 200) {
       // ارسال موفق بود، پیام را از صف حذف کن
       ArrayRemove(g_telegramQueue, 0, 1);
   } else {
       Print("❌ [Telegram Error] HTTP Code: ", response, " - Details: ", CharArrayToString(result));
       // اگر ارور 429 (محدودیت سرعت تلگرام) یا -1 (مشکل شبکه) بود، پیام را در صف نگه دار تا در ثانیه بعدی دوباره تلاش کند
       if(response == 429 || response == -1 || response == 502) {
           Print("⏳ [Telegram] Rate limited or network issue. Retrying in next timer tick...");
           // DO NOT REMOVE FROM QUEUE
       } else {
           // ارورهای غیرقابل بازگشت مثل 401 (توکن اشتباه) یا 400 (چت آیدی اشتباه)
           ArrayRemove(g_telegramQueue, 0, 1);
       }
   }
}

struct DailyStats {
   string tf;
   int trades;
   int wins;
   int losses;
   double pnl;
};

void SendDailyReportToTelegram()
{
   if(!InpSendTelegram) return;
   
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   if(startOfDay <= 0) return;
   if(!HistorySelect(startOfDay, TimeCurrent())) return;

   int deals = HistoryDealsTotal();
   DailyStats stats[];
   double totalPnL = 0.0;
   int totalTrades = 0;

   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                      HistoryDealGetDouble(ticket, DEAL_SWAP);
         
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
         string dealTF = "Other";
         int tfStart = StringFind(comment, "[");
         int tfEnd = StringFind(comment, "]");
         if(tfStart >= 0 && tfEnd > tfStart) {
            dealTF = StringSubstr(comment, tfStart + 1, tfEnd - tfStart - 1);
         } else {
            dealTF = TimeframeToString(_Period);
         }
         
         int foundIdx = -1;
         for(int s=0; s<ArraySize(stats); s++) {
             if(stats[s].tf == dealTF) { foundIdx = s; break; }
         }
         if(foundIdx == -1) {
             foundIdx = ArraySize(stats);
             ArrayResize(stats, foundIdx + 1);
             stats[foundIdx].tf = dealTF;
             stats[foundIdx].trades = 0;
             stats[foundIdx].wins = 0;
             stats[foundIdx].losses = 0;
             stats[foundIdx].pnl = 0.0;
         }
         
         stats[foundIdx].trades++;
         stats[foundIdx].pnl += pnl;
         if(pnl > 0) stats[foundIdx].wins++;
         else if(pnl < 0) stats[foundIdx].losses++;
         
         totalPnL += pnl;
         totalTrades++;
      }
   }
   
   if(totalTrades == 0) return;
   
   string pnlEmoji = (totalPnL >= 0) ? "💵" : "🩸";
   string msg = "📊 گزارش عملکرد روزانه NEXUS 📊\n\n";
   msg += "📅 نماد: #" + _Symbol + "\n";
   msg += pnlEmoji + " سود/زیان کل: " + DoubleToString(totalPnL, 2) + "\n\n";
   
   for(int s=0; s<ArraySize(stats); s++) {
       double winRate = (stats[s].trades > 0) ? ((double)stats[s].wins / stats[s].trades) * 100.0 : 0.0;
       msg += "⏳ تایم‌فریم: " + stats[s].tf + "\n";
       msg += "🔹 تعداد معاملات: " + IntegerToString(stats[s].trades) + "\n";
       msg += "✅ برد: " + IntegerToString(stats[s].wins) + " | ❌ باخت: " + IntegerToString(stats[s].losses) + "\n";
       msg += "📈 وین‌ریت: " + DoubleToString(winRate, 1) + "%\n";
       msg += "💰 برآیند: " + DoubleToString(stats[s].pnl, 2) + "\n";
       msg += "──────────────\n";
   }

   EnqueueTelegramMessage(msg);
}

void SendTelegramSignal(SignalData &sig)
{
   if(!InpSendTelegram || InpTelegramToken == "" || InpTelegramChatID == "") return;

   // مدیریت اشتراکی شماره سیگنال بین تمام چارت‌ها (Global Variable)
   string counterName = "Nexus_Signal_Counter";
   if(!GlobalVariableCheck(counterName)) GlobalVariableSet(counterName, 1.0);
   int currentCounter = (int)GlobalVariableGet(counterName);
   GlobalVariableSet(counterName, currentCounter + 1.0); // افزایش برای چارت بعدی

   double dist = MathAbs(sig.entry_price - sig.sl_price);
   
   double tp1 = sig.entry_price + (sig.type == "BUY" ? dist : -dist);
   double tp2 = sig.entry_price + (sig.type == "BUY" ? dist*2 : -dist*2);
   double tp3 = sig.entry_price + (sig.type == "BUY" ? dist*3 : -dist*3);
   double tp4 = sig.tp_price;

   string typeEmoji = (sig.type == "BUY") ? "🟢 BUY" : "🔴 SELL";
   string gradeEmoji = (sig.grade == "A+") ? "🏆" : "💠";

   string msg = "🚨 سیگنال جدید VIP (شماره #" + IntegerToString(currentCounter) + ")\n\n";

   msg += "💎 نماد: #" + _Symbol + "\n";
   msg += "⏳ تایم‌فریم: " + TimeframeToString(_Period) + "\n";
   msg += "🛒 موقعیت: " + typeEmoji + "\n";
   msg += "⭐ درجه سیگنال: " + sig.grade + " " + gradeEmoji + "\n\n";
   
   msg += "💰 نقطه ورود: " + DoubleToString(sig.entry_price, _Digits) + "\n";
   msg += "🛑 حد ضرر: " + DoubleToString(sig.sl_price, _Digits) + "\n\n";
   
   msg += "🎯 اهداف سود:\n";
   msg += "➖ TP 1: " + DoubleToString(tp1, _Digits) + " (BE 🛡)\n";
   msg += "➖ TP 2: " + DoubleToString(tp2, _Digits) + "\n";
   msg += "➖ TP 3: " + DoubleToString(tp3, _Digits) + "\n";
   msg += "➖ TP 4: " + DoubleToString(tp4, _Digits) + "\n";

   EnqueueTelegramMessage(msg);
}

void TrackNewTrade(ulong ticket)
{
   int size = ArraySize(g_activeTickets);
   ArrayResize(g_activeTickets, size + 1);
   g_activeTickets[size] = ticket;
}

void CheckClosedTradesForResults()
{
   if(!InpSendTelegram || !InpSendTradeResult) return;

   for(int i = ArraySize(g_activeTickets) - 1; i >= 0; i--)
   {
      ulong ticket = g_activeTickets[i];
      
      if(!PositionSelectByTicket(ticket))
      {
         if(HistorySelectByPosition(ticket))
         {
            double pnl = 0;
            int deals = HistoryDealsTotal();
            for(int d = 0; d < deals; d++)
            {
               ulong dTicket = HistoryDealGetTicket(d);
               pnl += HistoryDealGetDouble(dTicket, DEAL_PROFIT) + 
                      HistoryDealGetDouble(dTicket, DEAL_COMMISSION) + 
                      HistoryDealGetDouble(dTicket, DEAL_SWAP);
            }
            
            string resMsg = "🏁 نتیجه معامله 🏁\n\n";
            resMsg += "💎 نماد: #" + _Symbol + "\n";
            if(pnl > 0) {
               resMsg += "✅ با سود بسته شد (WIN)\n";
               resMsg += "💵 سود خالص: +" + DoubleToString(pnl, 2) + "\n";
            } else {
               resMsg += "❌ با ضرر بسته شد (LOSS)\n";
               resMsg += "🩸 ضرر خالص: " + DoubleToString(pnl, 2) + "\n";
            }
            
            EnqueueTelegramMessage(resMsg);
         }
         ArrayRemove(g_activeTickets, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| LTF Confirmation                                                 |
//+------------------------------------------------------------------+
bool CheckLTFConfirmation(string tradeType)
{
   if(!InpUseLTFConfirmation) return true;

   double closePrices[], openPrices[];
   if(CopyClose(_Symbol, InpLTFTimeframe, 1, 5, closePrices) <= 0 ||
      CopyOpen(_Symbol, InpLTFTimeframe, 1, 5, openPrices) <= 0) return false;

   if(tradeType == "BUY")
   {
      for(int i = 2; i <= 4; i++) {
          if(closePrices[i-1] < openPrices[i-1] && closePrices[i] > openPrices[i] && closePrices[i] > closePrices[i-1]) 
             return true; 
      }
   }
   else if(tradeType == "SELL")
   {
      for(int i = 2; i <= 4; i++) {
          if(closePrices[i-1] > openPrices[i-1] && closePrices[i] < openPrices[i] && closePrices[i] < closePrices[i-1]) 
             return true; 
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Init & Deinit                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_lastBarTime         = 0; 
   g_lastAttemptedSignal = 0; 
   g_lastAnalysisTime    = 0;
   
   g_tradeEnabled  = InpEnableAutoTrade;
   g_strictMode    = InpStrictGoldenRule; 
   g_useRTO        = InpWaitMitigation;
   g_useOB         = InpUseOBConfluence;
   g_useIDM        = InpUseInducement;
   g_useKillzone   = InpUseKillzones;
   g_useDailyLimit = InpUseDailyLimit;
   g_exitMode      = InpExitMode;

   DetectAssetAndOptimize();
   RecalculateMaxScore();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!EnsureHandles())
      Print("[NEXUS]: هشدار: اندیکاتورها هنوز به طور کامل بارگذاری نشده‌اند.");

   CreateInteractivePanel();
   EventSetTimer(1); 

   if(InpSendTelegram)
   {
      string welcomeMsg = "✅ ربات NEXUS ICT V12.5 PRO VIP فعال شد!\n\n";
      welcomeMsg += "📈 نماد متصل: #" + _Symbol + "\n";
      welcomeMsg += "⏳ تایم‌فریم ورودی: " + TimeframeToString(_Period) + "\n";
      welcomeMsg += "🔭 تایم‌فریم ماژور (MTF): " + TimeframeToString(InpMTFTimeframe) + "\n\n";
      welcomeMsg += "🚀 سیستم اشتراکی شمارش سیگنال‌ها اضافه شد ✅\n";
      welcomeMsg += "موفق و پرسود باشید! 🚀";
      EnqueueTelegramMessage(welcomeMsg);
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteObjectsByPrefix("NEXUS_");
   DeleteObjectsByPrefix("BTN_");

   if(g_atrHandle != INVALID_HANDLE) 
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   if(g_emaHandle != INVALID_HANDLE) 
   {
      IndicatorRelease(g_emaHandle);
      g_emaHandle = INVALID_HANDLE;
   }
}

void OnTick()
{
   ProcessCalculations();
   ManagePositions();
}

void OnTimer()
{
   ProcessCalculations();
   ManagePositions();
   CheckClosedTradesForResults(); 
   ProcessTelegramQueue(); 
   
   if(InpSendDailyReport)
   {
      static int lastReportDay = -1;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      if(dt.hour == InpDailyReportHour && dt.min >= InpDailyReportMinute && dt.day_of_year != lastReportDay)
      {
         SendDailyReportToTelegram();
         lastReportDay = dt.day_of_year;
      }
   }
}

//+------------------------------------------------------------------+
//| Daily Drawdown                                                   |
//+------------------------------------------------------------------+
void CheckDailyDrawdown()
{
   if(!g_useDailyLimit)
   {
      g_dailyLimitReached = false;
      return;
   }

   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   if(startOfDay <= 0) return;
   if(!HistorySelect(startOfDay, TimeCurrent())) return;

   double dailyPnL = 0.0;
   int deals = HistoryDealsTotal();

   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
      {
         dailyPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         dailyPnL += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         dailyPnL += HistoryDealGetDouble(ticket, DEAL_SWAP);
      }
   }

   double balance = (InpCustomBalance > 0.0) ? InpCustomBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double maxLossAmount = balance * InpMaxDailyLossPercent / 100.0;

   g_dailyLimitReached = (dailyPnL < 0.0 && MathAbs(dailyPnL) >= maxLossAmount);
}

//+------------------------------------------------------------------+
//| Core Signal Engine                                               |
//+------------------------------------------------------------------+
void ProcessCalculations()
{
   if(!EnsureHandles()) return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime <= 0) return;

   CheckDailyDrawdown();

   bool isNewBar = false;
   if(g_lastAnalysisTime != currentBarTime)
   {
      isNewBar = true;
      g_lastAnalysisTime = currentBarTime;
   }

   int bars = Bars(_Symbol, _Period);
   int limit = MathMin(InpHistoryBars, bars - g_pivotLength - 60); 
   if(limit <= g_pivotLength + 5) return;

   int startLoop = limit;
   if(!isNewBar) startLoop = MathMin(80, limit); 

   double highPrices[]; double lowPrices[]; double closePrices[]; double openPrices[]; datetime timeArr[];
   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   ArraySetAsSeries(closePrices, true);
   ArraySetAsSeries(openPrices, true);
   ArraySetAsSeries(timeArr, true);

   int reqCount = startLoop + g_pivotLength + 60; 
   if(CopyHigh(_Symbol, _Period, 0, reqCount, highPrices) <= 0 ||
      CopyLow(_Symbol, _Period, 0, reqCount, lowPrices) <= 0 ||
      CopyClose(_Symbol, _Period, 0, reqCount, closePrices) <= 0 ||
      CopyOpen(_Symbol, _Period, 0, reqCount, openPrices) <= 0 ||
      CopyTime(_Symbol, _Period, 0, reqCount, timeArr) <= 0) return;

   SignalData signals[];
   ArrayResize(signals, startLoop);

   int signalCount = 0;
   int lastSignalBar = -100000;

   for(int i = startLoop; i >= g_pivotLength + 2; i--)
   {
      int ph_idx = ArrayMaximum(highPrices, i - g_pivotLength, g_pivotLength * 2 + 1);
      int pl_idx = ArrayMinimum(lowPrices, i - g_pivotLength, g_pivotLength * 2 + 1);

      if(ph_idx < 0 || pl_idx < 0) continue;

      bool isPivotHigh = (ph_idx == i);
      bool isPivotLow  = (pl_idx == i);

      if(!isPivotHigh && !isPivotLow) continue;
      
      double atr = GetNexusATR(i);
      if(atr <= 0.0) continue;

      SignalData sig;
      sig.atr = atr;
      sig.rule_ob = false;
      sig.rule_idm = false;

      // ---------------- BUY SETUP ---------------- //
      if(isPivotLow)
      {
         int prev_pl_idx = ArrayMinimum(lowPrices, pl_idx + 5, 50); 
         bool rule_sweep_buy = false;
         bool rule_choch_buy = false;
         int idx_choch_buy = -1;
         
         if(prev_pl_idx > pl_idx && prev_pl_idx != -1) 
         {
            rule_sweep_buy = (lowPrices[pl_idx] < lowPrices[prev_pl_idx]);
         }
         
         int count_bull = prev_pl_idx > pl_idx ? (prev_pl_idx - pl_idx) : 10;
         if(count_bull > 0) 
         {
            int interim_ph_idx = ArrayMaximum(highPrices, pl_idx + 1, count_bull);
            if(interim_ph_idx != -1) 
            {
               double choch_bull_level = highPrices[interim_ph_idx];
               for(int j = pl_idx - 1; j >= MathMax(1, pl_idx - 25); j--) {
                  if(closePrices[j] > choch_bull_level) {
                     rule_choch_buy = true;
                     idx_choch_buy = j;
                     break;
                  }
               }
            }
         }

         bool rule_fvg_buy = false;
         double fvg_top_buy = 0, fvg_bottom_buy = 0;
         int search_fvg_end = (idx_choch_buy != -1) ? idx_choch_buy : MathMax(1, pl_idx - 15);
         
         for(int k = pl_idx - 1; k >= search_fvg_end; k--) {
            if(lowPrices[k - 1] > highPrices[k + 1]) {
               rule_fvg_buy = true;
               fvg_top_buy = lowPrices[k - 1];
               fvg_bottom_buy = highPrices[k + 1];
               break;
            }
         }

         if(g_useOB && rule_fvg_buy) {
            int ob_cand_buy = -1;
            for(int k = pl_idx - 1; k <= pl_idx + 5; k++) {
               if(k >= reqCount || k < 0) continue;
               if(closePrices[k] < openPrices[k]) {
                  ob_cand_buy = k;
                  break; 
               }
            }
            if(ob_cand_buy != -1) {
               double ob_high = highPrices[ob_cand_buy];
               if(fvg_bottom_buy <= ob_high + (atr*0.1)) sig.rule_ob = true;
            }
         }

         int final_signal_idx = i;
         bool rule_mitigation_buy = false;
         int idx_trigger_buy = -1;

         if(rule_choch_buy && rule_fvg_buy) {
            bool touched_fvg = false;

            for(int k = idx_choch_buy - 1; k >= 1; k--) {
               if(lowPrices[k] <= fvg_top_buy) {
                  touched_fvg = true;
               }
               if(touched_fvg && closePrices[k] > openPrices[k]) {
                  rule_mitigation_buy = true;
                  idx_trigger_buy = k;
                  break;
               }
               if(closePrices[k] < fvg_bottom_buy) {
                  break;
               }
            }

            if(g_useRTO && rule_mitigation_buy) {
               final_signal_idx = idx_trigger_buy;
            } else if (rule_choch_buy) {
               final_signal_idx = idx_choch_buy;
            } else {
               final_signal_idx = i;
            }
         } else {
            if (rule_choch_buy) final_signal_idx = idx_choch_buy;
            else final_signal_idx = i;
         }

         if(g_useIDM && rule_choch_buy && idx_trigger_buy != -1) {
            int idm_idx = -1;
            for(int j = pl_idx - 2; j > idx_choch_buy; j--) {
               if(j < 1 || j+1 >= reqCount) continue;
               if(lowPrices[j] < lowPrices[j-1] && lowPrices[j] < lowPrices[j+1]) {
                  idm_idx = j;
                  break; 
               }
            }
            if(idm_idx != -1) {
               double idm_level = lowPrices[idm_idx];
               for(int k = idx_choch_buy - 1; k >= idx_trigger_buy; k--) {
                  if(lowPrices[k] < idm_level) {
                     sig.rule_idm = true;
                     break;
                  }
               }
            }
         }

         if(lastSignalBar > 0 && MathAbs(lastSignalBar - final_signal_idx) < g_minBars) continue;

         double htf_high = GetHTFHigh(timeArr[final_signal_idx], InpMTFTimeframe, InpDealingRangeBars);
         double htf_low = GetHTFLow(timeArr[final_signal_idx], InpMTFTimeframe, InpDealingRangeBars);
         double eq_level = (htf_high > 0 && htf_low > 0) ? (htf_high + htf_low) / 2.0 : 0.0;
         bool rule_discount = (eq_level > 0 && closePrices[final_signal_idx] <= eq_level); 
         bool rule_htf_trend_buy = GetHTFTrend(timeArr[final_signal_idx], InpMTFTimeframe, "BUY");

         sig.bar = final_signal_idx;
         sig.t = timeArr[final_signal_idx];
         sig.entry_price = closePrices[final_signal_idx];
         sig.type = "BUY";
         sig.draw_price = lowPrices[i];
         sig.clr = clrLime;
         sig.sl_price = NormalizePrice(lowPrices[pl_idx] - atr * 0.5); 

         sig.rule_sweep = rule_sweep_buy;
         sig.rule_choch = rule_choch_buy;
         sig.rule_fvg = rule_fvg_buy;
         sig.rule_fib_zone = rule_discount;
         sig.rule_htf_trend = rule_htf_trend_buy;
         sig.rule_mitigation = rule_mitigation_buy;
         
         sig.score = 0;
         if(sig.rule_sweep) sig.score++; 
         if(sig.rule_choch) sig.score++;
         if(sig.rule_fvg) sig.score++; 
         if(sig.rule_fib_zone) sig.score++;
         if(sig.rule_htf_trend) sig.score++;
         if(g_useOB && sig.rule_ob) sig.score++;
         if(g_useIDM && sig.rule_idm) sig.score++;
         
         if(sig.score == g_maxScore) sig.grade = "A+"; 
         else if(sig.score >= g_maxScore - 2) sig.grade = "B"; 
         else sig.grade = "C";
         
         double sl_dist = sig.entry_price - sig.sl_price;
         if(sl_dist > 0.0)
         {
            sig.lot_size = CalculateLotSize(sl_dist); 
            sig.tp_price = NormalizePrice(sig.entry_price + MathMax(sl_dist, atr) * InpRR_Ratio);
            signals[signalCount++] = sig;
            lastSignalBar = final_signal_idx;
         }
      }
      
      // ---------------- SELL SETUP ---------------- //
      else if(isPivotHigh)
      {
         int prev_ph_idx = ArrayMaximum(highPrices, ph_idx + 5, 50); 
         bool rule_sweep_sell = false;
         bool rule_choch_sell = false;
         int idx_choch_sell = -1;

         if(prev_ph_idx > ph_idx && prev_ph_idx != -1) 
         {
            rule_sweep_sell = (highPrices[ph_idx] > highPrices[prev_ph_idx]);
         }
         
         int count_bear = prev_ph_idx > ph_idx ? (prev_ph_idx - ph_idx) : 10;
         if(count_bear > 0) 
         {
            int interim_pl_idx = ArrayMinimum(lowPrices, ph_idx + 1, count_bear);
            if(interim_pl_idx != -1) 
            {
               double choch_bear_level = lowPrices[interim_pl_idx];
               for(int j = ph_idx - 1; j >= MathMax(1, ph_idx - 25); j--) {
                  if(closePrices[j] < choch_bear_level) {
                     rule_choch_sell = true;
                     idx_choch_sell = j;
                     break;
                  }
               }
            }
         }

         bool rule_fvg_sell = false;
         double fvg_top_sell = 0, fvg_bottom_sell = 0;
         int search_fvg_end = (idx_choch_sell != -1) ? idx_choch_sell : MathMax(1, ph_idx - 15);
         
         for(int k = ph_idx - 1; k >= search_fvg_end; k--) {
            if(lowPrices[k + 1] > highPrices[k - 1]) {
               rule_fvg_sell = true;
               fvg_top_sell = highPrices[k - 1]; 
               fvg_bottom_sell = lowPrices[k + 1]; 
               break;
            }
         }

         if(g_useOB && rule_fvg_sell) {
            int ob_cand_sell = -1;
            for(int k = ph_idx - 1; k <= ph_idx + 5; k++) {
               if(k >= reqCount || k < 0) continue;
               if(closePrices[k] > openPrices[k]) { 
                  ob_cand_sell = k;
                  break; 
               }
            }
            if(ob_cand_sell != -1) {
               double ob_low = lowPrices[ob_cand_sell];
               if(fvg_top_sell >= ob_low - (atr*0.1)) sig.rule_ob = true;
            }
         }

         int final_signal_idx = i;
         bool rule_mitigation_sell = false;
         int idx_trigger_sell = -1;

         if(rule_choch_sell && rule_fvg_sell) {
            bool touched_fvg = false;

            for(int k = idx_choch_sell - 1; k >= 1; k--) {
               if(highPrices[k] >= fvg_bottom_sell) {
                  touched_fvg = true;
               }
               if(touched_fvg && closePrices[k] < openPrices[k]) {
                  rule_mitigation_sell = true;
                  idx_trigger_sell = k;
                  break;
               }
               if(closePrices[k] > fvg_top_sell) {
                  break;
               }
            }

            if(g_useRTO && rule_mitigation_sell) {
               final_signal_idx = idx_trigger_sell;
            } else if (rule_choch_sell) {
               final_signal_idx = idx_choch_sell;
            } else {
               final_signal_idx = i;
            }
         } else {
            if (rule_choch_sell) final_signal_idx = idx_choch_sell;
            else final_signal_idx = i;
         }

         if(g_useIDM && rule_choch_sell && idx_trigger_sell != -1) {
            int idm_idx = -1;
            for(int j = ph_idx - 2; j > idx_choch_sell; j--) {
               if(j < 1 || j+1 >= reqCount) continue;
               if(highPrices[j] > highPrices[j-1] && highPrices[j] > highPrices[j+1]) {
                  idm_idx = j;
                  break; 
               }
            }
            if(idm_idx != -1) {
               double idm_level = highPrices[idm_idx];
               for(int k = idx_choch_sell - 1; k >= idx_trigger_sell; k--) {
                  if(highPrices[k] > idm_level) {
                     sig.rule_idm = true;
                     break;
                  }
               }
            }
         }

         if(lastSignalBar > 0 && MathAbs(lastSignalBar - final_signal_idx) < g_minBars) continue;

         double htf_high = GetHTFHigh(timeArr[final_signal_idx], InpMTFTimeframe, InpDealingRangeBars);
         double htf_low = GetHTFLow(timeArr[final_signal_idx], InpMTFTimeframe, InpDealingRangeBars);
         double eq_level = (htf_high > 0 && htf_low > 0) ? (htf_high + htf_low) / 2.0 : 0.0;
         bool rule_premium = (eq_level > 0 && closePrices[final_signal_idx] >= eq_level); 
         bool rule_htf_trend_sell = GetHTFTrend(timeArr[final_signal_idx], InpMTFTimeframe, "SELL");

         sig.bar = final_signal_idx;
         sig.t = timeArr[final_signal_idx];
         sig.entry_price = closePrices[final_signal_idx];
         sig.type = "SELL";
         sig.draw_price = highPrices[i];
         sig.clr = clrTomato;
         
         double spreadPrice = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         sig.sl_price = NormalizePrice(highPrices[ph_idx] + atr * 0.5 + spreadPrice);

         sig.rule_sweep = rule_sweep_sell;
         sig.rule_choch = rule_choch_sell;
         sig.rule_fvg = rule_fvg_sell;
         sig.rule_fib_zone = rule_premium;
         sig.rule_htf_trend = rule_htf_trend_sell;
         sig.rule_mitigation = rule_mitigation_sell;
         
         sig.score = 0;
         if(sig.rule_sweep) sig.score++; 
         if(sig.rule_choch) sig.score++;
         if(sig.rule_fvg) sig.score++; 
         if(sig.rule_fib_zone) sig.score++;
         if(sig.rule_htf_trend) sig.score++;
         if(g_useOB && sig.rule_ob) sig.score++;
         if(g_useIDM && sig.rule_idm) sig.score++;
         
         if(sig.score == g_maxScore) sig.grade = "A+"; 
         else if(sig.score >= g_maxScore - 2) sig.grade = "B"; 
         else sig.grade = "C";
         
         double sl_dist = sig.sl_price - sig.entry_price;
         if(sl_dist > 0.0)
         {
            sig.lot_size = CalculateLotSize(sl_dist); 
            sig.tp_price = NormalizePrice(sig.entry_price - MathMax(sl_dist, atr) * InpRR_Ratio);
            signals[signalCount++] = sig;
            lastSignalBar = final_signal_idx;
         }
      }
   }

   ArrayResize(signals, signalCount);
   
   if (isNewBar) {
      DrawRecentSignals(signals);
   }

   if (signalCount > 0)
   {
      SignalData latestSignal = signals[signalCount - 1];
      DrawSignalGlassBox(latestSignal, false);
      
      if (latestSignal.t > g_lastTradeTime && latestSignal.t > g_lastAttemptedSignal && latestSignal.bar <= g_pivotLength + 25)
      {
         bool strictTrade = g_strictMode ? (latestSignal.grade == "A+") : true;
         
         if (!g_tradeEnabled) {
            g_lastAttemptedSignal = latestSignal.t;
            Print("[NEXUS] ⚠️ Signal Ignored. Auto Trade is OFF on the panel.");
         } else if (g_dailyLimitReached) {
            g_lastAttemptedSignal = latestSignal.t;
            Print("[NEXUS] 🛑 Signal Ignored. Daily Drawdown Limit Reached!");
         } else if (!strictTrade) {
            g_lastAttemptedSignal = latestSignal.t;
            Print("[NEXUS] ⚠️ Signal Ignored. Strict Mode is ON, but signal is ", latestSignal.grade, ".");
         } else if (!IsSpreadAllowed()) {
            // منتظر کاهش اسپرد
         } else if (g_useRTO && !latestSignal.rule_mitigation) {
            // منتظر تاچ منطقه RTO
         } else if (InpUseLTFConfirmation && !CheckLTFConfirmation(latestSignal.type)) {
            // منتظر کندل تاییدیه در تایم فریم پایین
         } else {
            g_lastAttemptedSignal = latestSignal.t;
            ExecuteTrade(latestSignal);
         }
      }
   }
   else
   {
      if (isNewBar) {
         SignalData emptySignal;
         DrawSignalGlassBox(emptySignal, true);
      }
   }

   g_lastSignalCount = signalCount;

   if(isNewBar && InpShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Risk Management & Helper Functions                               |
//+------------------------------------------------------------------+
double GetSmartRisk()
{
   if(!HistorySelect(0, TimeCurrent())) return InpRiskPercent;

   int total = HistoryDealsTotal();
   int losses = 0, checked = 0;
   int maxAllowedLosses = (InpMaxConsecutiveLosses > 0) ? InpMaxConsecutiveLosses : 3;

   for(int i = total - 1; i >= 0 && checked < maxAllowedLosses; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         if(HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0.0) losses++;
         checked++;
      }
   }
   return (losses >= maxAllowedLosses) ? InpRiskPercent / 2.0 : InpRiskPercent;
}

double NormalizeVolume(double vol)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   double result = MathFloor(vol / step) * step;
   if(result < min) result = min;
   if(result > max) result = max;

   int digits = 2;
   if(step >= 1.0) digits = 0;
   else if(step >= 0.1) digits = 1;
   else if(step >= 0.01) digits = 2;
   else if(step >= 0.001) digits = 3;
   else digits = 4;
   return NormalizeDouble(result, digits);
}

double CalculateLotSize(double slDistanceInPrice)
{
   if(slDistanceInPrice <= 0.0) return 0.0;
   double balance = (InpCustomBalance > 0.0) ? InpCustomBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double finalLot = 0.0;

   if(InpFixedLot > 0.0) {
      finalLot = NormalizeVolume(InpFixedLot);
   } else {
      double maxAllowedRiskPercent = 2.0;
      double currentRiskPercent = MathMin(GetSmartRisk(), maxAllowedRiskPercent);
      double riskAmount = balance * currentRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue <= 0.0 || tickSize <= 0.0) return 0.0;
      double slTicks = slDistanceInPrice / tickSize;
      if(slTicks <= 0.0) return 0.0;

      double rawLot = riskAmount / (slTicks * tickValue);
      finalLot = NormalizeVolume(rawLot);
   }
   return finalLot;
}

bool IsInKillzone()
{
   if(!g_useKillzone) return true;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(InpStartHour == InpEndHour) return true;
   if(InpStartHour < InpEndHour) return dt.hour >= InpStartHour && dt.hour < InpEndHour;
   return dt.hour >= InpStartHour || dt.hour < InpEndHour;
}

bool IsStopDistanceValid(double entry, double sl, double tp)
{
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * _Point;
   if(minDistance <= 0.0) return true;
   if(MathAbs(entry - sl) < minDistance) return false;
   if(tp > 0.0 && MathAbs(entry - tp) < minDistance) return false;
   return true;
}

bool CanPartialClose(double currentVolume, double closeVolume)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(closeVolume < minVol) return false;
   if(currentVolume - closeVolume < minVol) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Trade Execution                                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(SignalData &sig)
{
   if(!IsInKillzone()) {
      Print("[NEXUS]: Trade canceled! Outside of Killzone active hours.");
      return;
   }
   if(InpOnePositionPerSymbol && HasOpenPosition()) {
      Print("[NEXUS]: Trade ignored! Position already open for this symbol.");
      return;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double safe_rr = (InpRR_Ratio > 0.1) ? InpRR_Ratio : 2.0;
   double tp_multiplier = MathMax(4.0, safe_rr); 

   SignalData tradeSig = sig;

   if(sig.type == "BUY")
   {
      double entry = NormalizePrice(ask);
      double sl = NormalizePrice(sig.sl_price);
      double distance = entry - sl;

      if(distance <= 0.0) return;
      double tp = NormalizePrice(entry + distance * tp_multiplier);

      if(!IsStopDistanceValid(entry, sl, tp)) return;

      double lot = CalculateLotSize(distance);
      if(lot <= 0.0) return;

      if(m_trade.Buy(lot, _Symbol, entry, sl, tp, "NEXUS [" + TimeframeToString(_Period) + "] B"))
      {
         Print("[NEXUS]: ✅ BUY Trade executed successfully!");
         g_lastTradeTime = sig.t;
         tradeSig.entry_price = entry; tradeSig.sl_price = sl; tradeSig.tp_price = tp; tradeSig.lot_size = lot;
         TrackNewTrade(m_trade.ResultOrder()); 
         SendTelegramSignal(tradeSig);
      } else {
         Print("[NEXUS]: ❌ BUY Trade execution failed. Error Code: ", GetLastError());
      }
   }
   else if(sig.type == "SELL")
   {
      double entry = NormalizePrice(bid);
      double sl = NormalizePrice(sig.sl_price);
      double distance = sl - entry;

      if(distance <= 0.0) return;
      double tp = NormalizePrice(entry - distance * tp_multiplier);

      if(!IsStopDistanceValid(entry, sl, tp)) return;

      double lot = CalculateLotSize(distance);
      if(lot <= 0.0) return;

      if(m_trade.Sell(lot, _Symbol, entry, sl, tp, "NEXUS [" + TimeframeToString(_Period) + "] S"))
      {
         Print("[NEXUS]: ✅ SELL Trade executed successfully!");
         g_lastTradeTime = sig.t;
         tradeSig.entry_price = entry; tradeSig.sl_price = sl; tradeSig.tp_price = tp; tradeSig.lot_size = lot;
         TrackNewTrade(m_trade.ResultOrder()); 
         SendTelegramSignal(tradeSig);
      } else {
         Print("[NEXUS]: ❌ SELL Trade execution failed. Error Code: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| مدیریت پوزیشن‌ها (Position Management - Break-Even & Partial)    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!g_tradeEnabled) return;
   if(!EnsureHandles()) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentVol= PositionGetDouble(POSITION_VOLUME);
      long posType     = PositionGetInteger(POSITION_TYPE);

      if(currentSL <= 0.0 || currentTP <= 0.0) continue;

      double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(InpUseBreakEven)
      {
         double slRiskDistance = MathAbs(openPrice - currentSL);
         double currentProfitDistance = (posType == POSITION_TYPE_BUY) ? (currentPrice - openPrice) : (openPrice - currentPrice);

         if(slRiskDistance > 0 && (currentProfitDistance / slRiskDistance) >= InpBreakEvenRR)
         {
            double bePrice = openPrice; 
            
            bool modifyBE = false;
            if(posType == POSITION_TYPE_BUY && currentSL < bePrice) modifyBE = true;
            if(posType == POSITION_TYPE_SELL && (currentSL > bePrice || currentSL == 0.0)) modifyBE = true;

            if(modifyBE)
            {
               m_trade.PositionModify(ticket, bePrice, currentTP);
            }
         }
      }

      double initialVol = currentVol;
      if(HistorySelectByPosition(PositionGetInteger(POSITION_IDENTIFIER))) {
         int dealsCount = HistoryDealsTotal();
         for(int d = 0; d < dealsCount; d++) {
            ulong dealTicket = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
               initialVol = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
               break;
            }
         }
      }

      double segment = MathAbs(currentTP - openPrice) / 4.0;
      double stepVol = NormalizeVolume(initialVol * 0.25);
      
      double tp1 = openPrice + (posType == POSITION_TYPE_BUY ? segment : -segment);
      double tp2 = openPrice + (posType == POSITION_TYPE_BUY ? segment*2 : -segment*2);
      double tp3 = openPrice + (posType == POSITION_TYPE_BUY ? segment*3 : -segment*3);

      bool hitTP1 = (posType == POSITION_TYPE_BUY) ? (currentPrice >= tp1) : (currentPrice <= tp1);
      bool hitTP2 = (posType == POSITION_TYPE_BUY) ? (currentPrice >= tp2) : (currentPrice <= tp2);
      bool hitTP3 = (posType == POSITION_TYPE_BUY) ? (currentPrice >= tp3) : (currentPrice <= tp3);

      if (currentVol >= initialVol * 0.85 && hitTP1) {
         if(CanPartialClose(currentVol, stepVol)) m_trade.PositionClosePartial(ticket, stepVol);
         m_trade.PositionModify(ticket, NormalizePrice(openPrice), currentTP);
      }
      else if (currentVol < initialVol * 0.85 && currentVol >= initialVol * 0.60 && hitTP2) {
         if(CanPartialClose(currentVol, stepVol)) m_trade.PositionClosePartial(ticket, stepVol);
      }
      else if (currentVol < initialVol * 0.60 && currentVol >= initialVol * 0.35 && hitTP3) {
         if(CanPartialClose(currentVol, stepVol)) m_trade.PositionClosePartial(ticket, stepVol);
      }

      int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double min_dist = MathMax(10.0 * _Point, stopsLevel * _Point);
      
      bool isBreakEven = false;
      if(posType == POSITION_TYPE_BUY && currentSL >= openPrice) isBreakEven = true;
      if(posType == POSITION_TYPE_SELL && currentSL <= openPrice && currentSL > 0.0) isBreakEven = true;

      if(isBreakEven) 
      {
         if(g_exitMode == EXIT_RUNNER_EMA)
         {
            double ema = NormalizePrice(GetNexusEMA(0));
            if(ema > 0.0) {
               if(posType == POSITION_TYPE_BUY && ema > currentSL && ema < currentPrice && (ema - currentSL) >= min_dist)
                  m_trade.PositionModify(ticket, ema, currentTP);
               else if(posType == POSITION_TYPE_SELL && ema < currentSL && ema > currentPrice && (currentSL - ema) >= min_dist)
                  m_trade.PositionModify(ticket, ema, currentTP);
            }
         }
         else if(g_exitMode == EXIT_RUNNER_STRUCT)
         {
            if(posType == POSITION_TYPE_BUY) {
               double lows[];
               if(CopyLow(_Symbol, _Period, 1, g_pivotLength * 2, lows) > 0) {
                  int low_idx = ArrayMinimum(lows);
                  double swingLow = lows[low_idx] - 20 * _Point;
                  if(swingLow > currentSL && swingLow < currentPrice - min_dist)
                     m_trade.PositionModify(ticket, NormalizePrice(swingLow), currentTP);
               }
            }
            else if(posType == POSITION_TYPE_SELL) {
               double highs[];
               if(CopyHigh(_Symbol, _Period, 1, g_pivotLength * 2, highs) > 0) {
                  int high_idx = ArrayMaximum(highs);
                  double swingHigh = highs[high_idx] + 20 * _Point;
                  if(swingHigh < currentSL && swingHigh > currentPrice + min_dist)
                     m_trade.PositionModify(ticket, NormalizePrice(swingHigh), currentTP);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| بهینه‌سازی و تنظیم مقادیر بر اساس پروفایل انتخاب شده           |
//+------------------------------------------------------------------+
void DetectAssetAndOptimize(string sym = "")
{
   if(sym == "") sym = _Symbol;
   StringToUpper(sym);
   g_assetType = ASSET_FOREX;
   g_assetName = sym + " (Standard)";
   g_pivotLength = InpPivotLength;
   g_minBars = InpMinBarsBetween;

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) {
      g_assetName = "Gold [" + sym + "]"; g_assetType = ASSET_GOLD;
   }
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0) {
      g_assetName = "Silver [" + sym + "]"; g_assetType = ASSET_GOLD;
   }
   else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "DOW") >= 0) {
      g_assetName = "DowJones [" + sym + "]"; g_assetType = ASSET_INDEX;
   }
   else if(StringFind(sym, "US100") >= 0 || StringFind(sym, "NAS") >= 0) {
      g_assetName = "Nasdaq [" + sym + "]"; g_assetType = ASSET_INDEX;
   }
   else if(StringFind(sym, "BTC") >= 0) {
      g_assetName = "Bitcoin [" + sym + "]"; g_assetType = ASSET_CRYPTO;
   }
   else if(StringFind(sym, "BNB") >= 0) {
      g_assetName = "BNB [" + sym + "]"; g_assetType = ASSET_CRYPTO;
   }

   if(InpOptProfile == PROFILE_CUSTOM)
   {
      g_pivotLength = InpPivotLength;
      g_minBars = InpMinBarsBetween;
   }
   else if(InpOptProfile == PROFILE_SCALP_M1_M5)
   {
      g_pivotLength = 4;
      g_minBars = 8;
   }
   else if(InpOptProfile == PROFILE_DAY_M15_H1)
   {
      g_pivotLength = 5;
      g_minBars = 10;
   }
   else if(InpOptProfile == PROFILE_SWING_H4_D1)
   {
      g_pivotLength = 3;
      g_minBars = 6;
   }
   else if(InpOptProfile == PROFILE_AUTO)
   {
      if(g_assetType == ASSET_GOLD) { g_pivotLength = 4; g_minBars = 8; }
      else if(g_assetType == ASSET_INDEX) { g_pivotLength = 5; g_minBars = 10; }
      else if(g_assetType == ASSET_CRYPTO) { g_pivotLength = 7; g_minBars = 18; }
      else { g_pivotLength = 5; g_minBars = 10; }
      
      if(_Period <= PERIOD_M5) { g_pivotLength += 1; g_minBars += 2; }
      else if(_Period >= PERIOD_H1) { g_pivotLength -= 1; if(g_pivotLength < 3) g_pivotLength = 3; }
   }
}

void DrawRecentSignals(SignalData &signals[])
{
   DeleteObjectsByPrefix("NEXUS_SIG_");
   int total = ArraySize(signals);
   if(total <= 0) return;
   
   int maxAllowed = MathMax(1, InpMaxVisibleSignals); 
   int startIndex = InpShowOnlyRecentSignals ? MathMax(0, total - maxAllowed) : 0;
   int visibleIndex = 0;
   
   for(int i = startIndex; i < total; i++) {
      string base = "NEXUS_SIG_" + IntegerToString(visibleIndex) + "_";
      DrawOneSignal(base, signals[i]);
      visibleIndex++;
   }
}

void DrawLevel(string base, string nameExt, datetime t1, double price, color clr, string label)
{
   datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * InpLineLengthBars;
   string lineName = base + nameExt + "_LINE";
   ObjectCreate(0, lineName, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);

   string txtName = base + nameExt + "_TXT";
   ObjectCreate(0, txtName, OBJ_TEXT, 0, t2, price);
   ObjectSetString(0, txtName, OBJPROP_TEXT, " " + label + ": " + DoubleToString(price, _Digits));
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 8);
}

void DrawOneSignal(string base, SignalData &sig)
{
   double offset = sig.atr * 0.20;
   double y = (sig.type == "BUY") ? sig.draw_price - offset : sig.draw_price + offset;

   if(InpUseArrowsInsteadOfText) {
      string arrowName = base + "ARROW";
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, sig.t, y);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, sig.clr);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, sig.type == "BUY" ? 233 : 234);
   }

   if(InpShowSignalText) {
      string txtName = base + "TXT";
      string labelText = sig.type + " [" + sig.grade + "]";
      if(InpShowEntryPrice) labelText += " @ " + DoubleToString(sig.entry_price, _Digits);

      ObjectCreate(0, txtName, OBJ_TEXT, 0, sig.t, y);
      ObjectSetString(0, txtName, OBJPROP_TEXT, labelText);
      
      color gradeClr = sig.clr;
      if(sig.grade == "A+") gradeClr = clrGold;
      else if(sig.grade == "B") gradeClr = clrDeepSkyBlue;
      else gradeClr = clrDarkGray;
      
      ObjectSetInteger(0, txtName, OBJPROP_COLOR, gradeClr);
      ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, txtName, OBJPROP_FONT, "Arial-Bold");
      ObjectSetInteger(0, txtName, OBJPROP_ANCHOR, sig.type == "BUY" ? ANCHOR_UPPER : ANCHOR_LOWER);
   }

   if(InpShowEntryLine) DrawLevel(base, "Entry", sig.t, sig.entry_price, clrGold, "Entry");
   if(InpShowSLLine) DrawLevel(base, "Liq_SL", sig.t, sig.sl_price, clrOrangeRed, "SL");
   if(InpShowTPLine) DrawLevel(base, "TP_Final", sig.t, sig.tp_price, clrDodgerBlue, "TP Final");
}

void UpdatePanel()
{
   string name = "NEXUS_PANEL";
   string txt = "NEXUS SMC PURE V12.5 VIP\n";
   txt += "Asset: " + g_assetName + "\n";
   
   string status = g_tradeEnabled ? "ON" : "OFF";
   if(g_dailyLimitReached) status = "LOCKED - Daily Limit";
   
   txt += "Signals: " + IntegerToString(g_lastSignalCount) + "\n";
   txt += "Spread: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " pts\n";

   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, name, OBJPROP_COLOR, g_dailyLimitReached ? clrTomato : clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
}