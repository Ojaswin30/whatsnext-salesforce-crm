/**
 * @description Controller for WhatsNext Vision Motors Operations Dashboard LWC.
 *              Provides real-time aggregated metrics for vehicles, physical inventory,
 *              order lifecycle distribution, low-stock alerts, and dealer performance.
 * @group WhatsNext CRM
 */
public with sharing class VehicleDashboardController {

    public static final Integer DEFAULT_LOW_STOCK_THRESHOLD = 3;

    /**
     * @description Comprehensive wrapper holding all dashboard datasets in a single optimized payload.
     */
    public class DashboardDataWrapper {
        @AuraEnabled public Integer totalVehicles { get; set; }
        @AuraEnabled public Integer availableUnits { get; set; }
        @AuraEnabled public Integer pendingOrders { get; set; }
        @AuraEnabled public Integer totalCustomers { get; set; }
        @AuraEnabled public Integer confirmedOrders { get; set; }
        @AuraEnabled public Integer deliveredOrders { get; set; }
        @AuraEnabled public Integer cancelledOrders { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Integer lowStockCount { get; set; }
        @AuraEnabled public Integer outOfStockCount { get; set; }
        @AuraEnabled public List<VehicleInventorySummary> inventoryMetrics { get; set; }
        @AuraEnabled public OrderAnalyticsSummary orderAnalytics { get; set; }
        @AuraEnabled public List<LowStockAlert> lowStockAlerts { get; set; }
        @AuraEnabled public List<DealerPerformanceSummary> dealerPerformance { get; set; }

        public DashboardDataWrapper() {
            this.totalVehicles = 0;
            this.availableUnits = 0;
            this.pendingOrders = 0;
            this.totalCustomers = 0;
            this.confirmedOrders = 0;
            this.deliveredOrders = 0;
            this.cancelledOrders = 0;
            this.totalOrders = 0;
            this.lowStockCount = 0;
            this.outOfStockCount = 0;
            this.inventoryMetrics = new List<VehicleInventorySummary>();
            this.orderAnalytics = new OrderAnalyticsSummary();
            this.lowStockAlerts = new List<LowStockAlert>();
            this.dealerPerformance = new List<DealerPerformanceSummary>();
        }
    }

    /**
     * @description DTO representation of a vehicle's inventory status and stock level.
     */
    public class VehicleInventorySummary {
        @AuraEnabled public Id vehicleId { get; set; }
        @AuraEnabled public String vehicleName { get; set; }
        @AuraEnabled public String model { get; set; }
        @AuraEnabled public Integer stockQuantity { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String dealerName { get; set; }
        @AuraEnabled public Integer percentage { get; set; }
        @AuraEnabled public String badgeClass { get; set; }
        @AuraEnabled public String progressVariant { get; set; }
    }

    /**
     * @description DTO representation of order status distribution and recent transaction feed.
     */
    public class OrderAnalyticsSummary {
        @AuraEnabled public Integer totalOrders { get; set; }
        @AuraEnabled public Integer pendingCount { get; set; }
        @AuraEnabled public Integer confirmedCount { get; set; }
        @AuraEnabled public Integer deliveredCount { get; set; }
        @AuraEnabled public Integer cancelledCount { get; set; }
        @AuraEnabled public Integer pendingPercentage { get; set; }
        @AuraEnabled public Integer confirmedPercentage { get; set; }
        @AuraEnabled public Integer deliveredPercentage { get; set; }
        @AuraEnabled public Integer cancelledPercentage { get; set; }
        @AuraEnabled public List<RecentOrderItem> recentOrders { get; set; }

        public OrderAnalyticsSummary() {
            this.totalOrders = 0;
            this.pendingCount = 0;
            this.confirmedCount = 0;
            this.deliveredCount = 0;
            this.cancelledCount = 0;
            this.pendingPercentage = 0;
            this.confirmedPercentage = 0;
            this.deliveredPercentage = 0;
            this.cancelledPercentage = 0;
            this.recentOrders = new List<RecentOrderItem>();
        }
    }

    /**
     * @description DTO representation of an individual recent vehicle order.
     */
    public class RecentOrderItem {
        @AuraEnabled public Id orderId { get; set; }
        @AuraEnabled public String orderNumber { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String vehicleName { get; set; }
        @AuraEnabled public Date orderDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusBadgeClass { get; set; }
    }

    /**
     * @description DTO representation of a vehicle triggering low inventory or out-of-stock warning.
     */
    public class LowStockAlert {
        @AuraEnabled public Id vehicleId { get; set; }
        @AuraEnabled public String vehicleName { get; set; }
        @AuraEnabled public String model { get; set; }
        @AuraEnabled public Integer stockQuantity { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String dealerName { get; set; }
        @AuraEnabled public String severity { get; set; } // 'critical' or 'warning'
        @AuraEnabled public String severityLabel { get; set; }
        @AuraEnabled public String alertMessage { get; set; }
    }

    /**
     * @description DTO representation of dealer-specific inventory and order metrics.
     */
    public class DealerPerformanceSummary {
        @AuraEnabled public Id dealerId { get; set; }
        @AuraEnabled public String dealerName { get; set; }
        @AuraEnabled public String dealerCode { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public Integer totalVehicles { get; set; }
        @AuraEnabled public Integer totalStockUnits { get; set; }
        @AuraEnabled public Integer totalOrders { get; set; }
    }

    /**
     * @description Retrieves the complete set of dashboard metrics in a single cacheable wire call.
     * @return DashboardDataWrapper containing all metrics, aggregates, and alert feeds.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardDataWrapper getDashboardData() {
        DashboardDataWrapper data = new DashboardDataWrapper();

        // 1. Basic counts
        data.totalVehicles = [SELECT COUNT() FROM Vehicle__c];
        data.totalCustomers = [SELECT COUNT() FROM Vehicle_Customer__c];

        // 2. Sum available physical units
        AggregateResult[] stockSumAgg = [
            SELECT SUM(Stock_Quantity__c) totalUnits 
            FROM Vehicle__c 
            WHERE Status__c != :VehicleInventoryService.VEHICLE_STATUS_DISCONTINUED
        ];
        if (!stockSumAgg.isEmpty() && stockSumAgg[0].get('totalUnits') != null) {
            data.availableUnits = ((Decimal) stockSumAgg[0].get('totalUnits')).intValue();
        }

        // 3. Inventory details & calculations
        data.inventoryMetrics = getInventoryMetrics();
        for (VehicleInventorySummary item : data.inventoryMetrics) {
            if (item.stockQuantity <= 0) {
                data.outOfStockCount++;
            } else if (item.stockQuantity <= DEFAULT_LOW_STOCK_THRESHOLD) {
                data.lowStockCount++;
            }
        }

        // 4. Order Analytics
        data.orderAnalytics = getOrderAnalytics();
        data.pendingOrders = data.orderAnalytics.pendingCount;
        data.confirmedOrders = data.orderAnalytics.confirmedCount;
        data.deliveredOrders = data.orderAnalytics.deliveredCount;
        data.cancelledOrders = data.orderAnalytics.cancelledCount;
        data.totalOrders = data.orderAnalytics.totalOrders;

        // 5. Low stock alerts
        data.lowStockAlerts = getLowStockAlerts();

        // 6. Dealer performance
        data.dealerPerformance = getDealerPerformance();

        return data;
    }

    /**
     * @description Retrieves inventory metrics sorted by stock volume.
     * @return List of VehicleInventorySummary items.
     */
    @AuraEnabled(cacheable=true)
    public static List<VehicleInventorySummary> getInventoryMetrics() {
        List<VehicleInventorySummary> result = new List<VehicleInventorySummary>();

        List<Vehicle__c> vehicles = [
            SELECT Id, Name, Vehicle_Name__c, Vehicle_Model__c, Stock_Quantity__c, Price__c, Status__c, Dealer__r.Dealer_Name__c 
            FROM Vehicle__c 
            ORDER BY Stock_Quantity__c DESC, Vehicle_Name__c ASC 
            LIMIT 100
        ];

        Integer maxStock = 1;
        for (Vehicle__c v : vehicles) {
            Integer stock = v.Stock_Quantity__c != null ? v.Stock_Quantity__c.intValue() : 0;
            if (stock > maxStock) {
                maxStock = stock;
            }
        }

        for (Vehicle__c v : vehicles) {
            VehicleInventorySummary item = new VehicleInventorySummary();
            item.vehicleId = v.Id;
            item.vehicleName = String.isNotBlank(v.Vehicle_Name__c) ? v.Vehicle_Name__c : (String.isNotBlank(v.Name) ? v.Name : 'Vehicle');
            item.model = String.isNotBlank(v.Vehicle_Model__c) ? v.Vehicle_Model__c : 'Standard';
            item.stockQuantity = v.Stock_Quantity__c != null ? v.Stock_Quantity__c.intValue() : 0;
            item.price = v.Price__c != null ? v.Price__c : 0;
            item.status = String.isNotBlank(v.Status__c) ? v.Status__c : (item.stockQuantity > 0 ? 'Available' : 'Out of Stock');
            item.dealerName = (v.Dealer__r != null && String.isNotBlank(v.Dealer__r.Dealer_Name__c)) ? v.Dealer__r.Dealer_Name__c : 'Unassigned';

            // Percentage relative to highest stock item for visual bar graph
            item.percentage = maxStock > 0 ? Math.min(100, (Integer) Math.round(((Double) item.stockQuantity / (Double) maxStock) * 100)) : 0;

            if (item.stockQuantity <= 0 || VehicleInventoryService.VEHICLE_STATUS_OUT_OF_STOCK.equalsIgnoreCase(item.status)) {
                item.badgeClass = 'slds-badge slds-theme_error';
                item.progressVariant = 'expired';
            } else if (item.stockQuantity <= DEFAULT_LOW_STOCK_THRESHOLD) {
                item.badgeClass = 'slds-badge slds-theme_warning';
                item.progressVariant = 'warning';
            } else {
                item.badgeClass = 'slds-badge slds-theme_success';
                item.progressVariant = 'base';
            }

            result.add(item);
        }

        return result;
    }

    /**
     * @description Retrieves order lifecycle metrics and recent order transactions.
     * @return OrderAnalyticsSummary containing count breakdowns, percentages, and recent records.
     */
    @AuraEnabled(cacheable=true)
    public static OrderAnalyticsSummary getOrderAnalytics() {
        OrderAnalyticsSummary summary = new OrderAnalyticsSummary();

        AggregateResult[] groupedOrders = [
            SELECT Status__c, COUNT(Id) cnt 
            FROM Vehicle_Order__c 
            GROUP BY Status__c
        ];

        Integer pending = 0;
        Integer confirmed = 0;
        Integer delivered = 0;
        Integer cancelled = 0;
        Integer total = 0;

        for (AggregateResult ar : groupedOrders) {
            String status = (String) ar.get('Status__c');
            Integer count = ((Decimal) ar.get('cnt')).intValue();
            total += count;

            if (String.isNotBlank(status)) {
                if (VehicleInventoryService.STATUS_PENDING.equalsIgnoreCase(status)) {
                    pending += count;
                } else if (VehicleInventoryService.STATUS_CONFIRMED.equalsIgnoreCase(status)) {
                    confirmed += count;
                } else if (VehicleInventoryService.STATUS_DELIVERED.equalsIgnoreCase(status)) {
                    delivered += count;
                } else if (VehicleInventoryService.isCancelledStatus(status)) {
                    cancelled += count;
                }
            }
        }

        summary.totalOrders = total;
        summary.pendingCount = pending;
        summary.confirmedCount = confirmed;
        summary.deliveredCount = delivered;
        summary.cancelledCount = cancelled;

        if (total > 0) {
            summary.pendingPercentage = (Integer) Math.round(((Double) pending / (Double) total) * 100);
            summary.confirmedPercentage = (Integer) Math.round(((Double) confirmed / (Double) total) * 100);
            summary.deliveredPercentage = (Integer) Math.round(((Double) delivered / (Double) total) * 100);
            summary.cancelledPercentage = (Integer) Math.round(((Double) cancelled / (Double) total) * 100);
        }

        // Recent orders feed
        List<Vehicle_Order__c> recentRecords = [
            SELECT Id, Name, Customer__r.Customer_Name__c, Customer__r.Name, 
                   Vehicle__r.Vehicle_Name__c, Vehicle__r.Name, Order_Date__c, Status__c 
            FROM Vehicle_Order__c 
            ORDER BY CreatedDate DESC 
            LIMIT 8
        ];

        for (Vehicle_Order__c ord : recentRecords) {
            RecentOrderItem item = new RecentOrderItem();
            item.orderId = ord.Id;
            item.orderNumber = ord.Name;
            item.customerName = (ord.Customer__r != null && String.isNotBlank(ord.Customer__r.Customer_Name__c)) 
                ? ord.Customer__r.Customer_Name__c 
                : (ord.Customer__r != null && String.isNotBlank(ord.Customer__r.Name) ? ord.Customer__r.Name : 'Customer');
            item.vehicleName = (ord.Vehicle__r != null && String.isNotBlank(ord.Vehicle__r.Vehicle_Name__c)) 
                ? ord.Vehicle__r.Vehicle_Name__c 
                : (ord.Vehicle__r != null && String.isNotBlank(ord.Vehicle__r.Name) ? ord.Vehicle__r.Name : 'Vehicle');
            item.orderDate = ord.Order_Date__c;
            item.status = ord.Status__c;

            if (VehicleInventoryService.STATUS_CONFIRMED.equalsIgnoreCase(ord.Status__c)) {
                item.statusBadgeClass = 'slds-badge slds-theme_success';
            } else if (VehicleInventoryService.STATUS_DELIVERED.equalsIgnoreCase(ord.Status__c)) {
                item.statusBadgeClass = 'slds-badge slds-badge_inverse';
            } else if (VehicleInventoryService.STATUS_PENDING.equalsIgnoreCase(ord.Status__c)) {
                item.statusBadgeClass = 'slds-badge slds-theme_warning';
            } else {
                item.statusBadgeClass = 'slds-badge slds-theme_error';
            }

            summary.recentOrders.add(item);
        }

        return summary;
    }

    /**
     * @description Identifies low stock and exhausted vehicles requiring immediate dealer attention.
     * @return List of LowStockAlert items.
     */
    @AuraEnabled(cacheable=true)
    public static List<LowStockAlert> getLowStockAlerts() {
        List<LowStockAlert> alerts = new List<LowStockAlert>();

        List<Vehicle__c> lowStockVehicles = [
            SELECT Id, Name, Vehicle_Name__c, Vehicle_Model__c, Stock_Quantity__c, Status__c, Dealer__r.Dealer_Name__c 
            FROM Vehicle__c 
            WHERE Stock_Quantity__c <= :DEFAULT_LOW_STOCK_THRESHOLD 
              AND Status__c != :VehicleInventoryService.VEHICLE_STATUS_DISCONTINUED 
            ORDER BY Stock_Quantity__c ASC, Vehicle_Name__c ASC 
            LIMIT 25
        ];

        for (Vehicle__c v : lowStockVehicles) {
            LowStockAlert alert = new LowStockAlert();
            alert.vehicleId = v.Id;
            alert.vehicleName = String.isNotBlank(v.Vehicle_Name__c) ? v.Vehicle_Name__c : (String.isNotBlank(v.Name) ? v.Name : 'Vehicle');
            alert.model = String.isNotBlank(v.Vehicle_Model__c) ? v.Vehicle_Model__c : 'Standard';
            alert.stockQuantity = v.Stock_Quantity__c != null ? v.Stock_Quantity__c.intValue() : 0;
            alert.status = v.Status__c;
            alert.dealerName = (v.Dealer__r != null && String.isNotBlank(v.Dealer__r.Dealer_Name__c)) ? v.Dealer__r.Dealer_Name__c : 'All Dealerships';

            if (alert.stockQuantity <= 0) {
                alert.severity = 'critical';
                alert.severityLabel = 'OUT OF STOCK';
                alert.alertMessage = 'Physical stock depleted (0 units). Restocking required immediately.';
            } else {
                alert.severity = 'warning';
                alert.severityLabel = 'LOW STOCK';
                alert.alertMessage = 'Critical stock level (' + alert.stockQuantity + ' units remaining). Schedule inventory transfer.';
            }

            alerts.add(alert);
        }

        return alerts;
    }

    /**
     * @description Aggregates inventory and order counts per dealership.
     * @return List of DealerPerformanceSummary items.
     */
    @AuraEnabled(cacheable=true)
    public static List<DealerPerformanceSummary> getDealerPerformance() {
        List<DealerPerformanceSummary> result = new List<DealerPerformanceSummary>();

        // Query dealers and their assigned vehicles
        List<Vehicle_Dealer__c> dealers = [
            SELECT Id, Name, Dealer_Name__c, Dealer_Code__c, Dealer_Location__c, Phone__c, Email__c, 
                   (SELECT Id, Stock_Quantity__c FROM Vehicles__r WHERE Status__c != :VehicleInventoryService.VEHICLE_STATUS_DISCONTINUED) 
            FROM Vehicle_Dealer__c 
            ORDER BY Dealer_Name__c ASC 
            LIMIT 50
        ];

        if (dealers.isEmpty()) {
            return result;
        }

        // Aggregate orders count per dealer via vehicle relationship
        Map<Id, Integer> dealerOrderCounts = new Map<Id, Integer>();
        AggregateResult[] orderAggs = [
            SELECT Vehicle__r.Dealer__c dealerId, COUNT(Id) orderCount 
            FROM Vehicle_Order__c 
            WHERE Vehicle__r.Dealer__c != null 
            GROUP BY Vehicle__r.Dealer__c
        ];

        for (AggregateResult ar : orderAggs) {
            Id dId = (Id) ar.get('dealerId');
            Integer count = ((Decimal) ar.get('orderCount')).intValue();
            dealerOrderCounts.put(dId, count);
        }

        for (Vehicle_Dealer__c d : dealers) {
            DealerPerformanceSummary summary = new DealerPerformanceSummary();
            summary.dealerId = d.Id;
            summary.dealerName = String.isNotBlank(d.Dealer_Name__c) ? d.Dealer_Name__c : (String.isNotBlank(d.Name) ? d.Name : 'Dealership');
            summary.dealerCode = String.isNotBlank(d.Dealer_Code__c) ? d.Dealer_Code__c : 'DLR-N/A';
            summary.location = String.isNotBlank(d.Dealer_Location__c) ? d.Dealer_Location__c : 'Regional Hub';
            summary.phone = d.Phone__c;
            summary.email = d.Email__c;

            Integer totalStock = 0;
            Integer vehicleCount = 0;
            if (d.Vehicles__r != null) {
                vehicleCount = d.Vehicles__r.size();
                for (Vehicle__c v : d.Vehicles__r) {
                    if (v.Stock_Quantity__c != null) {
                        totalStock += v.Stock_Quantity__c.intValue();
                    }
                }
            }

            summary.totalVehicles = vehicleCount;
            summary.totalStockUnits = totalStock;
            summary.totalOrders = dealerOrderCounts.containsKey(d.Id) ? dealerOrderCounts.get(d.Id) : 0;

            result.add(summary);
        }

        return result;
    }
}
