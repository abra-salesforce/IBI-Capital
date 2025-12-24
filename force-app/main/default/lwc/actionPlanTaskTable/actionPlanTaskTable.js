import { LightningElement, api, wire, track } from 'lwc';
import updateStatus from '@salesforce/apex/ActionPlanPanelController.updateTaskStatus';
import getPlanTasks from '@salesforce/apex/ActionPlanPanelController.getPlanTasks';


export default class ActionPlanTaskTable extends LightningElement {
    @api plan;
    @track tasks = [];
    loading = true;
    @track selectedTask = null;

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
    }

    get openModal() {
      return this.selectedTask !== null;
    }

    handleCloseModal() {
      this.selectedTask = null;
    }

    handleCheckboxClick(event) {
      event.stopPropagation();
    }

    async handleCheckCompleted(event) {
      event.stopPropagation();
      const taskId = event.currentTarget.dataset.id;
      const isChecked = event.target.checked;
      const taskStatus = isChecked ? 'Completed' : 'Reopen';

      try {
        await updateStatus({ taskId: taskId, status: taskStatus });
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
}