/**
 * @description Authoritative service layer for Vehicle inventory management, concurrency locking,
 *              bulk stock deductions, and status transition validations.
 * @group WhatsNext CRM
 */
public with sharing class VehicleInventoryService {

    public static final String STATUS_PENDING    = 'Pending';
    public static final String STATUS_CONFIRMED  = 'Confirmed';
    public static final String STATUS_DELIVERED  = 'Delivered';
    public static final String STATUS_CANCELLED  = 'Cancelled';
    public static final String STATUS_CANCELED   = 'Canceled';

    public static final String VEHICLE_STATUS_AVAILABLE    = 'Available';
    public static final String VEHICLE_STATUS_OUT_OF_STOCK = 'Out of Stock';
    public static final String VEHICLE_STATUS_DISCONTINUED = 'Discontinued';

    /**
     * @description Programmatic validation that verifies vehicle stock availability
     *              and throws a VehicleInventoryException if the vehicle is out of stock,
     *              discontinued, or does not have sufficient units for the requested quantity.
     * @param vehicleId ID of the vehicle to check
     * @param requestedUnits Number of units requested
     */
    public static void verifyStockAvailability(Id vehicleId, Integer requestedUnits) {
        if (vehicleId == null) {
            throw new VehicleInventoryException('Vehicle ID cannot be null.');
        }
        if (requestedUnits == null || requestedUnits <= 0) {
            throw new VehicleInventoryException('Requested units must be greater than zero.');
        }

        List<Vehicle__c> vehicles = [
            SELECT Id, Vehicle_Name__c, Stock_Quantity__c, Status__c 
            FROM Vehicle__c 
            WHERE Id = :vehicleId
        ];

        if (vehicles.isEmpty()) {
            throw new VehicleInventoryException('Vehicle record not found for ID: ' + vehicleId);
        }

        Vehicle__c vehicle = vehicles[0];

        if (VEHICLE_STATUS_DISCONTINUED.equalsIgnoreCase(vehicle.Status__c)) {
            throw new VehicleInventoryException('Cannot reserve units for discontinued vehicle: ' + vehicle.Vehicle_Name__c);
        }

        Decimal availableStock = vehicle.Stock_Quantity__c != null ? vehicle.Stock_Quantity__c : 0;
        if (availableStock < requestedUnits) {
            throw new VehicleInventoryException('Insufficient stock for vehicle "' + vehicle.Vehicle_Name__c 
                + '". Requested: ' + requestedUnits + ', Available: ' + availableStock);
        }
    }

    public static void validateAndDeductInventory(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        if (newOrders == null || newOrders.isEmpty()) {
            return;
        }

        List<Vehicle_Order__c> qualifyingOrders = new List<Vehicle_Order__c>();
        Set<Id> vehicleIds = new Set<Id>();

        for (Vehicle_Order__c newOrder : newOrders) {
            Boolean isConfirmed = isConfirmedStatus(newOrder.Status__c);
            Boolean wasConfirmed = (oldOrdersMap != null && oldOrdersMap.containsKey(newOrder.Id))
                ? isConfirmedStatus(oldOrdersMap.get(newOrder.Id).Status__c)
                : false;

            if (isConfirmed && !wasConfirmed) {
                if (newOrder.Vehicle__c == null) {
                    newOrder.addError('A valid Vehicle reference is required to confirm an order.');
                    continue;
                }
                qualifyingOrders.add(newOrder);
                vehicleIds.add(newOrder.Vehicle__c);
            }
        }

        if (qualifyingOrders.isEmpty() || vehicleIds.isEmpty()) {
            return;
        }

        Map<Id, Vehicle__c> lockedVehiclesMap = new Map<Id, Vehicle__c>(
            [SELECT Id, Name, Vehicle_Name__c, Stock_Quantity__c, Status__c 
             FROM Vehicle__c 
             WHERE Id IN :vehicleIds 
             FOR UPDATE]
        );

        Map<Id, Decimal> availableStockTracker = new Map<Id, Decimal>();
        for (Id vId : lockedVehiclesMap.keySet()) {
            Decimal initialStock = lockedVehiclesMap.get(vId).Stock_Quantity__c;
            availableStockTracker.put(vId, initialStock != null ? initialStock : 0);
        }

        List<Vehicle_Order__c> ordersToConfirm = new List<Vehicle_Order__c>();

        for (Vehicle_Order__c order : qualifyingOrders) {
            Vehicle__c vehicle = lockedVehiclesMap.get(order.Vehicle__c);
            if (vehicle == null) {
                order.addError('Associated vehicle record could not be found.');
                continue;
            }

            if (VEHICLE_STATUS_DISCONTINUED.equalsIgnoreCase(vehicle.Status__c)) {
                order.addError('Cannot confirm order for a discontinued vehicle model.');
                continue;
            }

            Decimal currentStock = availableStockTracker.get(order.Vehicle__c);
            if (currentStock != null && currentStock >= 1) {
                availableStockTracker.put(order.Vehicle__c, currentStock - 1);
                ordersToConfirm.add(order);
            } else {
                String displayName = String.isNotBlank(vehicle.Vehicle_Name__c) ? vehicle.Vehicle_Name__c : vehicle.Name;
                order.addError('Insufficient inventory: Vehicle "' + displayName + '" is out of stock. Order cannot be confirmed.');
            }
        }

        Map<Id, Vehicle__c> vehiclesToUpdate = new Map<Id, Vehicle__c>();
        for (Id vId : availableStockTracker.keySet()) {
            Vehicle__c lockedVehicle = lockedVehiclesMap.get(vId);
            Decimal finalStock = availableStockTracker.get(vId);
            Decimal originalStock = lockedVehicle.Stock_Quantity__c != null ? lockedVehicle.Stock_Quantity__c : 0;

            if (finalStock != originalStock) {
                lockedVehicle.Stock_Quantity__c = finalStock;
                if (finalStock <= 0) {
                    lockedVehicle.Status__c = VEHICLE_STATUS_OUT_OF_STOCK;
                }
                vehiclesToUpdate.put(vId, lockedVehicle);
            }
        }

        if (!vehiclesToUpdate.isEmpty()) {
            update vehiclesToUpdate.values();
            System.debug(LoggingLevel.INFO, 'VehicleInventoryService: Deducted stock for ' + vehiclesToUpdate.size() + ' vehicle(s).');
        }
    }

    public static void restoreInventoryOnCancellation(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        if (newOrders == null || oldOrdersMap == null || newOrders.isEmpty()) {
            return;
        }

        List<Vehicle_Order__c> qualifyingCancellations = new List<Vehicle_Order__c>();
        Set<Id> vehicleIds = new Set<Id>();

        for (Vehicle_Order__c newOrder : newOrders) {
            if (!oldOrdersMap.containsKey(newOrder.Id)) {
                continue;
            }
            Vehicle_Order__c oldOrder = oldOrdersMap.get(newOrder.Id);
            if (oldOrder == null) {
                continue;
            }

            Boolean isNowCancelled = isCancelledStatus(newOrder.Status__c);
            Boolean wasConfirmed = isConfirmedStatus(oldOrder.Status__c);

            if (isNowCancelled && wasConfirmed && newOrder.Vehicle__c != null) {
                qualifyingCancellations.add(newOrder);
                vehicleIds.add(newOrder.Vehicle__c);
            }
        }

        if (qualifyingCancellations.isEmpty() || vehicleIds.isEmpty()) {
            return;
        }

        Map<Id, Vehicle__c> lockedVehiclesMap = new Map<Id, Vehicle__c>(
            [SELECT Id, Name, Stock_Quantity__c, Status__c 
             FROM Vehicle__c 
             WHERE Id IN :vehicleIds 
             FOR UPDATE]
        );

        Map<Id, Decimal> stockRestorationTracker = new Map<Id, Decimal>();
        for (Id vId : lockedVehiclesMap.keySet()) {
            Decimal stock = lockedVehiclesMap.get(vId).Stock_Quantity__c;
            stockRestorationTracker.put(vId, stock != null ? stock : 0);
        }

        for (Vehicle_Order__c order : qualifyingCancellations) {
            if (stockRestorationTracker.containsKey(order.Vehicle__c)) {
                Decimal current = stockRestorationTracker.get(order.Vehicle__c);
                stockRestorationTracker.put(order.Vehicle__c, current + 1);
            }
        }

        Map<Id, Vehicle__c> vehiclesToUpdate = new Map<Id, Vehicle__c>();
        for (Id vId : stockRestorationTracker.keySet()) {
            Vehicle__c vehicle = lockedVehiclesMap.get(vId);
            Decimal restoredStock = stockRestorationTracker.get(vId);
            Decimal originalStock = vehicle.Stock_Quantity__c != null ? vehicle.Stock_Quantity__c : 0;

            if (restoredStock != originalStock) {
                vehicle.Stock_Quantity__c = restoredStock;
                if (restoredStock > 0 && VEHICLE_STATUS_OUT_OF_STOCK.equalsIgnoreCase(vehicle.Status__c)) {
                    vehicle.Status__c = VEHICLE_STATUS_AVAILABLE;
                }
                vehiclesToUpdate.put(vId, vehicle);
            }
        }

        if (!vehiclesToUpdate.isEmpty()) {
            update vehiclesToUpdate.values();
            System.debug(LoggingLevel.INFO, 'VehicleInventoryService: Restored stock for ' + vehiclesToUpdate.size() + ' vehicle(s) on order cancellation.');
        }
    }

    public static Boolean isConfirmedStatus(String status) {
        return STATUS_CONFIRMED.equalsIgnoreCase(status);
    }

    public static Boolean isCancelledStatus(String status) {
        return STATUS_CANCELLED.equalsIgnoreCase(status) || STATUS_CANCELED.equalsIgnoreCase(status);
    }
}
