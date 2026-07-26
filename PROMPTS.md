# PROMPTS.md

# XAUUSD Breakout Expert Advisor (MQL5)

## Objective

Design and implement a production-ready MetaTrader 5 (MQL5) Expert Advisor that automatically trades XAUUSD using pending breakout orders.

The EA should prioritize execution reliability, risk consistency, and automatic order management.

---

# Strategy Overview

The EA continuously waits for breakouts by maintaining one Buy Stop and one Sell Stop pending order around the current market price.

Only one market position may exist at any time.

Once a trade is activated, the opposite pending order must be deleted immediately.

After the trade closes, a new breakout setup must be created automatically.

---

# Pending Order Placement

The pending orders should always remain symmetrical around the current market.

Example:

Current Market Price

5000.00

PendingGap = 1.70

Buy Stop

5000.85

Sell Stop

4999.15

Distance between pending orders:

1.70

The pending gap must be configurable.

---

# Inputs

```mql5
input double LotSize            = 0.01;
input double PendingGap         = 1.70;
input double InitialSLDistance  = 0.50;
input double TrailingDistance   = 0.50;
input double TrailingStep       = 0.10;

input double MaxSpread          = 0.30;

input int MaxSlippagePoints     = 15;

input ulong MagicNumber         = 777777;
```

---

# Initial Stop Loss

Immediately after a pending order becomes a market position, the position must have an initial stop loss.

BUY

```
SL = EntryPrice - 0.50
```

SELL

```
SL = EntryPrice + 0.50
```

All distances represent actual price values rather than broker points.

---

# Entry Slippage Protection

The EA must detect the actual executed price after a pending order becomes a market position.

Example:

Pending Buy Stop

```
5000.50
```

Broker executes at

```
5001.00
```

Instead of leaving the stop at

```
4999.50
```

the EA must immediately recalculate the stop loss using the actual fill price.

```
SL = ExecutedPrice - InitialSLDistance
```

This ensures consistent monetary risk regardless of execution slippage.

---

# Trailing Stop Logic

The trailing stop begins immediately after entry.

There is no activation threshold.

The stop loss must:

- Move only after every favorable 0.10 price movement.
- Always remain exactly 0.50 behind current market price.
- Never move backwards.

BUY Example

Entry

```
5000.00
```

Initial SL

```
4999.50
```

Price movement

```
5000.10
SL = 4999.60

5000.20
SL = 4999.70

5000.30
SL = 4999.80

5000.40
SL = 4999.90

5000.50
SL = 5000.00
```

SELL Example

Entry

```
5000.00
```

Initial SL

```
5000.50
```

Price movement

```
4999.90
SL = 5000.40

4999.80
SL = 5000.30

4999.70
SL = 5000.20
```

---

# Order Management

If Buy Stop triggers

Delete Sell Stop immediately.

If Sell Stop triggers

Delete Buy Stop immediately.

Only one position may remain open.

---

# Automatic Recreation

Whenever a position closes by

- Stop Loss
- Manual close
- Broker close

the EA must immediately recreate both pending orders around the current market.

---

# Risk Controls

Implement:

- Magic Number filtering
- One-trade-at-a-time protection
- Spread filter
- Broker StopLevel validation
- Slippage control
- Duplicate pending order prevention
- Retry mechanism for failed order placement
- Cleanup of partially created pending orders

---

# Execution Reliability

Avoid blocking functions such as

```
Sleep()
```

inside `OnTick()`.

Instead, implement timestamp-based retry logic.

---

# Logging

Log:

- Requested pending order prices
- Executed fill prices
- Requested stop-loss values
- Applied stop-loss values
- Spread
- Slippage
- Broker return codes
- Position modifications

This information is used to diagnose execution quality and distinguish between market gaps and execution latency.

---

# Design Goals

The implementation should emphasize:

- Robust order handling
- Consistent risk management
- Fast breakout execution
- Low latency
- Recovery after broker failures
- Clean, modular MQL5 architecture
- Production-ready code quality

---

# Expected Outcome

The resulting Expert Advisor should be capable of:

- Trading XAUUSD breakout movements
- Maintaining symmetrical pending orders
- Protecting capital through dynamic stop-loss management
- Automatically recovering from execution failures
- Preserving intended risk even when entry slippage occurs
- Operating continuously without manual intervention
