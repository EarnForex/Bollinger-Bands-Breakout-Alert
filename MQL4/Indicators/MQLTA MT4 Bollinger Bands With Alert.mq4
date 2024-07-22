#property link          "https://www.earnforex.com/metatrader-indicators/bollinger-bands-breakout-alert/"
#property version       "1.05"
#property strict
#property copyright     "EarnForex.com - 2019-2024"
#property description   "The classic Bollinger Bands with more features."
#property description   ""
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   ""
#property description   "Find More on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 clrLightSeaGreen
#property indicator_color2 clrLightSeaGreen
#property indicator_color3 clrLightSeaGreen
#property indicator_type1 DRAW_LINE
#property indicator_type2 DRAW_LINE
#property indicator_type3 DRAW_LINE
#property indicator_width1  1
#property indicator_width2  1
#property indicator_width3  1
#property indicator_label1  "Bollinger Moving Average"
#property indicator_label2  "Bollinger Upper Band"
#property indicator_label3  "Bollinger Lower Band"

enum ENUM_TRADE_SIGNAL
{
    SIGNAL_BUY = 1,    // BUY
    SIGNAL_SELL = -1,  // SELL
    SIGNAL_NEUTRAL = 0 // NEUTRAL
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0, // CURRENT CANDLE
    CLOSED_CANDLE = 1   // PREVIOUS CANDLE
};

enum ENUM_ALERT_SIGNAL
{
    ON_BREAK_OUT = 0,    //ON BREAK OUT OF BANDS
    ON_BOUNCE_IN = 1,    //ON RE-ENTER IN BANDS
};

input string Comment1 = "========================"; // MQLTA Bollinger Bands With Alert
input string IndicatorName = "MQLTA-BBWA";          // Indicator Short Name

input string Comment2 = "========================"; // Indicator Parameters
input int    InpBandsPeriod = 20;                   // Bands Period
input int    InpBandsShift = 0;                     // Bands Shift
input double InpBandsDeviations = 2.0;              // Bands Deviations
input ENUM_APPLIED_PRICE InpBandsAppliedPrice = PRICE_CLOSE; // Bands Applied Price
input ENUM_ALERT_SIGNAL AlertSignal = ON_BREAK_OUT;          // Alert Signal When
input ENUM_CANDLE_TO_CHECK CandleToCheck = CURRENT_CANDLE;   // Candle To Use For Analysis
input bool IgnoreSameCandleCrosses = false;         // Ignore Same Candle Crosses
input int BarsToScan = 500;                         // Number Of Candles To Analyze

input string Comment_3 = "====================";    // Notification Options
input bool EnableNotify = false;                    // Enable Notifications Feature
input bool SendAlert = true;                        // Send Alert Notification
input bool SendApp = true;                          // Send Notification to Mobile
input bool SendEmail = true;                        // Send Notification via Email

input string Comment_4 = "====================";    // Drawing Options
input bool EnableDrawArrows = true;                 // Draw Signal Arrows
input int ArrowBuy = 241;                           // Buy Arrow Code
input int ArrowSell = 242;                          // Sell Arrow Code
input color ArrowBuyColor = clrGreen;               // Buy Arrow Color
input color ArrowSellColor = clrRed;                // Sell Arrow Color
input int ArrowSize = 3;                            // Arrow Size (1-5)

double BufferUpperBand[];
double BufferLowerBand[];
double BufferSMA[];

datetime LastNotificationTime;
ENUM_TRADE_SIGNAL LastNotificationDirection;
int Shift = 0;

