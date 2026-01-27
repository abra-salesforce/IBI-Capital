import { LightningElement, api, track } from 'lwc';
import searchOwners from '@salesforce/apex/ActionPlanPanelController.searchOwners';
import changeTaskOwner from '@salesforce/apex/ActionPlanPanelController.changeTaskOwner';

export default class ChangeOwnerModal extends LightningElement {
    @api task;

    @track isMenuOpen = false;
    @track selectedType = 'Users';
    @track selectedIcon = 'standard:user';

    @track searchTerm = '';
    @track results = [];
    @track showResults = false;

    selectedOwnerId;
    selectedOwnerName;
    _outsideClickHandler;

    @track isSaving = false;


    connectedCallback() {
        this._outsideClickHandler = this.handleOutsideClick.bind(this);
        window.addEventListener('click', this._outsideClickHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._outsideClickHandler);
    }

    handleOutsideClick(event) {
        if (!this.template.contains(event.target)) {
            this.isMenuOpen = false;
            this.showResults = false;
        }
    }

    get comboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        return `${base} ${(this.isMenuOpen || this.showResults) ? 'slds-is-open' : ''}`;
    }

    get placeholderText() {
        return `Search ${this.selectedType}...`;
    }

    get ownerTypeApi() {
        return this.selectedType === 'Users' ? 'User' : 'Queue';
    }

    get isDropdownOpen() {
        return this.isMenuOpen || this.showResults;
    }

    toggleMenu(event) {
        event.stopPropagation();
        this.isMenuOpen = !this.isMenuOpen;
    }

    selectUser(event) {
        event.preventDefault();
        event.stopPropagation();
        this.selectedType = 'Users';
        this.selectedIcon = 'standard:user';
        this.isMenuOpen = false;
        this.clearSelectionAndResults();
    }

    selectQueue(event) {
        event.preventDefault();
        event.stopPropagation();
        this.selectedType = 'Queues';
        this.selectedIcon = 'standard:queue';
        this.isMenuOpen = false;
        this.clearSelectionAndResults();
    }

    clearSelectionAndResults() {
        this.searchTerm = '';
        this.results = [];
        this.showResults = false;
        this.selectedOwnerId = null;
        this.selectedOwnerName = null;
    }

    async handleInputFocus() {
        await this.fetchResults();
    }

    async handleSearchChange(event) {
        this.searchTerm = event.target.value;
        await this.fetchResults();
    }

    async fetchResults() {
        try {
            const data = await searchOwners({
                ownerType: this.ownerTypeApi,
                searchTerm: this.searchTerm
            });

            this.results = data || [];
            this.showResults = this.results.length > 0;
        } catch (e) {
            console.error('searchOwners error', e?.body?.message || e);
            this.results = [];
            this.showResults = false;
        }
    }

    handleSelectOwner(event) {
        const { id, name } = event.currentTarget.dataset;
        this.selectedOwnerId = id;
        this.selectedOwnerName = name;
        this.searchTerm = name;
        this.showResults = false;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleSave() {
        if (!this.selectedOwnerId) {
            return;
        }

        this.isSaving = true;
        try {
            await changeTaskOwner({
                taskId: this.task.Id,
                ownerId: this.selectedOwnerId
            });

            this.dispatchEvent(new CustomEvent('saved', {
                bubbles: true,
                composed: true,
                detail: {
                    ownerId: this.selectedOwnerId,
                    ownerName: this.selectedOwnerName
                }
            }));
        } catch (e) {
            const msg = e?.body?.message || 'שגיאה בשינוי בעלים למשימה';
            this.dispatchEvent(new CustomEvent('validationerror', {
                detail: { message: msg },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.isSaving = false;
        }
    }
}