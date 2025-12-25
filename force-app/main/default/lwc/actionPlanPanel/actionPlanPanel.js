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
        this.plans = (result || []).map(p => this.buildPlan(p));
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

    buildPlan(p, existingPlan) {
      const completedTasks = p.Completed_Plan_Item__c ?? 0;
      const totalTasks = p.Total_Plan_Item__c ?? 0;

      return {
          ...p,
          OwnerName: p.Owner?.Name,
          Completed: p.Status__c === 'Completed',
          CompletedTasksString: `${completedTasks} of ${totalTasks}`,
          TaskListLabel: `View Task List (${totalTasks})`,
          badgeClass:
              'slds-badge slds-m-left_small ' +
              (p.Status__c === 'Completed'
                  ? 'slds-theme_success'
                  : p.Status__c === 'In Progress'
                  ? 'slds-theme_info'
                  : ''),
          tasksOpen: existingPlan?.tasksOpen ?? false
      };
    }


    async handleTaskStatusChange(event) {
      const planId = event.detail?.planId;
      if (!planId) return;

      try {
        const p = await getPlanById({ planId });
        this.plans = this.plans.map(existing =>
          existing.Id === planId
            ? this.buildPlan(p, existing)   // משתמשת בתצוגה הישנה רק בשביל tasksOpen
            : existing
        );
      } catch (e) {
        console.error('getPlanById error:', e?.body ?? e);
      }
    }


}