int OnInit(void)
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    OnInitInitialization();
    if (!OnInitPreChecksPass())
    {
        return(INIT_FAILED);
    }

    InitialiseBuffers();

    return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (Bars(Symbol(), PERIOD_CURRENT) < InpBandsPeriod + InpBandsShift)
    {
        Print("Not Enough Historical Candles");
        return false;
    }

    bool IsNewCandle = CheckIfNewCandle();

    int counted_bars = 0;
    if (prev_calculated > 0) counted_bars = prev_calculated - 1;

    if (counted_bars < 0) return -1;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;

    if ((limit > BarsToScan) && (BarsToScan > 0))
    {
        limit = BarsToScan;
        if (rates_total < BarsToScan + InpBandsPeriod + InpBandsShift) limit = BarsToScan - 2 - InpBandsPeriod - InpBandsShift;
        if (limit <= 0)
        {
            Print("Need more historical data.");
            return 0;
        }
    }
    if (limit > rates_total - 2 - InpBandsPeriod - InpBandsShift) limit = rates_total - 2 - InpBandsPeriod - InpBandsShift;

    for (int i = limit; i >= 0; i--)
    {
        BufferSMA[i] = iBands(Symbol(), PERIOD_CURRENT, InpBandsPeriod, InpBandsDeviations, InpBandsShift, InpBandsAppliedPrice, MODE_MAIN, i);
        BufferUpperBand[i] = iBands(Symbol(), PERIOD_CURRENT, InpBandsPeriod, InpBandsDeviations, InpBandsShift, InpBandsAppliedPrice, MODE_UPPER, i);
        BufferLowerBand[i] = iBands(Symbol(), PERIOD_CURRENT, InpBandsPeriod, InpBandsDeviations, InpBandsShift, InpBandsAppliedPrice, MODE_LOWER, i);
    }

    if ((IsNewCandle) || (prev_calculated == 0))
    {
        if (EnableDrawArrows) DrawArrows(limit);
        CleanUpOldArrows();
    }

    if (EnableDrawArrows) DrawArrow(0);

    if (EnableNotify) NotifyHit();

    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

void OnInitInitialization()
{
    LastNotificationTime = TimeCurrent();
    Shift = CandleToCheck;
}

bool OnInitPreChecksPass()
{
    if (InpBandsPeriod <= 0)
    {
        Print("Wrong input parameter value: Bands Period = ", InpBandsPeriod);
        return false;
    }
    return true;
}

void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

void InitialiseBuffers()
{
    IndicatorDigits(Digits);
    SetIndexBuffer(0, BufferSMA);
    SetIndexShift(0, InpBandsShift);
    SetIndexBuffer(1, BufferUpperBand);
    SetIndexShift(1, InpBandsShift);
    SetIndexBuffer(2, BufferLowerBand);
    SetIndexShift(2, InpBandsShift);
    SetIndexDrawBegin(0, InpBandsPeriod + InpBandsShift);
    SetIndexDrawBegin(1, InpBandsPeriod + InpBandsShift);
    SetIndexDrawBegin(2, InpBandsPeriod + InpBandsShift);
}

datetime NewCandleTime = TimeCurrent();
bool CheckIfNewCandle()
{
    if (NewCandleTime == iTime(Symbol(), 0, 0)) return false;
    else
    {
        NewCandleTime = iTime(Symbol(), 0, 0);
        return true;
    }
}

// Check if it is a trade Signal 0 = Neutral, 1 = Buy, -1 = Sell.
ENUM_TRADE_SIGNAL IsSignal(int i)
{
    int j = i + Shift;
    if (AlertSignal == ON_BREAK_OUT)
    {
        // Classic close-only cross.
        if ((Close[j + 1] < BufferUpperBand[j + 1]) && (Close[j] > BufferUpperBand[j])) return SIGNAL_BUY;
        if ((Close[j + 1] > BufferLowerBand[j + 1]) && (Close[j] < BufferLowerBand[j])) return SIGNAL_SELL;
        // If the trader prefers to ignore signals when it's just the current candle that opened inside the bands and closed outside, while the previous candle closed on the same side as the current one.
        if (IgnoreSameCandleCrosses) return SIGNAL_NEUTRAL;
        // Current candle only cross (open/close).
        if ((Open[j] < BufferUpperBand[j]) && (Close[j] > BufferUpperBand[j])) return SIGNAL_BUY;
        if ((Open[j] > BufferLowerBand[j]) && (Close[j] < BufferLowerBand[j])) return SIGNAL_SELL;
    }
    if (AlertSignal == ON_BOUNCE_IN)
    {
        // Classic close-only cross.
        if ((Close[j + 1] < BufferLowerBand[j + 1]) && (Close[j] > BufferLowerBand[j])) return SIGNAL_BUY;
        if ((Close[j + 1] > BufferUpperBand[j + 1]) && (Close[j] < BufferUpperBand[j])) return SIGNAL_SELL;
        // If the trader prefers to ignore signals when it's just the current candle that opened outside the bands and closed inside, while the previous candle closed on the same side as the current one.
        if (IgnoreSameCandleCrosses) return SIGNAL_NEUTRAL;
        // Current candle only cross (open/close).
        if ((Open[j] < BufferLowerBand[j]) && (Close[j] > BufferLowerBand[j])) return SIGNAL_BUY;
        if ((Open[j] > BufferUpperBand[j]) && (Close[j] < BufferUpperBand[j])) return SIGNAL_SELL;
    }
    return SIGNAL_NEUTRAL;
}

