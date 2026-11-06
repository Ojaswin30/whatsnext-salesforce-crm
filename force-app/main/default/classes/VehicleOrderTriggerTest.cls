/**
 * @description Enterprise Apex test suite for VehicleOrderTrigger and VehicleInventoryService.
 *              Validates business transitions, bulk limits, concurrency locks, and edge cases.
 * @group WhatsNext CRM Tests
 */
@isTest
private class VehicleOrderTriggerTest {

    @testSetup
    static void setupTestData() {
        Vehicle_Dealer__c dealer = VehicleTestDataFactory.createDealer('Apex Test Dealership', 'Pune');
        Vehicle_Customer__c customer = VehicleTestDataFactory.createCustomer('Aarav Mehta', 'aarav.mehta@example.com');

        VehicleTestDataFactory.createVehicle('Nexon EV Max', 'EV', 10, 1600000, dealer.Id);
        VehicleTestDataFactory.createVehicle('Curvv EV Ultra', 'EV', 1, 1900000, dealer.Id);
        VehicleTestDataFactory.createVehicle('Harrier Dark Edition', 'SUV', 0, 2400000, dealer.Id);
    }

    @isTest
    static void testSuccessfulPendingOrderCreation() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Test.startTest();
        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_PENDING);
        insert order;
        Test.stopTest();

        Assert.isNotNull(order.Id, 'Order should be created with a valid ID.');
        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(10, freshVehicle.Stock_Quantity__c, 'Pending order should not decrement inventory.');
    }

    @isTest
    static void testSuccessfulConfirmedOrderCreation_DeductsStock() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Test.startTest();
        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED);
        insert order;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(9, freshVehicle.Stock_Quantity__c, 'Inserting a Confirmed order must deduct exactly 1 unit of stock.');
    }

    @isTest
    static void testOrderConfirmationFromPending_DeductsStockOnce() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_PENDING);
        insert order;

        Test.startTest();
        order.Status__c = VehicleInventoryService.STATUS_CONFIRMED;
        update order;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(9, freshVehicle.Stock_Quantity__c, 'Transitioning Pending -> Confirmed must deduct stock once.');
    }

    @isTest
    static void testRepeatedUpdateOnConfirmedOrder_DoesNotDeductAgain() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED);
        insert order;

        Vehicle__c afterInsertVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(9, afterInsertVehicle.Stock_Quantity__c, 'Initial stock should be 9.');

        Test.startTest();
        order.Order_Date__c = Date.today().addDays(-1);
        update order;
        Test.stopTest();

        Vehicle__c afterUpdateVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(9, afterUpdateVehicle.Stock_Quantity__c, 'Repeated updates to a Confirmed order must NOT deduct stock again.');
    }

    @isTest
    static void testInsufficientInventory_PreventsConfirmation() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c outOfStockVehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Harrier Dark Edition' LIMIT 1];
        Assert.areEqual(0, outOfStockVehicle.Stock_Quantity__c, 'Precondition: vehicle stock must be 0.');

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, outOfStockVehicle.Id, VehicleInventoryService.STATUS_CONFIRMED);

        Test.startTest();
        Database.SaveResult sr = Database.insert(order, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Order confirmation must fail when vehicle is out of stock.');
        Assert.isTrue(sr.getErrors()[0].getMessage().contains('out of stock'), 'Error message must clearly communicate stock exhaustion.');
        
        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :outOfStockVehicle.Id];
        Assert.areEqual(0, freshVehicle.Stock_Quantity__c, 'Stock quantity must remain unchanged after failed confirmation.');
    }

    @isTest
    static void testMultipleOrdersForSameVehicle_DeductsAccurately() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        List<Vehicle_Order__c> orders = VehicleTestDataFactory.createOrders(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED, 3);

        Test.startTest();
        insert orders;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(7, freshVehicle.Stock_Quantity__c, 'Three confirmed orders must decrement stock from 10 to 7.');
    }

    @isTest
    static void testMultipleOrdersExceedingStock_PartialRejection() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Curvv EV Ultra' LIMIT 1];
        Assert.areEqual(1, vehicle.Stock_Quantity__c, 'Precondition: only 1 unit in stock.');

        List<Vehicle_Order__c> orders = VehicleTestDataFactory.createOrders(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED, 2);

        Test.startTest();
        Database.SaveResult[] results = Database.insert(orders, false);
        Test.stopTest();

        Assert.isTrue(results[0].isSuccess(), 'First order should successfully claim available stock.');
        Assert.isFalse(results[1].isSuccess(), 'Second order must fail due to stock depletion.');

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(0, freshVehicle.Stock_Quantity__c, 'Stock quantity must be exactly 0.');
        Assert.areEqual(VehicleInventoryService.VEHICLE_STATUS_OUT_OF_STOCK, freshVehicle.Status__c, 'Vehicle status should transition to Out of Stock.');
    }

    @isTest
    static void testBulkInsertion200Orders_GovernorLimits() {
        Vehicle_Dealer__c dealer = [SELECT Id FROM Vehicle_Dealer__c LIMIT 1];
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c bulkVehicle = VehicleTestDataFactory.createVehicle('Bulk Test Vehicle', 'Sedan', 250, 1200000, dealer.Id);

        List<Vehicle_Order__c> bulkOrders = VehicleTestDataFactory.createOrders(customer.Id, bulkVehicle.Id, VehicleInventoryService.STATUS_CONFIRMED, 200);

        Test.startTest();
        insert bulkOrders;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :bulkVehicle.Id];
        Assert.areEqual(50, freshVehicle.Stock_Quantity__c, 'Bulk insertion of 200 confirmed orders must reduce stock from 250 to 50.');
        Assert.isTrue(Limits.getQueries() <= 50, 'SOQL queries consumed must remain well below governor limits.');
        Assert.isTrue(Limits.getDmlStatements() <= 50, 'DML statements consumed must remain well below governor limits.');
    }

    @isTest
    static void testOrderCancellation_RestoresInventory() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Curvv EV Ultra' LIMIT 1];

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED);
        insert order;

        Vehicle__c vehicleAfterConfirm = [SELECT Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(0, vehicleAfterConfirm.Stock_Quantity__c, 'Stock should be 0 after confirming the only unit.');
        Assert.areEqual(VehicleInventoryService.VEHICLE_STATUS_OUT_OF_STOCK, vehicleAfterConfirm.Status__c, 'Status should be Out of Stock.');

        Test.startTest();
        order.Status__c = VehicleInventoryService.STATUS_CANCELLED;
        update order;
        Test.stopTest();

        Vehicle__c vehicleAfterCancel = [SELECT Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(1, vehicleAfterCancel.Stock_Quantity__c, 'Cancelling a confirmed order must restore 1 unit to stock.');
        Assert.areEqual(VehicleInventoryService.VEHICLE_STATUS_AVAILABLE, vehicleAfterCancel.Status__c, 'Vehicle status should restore to Available.');
    }

    @isTest
    static void testPendingOrderCancellation_DoesNotRestoreInventory() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_PENDING);
        insert order;

        Test.startTest();
        order.Status__c = VehicleInventoryService.STATUS_CANCELLED;
        update order;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(10, freshVehicle.Stock_Quantity__c, 'Cancelling a Pending order must not restore stock.');
    }

    @isTest
    static void testCancelledToConfirmed_ReconfirmsSafely() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_CONFIRMED);
        insert order; // stock = 9

        order.Status__c = VehicleInventoryService.STATUS_CANCELLED;
        update order; // stock = 10

        Test.startTest();
        order.Status__c = VehicleInventoryService.STATUS_CONFIRMED;
        update order;
        Test.stopTest();

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(9, freshVehicle.Stock_Quantity__c, 'Re-confirming a cancelled order must deduct stock again safely.');
    }

    @isTest
    static void testOrderWithoutVehicle_HandlesGracefully() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle_Order__c order = VehicleTestDataFactory.createOrder(customer.Id, null, VehicleInventoryService.STATUS_CONFIRMED);

        Test.startTest();
        Database.SaveResult sr = Database.insert(order, false);
        Test.stopTest();

        Assert.isFalse(sr.isSuccess(), 'Order confirmation without vehicle must be prevented.');
        Assert.isTrue(sr.getErrors()[0].getMessage().contains('valid Vehicle reference is required'), 'Validation error message should match requirement.');
    }

    @isTest
    static void testVerifyStockAvailability_Success() {
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];

        Test.startTest();
        VehicleInventoryService.verifyStockAvailability(vehicle.Id, 2);
        Test.stopTest();

        Assert.isTrue(true, 'Stock availability verified successfully.');
    }

    @isTest
    static void testVerifyStockAvailability_InsufficientStockThrowsException() {
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Vehicle_Name__c = 'Curvv EV Ultra' LIMIT 1];

        Test.startTest();
        try {
            VehicleInventoryService.verifyStockAvailability(vehicle.Id, 5);
            Assert.fail('Expected VehicleInventoryException was not thrown for insufficient stock.');
        } catch (VehicleInventoryException ex) {
            Assert.isTrue(ex.getMessage().contains('Insufficient stock'), 'Exception message should report insufficient stock.');
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyStockAvailability_DiscontinuedThrowsException() {
        Vehicle_Dealer__c dealer = [SELECT Id FROM Vehicle_Dealer__c LIMIT 1];
        Vehicle__c discVehicle = VehicleTestDataFactory.createVehicle('Legacy Diesel Sedan', 'Sedan', 5, 800000, dealer.Id);
        discVehicle.Status__c = VehicleInventoryService.VEHICLE_STATUS_DISCONTINUED;
        update discVehicle;

        Test.startTest();
        try {
            VehicleInventoryService.verifyStockAvailability(discVehicle.Id, 1);
            Assert.fail('Expected VehicleInventoryException was not thrown for discontinued vehicle.');
        } catch (VehicleInventoryException ex) {
            Assert.isTrue(ex.getMessage().contains('discontinued'), 'Exception message should report discontinued status.');
        }
        Test.stopTest();
    }

    @isTest
    static void testVerifyStockAvailability_NullAndInvalidInputs() {
        Test.startTest();
        try {
            VehicleInventoryService.verifyStockAvailability(null, 1);
            Assert.fail('Expected VehicleInventoryException for null vehicle ID.');
        } catch (VehicleInventoryException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot be null'), 'Message should report null ID.');
        }

        try {
            Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Vehicle_Name__c = 'Nexon EV Max' LIMIT 1];
            VehicleInventoryService.verifyStockAvailability(vehicle.Id, 0);
            Assert.fail('Expected VehicleInventoryException for zero requested units.');
        } catch (VehicleInventoryException ex) {
            Assert.isTrue(ex.getMessage().contains('greater than zero'), 'Message should report invalid units.');
        }
        Test.stopTest();
    }
}
