//+------------------------------------------------------------------+
//|                                                     SAMOA.mq5    |
//|                  Dynamic Profit-Based Gold EA                    |
//|                     Broker: JustMarkets                          |
//|                     Symbol: XAUUSD.ecn                           |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//============================ INPUTS ==============================//
input double LotSize                = 0.01;

input double PendingGap             = 3.0;
input double ShiftDistance          = 3.0;

input double TakeProfitDistance     = 9.0;
input double InitialSLDistance      = 3.0;

input int    MagicNumber            = 777001;
input int    SlippagePoints          = 20;

input bool   UseVolatilityMode      = true;
input int    ATRPeriod              = 14;
input double HighVolatilityATR      = 15.0;

input int    MaxSpreadPoints        = 50;

//============================ GLOBALS =============================//
double CurrentBuyPrice  = 0;
double CurrentSellPrice = 0;

bool TradeWasBuy  = false;
bool TradeWasSell = false;
datetime LastM1BarTime = 0;

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);

   trade.SetDeviationInPoints(SlippagePoints);

   Print("SAMOA INITIALIZED");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageTrailingStop();

   CloseOnNewM1Bar();

   CheckTradeState();

   EnsurePendingOrders();
}

//+------------------------------------------------------------------+
//| Ensure Orders                                                    |
//+------------------------------------------------------------------+
void EnsurePendingOrders()
{
   if(HasOpenPosition())
      return;

   if(CountPendingOrders() > 0)
      return;

   if(CurrentSpreadTooHigh())
      return;

   CreatePendingOrders();
}

