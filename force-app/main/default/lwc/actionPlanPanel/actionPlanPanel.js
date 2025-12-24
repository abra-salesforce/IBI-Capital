import { LightningElement, api, track, wire } from 'lwc';
import getPlans from '@salesforce/apex/ActionPlanPanelController.getPlans';
import getPlanById from '@salesforce/apex/ActionPlanPanelController.getPlanById';
export default class ActionPlanPanel extends LightningElement {
    activeSections = [];
    @track plans = [];    
    @api recordId;
    @api planLookupFieldApiName;

    connectedCallback() {
      this.loadPlans();
    }

    async loadPlans() {
      try {
        const result = await getPlans({ recordId: this.recordId, apiFieldName: this.planLookupFieldApiName });
        this.plans = (result || []).map(p => {
            const completedTasks = p.Completed_Plan_Item__c ?? 0;
            const totalTasks = p.Total_Plan_Item__c ?? 0;

            return {
              ...p,
              OwnerName: p.Owner?.Name,
              Completed: p.Status__c === 'Completed',
              CompletedTasksString: `${completedTasks} of ${totalTasks}`,
              TaskListLabel: `View Task List (${totalTasks})`,
              tasksOpen: false
            };
          });
      } catch (e) {
        console.error('getPlans error:', e?.body ?? e);
      }
    }

    get numberOfPlans() {
      return this.plans.length;
    }

    handleToggleTasks(event) {
      const planId = event.currentTarget.dataset.id;

      this.plans = this.plans.map(plan =>
          plan.Id === planId
              ? { ...plan, tasksOpen: !plan.tasksOpen }
              : plan
      );
    }
    get test(){
      return true;
    }

    async handleTaskStatusChange(event) {
      const planId = event.detail?.planId;
      if (!planId) return;

      try {
        const p = await getPlanById({ planId });

        const completedTasks = p.Completed_Plan_Item__c ?? 0;
        const totalTasks = p.Total_Plan_Item__c ?? 0;

        const refreshed = {
          ...p,
          OwnerName: p.Owner?.Name,
          Completed: p.Status__c === 'Completed',
          CompletedTasksString: `${completedTasks} of ${totalTasks}`,
          TaskListLabel: `View Task List (${totalTasks})`
        };

        this.plans = this.plans.map(existing =>
          existing.Id === planId
            ? { ...refreshed, tasksOpen: existing.tasksOpen } // שומרת אם הטבלה פתוחה
            : existing
        );
      } catch (e) {
        console.error('getPlanById error:', e?.body ?? e);
      }
    }


}