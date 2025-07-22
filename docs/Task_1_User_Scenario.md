# Task 1: User Scenario

## Project Overview

**WhatsNext Vision Motors** is a pioneer in the automotive industry, committed to enhancing mobility through innovation and customer-focused solutions. As part of its digital transformation, the company is implementing a Salesforce CRM system to streamline its operations and enhance customer experience.

---

## Objective

To design a customer-centric and efficient vehicle ordering system using Salesforce, focusing on:
- Nearest dealer assignment based on customer address.
- Order restrictions based on stock availability.
- Automatic updates to order statuses.
- Workflow automation for reminders and notifications.

---

## Users Involved

- **Customers:** Ordering vehicles, booking test drives.
- **Sales Reps:** Managing orders and communicating with customers.
- **Dealers:** Fulfilling assigned vehicle orders.
- **Inventory Managers:** Updating stock.
- **Admin Staff:** Monitoring CRM processes.

---

## Current Challenges

- Customers are unaware of the nearest dealer.
- Orders are mistakenly placed for out-of-stock vehicles.
- Manual updates cause delays and confusion.
- No proactive communication regarding order/test drive status.

---

## Requirements

1. **Dealer Assignment Automation**
   - Auto-select nearest dealer using customer’s address.
2. **Stock Validation**
   - Prevent placing orders for unavailable vehicles.
3. **Order Status Automation**
   - Set status to `Pending` or `Confirmed` based on vehicle stock.
4. **Workflow Automations**
   - Test drive reminders via email.
   - Notifications for low stock or backorders.

---

## Salesforce Modules Involved

- **Custom Objects:** Vehicle, Dealer, Customer, Order, Test Drive, Service Request.
- **Record-Triggered Flows:** For dealer assignment and validations.
- **Scheduled Flows:** For daily status updates.
- **Apex Triggers:** Business logic enforcement and modular validation.
- **Batch Apex:** Periodic stock checks and updates.
- **Email Alerts:** Test drive reminders and stock notifications.

---

## Expected Outcomes

| Area | Benefit |
|------|---------|
| Customer Experience | Transparent, quick, and location-aware ordering |
| Stock Management | Real-time vehicle availability |
| Workflow Efficiency | Reduced manual efforts with automation |
| Communication | Proactive email updates to customers and staff |
| Scalability | Modular design for future enhancements |

---

## File Location

This document is located in:  `docs/Task_1_User_Scenario.md`

---

## Next Steps

Proceed to:
- Task 2: Data Modeling
- Task 3: Flow Automation
- Task 4: Apex Triggers
- Task 5: Batch Processing
