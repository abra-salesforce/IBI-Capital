import { LightningElement, api, wire, track } from 'lwc';
import updateStatus from '@salesforce/apex/ActionPlanPanelController.updateTaskStatus';
import getPlanTasks from '@salesforce/apex/ActionPlanPanelController.getPlanTasks';
import planCssNubbinBottom from '@salesforce/resourceUrl/planCSS_nubbin_buttom';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class ActionPlanTaskTable extends LightningElement {
    @api plan;
    @track tasks = [];
    loading = true;
    @track selectedTask = null;
    currentModal = null;
    updatingTaskId = null;

    _styleLoaded = false;

    async connectedCallback() {
      if (!this._styleLoaded) {
        this._styleLoaded = true;
        try {
          await loadStyle(this, planCssNubbinBottom);
        } catch (e) {

        }
      }

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
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        this.tasks = (result || []).map(t => this.enrichTask(t, today));

      } catch (e) {
        const msg = e?.body?.message || e?.message || 'שגיאה בטעינת המשימות';
        this.dispatchEvent(new CustomEvent('validationerror', {
            detail: { message: msg },
            bubbles: true,
            composed: true
        }));
        this.tasks = [];
      } finally {
        this.loading = false;
      }
    }

    enrichTask(t, today) {
  const status = t.Status;
  const due = t.ActivityDate ? new Date(t.ActivityDate) : null;
  if (due) due.setHours(0, 0, 0, 0);

  const isOverdue = !!due && due < today && status !== 'Completed';

  const isUpdating = (t.Id === this.updatingTaskId);

  const baseIcon = status === 'Completed' ? 'utility:check' : null;

  return {
    ...t,
    Completed: status === 'Completed',
    checkboxLabel: status === 'Completed' ? 'Completed' : 'Mark as completed',
    displayIconName: isUpdating ? 'utility:spinner' : (status === 'Completed' ? 'utility:check' : null),
    displayDisabled: (status === 'Waiting in Dependency') || isUpdating,
    isMandatory: !!t.Plan_Item__r?.Is_Mandatory__c,
    hasInstrunction: t.Plan_Item__r?.Instructions__c != null,
    dateClass: 'slds-truncate slds-text-title_bold ' + (isOverdue ? 'slds-text-color_error' : ''),
    rowClass: `slds-hint-parent task-row ${this.getRowClassByStatus(status)}`
  };
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
        if (this.updatingTaskId) return;

        this.selectedTask = task; 
        
        const isCurrentlyCompleted = task.Completed;
        const newStatus = isCurrentlyCompleted ? 'Reopen' : 'Completed';

        if (isCurrentlyCompleted && this.currentModal !== 'confirm') {
            this.currentModal = 'confirm';
            return;
        }

        this.updatingTaskId = taskId;

        {
          const today = new Date();
          today.setHours(0, 0, 0, 0);
          this.tasks = this.tasks.map(t => this.enrichTask(t, today));
        }

        try {
            const result = await updateStatus({ taskId, status: newStatus });

            const updated = result?.updatedTasks || [];
            const updatedMap = new Map(updated.map(t => [t.Id, t]));

            const today = new Date();
            today.setHours(0, 0, 0, 0);

            this.tasks = this.tasks.map(oldT => {
              const fresh = updatedMap.get(oldT.Id);
              return fresh ? this.enrichTask(fresh, today) : this.enrichTask(oldT, today);
            });

            this.dispatchEvent(new CustomEvent('taskstatuschange', {
                detail: { planId: this.plan?.Id },
                bubbles: true,
                composed: true
            }));
        } catch (e) {
            const msg = e?.body?.message || 'שגיאה בעדכון המשימה';
            this.dispatchEvent(new CustomEvent('validationerror', {
                detail: { message: msg },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.updatingTaskId = null;

            const today = new Date();
            today.setHours(0, 0, 0, 0);
            this.tasks = this.tasks.map(t => this.enrichTask(t, today));
            this.currentModal = null;
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

    get openConfirmModal() {
      return this.currentModal === 'confirm';
    }

    handleSaveConfirm() {
        this.handleStatusClick({ 
            stopPropagation: () => {}, 
            currentTarget: { dataset: { id: this.selectedTask.Id } } 
        });
    }

}