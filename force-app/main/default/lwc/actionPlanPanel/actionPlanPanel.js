import { LightningElement, api, track, wire } from 'lwc';
import getPlans from '@salesforce/apex/ActionPlanPanelController.getPlans';
import getPlanById from '@salesforce/apex/ActionPlanPanelController.getPlanById';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class ActionPlanPanel extends LightningElement {
    activeSections = [];
    @track plans = [];    
    @api recordId;
    @api planLookupFieldApiName;
    _refreshTimeout;

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

      this.plans = this.plans.map(plan => {
          if (plan.Id !== planId) {
              return plan;
          }

          const isOpen = !plan.tasksOpen;

          return {
              ...plan,
              tasksOpen: isOpen,
              iconName: isOpen
                  ? 'utility:chevrondown'
                  : 'utility:chevronright'
          };
      });
    }

    buildPlan(p, existingPlan) {
      const completedTasks = p.Completed_Plan_Item__c ?? 0;
      const totalTasks = p.Total_Plan_Item__c ?? 0;
      const tasksOpen = existingPlan?.tasksOpen ?? false;

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
          tasksOpen: existingPlan?.tasksOpen ?? false,
          iconName: tasksOpen ? 'utility:chevrondown' : 'utility:chevronright'
      };
    }

    async addMissingPlansInOrder() {
      try {
        const fresh = await getPlans({
          recordId: this.recordId,
          apiFieldName: this.planLookupFieldApiName
        });

        const existingById = new Map(this.plans.map(p => [p.Id, p]));

        this.plans = (fresh || []).map(p => {
          const existing = existingById.get(p.Id);
          return this.buildPlan(p, existing); 
        });
      } catch (e) {
        console.error('addMissingPlansInOrder error:', e?.body ?? e);
      }
    }

    handleRefreshPlansRequested() {
      window.clearTimeout(this._refreshTimeout);
      this._refreshTimeout = window.setTimeout(() => {
        this.addMissingPlansInOrder();
      }, 400);
    }



    async handleTaskStatusChange(event) {
      const planId = event.detail?.planId;
      if (!planId) return;

      try {
        const p = await getPlanById({ planId });
        this.plans = this.plans.map(existing =>
          existing.Id === planId
            ? this.buildPlan(p, existing)
            : existing
        );
      } catch (e) {
        console.error('getPlanById error:', e?.body ?? e);
      }
    }

    handleTaskSaved() {
        this.dispatchEvent(
            new ShowToastEvent({
                message: 'המשימה עודכנה בהצלחה',
                variant: 'success'
            })
        );
    }

    handleChildError(event) {
      const msg = event.detail?.message || 'שגיאה';
      this.dispatchEvent(
          new ShowToastEvent({
              title: 'שגיאה',
              message: msg,
              variant: 'error'
          })
      );
    }



}