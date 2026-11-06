import { LightningElement, api, wire, track } from 'lwc';
import getLowStockAlerts from '@salesforce/apex/VehicleDashboardController.getLowStockAlerts';

export default class LowStockAlerts extends LightningElement {
    @api
    get alerts() {
        return this._rawAlerts;
    }
    set alerts(value) {
        if (value) {
            this._rawAlerts = value;
            this.processAlerts(value);
            this.isLoading = false;
        }
    }

    @track alertItems = [];
    @track isLoading = true;
    _rawAlerts = [];

    @wire(getLowStockAlerts)
    wiredAlerts({ error, data }) {
        if (!this._rawAlerts || this._rawAlerts.length === 0) {
            if (data) {
                this._rawAlerts = data;
                this.processAlerts(data);
                this.isLoading = false;
            } else if (error) {
                console.error('Error fetching low stock alerts:', error);
                this.isLoading = false;
            }
        }
    }

    processAlerts(dataList) {
        if (!dataList) {
            this.alertItems = [];
            return;
        }

        this.alertItems = dataList.map(item => {
            const isCritical = item.severity === 'critical';
            return {
                ...item,
                containerClass: isCritical 
                    ? 'alert-row alert-critical slds-p-around_small slds-m-bottom_x-small' 
                    : 'alert-row alert-warning slds-p-around_small slds-m-bottom_x-small',
                badgeClass: isCritical 
                    ? 'slds-badge slds-theme_error' 
                    : 'slds-badge slds-theme_warning',
                iconName: isCritical ? 'utility:error' : 'utility:warning',
                iconVariant: isCritical ? 'error' : 'warning'
            };
        });
    }

    get hasAlerts() {
        return !this.isLoading && this.alertItems && this.alertItems.length > 0;
    }

    get showHealthyState() {
        return !this.isLoading && (!this.alertItems || this.alertItems.length === 0);
    }

    get alertCount() {
        return this.alertItems ? this.alertItems.length : 0;
    }
}
