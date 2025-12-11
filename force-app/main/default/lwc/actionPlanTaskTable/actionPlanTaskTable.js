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
            Completed: e.node.Status?.value === 'Completed'
            })) ?? [];
        } else if (errors) {
            console.error('GraphQL errors:', errors);
        }
    }
}