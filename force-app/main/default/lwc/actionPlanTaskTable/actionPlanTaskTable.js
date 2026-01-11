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
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        this.tasks = (result || []).map(t => {
          const status = t.Status;
          const due = t.ActivityDate ? new Date(t.ActivityDate) : null; // YYYY-MM-DD
          if (due) due.setHours(0, 0, 0, 0);
          const isOverdue = !!due && due < today && status !== 'Completed';
          return {
            ...t,
            Completed: status === 'Completed',
            checkboxLabel: status === 'Completed' ? 'Completed' : 'Mark as completed',
            iconName: status === 'Completed' ? 'utility:check' : null,
            disabled: status === 'Waiting in Dependency' ? true : false,
            isMandatory: !!t.Plan_Item__r?.Is_Mandatory__c,
            hasInstrunction: t.Plan_Item__r?.Instructions__c != null ? true : false,
            dateClass: 'slds-truncate slds-text-title_bold ' + (isOverdue ? 'slds-text-color_error' : ''),
            rowClass: `slds-hint-parent task-row ${this.getRowClassByStatus(status)}`
          };
        });
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

        this.selectedTask = task; 
        
        const isCurrentlyCompleted = task.Completed;
        const newStatus = isCurrentlyCompleted ? 'Reopen' : 'Completed';

        if (isCurrentlyCompleted && this.currentModal !== 'confirm') {
            this.currentModal = 'confirm';
            return;
        }

        try {
            this.loading = true;
            await updateStatus({ taskId, status: newStatus });
            await this.loadTasks();

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
            this.loading = false;
            this.currentModal = null;
            // אנחנו לא מאפסים את selectedTask כאן כדי לא להרוס פונקציות אחרות
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