/**
 * @description Enterprise Trigger Handler for Vehicle_Order__c.
 *              Separates concerns, routes trigger context events, and delegates
 *              inventory transactions to VehicleInventoryService.
 * @group WhatsNext CRM
 */
public with sharing class VehicleOrderTriggerHandler {

    public static void handleTrigger(
        List<Vehicle_Order__c> newOrders,
        Map<Id, Vehicle_Order__c> oldOrders,
        Boolean isBefore,
        Boolean isAfter,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (isBefore) {
            if (isInsert) {
                beforeInsert(newOrders);
            } else if (isUpdate) {
                beforeUpdate(newOrders, oldOrders);
            }
        } else if (isAfter) {
            if (isInsert) {
                afterInsert(newOrders);
            } else if (isUpdate) {
                afterUpdate(newOrders, oldOrders);
            }
        }
    }

    public static void beforeInsert(List<Vehicle_Order__c> newOrders) {
        if (newOrders == null) {
            return;
        }

        for (Vehicle_Order__c order : newOrders) {
            if (order.Order_Date__c == null) {
                order.Order_Date__c = Date.today();
            }
            if (order.Status__c == null) {
                order.Status__c = VehicleInventoryService.STATUS_PENDING;
            }
        }
    }

    public static void beforeUpdate(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        if (newOrders == null) {
            return;
        }

        for (Vehicle_Order__c order : newOrders) {
            if (VehicleInventoryService.isConfirmedStatus(order.Status__c) && order.Vehicle__c == null) {
                order.addError('A valid Vehicle reference is required to maintain a Confirmed order.');
            }
        }
    }

    public static void afterInsert(List<Vehicle_Order__c> newOrders) {
        VehicleInventoryService.validateAndDeductInventory(newOrders, null);
    }

    public static void afterUpdate(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        VehicleInventoryService.validateAndDeductInventory(newOrders, oldOrdersMap);
        VehicleInventoryService.restoreInventoryOnCancellation(newOrders, oldOrdersMap);
    }
}