//+------------------------------------------------------------------+
//| Create Pending Orders                                            |
//+------------------------------------------------------------------+
void CreatePendingOrders()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int stopLevel =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   double minimumDistance =
      (stopLevel * _Point) + (2 * _Point);

   //================ BUY PRICE =================//

   CurrentBuyPrice =
      NormalizeDouble(
         ask + PendingGap + minimumDistance,
         _Digits
      );

   //================ SELL PRICE =================//

   CurrentSellPrice =
      NormalizeDouble(
         bid - PendingGap - minimumDistance,
         _Digits
      );

   //================ MONEY DISTANCES =================//

   double tpDistance = TakeProfitDistance;
   double slDistance = InitialSLDistance;

   //================ BUY LEVELS =================//

   double buySL =
      NormalizeDouble(
         CurrentBuyPrice - slDistance,
         _Digits
      );

   double buyTP =
      NormalizeDouble(
         CurrentBuyPrice + tpDistance,
         _Digits
      );

   //================ SELL LEVELS =================//

   double sellSL =
      NormalizeDouble(
         CurrentSellPrice + slDistance,
         _Digits
      );

   double sellTP =
      NormalizeDouble(
         CurrentSellPrice - tpDistance,
         _Digits
      );

   //================ BUY STOP =================//

   bool buyPlaced = trade.BuyStop(
      LotSize,
      CurrentBuyPrice,
      _Symbol,
      buySL,
      buyTP,
      ORDER_TIME_GTC,
      0,
      "SAMOA.AI"
   );

   if(buyPlaced)
   {
      Print("BUY STOP CREATED: ",
            CurrentBuyPrice);
   }
   else
   {
      Print("BUY STOP FAILED: ",
            trade.ResultRetcodeDescription());
   }

   Sleep(500);

   //================ REFRESH PRICES =================//

   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   CurrentSellPrice =
      NormalizeDouble(
         bid - PendingGap - minimumDistance,
         _Digits
      );

   sellSL =
      NormalizeDouble(
         CurrentSellPrice + slDistance,
         _Digits
      );

   sellTP =
      NormalizeDouble(
         CurrentSellPrice - tpDistance,
         _Digits
      );

   //================ SELL STOP =================//

   bool sellPlaced = trade.SellStop(
      LotSize,
      CurrentSellPrice,
      _Symbol,
      sellSL,
      sellTP,
      ORDER_TIME_GTC,
      0,
      "SAMOA.AI"
   );

   if(sellPlaced)
   {
      Print("SELL STOP CREATED: ",
            CurrentSellPrice);
   }
   else
   {
      Print("SELL STOP FAILED: ",
            trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check Trade State                                                |
//+------------------------------------------------------------------+
void CheckTradeState()
{
   static bool hadPosition = false;

   bool hasPosition = HasOpenPosition();

   //================ POSITION OPENED =================//

   if(hasPosition && !hadPosition)
   {
      DeleteOppositePending();
   }

   //================ POSITION CLOSED =================//

   if(!hasPosition && hadPosition)
   {
      if(TradeWasBuy)
      {
         CurrentBuyPrice  += ShiftDistance;
         CurrentSellPrice += ShiftDistance;

         TradeWasBuy = false;

         Print("BUY CLOSED -> SHIFT UP");
      }

      if(TradeWasSell)
      {
         CurrentBuyPrice  -= ShiftDistance;
         CurrentSellPrice -= ShiftDistance;

         TradeWasSell = false;

         Print("SELL CLOSED -> SHIFT DOWN");
      }

      Sleep(1000);
   }

   hadPosition = hasPosition;

   DetectTradeDirection();
}

//+------------------------------------------------------------------+
//| Detect Trade Direction                                           |
//+------------------------------------------------------------------+
void DetectTradeDirection()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)
         != MagicNumber)
      {
         continue;
      }

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
      {
         TradeWasBuy = true;
         TradeWasSell = false;
      }

      if(type == POSITION_TYPE_SELL)
      {
         TradeWasSell = true;
         TradeWasBuy = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Delete Opposite Pending                                          |
//+------------------------------------------------------------------+
void DeleteOppositePending()
{
   ENUM_POSITION_TYPE activeType =
      GetOpenPositionType();

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong ticket = OrderGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(OrderGetInteger(ORDER_MAGIC)
         != MagicNumber)
      {
         continue;
      }

      ENUM_ORDER_TYPE orderType =
         (ENUM_ORDER_TYPE)
         OrderGetInteger(ORDER_TYPE);

      if(activeType == POSITION_TYPE_BUY &&
         orderType == ORDER_TYPE_SELL_STOP)
      {
         trade.OrderDelete(ticket);
      }

      if(activeType == POSITION_TYPE_SELL &&
         orderType == ORDER_TYPE_BUY_STOP)
      {
         trade.OrderDelete(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Profit-Based Trailing Stop                                       |
//+------------------------------------------------------------------+

void ManageTrailingStop()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket<=0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL=PositionGetDouble(POSITION_SL);
      double currentTP=PositionGetDouble(POSITION_TP);

      double price=(type==POSITION_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                   : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      double move=(type==POSITION_TYPE_BUY)
                  ? price-entry
                  : entry-price;

      double desiredSL=currentSL;

      if(move>=0.10)
      {
         if(move<0.20)
         {
            desiredSL=(type==POSITION_TYPE_BUY)?entry-1.00:entry+1.00;
         }
         else
         {
            desiredSL=(type==POSITION_TYPE_BUY)?
                      price-1.10:
                      price+1.10;
         }
      }

      desiredSL=NormalizeDouble(desiredSL,_Digits);

      if(type==POSITION_TYPE_BUY && desiredSL>currentSL)
         trade.PositionModify(ticket,desiredSL,currentTP);

      if(type==POSITION_TYPE_SELL &&
         (currentSL==0 || desiredSL<currentSL))
         trade.PositionModify(ticket,desiredSL,currentTP);
   }
}


//+------------------------------------------------------------------+
//| Count Pending Orders                                             |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int total = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong ticket = OrderGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(OrderGetInteger(ORDER_MAGIC)
         != MagicNumber)
      {
         continue;
      }

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)
         OrderGetInteger(ORDER_TYPE);

      if(type == ORDER_TYPE_BUY_STOP ||
         type == ORDER_TYPE_SELL_STOP)
      {
         total++;
      }
   }

   return total;
}

//+------------------------------------------------------------------+
//| Has Open Position                                                |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)
         == MagicNumber)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get Open Position Type                                           |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetOpenPositionType()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)
         == MagicNumber)
      {
         return (ENUM_POSITION_TYPE)
            PositionGetInteger(POSITION_TYPE);
      }
   }

   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Spread Filter                                                    |
//+------------------------------------------------------------------+
bool CurrentSpreadTooHigh()
{
   double spread =
      (SymbolInfoDouble(_Symbol,SYMBOL_ASK) -
       SymbolInfoDouble(_Symbol,SYMBOL_BID))
       / _Point;

   if(spread > MaxSpreadPoints)
   {
      Print("SPREAD TOO HIGH: ", spread);
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close position at every new M1 candle                            |
//+------------------------------------------------------------------+
void CloseOnNewM1Bar()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);

   if(currentBar == 0)
      return;

   if(LastM1BarTime == 0)
   {
      LastM1BarTime = currentBar;
      return;
   }

   if(currentBar != LastM1BarTime)
   {
      LastM1BarTime = currentBar;

      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket <= 0)
            continue;

         if(!PositionSelectByTicket(ticket))
            continue;

         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}
