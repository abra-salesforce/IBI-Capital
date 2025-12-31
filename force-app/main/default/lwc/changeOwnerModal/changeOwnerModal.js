import { LightningElement, api, track} from 'lwc';

export default class ChangeOwnerModal extends LightningElement {
    @api task;

@track isMenuOpen = false;
    @track selectedType = 'Users';
    @track selectedIcon = 'standard:user';

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isMenuOpen ? 'slds-is-open' : ''}`;
    }

    get placeholderText() {
        return `Search ${this.selectedType}...`;
    }

    toggleMenu(event) {
        event.stopPropagation();
        this.isMenuOpen = !this.isMenuOpen;
    }

    selectUser(event) {
        event.preventDefault();
        this.selectedType = 'Users';
        this.selectedIcon = 'standard:user';
        this.isMenuOpen = false;
    }

    selectQueue(event) {
        event.preventDefault();
        this.selectedType = 'Queues';
        this.selectedIcon = 'standard:orders';
        this.isMenuOpen = false;
    }

    handleClose() { /* ... */ }
    handleSave() { /* ... */ }
}