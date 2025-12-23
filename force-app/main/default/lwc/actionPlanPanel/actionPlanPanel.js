import { LightningElement, api, track, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import getPlans from '@salesforce/apex/ActionPlanPanelController.getPlans';

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

}