import { LightningElement, api } from 'lwc';
import updateTaskDescriptionAndDate from '@salesforce/apex/ActionPlanPanelController.updateTaskDescriptionAndDate';

export default class TaskDetailsModal extends LightningElement {
    @api task;
    errorMessage;
    dueDateValue;

    connectedCallback() {
        this.dueDateValue = this.task?.ActivityDate || null;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleSave() {
        this.errorMessage = null;
        const description = this.template.querySelector('lightning-textarea')?.value;
        try {
            await updateTaskDescriptionAndDate({taskId: this.task.Id, description: description, dueDate: this.dueDateValue});

            this.dispatchEvent(
                new CustomEvent('saved', {
                    detail: { taskId: this.task.Id, description, dueDate: this.dueDateValue },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            this.errorMessage =
                error?.body?.message ||
                'An error occurred while updating the task.';
        }
    }

    handleDueDateChange(event) {
        this.dueDateValue = event.target.value;
    }


}
