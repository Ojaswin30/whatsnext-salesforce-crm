import { LightningElement, api, wire, track } from 'lwc';
import getDealerPerformance from '@salesforce/apex/VehicleDashboardController.getDealerPerformance';

export default class DealerPerformance extends LightningElement {
    @api
    get dealersData() {
        return this._rawDealers;
    }
    set dealersData(value) {
        if (value) {
            this._rawDealers = value;
            this.dealersList = value;
            this.isLoading = false;
        }
    }

    @track dealersList = [];
    @track isLoading = true;
    _rawDealers = [];

    @wire(getDealerPerformance)
    wiredDealers({ error, data }) {
        if (!this._rawDealers || this._rawDealers.length === 0) {
            if (data) {
                this._rawDealers = data;
                this.dealersList = data;
                this.isLoading = false;
            } else if (error) {
                console.error('Error fetching dealer performance:', error);
                this.isLoading = false;
            }
        }
    }

    get hasDealers() {
        return !this.isLoading && this.dealersList && this.dealersList.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && (!this.dealersList || this.dealersList.length === 0);
    }

    get dealersCount() {
        return this.dealersList ? this.dealersList.length : 0;
    }
}
