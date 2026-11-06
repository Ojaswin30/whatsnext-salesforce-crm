import { LightningElement, api, wire, track } from 'lwc';
import getOrderAnalytics from '@salesforce/apex/VehicleDashboardController.getOrderAnalytics';

export default class OrderAnalytics extends LightningElement {
    @api
    get analyticsData() {
        return this._rawData;
    }
    set analyticsData(value) {
        if (value) {
            this._rawData = value;
            this.analytics = value;
            this.isLoading = false;
        }
    }

    @track analytics = null;
    @track isLoading = true;
    _rawData = null;

    @wire(getOrderAnalytics)
    wiredAnalytics({ error, data }) {
        if (!this._rawData) {
            if (data) {
                this._rawData = data;
                this.analytics = data;
                this.isLoading = false;
            } else if (error) {
                console.error('Error fetching order analytics:', error);
                this.isLoading = false;
            }
        }
    }

    get hasData() {
        return !this.isLoading && this.analytics != null;
    }

    get showEmptyState() {
        return !this.isLoading && (!this.analytics || this.analytics.totalOrders === 0);
    }

    get totalOrders() {
        return this.analytics ? this.analytics.totalOrders : 0;
    }

    get pendingCount() {
        return this.analytics ? this.analytics.pendingCount : 0;
    }

    get confirmedCount() {
        return this.analytics ? this.analytics.confirmedCount : 0;
    }

    get deliveredCount() {
        return this.analytics ? this.analytics.deliveredCount : 0;
    }

    get cancelledCount() {
        return this.analytics ? this.analytics.cancelledCount : 0;
    }

    get pendingPercentage() {
        return this.analytics ? this.analytics.pendingPercentage : 0;
    }

    get confirmedPercentage() {
        return this.analytics ? this.analytics.confirmedPercentage : 0;
    }

    get deliveredPercentage() {
        return this.analytics ? this.analytics.deliveredPercentage : 0;
    }

    get cancelledPercentage() {
        return this.analytics ? this.analytics.cancelledPercentage : 0;
    }

    get recentOrders() {
        return (this.analytics && this.analytics.recentOrders) ? this.analytics.recentOrders : [];
    }

    get hasRecentOrders() {
        return this.recentOrders.length > 0;
    }
}
