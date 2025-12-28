import { LightningElement, api } from 'lwc';
import updateTaskDescription from '@salesforce/apex/ActionPlanPanelController.updateTaskDescription';

export default class TaskDetailsModal extends LightningElement {
    @api task;
    errorMessage;

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleSave() {
        this.errorMessage = null;
        const description = this.template.querySelector('lightning-textarea')?.value;
        try {
            await updateTaskDescription({taskId: this.task.Id, description: description});

            this.dispatchEvent(
                new CustomEvent('saved', {
                    detail: { taskId: this.task.Id, description },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            console.error('Error updating task', error);
            this.errorMessage =
                error?.body?.message ||
                'An error occurred while updating the task.';
        }
    }
}
