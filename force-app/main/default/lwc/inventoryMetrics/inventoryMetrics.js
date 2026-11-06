import { LightningElement, api, wire, track } from 'lwc';
import getInventoryMetrics from '@salesforce/apex/VehicleDashboardController.getInventoryMetrics';

export default class InventoryMetrics extends LightningElement {
    @api 
    get inventoryData() {
        return this._rawInventory;
    }
    set inventoryData(value) {
        if (value) {
            this._rawInventory = value;
            this.processItems(value);
            this.isLoading = false;
        }
    }

    @track items = [];
    @track selectedModel = 'ALL';
    @track isLoading = true;
    _rawInventory = [];

    @wire(getInventoryMetrics)
    wiredInventory({ error, data }) {
        // Only use wire if parent did not provide data directly
        if (!this._rawInventory || this._rawInventory.length === 0) {
            if (data) {
                this._rawInventory = data;
                this.processItems(data);
                this.isLoading = false;
            } else if (error) {
                console.error('Error fetching inventory metrics:', error);
                this.isLoading = false;
            }
        }
    }

    processItems(dataList) {
        if (!dataList) {
            this.items = [];
            return;
        }
        this.items = dataList.map(item => ({
            ...item,
            unitLabel: item.stockQuantity === 1 ? 'unit' : 'units'
        }));
    }

    get filteredInventory() {
        if (this.selectedModel === 'ALL') {
            return this.items;
        }
        return this.items.filter(item => 
            item.model && item.model.toUpperCase() === this.selectedModel.toUpperCase()
        );
    }

    get hasItems() {
        return !this.isLoading && this.filteredInventory && this.filteredInventory.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && (!this.filteredInventory || this.filteredInventory.length === 0);
    }

    get allButtonVariant() {
        return this.selectedModel === 'ALL' ? 'brand' : 'neutral';
    }

    get suvButtonVariant() {
        return this.selectedModel === 'SUV' ? 'brand' : 'neutral';
    }

    get evButtonVariant() {
        return this.selectedModel === 'EV' ? 'brand' : 'neutral';
    }

    get sedanButtonVariant() {
        return this.selectedModel === 'SEDAN' ? 'brand' : 'neutral';
    }

    handleFilterAll() {
        this.selectedModel = 'ALL';
    }

    handleFilterSuv() {
        this.selectedModel = 'SUV';
    }

    handleFilterEv() {
        this.selectedModel = 'EV';
    }

    handleFilterSedan() {
        this.selectedModel = 'SEDAN';
    }
}
