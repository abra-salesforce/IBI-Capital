import { LightningElement, api, wire, track } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';

const PLAN_ITEM_QUERY = gql`
  query ($planId: ID!) {
    uiapi {
      query {
        Plan_Item__c(where: { Plan__c: { eq: $planId } }) {
          edges {
            node {
              Id
              Task_ID__c { value }
            }
          }
        }
      }
    }
  }
`;

const TASK_QUERY = gql`
  query ($taskIds: [ID!]!) {
    uiapi {
      query {
        Task(where: { Id: { in: $taskIds } }) {
          edges {
            node {
              Id
              Subject { value }
              Status { value }
              Description { value }
              ActivityDate { value }
              Owner {
                ... on User {
                  Id
                  Name { value }
                }
                ... on Group {
                  Id
                  Name { value }
                }
              }
            }
          }
        }
      }
    }
  }
`;

export default class ActionPlanTaskTable extends LightningElement {
    @api plan;
    @track taskIds = [];
    @track tasks = [];
    loading = true;
    @track selectedTask = null;

    get planItemVars() {
        return this.plan?.Id ? { planId: this.plan.Id } : undefined;
    }

    @wire(graphql, { query: PLAN_ITEM_QUERY, variables: '$planItemVars' })
    wiredPlanItems({ data, errors }) {
        if (data) {
            const edges = data.uiapi?.query?.Plan_Item__c?.edges || [];
            this.taskIds = edges
                .map(e => e.node.Task_ID__c?.value)
                .filter(id => !!id);
            console.log('taskIds = ', this.taskIds);
        } else if (errors) {
            console.error('GraphQL errors:', errors);
        }
    }

    get taskVars() {
        return this.taskIds.length > 0 ? { taskIds: this.taskIds } : undefined;
    }

    @wire(graphql, { query: TASK_QUERY, variables: '$taskVars' })
    wiredTasks({ data, errors }) {
        if (data) {
            console.log('Tasks data = ', data);
            this.tasks =
            data.uiapi?.query?.Task?.edges?.map(e => ({
            Id: e.node.Id,
            Subject: e.node.Subject?.value,
            Status: e.node.Status?.value,
            Date: e.node.ActivityDate?.value,
            AssignedTo: e.node.Owner?.Name?.value,
            Description: e.node.Description?.value,
            Completed: e.node.Status?.value === 'Completed',
            checkboxLabel: e.node.Status?.value === 'Completed' ? 'Completed' : 'Mark as completed'
            })) ?? [];
            this.loading = false;
        } else if (errors) {
            console.error('GraphQL errors:', errors);
        }
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
}