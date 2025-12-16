public with sharing class TaskPlanItemService {
    public static void linkTaskToPlanItem(List <Task> newTasks) {
        List<Plan_Item__c> planItemsToUpdate = new List<Plan_Item__c>();

        for (Task taskRecord : newTasks) {
            if (taskRecord.Plan_Item__c != null) {
                Plan_Item__c pi = new Plan_Item__c(Id = taskRecord.Plan_Item__c, Task_Id__c = taskRecord.Id);
                planItemsToUpdate.add(pi);
            }
        }

        if (planItemsToUpdate.size() > 0) {
            update planItemsToUpdate;
        }
    }

    public static void syncPlanItemStatus(List <Task> newTasks, Map <Id,Task> oldTasks){
        List<Plan_Item__c> planItemsToUpdate = new List<Plan_Item__c>();
        List<Task> completedTasks = new List<Task>();
        Map<Id, Task> oldCompletedTasks = new Map<Id, Task>();
        system.debug('syncPlanItemStatus');
        system.debug(newTasks);
        for(Task t : newTasks){
            if(t.Plan_Item__c != null && (oldTasks == null || t.status != oldTasks.get(t.Id).status)) {
                Plan_Item__c pi = new Plan_Item__c(Id = t.Plan_Item__c, Task_Status__c = t.Status);
                planItemsToUpdate.add(pi);
                if(t.Status == 'Completed'){
                    completedTasks.add(t);
                    oldCompletedTasks.put(t.Id, oldTasks != null ? oldTasks.get(t.Id) : null);
                    system.debug(t.Id);
                }
            }
        }
        
        if(planItemsToUpdate.size() > 0){
            update planItemsToUpdate;
        }
        if(completedTasks.size() > 0){
            completedTaskProcessing(completedTasks, oldCompletedTasks);
        }
    }

    public static void completedTaskProcessing(List<Task> tasks, Map<Id, Task> oldCompletedTasks) {
        List<Id> planItemsIds = new List<Id>();
        Map<Id,String> taskStatusMap = new Map<Id,String>();
        for(Task t : tasks) {
            if(t.Status == 'Completed' && t.Plan_Item__c != null) {
                planItemsIds.add(t.Plan_Item__c);
                Task oldT = oldCompletedTasks.get(t.Id);
                taskStatusMap.put(t.Plan_Item__c, oldT != null ? oldT.Status : 'Open');
            }
        }

        List<Plan_Item__c> dependentPlanItems = [SELECT Id, Previous_Plan_Item__c, Task_Id__c FROM Plan_Item__c WHERE Previous_Plan_Item__c IN :planItemsIds];
        List<Task> tasksToUpdate = new List<Task>();

        for(Plan_Item__c pi : dependentPlanItems) {
            if(pi.Task_Id__c != null) {
                Task t = new Task(Id = pi.Task_Id__c, Status = taskStatusMap.get(pi.Previous_Plan_Item__c));
                tasksToUpdate.add(t);
            }
        }

        if(tasksToUpdate.size() > 0) {
            update tasksToUpdate;
        }
    }

    public static void reopenTaskProcessing(List <Task> newTasks, Map <Id,Task> oldTasks) {
        Set<Id> taskIds = new Set<Id>();
        for(Task t : newTasks) {
            if(t.Status != oldTasks.get(t.Id).Status && oldTasks.get(t.Id).Status == 'Completed' && t.Status == 'Reopen') {
                taskIds.add(t.Id);
            }
        }

        List<Plan_Item__c> triggeredPlanItems = [SELECT Id, Plan__c FROM Plan_Item__c WHERE Task_Id__c IN :taskIds];
        Set<Id> planIds = new Set<Id>();
        for (Plan_Item__c pi : triggeredPlanItems) {
            if (pi.Plan__c != null) {
                planIds.add(pi.Plan__c);
            }
        }
        List<Plan_Item__c> planItems = [SELECT Id, Previous_Plan_Item__c, Task_Id__c FROM Plan_Item__c WHERE Plan__c IN :planIds];

        Map<Id,List<Plan_Item__c>> previousPerPI = new Map<Id,List<Plan_Item__c>>();

        for (Plan_Item__c pi : planItems) {
            if (pi.Previous_Plan_Item__c != null) {
                if (!previousPerPI.containsKey(pi.Previous_Plan_Item__c)) {
                    previousPerPI.put(pi.Previous_Plan_Item__c, new List<Plan_Item__c>());
                }
                previousPerPI.get(pi.Previous_Plan_Item__c).add(pi);
            }
        }

        List<Task> tasksToUpdate = new List<Task>();

        Set<Id> visited = new Set<Id>();
        List<Id> queue = new List<Id>();

        for (Plan_Item__c pi : triggeredPlanItems) {
            visited.add(pi.Id);
            queue.add(pi.Id);
        }

        Integer i = 0;
        while (i < queue.size()) {
            Id currentId = queue[i];
            i++;

            List<Plan_Item__c> children = previousPerPI.get(currentId);
            if (children == null) continue;

            for (Plan_Item__c child : children) {
                if (visited.contains(child.Id)) continue;

                visited.add(child.Id);
                queue.add(child.Id);

                if (child.Task_Id__c != null) {
                    tasksToUpdate.add(new Task(
                        Id = child.Task_Id__c,
                        Status = 'Waiting in Dependency'
                    ));
                }
            }
        }

        if(tasksToUpdate.size() > 0) {
            update tasksToUpdate;
        }
    }
}