void NotifyHit()
{
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if ((CandleToCheck == CLOSED_CANDLE) && (Time[0] <= LastNotificationTime)) return;
    ENUM_TRADE_SIGNAL Signal = IsSignal(0);
    if (Signal == SIGNAL_NEUTRAL)
    {
        LastNotificationDirection = Signal;
        return;
    }
    if (Signal == LastNotificationDirection) return;
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    string AlertText = IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " ";
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " - ";
    string Text = "";

    if ((AlertSignal == ON_BREAK_OUT) && (Signal != SIGNAL_NEUTRAL))
    {
        Text = "Price broke outside of the Bollinger Bands";
    }
    else if ((AlertSignal == ON_BOUNCE_IN) && (Signal != SIGNAL_NEUTRAL))
    {
        Text = "Price broke insode of the Bollinger Bands";
    }

    EmailBody += Text;
    AlertText += Text;
    AppText += Text;
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    LastNotificationTime = Time[0];
    LastNotificationDirection = Signal;
}


void DrawArrows(int limit)
{
    for (int i = limit - 1; i >= 1; i--)
    {
        DrawArrow(i);
    }
}

void RemoveArrows()
{
    ObjectsDeleteAll(ChartID(), IndicatorName + "-ARWS-");
}

void DrawArrow(int i)
{
    RemoveArrow(i);
    ENUM_TRADE_SIGNAL Signal = IsSignal(i);
    if (Signal == SIGNAL_NEUTRAL) return;
    datetime ArrowDate = iTime(Symbol(), 0, i);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    double ArrowPrice = 0;
    ENUM_OBJECT ArrowType = OBJ_ARROW;
    color ArrowColor = 0;
    int ArrowAnchor = 0;
    string ArrowDesc = "";
    if (Signal == SIGNAL_BUY)
    {
        ArrowPrice = iLow(Symbol(), Period(), i);
        ArrowType = (ENUM_OBJECT)ArrowBuy;
        ArrowColor = ArrowBuyColor;
        ArrowAnchor = ANCHOR_TOP;
        ArrowDesc = "BUY";
    }
    else if (Signal == SIGNAL_SELL)
    {
        ArrowPrice = iHigh(Symbol(), Period(), i);
        ArrowType = (ENUM_OBJECT)ArrowSell;
        ArrowColor = ArrowSellColor;
        ArrowAnchor = ANCHOR_BOTTOM;
        ArrowDesc = "SELL";
    }
    ObjectCreate(0, ArrowName, OBJ_ARROW, 0, ArrowDate, ArrowPrice);
    ObjectSetInteger(0, ArrowName, OBJPROP_COLOR, ArrowColor);
    ObjectSetInteger(0, ArrowName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, ArrowName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, ArrowName, OBJPROP_ANCHOR, ArrowAnchor);
    ObjectSetInteger(0, ArrowName, OBJPROP_ARROWCODE, ArrowType);
    ObjectSetInteger(0, ArrowName, OBJPROP_WIDTH, ArrowSize);
    ObjectSetInteger(0, ArrowName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, ArrowName, OBJPROP_BGCOLOR, ArrowColor);
    ObjectSetString(0, ArrowName, OBJPROP_TEXT, ArrowDesc);
}

void RemoveArrow(int i)
{
    datetime ArrowDate = iTime(Symbol(), 0, i);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    ObjectDelete(0, ArrowName);
}

// Delete all arrows that are older than BarsToScan bars.
void CleanUpOldArrows()
{
    int total = ObjectsTotal(ChartID(), 0, OBJ_ARROW);
    for (int i = total - 1; i >= 0; i--)
    {
        string ArrowName = ObjectName(ChartID(), i, 0, OBJ_ARROW);
        datetime time = (datetime)ObjectGetInteger(ChartID(), ArrowName, OBJPROP_TIME);
        int bar = iBarShift(Symbol(), Period(), time);
        if (bar >= BarsToScan) ObjectDelete(ChartID(), ArrowName);
    }
}
//+------------------------------------------------------------------+
