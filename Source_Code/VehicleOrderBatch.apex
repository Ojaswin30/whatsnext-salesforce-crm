/**
 * @description Batch Apex process that periodically scans Pending vehicle orders
 *              and advances eligible orders to Confirmed when vehicle inventory is available.
 *              Authoritative inventory deduction is delegated to VehicleInventoryService
 *              via the trigger pipeline to guarantee single-source-of-truth consistency.
 * @group WhatsNext CRM
 */
public with sharing class VehicleOrderBatch implements Database.Batchable<sObject>, Database.Stateful {

    @TestVisible
    private Integer recordsProcessed = 0;
    @TestVisible
    private Integer ordersConfirmed = 0;
    @TestVisible
    private Integer failedOrders = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Status__c, Vehicle__c, CreatedDate 
            FROM Vehicle_Order__c 
            WHERE Status__c = :VehicleInventoryService.STATUS_PENDING 
              AND Vehicle__c != null 
            ORDER BY CreatedDate ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Vehicle_Order__c> orderList) {
        if (orderList == null || orderList.isEmpty()) {
            return;
        }

        recordsProcessed += orderList.size();
        Set<Id> vehicleIds = new Set<Id>();

        for (Vehicle_Order__c order : orderList) {
            if (order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
            }
        }

        if (vehicleIds.isEmpty()) {
            return;
        }

        Map<Id, Vehicle__c> vehicleStockMap = new Map<Id, Vehicle__c>(
            [SELECT Id, Stock_Quantity__c, Status__c 
             FROM Vehicle__c 
             WHERE Id IN :vehicleIds 
               AND Stock_Quantity__c > 0 
               AND Status__c != :VehicleInventoryService.VEHICLE_STATUS_DISCONTINUED]
        );

        Map<Id, Decimal> chunkAllocationTracker = new Map<Id, Decimal>();
        for (Id vId : vehicleStockMap.keySet()) {
            Decimal stock = vehicleStockMap.get(vId).Stock_Quantity__c;
            chunkAllocationTracker.put(vId, stock != null ? stock : 0);
        }

        List<Vehicle_Order__c> ordersToConfirm = new List<Vehicle_Order__c>();

        for (Vehicle_Order__c order : orderList) {
            Decimal available = chunkAllocationTracker.get(order.Vehicle__c);
            if (available != null && available >= 1) {
                order.Status__c = VehicleInventoryService.STATUS_CONFIRMED;
                chunkAllocationTracker.put(order.Vehicle__c, available - 1);
                ordersToConfirm.add(order);
            }
        }

        if (!ordersToConfirm.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(ordersToConfirm, false);

            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    ordersConfirmed++;
                } else {
                    failedOrders++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.WARN, 'VehicleOrderBatch confirmation failed for record ' 
                            + sr.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'VehicleOrderBatch completed: Processed ' 
            + recordsProcessed + ' orders, Confirmed: ' 
            + ordersConfirmed + ', Failed: ' + failedOrders);
    }
}
