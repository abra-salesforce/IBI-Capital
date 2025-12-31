import { LightningElement, api, wire, track } from 'lwc';
import updateStatus from '@salesforce/apex/ActionPlanPanelController.updateTaskStatus';
import getPlanTasks from '@salesforce/apex/ActionPlanPanelController.getPlanTasks';
import LightningConfirm from 'lightning/confirm';

export default class ActionPlanTaskTable extends LightningElement {
    @api plan;
    @track tasks = [];
    loading = true;
    @track selectedTask = null;
    currentModal = null;

    connectedCallback() {
      this.loadTasks();
    }

    async loadTasks() {
      this.loading = true;
      try {
        const planId = this.plan?.Id;
        if (!planId) {
          this.tasks = [];
          return;
        }

        const result = await getPlanTasks({ planId }); 

        this.tasks = (result || []).map(t => {
          const status = t.Status;
          return {
            ...t,
            Completed: status === 'Completed',
            checkboxLabel: status === 'Completed' ? 'Completed' : 'Mark as completed',
            iconName: status === 'Completed' ? 'utility:check' : null,
            disabled: status === 'Waiting in Dependency' ? true : false,
            rowClass: `slds-hint-parent task-row ${this.getRowClassByStatus(status)}`
          };
        });
      } catch (e) {
        console.error('getPlanTasks error:', e?.body ?? e);
        this.tasks = [];
      } finally {
        this.loading = false;
      }
    }

    getRowClassByStatus(status) {
      if (status === 'Completed') return 'task-success';
      if (status === 'Open' || status === 'Reopen') return 'task-open';
      if (status === 'Waiting in Dependency') return 'task-waiting';
      return 'task-default';
    }


    handleSelectedRow(event) {
      const taskId = event.currentTarget.dataset.id;
      this.selectedTask = this.tasks.find(t => t.Id === taskId);
      this.currentModal = 'details';
    }

    get openTaskDetailsModal() {
      return this.currentModal === 'details';
    }

    get openChangeOwnerModal() {
      return this.currentModal === 'owner';
    }

    handleCloseModal() {
      this.currentModal = null;
      this.selectedTask = null;
    }

    handleCheckboxClick(event) {
      event.stopPropagation();
    }

    async handleStatusClick(event) {
        event.stopPropagation();

        const taskId = event.currentTarget.dataset.id;
        const task = this.tasks.find(t => t.Id === taskId);
        if (!task) return;

        const isCurrentlyCompleted = task.Completed;
        const newStatus = isCurrentlyCompleted ? 'Reopen' : 'Completed';

        if (isCurrentlyCompleted) {
            const confirmed = await LightningConfirm.open({
                message: 'האם אתה בטוח שתרצה לשנות סטטוס?',
                theme: 'warning'
            });
            if (!confirmed) {
                await this.loadTasks();
                return;
            }
        }

        try {
            await updateStatus({ taskId, status: newStatus });
            await this.loadTasks();

            this.dispatchEvent(new CustomEvent('taskstatuschange', {
                detail: { planId: this.plan?.Id },
                bubbles: true,
                composed: true
            }));
        } catch (e) {
            console.error(e?.body?.message || e);
        }
    }

    handleTaskSaved() {
      this.currentModal = null;
      this.selectedTask = null;
      this.loadTasks();
    }

    handleChangeOwner(event) {
        event.stopPropagation();
        const taskId = event.currentTarget.dataset.id;
        this.selectedTask = this.tasks.find(t => t.Id === taskId);
        this.currentModal = 'owner';
    }

}