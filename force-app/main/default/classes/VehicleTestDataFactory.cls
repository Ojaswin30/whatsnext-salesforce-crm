/**
 * @description Centralized Test Data Factory for WhatsNext CRM test suites.
 *              Generates isolated in-memory and committed test entities with standard defaults.
 * @group WhatsNext CRM Tests
 */
@isTest
public inherited sharing class VehicleTestDataFactory {

    public static Vehicle_Dealer__c createDealer(String name, String location) {
        Vehicle_Dealer__c dealer = new Vehicle_Dealer__c(
            Dealer_Name__c = name,
            Dealer_Location__c = location,
            Phone__c = '9876543210',
            Email__c = 'dealer@whatsnext.com'
        );
        insert dealer;
        return dealer;
    }

    public static Vehicle_Customer__c createCustomer(String name, String email) {
        Vehicle_Customer__c customer = new Vehicle_Customer__c(
            Customer_Name__c = name,
            Email__c = email,
            Phone__c = '9876543210',
            Address__c = '123 Marine Drive, Mumbai',
            Preferred_Vehicle_Type__c = 'EV'
        );
        insert customer;
        return customer;
    }

    public static Vehicle__c createVehicle(String name, String model, Decimal stock, Decimal price, Id dealerId) {
        Vehicle__c vehicle = new Vehicle__c(
            Vehicle_Name__c = name,
            Vehicle_Model__c = model,
            Stock_Quantity__c = stock,
            Price__c = price,
            Dealer__c = dealerId,
            Status__c = (stock > 0) ? VehicleInventoryService.VEHICLE_STATUS_AVAILABLE : VehicleInventoryService.VEHICLE_STATUS_OUT_OF_STOCK
        );
        insert vehicle;
        return vehicle;
    }

    public static Vehicle_Order__c createOrder(Id customerId, Id vehicleId, String status) {
        return new Vehicle_Order__c(
            Customer__c = customerId,
            Vehicle__c = vehicleId,
            Order_Date__c = Date.today(),
            Status__c = status
        );
    }

    public static List<Vehicle_Order__c> createOrders(Id customerId, Id vehicleId, String status, Integer count) {
        List<Vehicle_Order__c> orders = new List<Vehicle_Order__c>();
        for (Integer i = 0; i < count; i++) {
            orders.add(new Vehicle_Order__c(
                Customer__c = customerId,
                Vehicle__c = vehicleId,
                Order_Date__c = Date.today(),
                Status__c = status
            ));
        }
        return orders;
    }

    @isTest
    static void testFactorySanity() {
        Vehicle_Dealer__c dealer = createDealer('Sanity Dealer', 'Mumbai');
        Assert.isNotNull(dealer.Id, 'Dealer should be created with a valid Id.');

        Vehicle_Customer__c customer = createCustomer('Sanity Customer', 'sanity@whatsnext.com');
        Assert.isNotNull(customer.Id, 'Customer should be created with a valid Id.');

        Vehicle__c vehicle = createVehicle('Sanity EV', 'EV', 5, 1000000, dealer.Id);
        Assert.isNotNull(vehicle.Id, 'Vehicle should be created with a valid Id.');

        Vehicle_Order__c order = createOrder(customer.Id, vehicle.Id, VehicleInventoryService.STATUS_PENDING);
        Assert.areEqual(VehicleInventoryService.STATUS_PENDING, order.Status__c, 'Order status should be Pending.');
    }
}
