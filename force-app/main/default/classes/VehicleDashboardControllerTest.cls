/**
 * @description Comprehensive unit test suite for VehicleDashboardController.
 *              Validates data calculations, aggregation wrappers, sorting logic,
 *              low-stock identification, order analytics, and empty state resilience.
 * @group WhatsNext CRM Tests
 */
@isTest
private class VehicleDashboardControllerTest {

    @testSetup
    static void setupTestData() {
        Vehicle_Dealer__c dealer1 = VehicleTestDataFactory.createDealer('Apex Motors Mumbai', 'Mumbai');
        Vehicle_Dealer__c dealer2 = VehicleTestDataFactory.createDealer('Vision Motors Delhi', 'Delhi');

        Vehicle_Customer__c customer1 = VehicleTestDataFactory.createCustomer('Aarav Mehta', 'aarav.mehta@example.com');
        Vehicle_Customer__c customer2 = VehicleTestDataFactory.createCustomer('Diya Sharma', 'diya.sharma@example.com');

        // Create sample vehicles matching the mockup models
        Vehicle__c nexon = VehicleTestDataFactory.createVehicle('Nexon EV Empowered', 'EV', 5, 1500000, dealer1.Id);
        Vehicle__c harrier = VehicleTestDataFactory.createVehicle('Harrier Fearless', 'SUV', 3, 2200000, dealer1.Id);
        Vehicle__c punch = VehicleTestDataFactory.createVehicle('Punch Adventure', 'SUV', 8, 800000, dealer2.Id);
        Vehicle__c safari = VehicleTestDataFactory.createVehicle('Safari Accomplished', 'SUV', 2, 2500000, dealer2.Id);
        Vehicle__c altroz = VehicleTestDataFactory.createVehicle('Altroz Racer', 'Sedan', 4, 950000, dealer1.Id);
        Vehicle__c outOfStockCar = VehicleTestDataFactory.createVehicle('Curvv EV Concept', 'EV', 0, 1900000, dealer2.Id);

        // Create sample orders across statuses
        // 1 Confirmed order
        Vehicle_Order__c confirmedOrder = VehicleTestDataFactory.createOrder(customer1.Id, nexon.Id, VehicleInventoryService.STATUS_CONFIRMED);
        insert confirmedOrder;

        // 2 Pending orders
        List<Vehicle_Order__c> pendingOrders = VehicleTestDataFactory.createOrders(customer2.Id, harrier.Id, VehicleInventoryService.STATUS_PENDING, 2);
        insert pendingOrders;

        // 1 Delivered order
        Vehicle_Order__c deliveredOrder = VehicleTestDataFactory.createOrder(customer1.Id, punch.Id, VehicleInventoryService.STATUS_DELIVERED);
        insert deliveredOrder;

        // 1 Cancelled order
        Vehicle_Order__c cancelledOrder = VehicleTestDataFactory.createOrder(customer2.Id, altroz.Id, VehicleInventoryService.STATUS_CANCELLED);
        insert cancelledOrder;
    }

    @isTest
    static void testGetDashboardData_ReturnsAggregatedMetrics() {
        Test.startTest();
        VehicleDashboardController.DashboardDataWrapper data = VehicleDashboardController.getDashboardData();
        Test.stopTest();

        Assert.isNotNull(data, 'Dashboard data wrapper should not be null.');
        Assert.areEqual(6, data.totalVehicles, 'Expected 6 vehicles total.');
        Assert.areEqual(2, data.totalCustomers, 'Expected 2 registered customers.');
        Assert.isTrue(data.availableUnits > 0, 'Available units should be greater than zero.');
        Assert.areEqual(2, data.pendingOrders, 'Expected 2 pending orders.');
        Assert.areEqual(1, data.confirmedOrders, 'Expected 1 confirmed order.');
        Assert.areEqual(1, data.deliveredOrders, 'Expected 1 delivered order.');
        Assert.areEqual(1, data.cancelledOrders, 'Expected 1 cancelled order.');
        Assert.areEqual(5, data.totalOrders, 'Expected 5 total orders across statuses.');

        // Verify low stock calculation
        Assert.isTrue(data.lowStockCount >= 1, 'Expected at least 1 low stock vehicle.');
        Assert.isTrue(data.outOfStockCount >= 1, 'Expected at least 1 out of stock vehicle.');
        Assert.isFalse(data.inventoryMetrics.isEmpty(), 'Inventory metrics list should be populated.');
        Assert.isNotNull(data.orderAnalytics, 'Order analytics should be populated.');
        Assert.isFalse(data.lowStockAlerts.isEmpty(), 'Low stock alerts list should be populated.');
        Assert.isFalse(data.dealerPerformance.isEmpty(), 'Dealer performance list should be populated.');
    }

    @isTest
    static void testGetInventoryMetrics_CalculatesPercentagesAndBadges() {
        Test.startTest();
        List<VehicleDashboardController.VehicleInventorySummary> metrics = VehicleDashboardController.getInventoryMetrics();
        Test.stopTest();

        Assert.isNotNull(metrics, 'Metrics list should not be null.');
        Assert.areEqual(6, metrics.size(), 'Expected 6 vehicles in inventory list.');

        for (VehicleDashboardController.VehicleInventorySummary item : metrics) {
            Assert.isNotNull(item.vehicleId, 'Vehicle ID should not be null.');
            Assert.isNotNull(item.vehicleName, 'Vehicle Name should not be blank.');
            Assert.isNotNull(item.model, 'Model should not be blank.');
            Assert.isNotNull(item.badgeClass, 'Badge class must be assigned.');
            Assert.isNotNull(item.progressVariant, 'Progress variant must be assigned.');
            Assert.isTrue(item.percentage >= 0 && item.percentage <= 100, 'Percentage must be between 0 and 100.');
        }
    }

