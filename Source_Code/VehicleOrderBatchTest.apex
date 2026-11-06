/**
 * @description Test suite for VehicleOrderBatch and VehicleOrderBatchScheduler.
 *              Validates asynchronous batch processing, single stock deduction,
 *              graceful exhaustion handling, and scheduling execution.
 * @group WhatsNext CRM Tests
 */
@isTest
private class VehicleOrderBatchTest {

    @testSetup
    static void setupTestData() {
        Vehicle_Dealer__c dealer = VehicleTestDataFactory.createDealer('Batch Test Hub', 'Delhi');
        Vehicle_Customer__c customer = VehicleTestDataFactory.createCustomer('Pooja Nair', 'pooja.nair@example.com');

        VehicleTestDataFactory.createVehicle('Punch EV Smart', 'EV', 2, 1100000, dealer.Id);
        VehicleTestDataFactory.createVehicle('Safari Gold', 'SUV', 0, 2600000, dealer.Id);
    }

    @isTest
    static void testBatchExecution_ConfirmsPendingOrdersWhenStockAvailable() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Punch EV Smart' LIMIT 1];
        Assert.areEqual(2, vehicle.Stock_Quantity__c, 'Precondition: vehicle has 2 units.');

        List<Vehicle_Order__c> pendingOrders = VehicleTestDataFactory.createOrders(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_PENDING, 2);
        insert pendingOrders;

        Test.startTest();
        VehicleOrderBatch batchJob = new VehicleOrderBatch();
        Database.executeBatch(batchJob, 50);
        Test.stopTest();

        List<Vehicle_Order__c> updatedOrders = [SELECT Id, Status__c FROM Vehicle_Order__c WHERE Id IN :pendingOrders];
        for (Vehicle_Order__c ord : updatedOrders) {
            Assert.areEqual(VehicleInventoryService.STATUS_CONFIRMED, ord.Status__c, 'Pending orders must be updated to Confirmed by batch.');
        }

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c, Status__c FROM Vehicle__c WHERE Id = :vehicle.Id];
        Assert.areEqual(0, freshVehicle.Stock_Quantity__c, 'Batch execution must deduct stock via trigger exactly once to 0.');
        Assert.areEqual(VehicleInventoryService.VEHICLE_STATUS_OUT_OF_STOCK, freshVehicle.Status__c, 'Vehicle status should update to Out of Stock.');
    }

    @isTest
    static void testBatchExecution_LeavesPendingWhenNoStock() {
        Vehicle_Customer__c customer = [SELECT Id FROM Vehicle_Customer__c LIMIT 1];
        Vehicle__c outOfStockVehicle = [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Vehicle_Name__c = 'Safari Gold' LIMIT 1];
        Assert.areEqual(0, outOfStockVehicle.Stock_Quantity__c, 'Precondition: vehicle has 0 units.');

        List<Vehicle_Order__c> pendingOrders = VehicleTestDataFactory.createOrders(customer.Id, outOfStockVehicle.Id, VehicleInventoryService.STATUS_PENDING, 2);
        insert pendingOrders;

        Test.startTest();
        VehicleOrderBatch batchJob = new VehicleOrderBatch();
        Database.executeBatch(batchJob, 50);
        Test.stopTest();

        List<Vehicle_Order__c> afterOrders = [SELECT Id, Status__c FROM Vehicle_Order__c WHERE Id IN :pendingOrders];
        for (Vehicle_Order__c ord : afterOrders) {
            Assert.areEqual(VehicleInventoryService.STATUS_PENDING, ord.Status__c, 'Pending orders should remain Pending when inventory is unavailable.');
        }

        Vehicle__c freshVehicle = [SELECT Stock_Quantity__c FROM Vehicle__c WHERE Id = :outOfStockVehicle.Id];
        Assert.areEqual(0, freshVehicle.Stock_Quantity__c, 'Vehicle stock must remain unchanged at 0.');
    }

    @isTest
    static void testSchedulerExecution_SchedulesSuccessfully() {
        Test.startTest();
        String jobId = VehicleOrderBatchScheduler.scheduleDailyAtNoon();
        Test.stopTest();

        Assert.isNotNull(jobId, 'Scheduled job ID must not be null.');

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, State FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(VehicleOrderBatchScheduler.DEFAULT_CRON_DAILY_NOON, ct.CronExpression, 'CRON expression must match daily noon schedule.');
    }
}
