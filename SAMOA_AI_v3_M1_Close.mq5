#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//================ INPUTS =================//

input double LotSize            = 0.01;
input double PendingGap         = 1.70;
input double InitialSLDistance  = 0.50;
input double TrailingDistance   = 0.50;
input double TrailingStep       = 0.10;

input double MaxSpread          = 0.30;

input int    MaxSlippagePoints  = 20;
input int    RetryAttempts      = 5;

input ulong  MagicNumber        = 777777;

//========================================//

double LastBuySL  = 0;
double LastSellSL = 0;

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageTriggeredOrder();
   ManageTrailingStop();

   if(!HasOpenPosition() && CountPendingOrders()==0)
   {
      PlacePendingOrders();
   }
}

//+------------------------------------------------------------------+
//| Open Position Check                                              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==(long)MagicNumber &&
            PositionGetString(POSITION_SYMBOL)==_Symbol)
         {
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Pending Orders Count                                             |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int count=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC)==(long)MagicNumber &&
            OrderGetString(ORDER_SYMBOL)==_Symbol)
         {
            ENUM_ORDER_TYPE type=
               (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

            if(type==ORDER_TYPE_BUY_STOP ||
               type==ORDER_TYPE_SELL_STOP)
            {
               count++;
            }
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Spread Filter                                                    |
//+------------------------------------------------------------------+
bool SpreadOK()
{
   double spread =
      SymbolInfoDouble(_Symbol,SYMBOL_ASK)
      - SymbolInfoDouble(_Symbol,SYMBOL_BID);

   return(spread<=MaxSpread);
}

//+------------------------------------------------------------------+
//| Broker StopLevel Validation                                      |
//+------------------------------------------------------------------+
bool StopLevelOK(double buyPrice,double sellPrice)
{
   int stopLevel =
      (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);

   double minDistance =
      stopLevel * _Point;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if((buyPrice-ask)<minDistance)
      return false;

   if((bid-sellPrice)<minDistance)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Place Pending Orders                                             |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if(!SpreadOK())
      return;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double buyPrice =
      NormalizeDouble(ask + PendingGap/2.0,_Digits);

   double sellPrice =
      NormalizeDouble(bid - PendingGap/2.0,_Digits);

   if(!StopLevelOK(buyPrice,sellPrice))
      return;

   double buySL =
      NormalizeDouble(buyPrice-InitialSLDistance,_Digits);

   double sellSL =
      NormalizeDouble(sellPrice+InitialSLDistance,_Digits);

   bool buyPlaced=false;
   bool sellPlaced=false;

   for(int i=0;i<RetryAttempts;i++)
   {
      if(trade.BuyStop(
            LotSize,
            buyPrice,
            _Symbol,
            buySL,
            0,
            ORDER_TIME_GTC,
            0,
            "Breakout Buy"))
      {
         buyPlaced=true;
         break;
      }

      Sleep(300);
   }

   for(int i=0;i<RetryAttempts;i++)
   {
      if(trade.SellStop(
            LotSize,
            sellPrice,
            _Symbol,
            sellSL,
            0,
            ORDER_TIME_GTC,
            0,
            "Breakout Sell"))
      {
         sellPlaced=true;
         break;
      }

      Sleep(300);
   }

   if(buyPlaced)
      Print("Buy Stop Created");

   if(sellPlaced)
      Print("Sell Stop Created");
}

//+------------------------------------------------------------------+
//| Delete Opposite Pending Order                                    |
//+------------------------------------------------------------------+
void ManageTriggeredOrder()
{
   if(!HasOpenPosition())
      return;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC)!=(long)MagicNumber)
            continue;

         if(OrderGetString(ORDER_SYMBOL)!=_Symbol)
            continue;

         trade.OrderDelete(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC)!=(long)MagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;

      ENUM_POSITION_TYPE type=
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double currentSL=
         PositionGetDouble(POSITION_SL);

      double tp=
         PositionGetDouble(POSITION_TP);

      if(type==POSITION_TYPE_BUY)
      {
         double bid=
            SymbolInfoDouble(_Symbol,SYMBOL_BID);

         double newSL=
            NormalizeDouble(
               bid-TrailingDistance,
               _Digits);

         if(newSL-currentSL>=TrailingStep)
         {
            trade.PositionModify(ticket,newSL,tp);
         }
      }

      if(type==POSITION_TYPE_SELL)
      {
         double ask=
            SymbolInfoDouble(_Symbol,SYMBOL_ASK);

         double newSL=
            NormalizeDouble(
               ask+TrailingDistance,
               _Digits);

         if(currentSL-newSL>=TrailingStep)
         {
            trade.PositionModify(ticket,newSL,tp);
         }
      }
   }
}