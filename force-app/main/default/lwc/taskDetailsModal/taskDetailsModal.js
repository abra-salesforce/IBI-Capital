import { LightningElement, api } from 'lwc';

export default class TaskDetailsModal extends LightningElement {
    @api task;

    handleClose(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}