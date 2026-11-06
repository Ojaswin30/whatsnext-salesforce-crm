# WhatsNext Vision Motors — Setup & Deployment Guide

This guide provides instructions to deploy, configure, and verify the **WhatsNext Vision Motors** CRM application on any Salesforce Developer Edition, Scratch Org, or Sandbox.

---

## Prerequisites
1. **Salesforce CLI (`sf`)**: Ensure version 2.x+ is installed (`sf --version`).
2. **Git**: Installed and authenticated.
3. **Salesforce Developer Edition Org**: Free developer account with System Administrator privileges.

---

## Step 1: Clone the Repository
```bash
git clone https://github.com/Ojaswin30/whatsnext-salesforce-crm.git
cd whatsnext-salesforce-crm
git checkout enhancement/apex-reliability
```

---

## Step 2: Authenticate Your Salesforce Org
Authorize your developer org with an alias (e.g., `WhatsNextDev`):
```bash
sf org login web --set-default --alias WhatsNextDev
```
Verify the connection:
```bash
sf org display --target-org WhatsNextDev
```

---

## Step 3: Deploy Metadata to the Org
Deploy all custom objects, fields, classes, triggers, tabs, flexipages, and LWC components:
```bash
sf project deploy start \
  --source-dir force-app \
  --target-org WhatsNextDev \
  --test-level RunSpecifiedTests \
  --tests VehicleOrderTriggerTest \
  --tests VehicleOrderBatchTest \
  --tests VehicleDashboardControllerTest \
  --wait 30
```

---

## Step 4: Assign the Permission Set
Grant yourself and operational users administrative access to all custom objects, the Apex dashboard controller, and custom tabs:
```bash
sf org assign permset --name WhatsNext_Vehicle_Manager --target-org WhatsNextDev
```

---

## Step 5: Seed Sample Data
To populate your org with dealership entities, inventory, and orders for testing:

Open Anonymous Apex in VS Code or CLI:
```bash
sf apex run --target-org WhatsNextDev
```
Paste and execute the following Apex script:
```apex
// 1. Create Dealerships
Vehicle_Dealer__c d1 = new Vehicle_Dealer__c(
    Dealer_Name__c = 'Vision Motors Mumbai Central',
    Dealer_Location__c = 'Mumbai',
    Phone__c = '+91 98765 43210',
    Email__c = 'mumbai.central@visionmotors.com'
);
Vehicle_Dealer__c d2 = new Vehicle_Dealer__c(
    Dealer_Name__c = 'Vision Motors Delhi Connaught',
    Dealer_Location__c = 'Delhi',
    Phone__c = '+91 98765 43211',
    Email__c = 'delhi.cp@visionmotors.com'
);
insert new List<Vehicle_Dealer__c>{ d1, d2 };

// 2. Create Customers
Vehicle_Customer__c c1 = new Vehicle_Customer__c(
    Customer_Name__c = 'Aarav Mehta',
    Email__c = 'aarav.mehta@example.com',
    Phone__c = '+91 98111 22334',
    Address__c = 'Flat 402, Sea Green Apartments, Worli, Mumbai',
    Preferred_Vehicle_Type__c = 'EV'
);
Vehicle_Customer__c c2 = new Vehicle_Customer__c(
    Customer_Name__c = 'Pooja Nair',
    Email__c = 'pooja.nair@example.com',
    Phone__c = '+91 98222 33445',
    Address__c = '12 Kasturba Gandhi Marg, New Delhi',
    Preferred_Vehicle_Type__c = 'SUV'
);
Vehicle_Customer__c c3 = new Vehicle_Customer__c(
    Customer_Name__c = 'Vikramaditya Roy',
    Email__c = 'vikram.roy@example.com',
    Phone__c = '+91 98333 44556',
    Address__c = '88 Park Street, Kolkata',
    Preferred_Vehicle_Type__c = 'Sedan'
);
insert new List<Vehicle_Customer__c>{ c1, c2, c3 };

// 3. Create Vehicles matching standard fleet
Vehicle__c v1 = new Vehicle__c(
    Vehicle_Name__c = 'Nexon EV Empowered',
    Vehicle_Model__c = 'EV',
    Stock_Quantity__c = 5,
    Price__c = 1549000,
    Status__c = 'Available',
    Dealer__c = d1.Id
);
Vehicle__c v2 = new Vehicle__c(
    Vehicle_Name__c = 'Harrier Fearless Dark',
    Vehicle_Model__c = 'SUV',
    Stock_Quantity__c = 3,
    Price__c = 2199000,
    Status__c = 'Available',
    Dealer__c = d1.Id
);
Vehicle__c v3 = new Vehicle__c(
    Vehicle_Name__c = 'Punch Adventure',
    Vehicle_Model__c = 'SUV',
    Stock_Quantity__c = 8,
    Price__c = 799000,
    Status__c = 'Available',
    Dealer__c = d2.Id
);
Vehicle__c v4 = new Vehicle__c(
    Vehicle_Name__c = 'Safari Accomplished Plus',
    Vehicle_Model__c = 'SUV',
    Stock_Quantity__c = 2,
    Price__c = 2499000,
    Status__c = 'Available',
    Dealer__c = d2.Id
);
Vehicle__c v5 = new Vehicle__c(
    Vehicle_Name__c = 'Altroz Racer Turbo',
    Vehicle_Model__c = 'Sedan',
    Stock_Quantity__c = 4,
    Price__c = 949000,
    Status__c = 'Available',
    Dealer__c = d1.Id
);
insert new List<Vehicle__c>{ v1, v2, v3, v4, v5 };

System.debug('Sample Dealership Data seeded successfully!');
```

---

## Step 6: Access the Application
1. In Salesforce, open the **App Launcher** (grid icon in the top left).
2. Search for and select **Vehicle Order Management**.
3. The first tab opens the **Vehicle Operations Dashboard** showing live metrics calculated directly from your newly seeded data!