    @isTest
    static void testGetOrderAnalytics_DistributesStatusesAccurately() {
        Test.startTest();
        VehicleDashboardController.OrderAnalyticsSummary summary = VehicleDashboardController.getOrderAnalytics();
        Test.stopTest();

        Assert.isNotNull(summary, 'Order analytics summary should not be null.');
        Assert.areEqual(5, summary.totalOrders, 'Total orders should be 5.');
        Assert.areEqual(2, summary.pendingCount, 'Pending count should be 2.');
        Assert.areEqual(1, summary.confirmedCount, 'Confirmed count should be 1.');
        Assert.areEqual(1, summary.deliveredCount, 'Delivered count should be 1.');
        Assert.areEqual(1, summary.cancelledCount, 'Cancelled count should be 1.');
        Assert.isTrue(summary.recentOrders.size() > 0, 'Recent orders list should contain items.');

        for (VehicleDashboardController.RecentOrderItem item : summary.recentOrders) {
            Assert.isNotNull(item.orderId, 'Order Id should not be null.');
            Assert.isNotNull(item.customerName, 'Customer Name should be populated.');
            Assert.isNotNull(item.vehicleName, 'Vehicle Name should be populated.');
            Assert.isNotNull(item.statusBadgeClass, 'Status badge class should be set.');
        }
    }

    @isTest
    static void testGetLowStockAlerts_IdentifiesExhaustedAndLowInventory() {
        Test.startTest();
        List<VehicleDashboardController.LowStockAlert> alerts = VehicleDashboardController.getLowStockAlerts();
        Test.stopTest();

        Assert.isNotNull(alerts, 'Alerts list should not be null.');
        Assert.isFalse(alerts.isEmpty(), 'Low stock alerts should identify low stock cars.');

        Boolean foundCritical = false;
        Boolean foundWarning = false;

        for (VehicleDashboardController.LowStockAlert alert : alerts) {
            Assert.isNotNull(alert.vehicleId, 'Alert vehicle ID must be present.');
            Assert.isNotNull(alert.alertMessage, 'Alert message must be present.');
            Assert.isTrue(alert.stockQuantity <= VehicleDashboardController.DEFAULT_LOW_STOCK_THRESHOLD, 
                'Stock quantity must be at or below default threshold.');

            if ('critical'.equalsIgnoreCase(alert.severity)) {
                foundCritical = true;
                Assert.areEqual(0, alert.stockQuantity, 'Critical alert must have 0 stock.');
            }
            if ('warning'.equalsIgnoreCase(alert.severity)) {
                foundWarning = true;
                Assert.isTrue(alert.stockQuantity > 0, 'Warning alert must have stock > 0.');
            }
        }

        Assert.isTrue(foundCritical, 'Must have at least one critical alert for Curvv EV Concept.');
        Assert.isTrue(foundWarning, 'Must have at least one warning alert for Safari or Harrier.');
    }

    @isTest
    static void testGetDealerPerformance_AggregatesInventoryAndOrdersPerDealer() {
        Test.startTest();
        List<VehicleDashboardController.DealerPerformanceSummary> dealerSummaries = VehicleDashboardController.getDealerPerformance();
        Test.stopTest();

        Assert.isNotNull(dealerSummaries, 'Dealer summaries list should not be null.');
        Assert.areEqual(2, dealerSummaries.size(), 'Expected 2 dealers.');

        for (VehicleDashboardController.DealerPerformanceSummary d : dealerSummaries) {
            Assert.isNotNull(d.dealerId, 'Dealer ID should not be null.');
            Assert.isNotNull(d.dealerName, 'Dealer name should not be blank.');
            Assert.isTrue(d.totalVehicles > 0, 'Each test dealer should have assigned vehicles.');
            Assert.isTrue(d.totalStockUnits >= 0, 'Stock units should be non-negative.');
        }
    }

    @isTest
    static void testEmptyOrg_ResilienceWithoutExceptions() {
        // Delete all orders, vehicles, customers, dealers to test empty database behavior
        delete [SELECT Id FROM Vehicle_Order__c];
        delete [SELECT Id FROM Vehicle__c];
        delete [SELECT Id FROM Vehicle_Customer__c];
        delete [SELECT Id FROM Vehicle_Dealer__c];

        Test.startTest();
        VehicleDashboardController.DashboardDataWrapper data = VehicleDashboardController.getDashboardData();
        Test.stopTest();

        Assert.isNotNull(data, 'Dashboard data wrapper should not be null even on empty org.');
        Assert.areEqual(0, data.totalVehicles, 'Total vehicles should be 0.');
        Assert.areEqual(0, data.availableUnits, 'Available units should be 0.');
        Assert.areEqual(0, data.pendingOrders, 'Pending orders should be 0.');
        Assert.areEqual(0, data.totalCustomers, 'Total customers should be 0.');
        Assert.areEqual(0, data.totalOrders, 'Total orders should be 0.');
        Assert.areEqual(0, data.lowStockCount, 'Low stock count should be 0.');
        Assert.areEqual(0, data.outOfStockCount, 'Out of stock count should be 0.');
        Assert.isTrue(data.inventoryMetrics.isEmpty(), 'Inventory metrics should be empty.');
        Assert.isTrue(data.lowStockAlerts.isEmpty(), 'Low stock alerts should be empty.');
        Assert.isTrue(data.dealerPerformance.isEmpty(), 'Dealer performance should be empty.');
    }
}
