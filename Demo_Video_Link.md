🎬 Demo Video Script: WhatsNext Vision Motors - Salesforce CRM
https://drive.google.com/file/d/1owrMI6A5gXZ24H4TBfWycFQbq3P4pW85/view?usp=sharing

---

1. Introduction (0:00 – 0:30)

> "Hi, I’m [Your Name], and this is a demo of my Salesforce CRM project titled WhatsNext Vision Motors: Shaping the Future of Mobility with Innovation and Excellence.
This application is built to streamline automotive operations — from managing vehicle inventory and dealers to automating orders, test drives, and service requests."




---

2. App Manager & Navigation Tabs (0:30 – 1:00)

> "Let’s begin with the Salesforce App Manager, where I created a custom app named WhatsNext Vision Motors.
This app includes custom tabs for managing Vehicles, Dealers, Customers, Orders, Test Drives, and Service Requests — all tied to custom objects."



Show App Manager > App open with visible tabs.


---

3. Custom Objects & Schema (1:00 – 2:30)

> "Here’s a quick overview of the data model:

Vehicle__c stores vehicle details

Vehicle_Dealer__c for authorized dealer info

Vehicle_Customer__c for customer details

Vehicle_Order__c to track purchases

Vehicle_Test_Drive__c for test drive scheduling

Vehicle_Service_Request__c for service requests


Each object contains key fields, lookups, and picklists. Let me show you the schema and fields now."



Go to Object Manager and open a few custom objects (especially Vehicle, Order, and Customer) and show their field definitions.


---

4. Automated Logic (2:30 – 3:30)

> "Now let’s move to automation.

I used Apex Triggers for validating stock before allowing an order.

Scheduled Apex jobs handle automatic stock updates.

Record-Triggered Flows update order statuses and send email reminders for scheduled test drives.


Let me quickly show you the Apex class and flows used."



Show the Apex trigger on Vehicle_Order__c, show the flow builder, and scheduled Apex in developer console or Apex classes.


---

5. End-to-End Demo (3:30 – 4:30)

> "Now, I’ll walk you through a complete flow:

First, I’ll create a new customer.

Then, I’ll place an order for a vehicle — if the stock is available, it will go through.

If not, it will show a validation error.

We’ll also look at how test drives are scheduled and how service requests can be raised for any vehicle."




Perform these live in the UI.


---

6. Conclusion (4:30 – 5:00)

> "This concludes the demo of WhatsNext Vision Motors on Salesforce.
Through custom objects, flows, Apex logic, and a clean tabbed interface, this CRM solution provides a complete, scalable system to manage automotive operations.
Thank you!"
