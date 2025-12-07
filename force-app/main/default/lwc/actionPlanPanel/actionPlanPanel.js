import { LightningElement, api, track, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';

const PLAN_QUERY = gql`
  query ($caseId: ID!) {
    uiapi {
      query {
        Plan__c(where: { Case__c: { eq: $caseId } }, orderBy: { Plan_Order__c: { order: DESC } }) {
          edges {
            node {
              Id
              Name { value }
              Status__c { value }
              Completed_Tasks__c { value }
              Total_Tasks__c { value }
              OwnerId { value }
              Start_Date__c { value }
              Due_Date__c { value }
              Progress__c { value }
              Plan_Order__c { value }
            }
          }
        }
      }
    }
  }
`;

export default class ActionPlanPanel extends LightningElement {
    activeSections = [];
    @track plans = [];    
    @api recordId;

    get planVars() {
      console.log('case:' + this.recordId);
      return this.recordId
          ? { caseId: this.recordId }
          : undefined;
    }

    @wire(graphql, { query: PLAN_QUERY, variables: '$planVars' })
    wiredPlan({ data, errors }) {
        if (data) {
            this.plans =
            data.uiapi?.query?.Plan__c?.edges?.map(e => ({
            Id: e.node.Id,
            Name: e.node.Name?.value,
            Status__c: e.node.Status__c?.value,
            Completed_Tasks__c: e.node.Completed_Tasks__c?.value,
            Total_Tasks__c: e.node.Total_Tasks__c?.value,
            OwnerId: e.node.OwnerId?.value,
            Start_Date__c: e.node.Start_Date__c?.value,
            Due_Date__c: e.node.Due_Date__c?.value,
            Progress__c: e.node.Progress__c?.value,
            Plan_Order__c: e.node.Plan_Order__c?.value,
            Completed: e.node.Status__c?.value === 'Completed',
            CompletedTasksString: `${e.node.Completed_Tasks__c?.value || 0} of ${e.node.Total_Tasks__c?.value || 0}`,
            isOpen: false
            })) ?? [];
        } else if (errors) {
          console.error('GraphQL errors:', JSON.stringify(errors));
        }
    }
    
    handleSectionToggle(event) {
        this.activeSections = event.detail.openSections;
    }

    handlePlanHeaderClick(event) {
        const planId = event.currentTarget.dataset.id;
        this.plans = this.plans.map(p => ({
            ...p,
            isOpen: p.Id === planId ? !p.isOpen : p.isOpen
        }));
    }
}