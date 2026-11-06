import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/VehicleDashboardController.getDashboardData';

export default class VehicleDashboard extends LightningElement {
    @track isLoading = true;
    @track dashboardData = null;
    @track errorMessage = '';

    _wiredResult;

    @wire(getDashboardData)
    wiredMetrics(result) {
        this._wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.dashboardData = data;
            this.errorMessage = '';
            this.isLoading = false;
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'Error loading dashboard metrics';
            console.error('Error fetching dashboard metrics:', error);
            this.isLoading = false;
        }
    }

    get totalVehicles() {
        return this.dashboardData ? this.dashboardData.totalVehicles : 0;
    }

    get availableUnits() {
        return this.dashboardData ? this.dashboardData.availableUnits : 0;
    }

    get pendingOrders() {
        return this.dashboardData ? this.dashboardData.pendingOrders : 0;
    }

    get totalCustomers() {
        return this.dashboardData ? this.dashboardData.totalCustomers : 0;
    }

    get inventoryList() {
        return (this.dashboardData && this.dashboardData.inventoryMetrics) 
            ? this.dashboardData.inventoryMetrics 
            : [];
    }

    get alertsList() {
        return (this.dashboardData && this.dashboardData.lowStockAlerts) 
            ? this.dashboardData.lowStockAlerts 
            : [];
    }

    get orderAnalyticsData() {
        return (this.dashboardData && this.dashboardData.orderAnalytics) 
            ? this.dashboardData.orderAnalytics 
            : null;
    }

    get dealersList() {
        return (this.dashboardData && this.dashboardData.dealerPerformance) 
            ? this.dashboardData.dealerPerformance 
            : [];
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            if (this._wiredResult) {
                await refreshApex(this._wiredResult);
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Dashboard Refreshed',
                    message: 'Latest inventory and operations metrics retrieved successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error refreshing dashboard:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refresh Error',
                    message: error.body ? error.body.message : 'Failed to refresh metrics.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}
