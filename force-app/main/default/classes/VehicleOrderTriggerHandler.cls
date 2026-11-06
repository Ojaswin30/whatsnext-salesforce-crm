/**
 * @description Enterprise Trigger Handler for Vehicle_Order__c.
 *              Separates concerns, routes trigger context events, and delegates
 *              inventory transactions to VehicleInventoryService.
 * @group WhatsNext CRM
 */
public with sharing class VehicleOrderTriggerHandler {

    /**
     * @description Legacy dispatch method preserved for backward-compatibility with existing trigger invocations.
     */
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

    /**
     * @description Context handler for before insert. Sets defaults and validates required fields.
     */
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

    /**
     * @description Context handler for before update.
     */
    public static void beforeUpdate(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        if (newOrders == null) {
            return;
        }

        for (Vehicle_Order__c order : newOrders) {
            // Guard against nullifying vehicle on confirmed order
            if (VehicleInventoryService.isConfirmedStatus(order.Status__c) && order.Vehicle__c == null) {
                order.addError('A valid Vehicle reference is required to maintain a Confirmed order.');
            }
        }
    }

    /**
     * @description Context handler for after insert.
     *              Deducts stock for orders placed directly as Confirmed.
     */
    public static void afterInsert(List<Vehicle_Order__c> newOrders) {
        VehicleInventoryService.validateAndDeductInventory(newOrders, null);
    }

    /**
     * @description Context handler for after update.
     *              Handles transition-based inventory deductions and restoration on cancellation.
     */
    public static void afterUpdate(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrdersMap) {
        // Handle transitions into Confirmed (e.g., Pending -> Confirmed, Cancelled -> Confirmed)
        VehicleInventoryService.validateAndDeductInventory(newOrders, oldOrdersMap);

        // Handle transitions into Cancelled (Confirmed -> Cancelled restores stock)
        VehicleInventoryService.restoreInventoryOnCancellation(newOrders, oldOrdersMap);
    }
}
